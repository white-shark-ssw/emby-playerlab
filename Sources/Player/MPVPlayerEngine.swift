import AVFoundation
import Foundation
import MPVKit
import QuartzCore
import UIKit

final class MPVPlayerEngine: PlayerEngine {
    let kind: PlayerEngineKind = .mpv
    var onSnapshot: ((PlayerSnapshot) -> Void)?
    var onSeekCompleted: ((SeekResult) -> Void)?

    let displayLayer = AVSampleBufferDisplayLayer()

    private let queue = DispatchQueue(label: "com.embyplayerlab.mpv", qos: .userInitiated)
    private let queueKey = DispatchSpecificKey<UInt8>()
    private var mpv: OpaquePointer?
    private var snapshot = PlayerSnapshot()
    private var pendingSeek: PendingSeek?
    private var lastConfiguration: Configuration?
    private var isStopping = false
    private var lastPositionEmission: TimeInterval = 0

    private struct Configuration {
        let url: URL
        let headers: [String: String]
        let preferredForwardBuffer: Double
        let compatibilityMode: Bool
    }

    private struct PendingSeek {
        let requestedAt: TimeInterval
        let target: Double
        let bufferHit: Bool
    }

    init() {
        queue.setSpecific(key: queueKey, value: 1)
        displayLayer.backgroundColor = UIColor.black.cgColor
        displayLayer.videoGravity = .resizeAspect
        if #available(iOS 17.0, *) {
            displayLayer.wantsExtendedDynamicRangeContent = true
        }
    }

    deinit {
        stop()
    }

    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        lastConfiguration = Configuration(
            url: url,
            headers: headers,
            preferredForwardBuffer: preferredForwardBuffer,
            compatibilityMode: false
        )
        if mpv == nil {
            do {
                try createMPV()
            } catch {
                snapshot.errorMessage = error.localizedDescription
                emitOnMain()
                return
            }
        }
        load(
            url: url,
            headers: headers,
            preferredForwardBuffer: preferredForwardBuffer,
            startPosition: startPosition,
            compatibilityMode: false
        )
    }

    func reloadForBadInterleavedMP4(
        url: URL,
        headers: [String: String],
        preferredForwardBuffer: Double,
        startPosition: Double,
        reason: String
    ) {
        lastConfiguration = Configuration(
            url: url,
            headers: headers,
            preferredForwardBuffer: preferredForwardBuffer,
            compatibilityMode: true
        )
        DiagnosticsLogger.shared.log(
            "MPVCompatibility",
            "reload reason=\(reason) start=\(startPosition) mode=bad-interleaved-mp4"
        )
        load(
            url: url,
            headers: headers,
            preferredForwardBuffer: preferredForwardBuffer,
            startPosition: startPosition,
            compatibilityMode: true
        )
    }

    func play() {
        setPropertyAsync(name: "pause", value: "no")
    }

    func pause() {
        setPropertyAsync(name: "pause", value: "yes")
    }

    func seek(to seconds: Double, direction: SeekDirection) {
        let duration = snapshot.duration
        let target = min(max(0, seconds), duration > 0 ? duration : seconds)
        let bufferHit = snapshot.bufferedRanges.contains(where: { $0.contains(target) })
        pendingSeek = PendingSeek(requestedAt: CACurrentMediaTime(), target: target, bufferHit: bufferHit)
        // Never overwrite time-pos with the requested target. MPV may land on an
        // earlier keyframe, especially for malformed remote MP4 files.
        snapshot.didReachEnd = false
        snapshot.isBuffering = true
        snapshot.waitingReason = "MPV seek"
        emitOnMain()

        queue.async { [weak self] in
            guard let self, let handle = self.mpv else { return }
            // Always use keyframe seek for remote media. Exact seek can decode through
            // malformed timestamp regions and caused item 63368 to stall again.
            let mode = "absolute+keyframes"
            DiagnosticsLogger.shared.log(
                "MPVSeekRequest",
                "target=\(target) mode=\(mode) bufferHit=\(bufferHit) enginePosition=\(self.snapshot.position)"
            )
            self.command(handle, ["seek", String(format: "%.3f", target), mode])
        }
    }

    func reload(at seconds: Double) {
        guard let configuration = lastConfiguration else { return }
        load(
            url: configuration.url,
            headers: configuration.headers,
            preferredForwardBuffer: configuration.preferredForwardBuffer,
            startPosition: seconds,
            compatibilityMode: configuration.compatibilityMode
        )
    }

    func stop() {
        guard !isStopping else { return }
        guard let handle = mpv else { return }
        isStopping = true
        DiagnosticsLogger.shared.log("MPVLifecycle", "stop begin")

        // Prevent new callbacks before touching the handle.
        mpv_set_wakeup_callback(handle, nil, nil)
        pendingSeek = nil

        let shutdown = { [self] in
            _ = commandSync(handle, ["quit"])

            // Drain events already produced by quit before destroying the handle.
            var drainCount = 0
            while drainCount < 100, let event = mpv_wait_event(handle, 0.02)?.pointee {
                if event.event_id == MPV_EVENT_NONE || event.event_id == MPV_EVENT_SHUTDOWN {
                    break
                }
                drainCount += 1
            }
            DiagnosticsLogger.shared.log("MPVLifecycle", "events drained=\(drainCount)")
        }

        if DispatchQueue.getSpecific(key: queueKey) != nil {
            shutdown()
        } else {
            queue.sync(execute: shutdown)
        }

        // Clear the shared handle before asynchronous destruction so no queued work can reuse it.
        mpv = nil
        snapshot = PlayerSnapshot()

        let flushLayer = { [displayLayer] in
            displayLayer.flushAndRemoveImage()
        }
        if Thread.isMainThread {
            flushLayer()
        } else {
            DispatchQueue.main.sync(execute: flushLayer)
        }

        DispatchQueue.global(qos: .userInitiated).async {
            mpv_terminate_destroy(handle)
            DiagnosticsLogger.shared.log("MPVLifecycle", "terminate_destroy finished")
        }

        // Keep isStopping true. createMPV() resets it for a fresh handle.
        DiagnosticsLogger.shared.log("MPVLifecycle", "stop detached")
    }

    private func createMPV() throws {
        guard let handle = mpv_create() else {
            throw MPVEngineError.creationFailed
        }
        mpv = handle
        isStopping = false

        check(mpv_request_log_messages(handle, "warn"), operation: "request logs")

        let layerAddress = Int(bitPattern: Unmanaged.passUnretained(displayLayer).toOpaque())
        var wid = Int64(layerAddress)
        try require(mpv_set_option(handle, "wid", MPV_FORMAT_INT64, &wid), operation: "set AVSampleBufferDisplayLayer")
        try require(mpv_set_option_string(handle, "vo", "avfoundation"), operation: "enable vo_avfoundation")
        // Do not force ao=avfoundation: this fork provides vo_avfoundation, not ao_avfoundation.
        // Let mpv select the compiled iOS audio backend automatically.
        #if targetEnvironment(simulator)
        check(mpv_set_option_string(handle, "avfoundation-composite-osd", "no"), operation: "set composite osd")
        #else
        check(mpv_set_option_string(handle, "avfoundation-composite-osd", "yes"), operation: "set composite osd")
        #endif
        check(mpv_set_option_string(handle, "hwdec", "videotoolbox"), operation: "set hwdec")
        check(mpv_set_option_string(handle, "hwdec-codecs", "all"), operation: "set hwdec codecs")
        check(mpv_set_option_string(handle, "hwdec-software-fallback", "yes"), operation: "set hw fallback")
        check(mpv_set_option_string(handle, "cache", "yes"), operation: "enable cache")
        check(mpv_set_option_string(handle, "demuxer-seekable-cache", "yes"), operation: "seekable cache")
        check(mpv_set_option_string(handle, "hr-seek", "no"), operation: "disable precise seek")
        check(mpv_set_option_string(handle, "network-timeout", "30"), operation: "network timeout")
        check(mpv_set_option_string(handle, "sub-auto", "fuzzy"), operation: "subtitle auto")

        let status = mpv_initialize(handle)
        guard status >= 0 else {
            mpv = nil
            mpv_terminate_destroy(handle)
            throw MPVEngineError.initializationFailed(status)
        }

        observeProperties(handle)
        mpv_set_wakeup_callback(handle, { context in
            guard let context else { return }
            let engine = Unmanaged<MPVPlayerEngine>.fromOpaque(context).takeUnretainedValue()
            engine.processEvents()
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    private func load(
        url: URL,
        headers: [String: String],
        preferredForwardBuffer: Double,
        startPosition: Double,
        compatibilityMode: Bool
    ) {
        snapshot = PlayerSnapshot(
            position: max(0, startPosition),
            isBuffering: true,
            waitingReason: compatibilityMode ? "MPV compatibility loading" : "MPV loading"
        )
        pendingSeek = nil
        emitOnMain()

        queue.async { [weak self] in
            guard let self, let handle = self.mpv, !self.isStopping else { return }

            // Keep one libmpv handle. Stop the current file synchronously, update
            // per-file options, then use loadfile replace like Streamyfin.
            _ = self.commandSync(handle, ["stop"])
            self.updateHTTPHeaders(handle: handle, headers: headers)

            let cacheSeconds = max(30, Int(preferredForwardBuffer.rounded()))
            self.setProperty(handle: handle, name: "cache", value: "yes")
            self.setProperty(handle: handle, name: "cache-secs", value: String(cacheSeconds))
            self.setProperty(handle: handle, name: "demuxer-max-bytes", value: "512MiB")

            if compatibilityMode {
                // FFmpeg MOV/MP4 workaround for badly interleaved audio/video tracks.
                // Avoid cache-internal seeks and do not freeze playback merely because
                // the demuxer has only a small amount of data queued.
                self.setProperty(handle: handle, name: "demuxer-lavf-o", value: "interleaved_read=0")
                self.setProperty(handle: handle, name: "demuxer-seekable-cache", value: "no")
                self.setProperty(handle: handle, name: "demuxer-max-back-bytes", value: "0")
                self.setProperty(handle: handle, name: "cache-pause", value: "no")
                self.setProperty(handle: handle, name: "cache-pause-wait", value: "0")
            } else {
                self.clearProperty(handle: handle, name: "demuxer-lavf-o")
                self.setProperty(handle: handle, name: "demuxer-seekable-cache", value: "auto")
                self.setProperty(handle: handle, name: "demuxer-max-back-bytes", value: "128MiB")
                self.setProperty(handle: handle, name: "cache-pause", value: "yes")
                self.setProperty(handle: handle, name: "cache-pause-wait", value: "1")
            }

            self.setProperty(handle: handle, name: "start", value: String(format: "%.3f", max(0, startPosition)))

            DiagnosticsLogger.shared.log(
                "MPVLoad",
                "mode=\(compatibilityMode ? "bad-interleaved-mp4" : "normal") start=\(startPosition) cacheSecs=\(cacheSeconds)"
            )

            let target = url.isFileURL ? url.path : url.absoluteString
            _ = self.commandSync(handle, ["loadfile", target, "replace"])
        }
    }

    private func observeProperties(_ handle: OpaquePointer) {
        let properties: [(String, mpv_format)] = [
            ("duration", MPV_FORMAT_DOUBLE),
            ("time-pos", MPV_FORMAT_DOUBLE),
            ("pause", MPV_FORMAT_FLAG),
            ("paused-for-cache", MPV_FORMAT_FLAG),
            ("demuxer-cache-duration", MPV_FORMAT_DOUBLE),
            ("current-ao", MPV_FORMAT_STRING),
            ("aid", MPV_FORMAT_STRING),
            ("audio-params", MPV_FORMAT_STRING),
            ("demuxer-cache-idle", MPV_FORMAT_FLAG),
            ("seekable", MPV_FORMAT_FLAG),
            ("partially-seekable", MPV_FORMAT_FLAG),
            ("demuxer-via-network", MPV_FORMAT_FLAG)
        ]
        for (name, format) in properties {
            mpv_observe_property(handle, 0, name, format)
        }
    }

    private func processEvents() {
        queue.async { [weak self] in
            guard let self, !self.isStopping else { return }
            while !self.isStopping, let handle = self.mpv, let eventPointer = mpv_wait_event(handle, 0) {
                let event = eventPointer.pointee
                if event.event_id == MPV_EVENT_NONE { break }
                self.handle(event: event, handle: handle)
                if event.event_id == MPV_EVENT_SHUTDOWN { break }
            }
        }
    }

    private func handle(event: mpv_event, handle: OpaquePointer) {
        switch event.event_id {
        case MPV_EVENT_FILE_LOADED:
            snapshot.isBuffering = false
            snapshot.waitingReason = nil
            logAudioState(handle: handle, reason: "file-loaded")
            emitOnMain()
        case MPV_EVENT_SEEK:
            snapshot.isBuffering = true
            snapshot.waitingReason = "MPV seek"
            emitOnMain()
        case MPV_EVENT_PLAYBACK_RESTART:
            snapshot.isBuffering = false
            snapshot.waitingReason = nil

            var actualPosition = snapshot.position
            var queriedPosition = Double(0)
            if getProperty(handle: handle, name: "time-pos", format: MPV_FORMAT_DOUBLE, value: &queriedPosition) >= 0,
               queriedPosition.isFinite {
                actualPosition = queriedPosition
                snapshot.position = queriedPosition
            }

            if let pending = pendingSeek {
                pendingSeek = nil
                let latency = (CACurrentMediaTime() - pending.requestedAt) * 1000
                DiagnosticsLogger.shared.log(
                    "MPVSeekLanding",
                    "target=\(pending.target) actual=\(actualPosition) delta=\(actualPosition - pending.target)"
                )
                DispatchQueue.main.async { [weak self] in
                    self?.onSeekCompleted?(SeekResult(
                        requestedAt: pending.requestedAt,
                        target: pending.target,
                        actualPosition: actualPosition,
                        bufferHit: pending.bufferHit,
                        completionLatencyMs: latency,
                        measurement: "MPV 恢复播放"
                    ))
                }
            }
            emitOnMain()
        case MPV_EVENT_END_FILE:
            if !isStopping {
                var reasonValue: Int32 = -1
                var errorValue: Int32 = 0
                if let data = event.data?.assumingMemoryBound(to: mpv_event_end_file.self) {
                    reasonValue = Int32(data.pointee.reason.rawValue)
                    errorValue = data.pointee.error
                }
                DiagnosticsLogger.shared.log(
                    "MPVEndFile",
                    "reason=\(reasonValue) error=\(errorValue) position=\(snapshot.position) duration=\(snapshot.duration)"
                )
                snapshot.didReachEnd = true
                snapshot.isPlaying = false
                emitOnMain()
            }
        case MPV_EVENT_PROPERTY_CHANGE:
            if let namePointer = event.data?.assumingMemoryBound(to: mpv_event_property.self).pointee.name {
                refreshProperty(name: String(cString: namePointer), handle: handle)
            }
        case MPV_EVENT_LOG_MESSAGE:
            if let message = event.data?.assumingMemoryBound(to: mpv_event_log_message.self).pointee {
                let prefix = String(cString: message.prefix)
                let text = String(cString: message.text).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    DiagnosticsLogger.shared.log("MPV", "[\(prefix)] \(text)")
                }
            }
        case MPV_EVENT_SHUTDOWN:
            DiagnosticsLogger.shared.log("MPV", "shutdown")
        default:
            break
        }
    }

    private func refreshProperty(name: String, handle: OpaquePointer) {
        switch name {
        case "duration":
            var value = Double(0)
            if getProperty(handle: handle, name: name, format: MPV_FORMAT_DOUBLE, value: &value) >= 0, value.isFinite, value > 0 {
                snapshot.duration = value
                rebuildBufferedRange()
                emitOnMain()
            }
        case "time-pos":
            var value = Double(0)
            if getProperty(handle: handle, name: name, format: MPV_FORMAT_DOUBLE, value: &value) >= 0, value.isFinite {
                snapshot.position = value
                rebuildBufferedRange()
                let now = CACurrentMediaTime()
                if pendingSeek != nil || now - lastPositionEmission >= 0.25 {
                    lastPositionEmission = now
                    emitOnMain()
                }
            }
        case "pause":
            var flag = Int32(0)
            if getProperty(handle: handle, name: name, format: MPV_FORMAT_FLAG, value: &flag) >= 0 {
                snapshot.isPlaying = flag == 0
                emitOnMain()
            }
        case "paused-for-cache":
            var flag = Int32(0)
            if getProperty(handle: handle, name: name, format: MPV_FORMAT_FLAG, value: &flag) >= 0 {
                snapshot.isBuffering = flag != 0
                snapshot.waitingReason = flag != 0 ? "MPV paused-for-cache" : nil
                emitOnMain()
            }
        case "demuxer-cache-duration":
            var seconds = Double(0)
            if getProperty(handle: handle, name: name, format: MPV_FORMAT_DOUBLE, value: &seconds) >= 0, seconds.isFinite {
                let end = max(snapshot.position, snapshot.position + max(0, seconds))
                snapshot.bufferedRanges = [snapshot.position...end]
                emitOnMain()
            }
        case "current-ao", "aid", "audio-params":
            let value = getStringProperty(handle: handle, name: name) ?? "nil"
            DiagnosticsLogger.shared.log("MPVAudio", "\(name)=\(value)")
        case "demuxer-cache-idle", "seekable", "partially-seekable", "demuxer-via-network":
            var flag = Int32(0)
            if getProperty(handle: handle, name: name, format: MPV_FORMAT_FLAG, value: &flag) >= 0 {
                DiagnosticsLogger.shared.log("MPVNetwork", "\(name)=\(flag != 0)")
            }
        default:
            break
        }
    }

    private func rebuildBufferedRange() {
        guard let current = snapshot.bufferedRanges.first else { return }
        let length = max(0, current.upperBound - current.lowerBound)
        snapshot.bufferedRanges = [snapshot.position...(snapshot.position + length)]
    }

    private func getStringProperty(handle: OpaquePointer, name: String) -> String? {
        guard let pointer = mpv_get_property_string(handle, name) else { return nil }
        defer { mpv_free(pointer) }
        return String(cString: pointer)
    }

    private func logAudioState(handle: OpaquePointer, reason: String) {
        let currentAO = getStringProperty(handle: handle, name: "current-ao") ?? "nil"
        let aid = getStringProperty(handle: handle, name: "aid") ?? "nil"
        let audioParams = getStringProperty(handle: handle, name: "audio-params") ?? "nil"
        DiagnosticsLogger.shared.log(
            "MPVAudio",
            "reason=\(reason) currentAO=\(currentAO) aid=\(aid) audioParams=\(audioParams)"
        )
    }

    private func updateHTTPHeaders(handle: OpaquePointer, headers: [String: String]) {
        guard !headers.isEmpty else {
            mpv_set_property(handle, "http-header-fields", MPV_FORMAT_NONE, nil)
            return
        }
        let value = headers.map { "\($0.key): \($0.value)" }.joined(separator: "\r\n")
        setProperty(handle: handle, name: "http-header-fields", value: value)
    }

    private func setPropertyAsync(name: String, value: String) {
        queue.async { [weak self] in
            guard let self, let handle = self.mpv else { return }
            self.setProperty(handle: handle, name: name, value: value)
        }
    }

    private func setProperty(handle: OpaquePointer, name: String, value: String) {
        let status = mpv_set_property_string(handle, name, value)
        check(status, operation: "set \(name)=\(value)")
    }

    private func clearProperty(handle: OpaquePointer, name: String) {
        let status = mpv_set_property(handle, name, MPV_FORMAT_NONE, nil)
        check(status, operation: "clear \(name)")
    }

    private func command(_ handle: OpaquePointer, _ arguments: [String]) {
        guard !arguments.isEmpty else { return }
        withCStringArray(arguments) { pointer in
            _ = mpv_command_async(handle, 0, pointer)
        }
    }

    @discardableResult
    private func commandSync(_ handle: OpaquePointer, _ arguments: [String]) -> Int32 {
        guard !arguments.isEmpty else { return -1 }
        return withCStringArray(arguments) { pointer in
            mpv_command(handle, pointer)
        }
    }

    @discardableResult
    private func getProperty<T>(handle: OpaquePointer, name: String, format: mpv_format, value: inout T) -> Int32 {
        withUnsafeMutablePointer(to: &value) { pointer in
            mpv_get_property(handle, name, format, pointer)
        }
    }

    private func check(_ status: Int32, operation: String) {
        guard status < 0 else { return }
        let message = String(cString: mpv_error_string(status))
        DiagnosticsLogger.shared.log("MPV", "\(operation) failed: \(message) (\(status))")
    }

    private func require(_ status: Int32, operation: String) throws {
        guard status < 0 else { return }
        let message = String(cString: mpv_error_string(status))
        DiagnosticsLogger.shared.log("MPV", "\(operation) failed: \(message) (\(status))")
        throw MPVEngineError.requiredVideoOutputUnavailable(operation, status, message)
    }

    private func emitOnMain() {
        let value = snapshot
        DispatchQueue.main.async { [weak self] in
            self?.onSnapshot?(value)
        }
    }

    @inline(__always)
    private func withCStringArray<Result>(
        _ arguments: [String],
        body: (UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> Result
    ) -> Result {
        var strings = arguments.map { strdup($0) }
        strings.append(nil)
        defer {
            for pointer in strings where pointer != nil {
                free(pointer)
            }
        }
        return strings.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: buffer.count) { rebound in
                body(UnsafeMutablePointer(mutating: rebound))
            }
        }
    }
}

enum MPVEngineError: LocalizedError {
    case creationFailed
    case initializationFailed(Int32)
    case requiredVideoOutputUnavailable(String, Int32, String)

    var errorDescription: String? {
        switch self {
        case .creationFailed:
            return "无法创建 MPV 实例。"
        case .initializationFailed(let status):
            return "MPV 初始化失败：\(status)。"
        case .requiredVideoOutputUnavailable(let operation, let status, let message):
            return "MPV 视频输出不可用：\(operation)，\(message)（\(status)）。"
        }
    }
}
