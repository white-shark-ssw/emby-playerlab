import Foundation

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
