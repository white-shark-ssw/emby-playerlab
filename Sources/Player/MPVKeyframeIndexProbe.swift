import Foundation

struct OnePlayerKeyframeNeighbors {
    let previous: Double?
    let next: Double?
    let nearest: Double?
    let previousStatus: String
    let nextStatus: String
}

enum OnePlayerKeyframeNeighborProbeResult {
    case ready(OnePlayerKeyframeNeighbors)
    case unavailable(String)
}

final class OnePlayerKeyframeIndex: @unchecked Sendable {
    let videoStreamIndex: Int32
    let timeBaseSeconds: Double
    let streamStartSeconds: Double
    let mode = "native-seek-cache-only"

    private let session: TransportDataSession
    private let contentLength: Int64

    init(session: TransportDataSession, contentLength: Int64, videoStreamIndex: Int32, timeBaseSeconds: Double, streamStartSeconds: Double) {
        self.session = session
        self.contentLength = contentLength
        self.videoStreamIndex = videoStreamIndex
        self.timeBaseSeconds = timeBaseSeconds
        self.streamStartSeconds = streamStartSeconds
    }

    func neighbors(around target: Double) async -> OnePlayerKeyframeNeighborProbeResult {
        await OnePlayerKeyframeIndexProbe.probeNeighbors(session: session, contentLength: contentLength, target: target)
    }
}

enum OnePlayerKeyframeIndexBuildResult {
    case ready(OnePlayerKeyframeIndex)
    case unavailable(String)
}

#if canImport(Libavformat) && canImport(Libavutil) && canImport(Libavcodec)
import Libavformat
import Libavutil
import Libavcodec

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

private final class OnePlayerKeyframeOpenedInput {
    let state: OnePlayerKeyframeAVIOState
    var avioContext: UnsafeMutablePointer<AVIOContext>?
    var formatContext: UnsafeMutablePointer<AVFormatContext>?

    private init(state: OnePlayerKeyframeAVIOState, avioContext: UnsafeMutablePointer<AVIOContext>, formatContext: UnsafeMutablePointer<AVFormatContext>) {
        self.state = state
        self.avioContext = avioContext
        self.formatContext = formatContext
    }

    deinit {
        state.cancel()
        if formatContext != nil { avformat_close_input(&formatContext) }
        if avioContext != nil { avio_context_free(&avioContext) }
    }

    static func open(session: TransportDataSession, contentLength: Int64) -> (OnePlayerKeyframeOpenedInput?, String?) {
        guard contentLength > 0 else { return (nil, "invalid-content-length") }
        let state = OnePlayerKeyframeAVIOState(session: session, contentLength: contentLength)
        let bufferSize: Int32 = 64 * 1024
        guard let rawBuffer = av_malloc(Int(bufferSize)) else { return (nil, "av-malloc-failed") }
        let buffer = rawBuffer.assumingMemoryBound(to: UInt8.self)
        var avioContext = avio_alloc_context(buffer, bufferSize, 0, Unmanaged.passUnretained(state).toOpaque(), onePlayerKeyframeReadCallback, nil, onePlayerKeyframeSeekCallback)
        guard let avio = avioContext else {
            av_free(rawBuffer)
            return (nil, "avio-alloc-context-failed")
        }
        var formatContext: UnsafeMutablePointer<AVFormatContext>? = avformat_alloc_context()
        guard formatContext != nil else {
            avio_context_free(&avioContext)
            return (nil, "avformat-alloc-context-failed")
        }
        formatContext?.pointee.pb = avio
        formatContext?.pointee.flags |= Int32(0x0080)
        let openStatus = avformat_open_input(&formatContext, nil, nil, nil)
        guard openStatus >= 0, let context = formatContext else {
            if let context = formatContext { avformat_free_context(context) }
            formatContext = nil
            avio_context_free(&avioContext)
            return (nil, "avformat-open-input=\(openStatus)")
        }
        return (OnePlayerKeyframeOpenedInput(state: state, avioContext: avio, formatContext: context), nil)
    }
}

private struct OnePlayerKeyframeStreamMetadata {
    let videoIndex: Int32
    let scale: Double
    let startTimestamp: Int64?
    let startSeconds: Double
}

private enum OnePlayerDirectionalKeyframeResult {
    case value(Double, String)
    case unavailable(String)
}

@_cdecl("oneplayer_keyframe_backend_libavformat_direct")
func oneplayerKeyframeBackendProbe() -> Int32 { avformat_version() > 0 && avutil_version() > 0 && avcodec_version() > 0 ? 1 : 0 }

enum OnePlayerKeyframeIndexProbe {
    static let backendMarker = "ONEPLAYER_KEYFRAME_BACKEND_LIBAVFORMAT_DIRECT"
    static let indexMarker = "ONEPLAYER_KEYFRAME_NATIVE_SEEK_READONLY"
    static var runtimeDescription: String { "\(backendMarker) \(indexMarker) backend=libavformat-direct probe=\(oneplayerKeyframeBackendProbe()) avformat=\(avformat_version()) avutil=\(avutil_version()) avcodec=\(avcodec_version()) mode=cache-only-native-seek-observe" }

    static func buildIndex(session: TransportDataSession, contentLength: Int64) async -> OnePlayerKeyframeIndexBuildResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: buildIndexSynchronously(session: session, contentLength: contentLength))
            }
        }
    }

    static func probeNeighbors(session: TransportDataSession, contentLength: Int64, target: Double) async -> OnePlayerKeyframeNeighborProbeResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: probeNeighborsSynchronously(session: session, contentLength: contentLength, target: target))
            }
        }
    }

    private static func buildIndexSynchronously(session: TransportDataSession, contentLength: Int64) -> OnePlayerKeyframeIndexBuildResult {
        let opened = OnePlayerKeyframeOpenedInput.open(session: session, contentLength: contentLength)
        guard let input = opened.0 else { return .unavailable(opened.1 ?? "open-failed") }
        guard let metadata = streamMetadata(context: input.formatContext) else { return .unavailable("video-stream-or-timebase-unavailable") }
        return .ready(OnePlayerKeyframeIndex(session: session, contentLength: contentLength, videoStreamIndex: metadata.videoIndex, timeBaseSeconds: metadata.scale, streamStartSeconds: metadata.startSeconds))
    }

    private static func probeNeighborsSynchronously(session: TransportDataSession, contentLength: Int64, target: Double) -> OnePlayerKeyframeNeighborProbeResult {
        guard target.isFinite, target >= 0 else { return .unavailable("invalid-target") }
        let previousResult = probeDirection(session: session, contentLength: contentLength, target: target, backward: true)
        let nextResult = probeDirection(session: session, contentLength: contentLength, target: target, backward: false)

        let previous: Double?
        let previousStatus: String
        switch previousResult {
        case .value(let value, let status): previous = value; previousStatus = status
        case .unavailable(let reason): previous = nil; previousStatus = reason
        }

        let next: Double?
        let nextStatus: String
        switch nextResult {
        case .value(let value, let status): next = value; nextStatus = status
        case .unavailable(let reason): next = nil; nextStatus = reason
        }

        guard previous != nil || next != nil else { return .unavailable("previous=\(previousStatus) next=\(nextStatus)") }
        let nearest: Double?
        switch (previous, next) {
        case let (previous?, next?): nearest = abs(target - previous) <= abs(next - target) ? previous : next
        case let (previous?, nil): nearest = previous
        case let (nil, next?): nearest = next
        default: nearest = nil
        }
        return .ready(OnePlayerKeyframeNeighbors(previous: previous, next: next, nearest: nearest, previousStatus: previousStatus, nextStatus: nextStatus))
    }

    private static func probeDirection(session: TransportDataSession, contentLength: Int64, target: Double, backward: Bool) -> OnePlayerDirectionalKeyframeResult {
        let opened = OnePlayerKeyframeOpenedInput.open(session: session, contentLength: contentLength)
        guard let input = opened.0, let context = input.formatContext else { return .unavailable(opened.1 ?? "open-failed") }
        guard let metadata = streamMetadata(context: context) else { return .unavailable("video-stream-or-timebase-unavailable") }
        let relativeUnits = Int64((target / metadata.scale).rounded())
        let targetTimestamp = (metadata.startTimestamp ?? 0) + relativeUnits
        let flags = backward ? Int32(AVSEEK_FLAG_BACKWARD) : 0
        let seekStatus = av_seek_frame(context, metadata.videoIndex, targetTimestamp, flags)
        guard seekStatus >= 0 else { return .unavailable("av-seek-frame=\(seekStatus)") }

        var packet: UnsafeMutablePointer<AVPacket>? = av_packet_alloc()
        guard let packetPointer = packet else { return .unavailable("av-packet-alloc-failed") }
        defer { av_packet_free(&packet) }

        for scan in 0..<2048 {
            let readStatus = av_read_frame(context, packetPointer)
            guard readStatus >= 0 else { return .unavailable("av-read-frame=\(readStatus) scan=\(scan)") }
            let isVideo = packetPointer.pointee.stream_index == metadata.videoIndex
            let isKey = (packetPointer.pointee.flags & Int32(AV_PKT_FLAG_KEY)) != 0
            let pts = packetPointer.pointee.pts
            let dts = packetPointer.pointee.dts
            let timestamp = pts != Int64.min ? pts : dts
            av_packet_unref(packetPointer)
            guard isVideo, isKey, timestamp != Int64.min else { continue }
            let relativeTimestamp = metadata.startTimestamp.map { timestamp - $0 } ?? timestamp
            let seconds = Double(relativeTimestamp) * metadata.scale
            guard seconds.isFinite else { continue }
            if backward {
                if seconds <= target + 0.001 { return .value(max(0, seconds), "ok-backward scan=\(scan)") }
            } else if seconds >= target - 0.001 {
                return .value(max(0, seconds), "ok-forward scan=\(scan)")
            }
        }
        return .unavailable("keyframe-not-found scan-limit=2048")
    }

    private static func streamMetadata(context: UnsafeMutablePointer<AVFormatContext>?) -> OnePlayerKeyframeStreamMetadata? {
        guard let context else { return nil }
        let videoIndex = av_find_best_stream(context, AVMEDIA_TYPE_VIDEO, -1, -1, nil, 0)
        guard videoIndex >= 0, let streams = context.pointee.streams, let stream = streams[Int(videoIndex)] else { return nil }
        let timeBase = stream.pointee.time_base
        guard timeBase.den != 0, timeBase.num != 0 else { return nil }
        let scale = Double(timeBase.num) / Double(timeBase.den)
        guard scale.isFinite, scale > 0 else { return nil }
        let rawStart = stream.pointee.start_time
        let startTimestamp = rawStart == Int64.min ? nil : rawStart
        let startSeconds = startTimestamp.map { Double($0) * scale } ?? 0
        return OnePlayerKeyframeStreamMetadata(videoIndex: videoIndex, scale: scale, startTimestamp: startTimestamp, startSeconds: startSeconds)
    }
}
#else
@_cdecl("oneplayer_keyframe_backend_unavailable")
func oneplayerKeyframeBackendProbe() -> Int32 { 0 }

enum OnePlayerKeyframeIndexProbe {
    static let backendMarker = "ONEPLAYER_KEYFRAME_BACKEND_UNAVAILABLE"
    static let indexMarker = "ONEPLAYER_KEYFRAME_NATIVE_SEEK_UNAVAILABLE"
    static var runtimeDescription: String { "\(backendMarker) \(indexMarker) backend=unavailable probe=\(oneplayerKeyframeBackendProbe()) reason=Libavformat-Libavutil-or-Libavcodec-not-importable" }
    static func buildIndex(session: TransportDataSession, contentLength: Int64) async -> OnePlayerKeyframeIndexBuildResult { .unavailable("Libavformat-Libavutil-or-Libavcodec-not-importable") }
    static func probeNeighbors(session: TransportDataSession, contentLength: Int64, target: Double) async -> OnePlayerKeyframeNeighborProbeResult { .unavailable("Libavformat-Libavutil-or-Libavcodec-not-importable") }
}
#endif
