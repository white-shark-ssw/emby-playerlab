from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, got {count}")
    return text.replace(old, new, 1)


app = Path("Sources/Core/AppIdentity.swift")
text = app.read_text()
if '"0.13.70"' not in text:
    count = text.count('"0.13.69"')
    if count != 2:
        raise SystemExit(f"AppIdentity version anchors: expected 2, got {count}")
    text = text.replace('"0.13.69"', '"0.13.70"')
    app.write_text(text)

transport = Path("Sources/Transport/TransportDataSession.swift")
text = transport.read_text()
old_protocol = '''    func read(offset: Int64, length: Int) async throws -> Data
    func prioritizeSeek(position: Double, duration: Double) async
'''
new_protocol = '''    func read(offset: Int64, length: Int) async throws -> Data
    func readCachedMetadata(offset: Int64, length: Int) async -> Data?
    func prioritizeSeek(position: Double, duration: Double) async
'''
if 'func readCachedMetadata(offset: Int64, length: Int) async -> Data?' not in text:
    text = replace_once(text, old_protocol, new_protocol, "cached metadata protocol")
old_extension = '''extension TransportDataSession {
    func noteDemand(range: Range<Int64>) async {}
'''
new_extension = '''extension TransportDataSession {
    func noteDemand(range: Range<Int64>) async {}
    func readCachedMetadata(offset: Int64, length: Int) async -> Data? { nil }
'''
if 'func readCachedMetadata(offset: Int64, length: Int) async -> Data? { nil }' not in text:
    text = replace_once(text, old_extension, new_extension, "cached metadata default")
transport.write_text(text)

download = Path("Sources/Transport/DownloadFirstMediaSession.swift")
text = download.read_text()
read_anchor = '''        metricsValue.elapsedSeconds = Date().timeIntervalSince(createdAt)
        return data
    }

    func prioritizeSeek(position: Double, duration: Double) async {
'''
read_cached = '''        metricsValue.elapsedSeconds = Date().timeIntervalSince(createdAt)
        return data
    }

    func readCachedMetadata(offset: Int64, length: Int) async -> Data? {
        guard !stopped, length > 0, let resource = try? await resolve(), offset >= 0, offset < resource.contentLength, let store else { return nil }
        let requestedLength = min(length, Int(resource.contentLength - offset))
        guard requestedLength > 0 else { return Data() }
        for attempt in 0..<8 {
            guard !Task.isCancelled else { return nil }
            let available = store.availableLength(from: offset, maximumLength: Int64(requestedLength))
            if available > 0 {
                let count = min(requestedLength, Int(available))
                return try? await store.readWhenAvailable(offset: offset, maximumLength: count, timeout: 0)
            }
            if attempt < 7 { try? await Task.sleep(nanoseconds: 50_000_000) }
        }
        return nil
    }

    func prioritizeSeek(position: Double, duration: Double) async {
'''
if 'func readCachedMetadata(offset: Int64, length: Int) async -> Data?' not in text:
    text = replace_once(text, read_anchor, read_cached, "download-first cached metadata")
download.write_text(text)

logger = Path("Sources/Diagnostics/DiagnosticsLogger.swift")
text = logger.read_text()
write_anchor = '''    private func write(channel: DiagnosticsLogChannel, category: String, message: String) {
        guard UserDefaults.standard.bool(forKey: channel.enabledKey) else {
'''
write_replacement = '''    private func write(channel: DiagnosticsLogChannel, category: String, message: String) {
        if shouldSuppressHighFrequencyEvent(category: category, message: message) { return }
        guard UserDefaults.standard.bool(forKey: channel.enabledKey) else {
'''
if 'shouldSuppressHighFrequencyEvent(category: category, message: message)' not in text:
    text = replace_once(text, write_anchor, write_replacement, "diagnostics suppression hook")
playback_anchor = '''    private func playbackCategory(_ category: String, message: String) -> Bool {
'''
suppression = '''    private func shouldSuppressHighFrequencyEvent(category: String, message: String) -> Bool {
        guard category == "SeekTransportRead" else { return false }
        if message.contains("phase=begin") { return true }
        guard message.contains("phase=end"), let marker = message.range(of: "waitMs=") else { return false }
        let suffix = message[marker.upperBound...]
        let token = suffix.prefix { $0.isNumber || $0 == "." || $0 == "-" }
        guard let waitMs = Double(token) else { return false }
        return waitMs < 5
    }

    private func playbackCategory(_ category: String, message: String) -> Bool {
'''
if 'private func shouldSuppressHighFrequencyEvent' not in text:
    text = replace_once(text, playback_anchor, suppression, "diagnostics high-frequency filter")
logger.write_text(text)

probe = Path("Sources/Player/MPVKeyframeIndexProbe.swift")
probe.write_text(r'''import Foundation

struct OnePlayerKeyframeNeighbors {
    let previous: Double?
    let next: Double?
    let nearest: Double?
}

struct OnePlayerKeyframeIndex {
    let keyframes: [Double]
    let videoStreamIndex: Int32
    let timeBaseSeconds: Double
    let streamStartSeconds: Double

    func neighbors(around target: Double) -> OnePlayerKeyframeNeighbors {
        guard !keyframes.isEmpty else { return OnePlayerKeyframeNeighbors(previous: nil, next: nil, nearest: nil) }
        var low = 0
        var high = keyframes.count
        while low < high {
            let mid = low + (high - low) / 2
            if keyframes[mid] < target { low = mid + 1 }
            else { high = mid }
        }
        if low < keyframes.count, abs(keyframes[low] - target) < 0.0005 {
            let exact = keyframes[low]
            return OnePlayerKeyframeNeighbors(previous: exact, next: exact, nearest: exact)
        }
        let previous = low > 0 ? keyframes[low - 1] : nil
        let next = low < keyframes.count ? keyframes[low] : nil
        let nearest: Double?
        switch (previous, next) {
        case let (previous?, next?): nearest = abs(target - previous) <= abs(next - target) ? previous : next
        case let (previous?, nil): nearest = previous
        case let (nil, next?): nearest = next
        default: nearest = nil
        }
        return OnePlayerKeyframeNeighbors(previous: previous, next: next, nearest: nearest)
    }
}

enum OnePlayerKeyframeIndexBuildResult {
    case ready(OnePlayerKeyframeIndex)
    case unavailable(String)
}

#if canImport(Libavformat) && canImport(Libavutil)
import Libavformat
import Libavutil

private final class OnePlayerKeyframeReadBox: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private var data: Data?

    func store(_ value: Data?) {
        lock.lock(); data = value; completed = true; lock.unlock()
    }

    func load() -> (Bool, Data?) {
        lock.lock(); defer { lock.unlock() }
        return (completed, data)
    }
}

private final class OnePlayerKeyframeAVIOState: @unchecked Sendable {
    let session: TransportDataSession
    let contentLength: Int64
    private let lock = NSLock()
    private var offset: Int64 = 0
    private var cancelled = false

    init(session: TransportDataSession, contentLength: Int64) {
        self.session = session
        self.contentLength = contentLength
    }

    func read(into buffer: UnsafeMutablePointer<UInt8>, maximumLength: Int32) -> Int32 {
        guard maximumLength > 0 else { return 0 }
        lock.lock()
        let current = offset
        let cancelledNow = cancelled
        lock.unlock()
        guard !cancelledNow else { return -5 }
        guard current < contentLength else { return 0 }
        let requested = min(Int(maximumLength), Int(contentLength - current))
        let semaphore = DispatchSemaphore(value: 0)
        let box = OnePlayerKeyframeReadBox()
        let task = Task { [session] in
            box.store(await session.readCachedMetadata(offset: current, length: requested))
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + 1.0) == .timedOut {
            task.cancel()
            return -5
        }
        let result = box.load()
        guard result.0, let data = result.1, !data.isEmpty else { return -5 }
        data.withUnsafeBytes { raw in
            if let base = raw.baseAddress { memcpy(buffer, base, data.count) }
        }
        lock.lock()
        if !cancelled, offset == current { offset = min(contentLength, current + Int64(data.count)) }
        lock.unlock()
        return Int32(data.count)
    }

    func seek(to requestedOffset: Int64, whence: Int32) -> Int64 {
        let baseWhence = whence & ~Int32(0x20000)
        if baseWhence == Int32(0x10000) { return contentLength }
        lock.lock()
        defer { lock.unlock() }
        guard !cancelled else { return -5 }
        let target: Int64
        switch baseWhence {
        case 0: target = requestedOffset
        case 1: target = offset + requestedOffset
        case 2: target = contentLength + requestedOffset
        default: return -5
        }
        guard target >= 0, target <= contentLength else { return -5 }
        offset = target
        return target
    }

    func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
    }
}

private let onePlayerKeyframeReadCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UInt8>?, Int32) -> Int32 = { opaque, buffer, size in
    guard let opaque, let buffer else { return -5 }
    return Unmanaged<OnePlayerKeyframeAVIOState>.fromOpaque(opaque).takeUnretainedValue().read(into: buffer, maximumLength: size)
}

private let onePlayerKeyframeSeekCallback: @convention(c) (UnsafeMutableRawPointer?, Int64, Int32) -> Int64 = { opaque, offset, whence in
    guard let opaque else { return -5 }
    return Unmanaged<OnePlayerKeyframeAVIOState>.fromOpaque(opaque).takeUnretainedValue().seek(to: offset, whence: whence)
}

@_cdecl("oneplayer_keyframe_backend_libavformat_direct")
func oneplayerKeyframeBackendProbe() -> Int32 { avformat_version() > 0 && avutil_version() > 0 ? 1 : 0 }

enum OnePlayerKeyframeIndexProbe {
    static let backendMarker = "ONEPLAYER_KEYFRAME_BACKEND_LIBAVFORMAT_DIRECT"
    static let indexMarker = "ONEPLAYER_KEYFRAME_INDEX_READONLY"
    static var runtimeDescription: String { "\(backendMarker) \(indexMarker) backend=libavformat-direct probe=\(oneplayerKeyframeBackendProbe()) avformat=\(avformat_version()) avutil=\(avutil_version()) mode=cache-only-observe" }

    static func buildIndex(session: TransportDataSession, contentLength: Int64) async -> OnePlayerKeyframeIndexBuildResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: buildIndexSynchronously(session: session, contentLength: contentLength))
            }
        }
    }

    private static func buildIndexSynchronously(session: TransportDataSession, contentLength: Int64) -> OnePlayerKeyframeIndexBuildResult {
        guard contentLength > 0 else { return .unavailable("invalid-content-length") }
        let state = OnePlayerKeyframeAVIOState(session: session, contentLength: contentLength)
        let bufferSize: Int32 = 64 * 1024
        guard let rawBuffer = av_malloc(Int(bufferSize)) else { return .unavailable("av-malloc-failed") }
        let buffer = rawBuffer.assumingMemoryBound(to: UInt8.self)
        var avioContext = avio_alloc_context(buffer, bufferSize, 0, Unmanaged.passUnretained(state).toOpaque(), onePlayerKeyframeReadCallback, nil, onePlayerKeyframeSeekCallback)
        guard avioContext != nil else {
            av_free(rawBuffer)
            return .unavailable("avio-alloc-context-failed")
        }
        defer {
            state.cancel()
            avio_context_free(&avioContext)
        }

        var formatContext: UnsafeMutablePointer<AVFormatContext>? = avformat_alloc_context()
        guard formatContext != nil else { return .unavailable("avformat-alloc-context-failed") }
        formatContext?.pointee.pb = avioContext
        formatContext?.pointee.flags |= Int32(0x0080)
        let openStatus = avformat_open_input(&formatContext, nil, nil, nil)
        guard openStatus >= 0, let context = formatContext else {
            if let context = formatContext { avformat_free_context(context) }
            formatContext = nil
            return .unavailable("avformat-open-input=\(openStatus)")
        }
        defer { avformat_close_input(&formatContext) }

        let videoIndex = av_find_best_stream(context, AVMEDIA_TYPE_VIDEO, -1, -1, nil, 0)
        guard videoIndex >= 0, let streams = context.pointee.streams, let stream = streams[Int(videoIndex)] else { return .unavailable("video-stream=\(videoIndex)") }
        let entryCount = avformat_index_get_entries_count(stream)
        guard entryCount > 0 else { return .unavailable("index-entry-count=\(entryCount)") }
        let timeBase = stream.pointee.time_base
        guard timeBase.den != 0 else { return .unavailable("invalid-time-base") }
        let scale = Double(timeBase.num) / Double(timeBase.den)
        let startTimestamp = stream.pointee.start_time
        let hasStartTimestamp = startTimestamp != Int64.min
        let startSeconds = hasStartTimestamp ? Double(startTimestamp) * scale : 0
        var keyframes: [Double] = []
        keyframes.reserveCapacity(Int(entryCount))

        for index in 0..<entryCount {
            guard let entry = avformat_index_get_entry(stream, index), (entry.pointee.flags & 1) != 0 else { continue }
            let timestamp = entry.pointee.timestamp
            guard timestamp != Int64.min else { continue }
            let relativeTimestamp = hasStartTimestamp ? timestamp - startTimestamp : timestamp
            let seconds = Double(relativeTimestamp) * scale
            if seconds.isFinite, seconds >= -0.001 { keyframes.append(max(0, seconds)) }
        }
        guard !keyframes.isEmpty else { return .unavailable("keyframe-entry-count=0 total-index=\(entryCount)") }
        keyframes.sort()
        var unique: [Double] = []
        unique.reserveCapacity(keyframes.count)
        for value in keyframes {
            if let last = unique.last, abs(last - value) < 0.0005 { continue }
            unique.append(value)
        }
        return .ready(OnePlayerKeyframeIndex(keyframes: unique, videoStreamIndex: videoIndex, timeBaseSeconds: scale, streamStartSeconds: startSeconds))
    }
}
#else
@_cdecl("oneplayer_keyframe_backend_unavailable")
func oneplayerKeyframeBackendProbe() -> Int32 { 0 }

enum OnePlayerKeyframeIndexProbe {
    static let backendMarker = "ONEPLAYER_KEYFRAME_BACKEND_UNAVAILABLE"
    static let indexMarker = "ONEPLAYER_KEYFRAME_INDEX_READONLY_UNAVAILABLE"
    static var runtimeDescription: String { "\(backendMarker) \(indexMarker) backend=unavailable probe=\(oneplayerKeyframeBackendProbe()) reason=Libavformat-or-Libavutil-not-importable" }
    static func buildIndex(session: TransportDataSession, contentLength: Int64) async -> OnePlayerKeyframeIndexBuildResult { .unavailable("Libavformat-or-Libavutil-not-importable") }
}
#endif
''')

engine = Path("Sources/Player/MPVPlayerEngine.swift")
text = engine.read_text()
old_state = '''    private var seekGeneration: UInt64 = 0
    private var latestNativeSeekDispatchID: UInt64?
    private var activeSeekingEpochID: UInt64?
    private var seekingPropertyActive = false
    private let sharedTransportSession: TransportDataSession?
'''
new_state = '''    private var seekGeneration: UInt64 = 0
    private var latestNativeSeekDispatchID: UInt64?
    private var activeSeekEventOwnerID: UInt64?
    private var seekingPropertyActive = false
    private var keyframeIndexGeneration: UInt64 = 0
    private var keyframeIndexTask: Task<Void, Never>?
    private var keyframeIndex: OnePlayerKeyframeIndex?
    private let sharedTransportSession: TransportDataSession?
'''
if 'private var activeSeekEventOwnerID' not in text:
    text = replace_once(text, old_state, new_state, "seek event fence state")

old_dispatch = '''                let dispatchAt = CACurrentMediaTime()
                self.latestNativeSeekDispatchID = seekID
                self.activeSeekingEpochID = nil
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(seekID) phase=native-dispatch owner=awaiting-seeking-true")
                DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=native-dispatch prioritizeMs=\\(String(format: \"%.1f\", (prioritizedAt - requestedAt) * 1000)) dispatchMs=\\(String(format: \"%.1f\", (dispatchAt - requestedAt) * 1000)) intent=\\(intent) mode=\\(mode) bufferHit=\\(bufferHit) enginePosition=\\(String(format: \"%.3f\", self.snapshot.position))")
                self.command(handle, ["seek", String(format: "%.3f", target), mode])
'''
new_dispatch = '''                let dispatchAt = CACurrentMediaTime()
                self.latestNativeSeekDispatchID = seekID
                self.activeSeekEventOwnerID = nil
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(seekID) phase=native-dispatch owner=awaiting-mpv-event-seek")
                self.logKeyframeIndexObservation(seekID: seekID, target: target)
                DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=native-dispatch prioritizeMs=\\(String(format: \"%.1f\", (prioritizedAt - requestedAt) * 1000)) dispatchMs=\\(String(format: \"%.1f\", (dispatchAt - requestedAt) * 1000)) intent=\\(intent) mode=\\(mode) bufferHit=\\(bufferHit) enginePosition=\\(String(format: \"%.3f\", self.snapshot.position))")
                self.command(handle, ["seek", String(format: "%.3f", target), mode])
'''
if 'owner=awaiting-mpv-event-seek' not in text:
    text = replace_once(text, old_dispatch, new_dispatch, "seek native dispatch ownership")

old_stop = '''        pendingSeek = nil
        latestNativeSeekDispatchID = nil
        activeSeekingEpochID = nil
        seekingPropertyActive = false
        pendingRendererLayout = nil
'''
new_stop = '''        pendingSeek = nil
        latestNativeSeekDispatchID = nil
        activeSeekEventOwnerID = nil
        seekingPropertyActive = false
        keyframeIndexGeneration &+= 1
        keyframeIndexTask?.cancel()
        keyframeIndexTask = nil
        keyframeIndex = nil
        pendingRendererLayout = nil
'''
if 'keyframeIndexTask?.cancel()' not in text:
    text = replace_once(text, old_stop, new_stop, "stop seek/index reset")

old_file_loaded = '''        case MPV_EVENT_FILE_LOADED:
            snapshot.isBuffering = false
            snapshot.waitingReason = nil
            logAudioState(handle: handle, reason: "file-loaded")
            logVideoState(handle: handle, reason: "file-loaded")
            emitOnMain()
'''
new_file_loaded = '''        case MPV_EVENT_FILE_LOADED:
            snapshot.isBuffering = false
            snapshot.waitingReason = nil
            logAudioState(handle: handle, reason: "file-loaded")
            logVideoState(handle: handle, reason: "file-loaded")
            if let session = sharedTransportSession, let bridge = streamBridge { startKeyframeIndexDiagnostics(session: session, contentLength: bridge.contentLength) }
            emitOnMain()
'''
if 'startKeyframeIndexDiagnostics(session: session' not in text:
    text = replace_once(text, old_file_loaded, new_file_loaded, "file-loaded keyframe index")

old_seek_event = '''        case MPV_EVENT_SEEK:
            snapshot.isBuffering = true
            snapshot.waitingReason = "MPV seek"
            let pendingText = pendingSeek.map { "id=\\($0.id) latestTarget=\\(String(format: \"%.3f\", $0.target))" } ?? "id=none latestTarget=none"
            DiagnosticsLogger.shared.log("MPVSeekEvent", "\\(pendingText) position=\\(String(format: \"%.3f\", snapshot.position)) event=seek")
            emitOnMain()
'''
new_seek_event = '''        case MPV_EVENT_SEEK:
            snapshot.isBuffering = true
            snapshot.waitingReason = "MPV seek"
            if let pending = pendingSeek, pending.id > 0, latestNativeSeekDispatchID == pending.id {
                activeSeekEventOwnerID = pending.id
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(pending.id) phase=mpv-event-seek owner=claimed")
            } else {
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(pendingSeek?.id.map(String.init) ?? \"none\") phase=mpv-event-seek owner=unclaimed nativeOwner=\\(latestNativeSeekDispatchID.map(String.init) ?? \"none\")")
            }
            let pendingText = pendingSeek.map { "id=\\($0.id) latestTarget=\\(String(format: \"%.3f\", $0.target))" } ?? "id=none latestTarget=none"
            DiagnosticsLogger.shared.log("MPVSeekEvent", "\\(pendingText) position=\\(String(format: \"%.3f\", snapshot.position)) event=seek")
            emitOnMain()
'''
if 'phase=mpv-event-seek owner=claimed' not in text:
    text = replace_once(text, old_seek_event, new_seek_event, "MPV_EVENT_SEEK ownership")

old_restart = '''        case MPV_EVENT_PLAYBACK_RESTART:
            var actualPosition = snapshot.position
            var queriedPosition = Double(0)
            if getProperty(handle: handle, name: "time-pos", format: MPV_FORMAT_DOUBLE, value: &queriedPosition) >= 0, queriedPosition.isFinite {
                actualPosition = queriedPosition
                snapshot.position = queriedPosition
            }

            if let pending = pendingSeek, pending.id > 0, activeSeekingEpochID != pending.id {
                snapshot.isBuffering = true
                snapshot.waitingReason = "MPV seek"
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(pending.id) phase=playback-restart ignored=true reason=no-latest-seeking-epoch actual=\\(String(format: \"%.3f\", actualPosition)) nativeOwner=\\(latestNativeSeekDispatchID.map(String.init) ?? \"none\") seekingOwner=\\(activeSeekingEpochID.map(String.init) ?? \"none\") seeking=\\(seekingPropertyActive)")
                emitOnMain()
                return
            }

            snapshot.isBuffering = false
            snapshot.waitingReason = nil
            if let pending = pendingSeek {
                pendingSeek = nil
                latestNativeSeekDispatchID = nil
                activeSeekingEpochID = nil
                let latency = (CACurrentMediaTime() - pending.requestedAt) * 1000
                let delta = actualPosition - pending.target
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(pending.id) phase=playback-restart accepted=true owner=seeking-epoch")
                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) actual=\\(String(format: \"%.3f\", actualPosition)) delta=\\(String(format: \"%.3f\", delta)) completionMs=\\(String(format: \"%.1f\", latency)) bufferHit=\\(pending.bufferHit) intent=\\(pending.intent) mode=\\(pending.mode) event=playback-restart")
                DispatchQueue.main.async { [weak self] in
                    self?.onSeekCompleted?(SeekResult(
                        requestedAt: pending.requestedAt,
                        target: pending.target,
                        actualPosition: actualPosition,
                        bufferHit: pending.bufferHit,
                        completionLatencyMs: latency,
                        measurement: "MPV playback-restart after latest seeking epoch"
                    ))
                }
            } else {
                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=none actual=\\(String(format: \"%.3f\", actualPosition)) event=playback-restart-without-pending")
            }
            emitOnMain()
'''
new_restart = '''        case MPV_EVENT_PLAYBACK_RESTART:
            var actualPosition = snapshot.position
            var queriedPosition = Double(0)
            if getProperty(handle: handle, name: "time-pos", format: MPV_FORMAT_DOUBLE, value: &queriedPosition) >= 0, queriedPosition.isFinite { actualPosition = queriedPosition }

            if let pending = pendingSeek, pending.id > 0, activeSeekEventOwnerID != pending.id {
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(pending.id) phase=playback-restart ignored=true reason=no-latest-seek-event-owner actual=\\(String(format: \"%.3f\", actualPosition)) nativeOwner=\\(latestNativeSeekDispatchID.map(String.init) ?? \"none\") seekEventOwner=\\(activeSeekEventOwnerID.map(String.init) ?? \"none\") seeking=\\(seekingPropertyActive)")
                return
            }

            snapshot.position = actualPosition
            snapshot.isBuffering = false
            snapshot.waitingReason = nil
            if let pending = pendingSeek {
                pendingSeek = nil
                latestNativeSeekDispatchID = nil
                activeSeekEventOwnerID = nil
                let latency = (CACurrentMediaTime() - pending.requestedAt) * 1000
                let delta = actualPosition - pending.target
                DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(pending.id) phase=playback-restart accepted=true owner=mpv-event-seek")
                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) actual=\\(String(format: \"%.3f\", actualPosition)) delta=\\(String(format: \"%.3f\", delta)) completionMs=\\(String(format: \"%.1f\", latency)) bufferHit=\\(pending.bufferHit) intent=\\(pending.intent) mode=\\(pending.mode) event=playback-restart")
                DispatchQueue.main.async { [weak self] in
                    self?.onSeekCompleted?(SeekResult(
                        requestedAt: pending.requestedAt,
                        target: pending.target,
                        actualPosition: actualPosition,
                        bufferHit: pending.bufferHit,
                        completionLatencyMs: latency,
                        measurement: "MPV playback-restart after latest MPV_EVENT_SEEK"
                    ))
                }
            } else {
                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=none actual=\\(String(format: \"%.3f\", actualPosition)) event=playback-restart-without-pending")
            }
            emitOnMain()
'''
if 'reason=no-latest-seek-event-owner' not in text:
    text = replace_once(text, old_restart, new_restart, "playback restart event fence")

old_handler = '''    private func handleSeekingPropertyChange(_ active: Bool) {
        seekingPropertyActive = active
        let pendingID = pendingSeek?.id
        if active, let pending = pendingSeek, pending.id > 0, latestNativeSeekDispatchID == pending.id {
            activeSeekingEpochID = pending.id
            DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(pending.id) phase=seeking-property active=true owner=claimed")
        } else {
            DiagnosticsLogger.shared.log("MPVSeekFence", "id=\\(pendingID.map(String.init) ?? \"none\") phase=seeking-property active=\\(active) nativeOwner=\\(latestNativeSeekDispatchID.map(String.init) ?? \"none\") seekingOwner=\\(activeSeekingEpochID.map(String.init) ?? \"none\")")
        }
    }

'''
new_handler = '''    private func handleSeekingPropertyChange(_ active: Bool) {
        seekingPropertyActive = active
        DiagnosticsLogger.shared.log("MPVSeekingState", "active=\\(active) pending=\\(pendingSeek?.id.map(String.init) ?? \"none\") nativeOwner=\\(latestNativeSeekDispatchID.map(String.init) ?? \"none\") seekEventOwner=\\(activeSeekEventOwnerID.map(String.init) ?? \"none\")")
    }

'''
if 'DiagnosticsLogger.shared.log("MPVSeekingState"' not in text:
    text = replace_once(text, old_handler, new_handler, "seeking property diagnostics only")

refresh_anchor = '''    private func refreshProperty(name: String, handle: OpaquePointer) {
'''
index_methods = '''    private func startKeyframeIndexDiagnostics(session: TransportDataSession, contentLength: Int64) {
        keyframeIndexGeneration &+= 1
        let generation = keyframeIndexGeneration
        keyframeIndexTask?.cancel()
        keyframeIndexTask = nil
        keyframeIndex = nil
        DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=starting generation=\\(generation) bytes=\\(contentLength) mode=cache-only-observe")
        keyframeIndexTask = Task { [weak self] in
            let result = await OnePlayerKeyframeIndexProbe.buildIndex(session: session, contentLength: contentLength)
            guard !Task.isCancelled else { return }
            self?.queue.async { [weak self] in
                guard let self, !self.isStopping, self.keyframeIndexGeneration == generation else { return }
                self.keyframeIndexTask = nil
                switch result {
                case .ready(let index):
                    self.keyframeIndex = index
                    DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=ready generation=\\(generation) entries=\\(index.keyframes.count) stream=\\(index.videoStreamIndex) timeBase=\\(String(format: \"%.9f\", index.timeBaseSeconds)) streamStart=\\(String(format: \"%.3f\", index.streamStartSeconds)) action=observe-only")
                case .unavailable(let reason):
                    self.keyframeIndex = nil
                    DiagnosticsLogger.shared.log("MPVKeyframeIndex", "status=unavailable generation=\\(generation) reason=\\(reason) action=observe-only")
                }
            }
        }
    }

    private func logKeyframeIndexObservation(seekID: UInt64, target: Double) {
        guard let index = keyframeIndex else {
            DiagnosticsLogger.shared.log("MPVKeyframeIndex", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) status=not-ready action=observe-only")
            return
        }
        let neighbors = index.neighbors(around: target)
        let previous = neighbors.previous.map { String(format: "%.3f", $0) } ?? "none"
        let next = neighbors.next.map { String(format: "%.3f", $0) } ?? "none"
        let nearest = neighbors.nearest.map { String(format: "%.3f", $0) } ?? "none"
        let previousDelta = neighbors.previous.map { String(format: "%.3f", $0 - target) } ?? "none"
        let nextDelta = neighbors.next.map { String(format: "%.3f", $0 - target) } ?? "none"
        let nearestDelta = neighbors.nearest.map { String(format: "%.3f", $0 - target) } ?? "none"
        DiagnosticsLogger.shared.log("MPVKeyframeIndex", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) previous=\\(previous) previousDelta=\\(previousDelta) next=\\(next) nextDelta=\\(nextDelta) nearest=\\(nearest) nearestDelta=\\(nearestDelta) entries=\\(index.keyframes.count) action=observe-only")
    }

    private func refreshProperty(name: String, handle: OpaquePointer) {
'''
if 'private func startKeyframeIndexDiagnostics' not in text:
    text = replace_once(text, refresh_anchor, index_methods, "keyframe index diagnostics methods")

if 'activeSeekingEpochID' in text:
    raise SystemExit("legacy seeking epoch state remains")
engine.write_text(text)
