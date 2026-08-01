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
    }

    private struct PendingSeek {
        let requestedAt: TimeInterval
        let target: Double
        let bufferHit: Bool
    }

    init() {
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
        lastConfiguration = Configuration(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer)
        if mpv == nil {
            do {
                try createMPV()
            } catch {
                snapshot.errorMessage = error.localizedDescription
                emitOnMain()
                return
            }
        }
        load(url: url, headers: headers, preferredForwardBuffer: preferredForwardBuffer, startPosition: startPosition)
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
        snapshot.position = target
        snapshot.didReachEnd = false
        snapshot.isBuffering = true
        snapshot.waitingReason = "MPV seek"
        emitOnMain()

        queue.async { [weak self] in
            guard let self, let handle = self.mpv else { return }
            self.command(handle, ["seek", String(format: "%.3f", target), "absolute+keyframes"])
        }
    }

    func reload(at seconds: Double) {
        guard let configuration = lastConfiguration else { return }
        load(
            url: configuration.url,
            headers: configuration.headers,
            preferredForwardBuffer: configuration.preferredForwardBuffer,
            startPosition: seconds
        )
    }

    func stop() {
        guard let handle = mpv, !isStopping else { return }
        isStopping = true
        mpv_set_wakeup_callback(handle, nil, nil)

        queue.sync {
            self.commandSync(handle, ["quit"])
        }

        mpv = nil
        pendingSeek = nil
        DispatchQueue.global(qos: .userInitiated).async {
            mpv_terminate_destroy(handle)
        }
        DispatchQueue.main.async { [weak self] in
            self?.displayLayer.flushAndRemoveImage()
        }
        snapshot = PlayerSnapshot()
        isStopping = false
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
        check(mpv_set_option_string(handle, "ao", "avfoundation"), operation: "set ao")
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
        check(mpv_set_option_string(handle, "hr-seek", "no"), operation: "fast seek")
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

    private func load(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {
        snapshot = PlayerSnapshot(position: max(0, startPosition), isBuffering: true, waitingReason: "MPV loading")
        emitOnMain()

        queue.async { [weak self] in
            guard let self, let handle = self.mpv else { return }
            self.command(handle, ["stop"])
            self.updateHTTPHeaders(handle: handle, headers: headers)

            let cacheSeconds = max(30, Int(preferredForwardBuffer.rounded()))
            self.setProperty(handle: handle, name: "cache", value: "yes")
            self.setProperty(handle: handle, name: "cache-secs", value: String(cacheSeconds))
            self.setProperty(handle: handle, name: "demuxer-max-bytes", value: "512MiB")
            self.setProperty(handle: handle, name: "demuxer-max-back-bytes", value: "128MiB")
            self.setProperty(handle: handle, name: "demuxer-seekable-cache", value: "yes")
            self.setProperty(handle: handle, name: "start", value: String(format: "%.3f", max(0, startPosition)))

            let target = url.isFileURL ? url.path : url.absoluteString
            self.command(handle, ["loadfile", target, "replace"])
        }
    }

    private func observeProperties(_ handle: OpaquePointer) {
        let properties: [(String, mpv_format)] = [
            ("duration", MPV_FORMAT_DOUBLE),
            ("time-pos", MPV_FORMAT_DOUBLE),
            ("pause", MPV_FORMAT_FLAG),
            ("paused-for-cache", MPV_FORMAT_FLAG),
            ("demuxer-cache-duration", MPV_FORMAT_DOUBLE)
        ]
        for (name, format) in properties {
            mpv_observe_property(handle, 0, name, format)
        }
    }

    private func processEvents() {
        queue.async { [weak self] in
            guard let self, !self.isStopping else { return }
            while let handle = self.mpv, let eventPointer = mpv_wait_event(handle, 0) {
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
            emitOnMain()
        case MPV_EVENT_SEEK:
            snapshot.isBuffering = true
            snapshot.waitingReason = "MPV seek"
            emitOnMain()
        case MPV_EVENT_PLAYBACK_RESTART:
            snapshot.isBuffering = false
            snapshot.waitingReason = nil
            if let pending = pendingSeek {
                pendingSeek = nil
                let latency = (CACurrentMediaTime() - pending.requestedAt) * 1000
                DispatchQueue.main.async { [weak self] in
                    self?.onSeekCompleted?(SeekResult(
                        requestedAt: pending.requestedAt,
                        target: pending.target,
                        bufferHit: pending.bufferHit,
                        completionLatencyMs: latency,
                        measurement: "MPV 恢复播放"
                    ))
                }
            }
            emitOnMain()
        case MPV_EVENT_END_FILE:
            if !isStopping {
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
        default:
            break
        }
    }

    private func rebuildBufferedRange() {
        guard let current = snapshot.bufferedRanges.first else { return }
        let length = max(0, current.upperBound - current.lowerBound)
        snapshot.bufferedRanges = [snapshot.position...(snapshot.position + length)]
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
        check(status, operation: "set \(name)")
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
