import AVFoundation
import CoreMedia
import Foundation

#if canImport(Libavformat) && canImport(Libavutil) && canImport(Libavcodec)
import Libavformat
import Libavutil
import Libavcodec

private final class OnePlayerPiPReadBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?

    func store(_ value: Data?) { lock.lock(); data = value; lock.unlock() }
    func load() -> Data? { lock.lock(); defer { lock.unlock() }; return data }
}

private final class OnePlayerPiPAVIOState: @unchecked Sendable {
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
        lock.lock(); let current = offset; let cancelledNow = cancelled; lock.unlock()
        guard !cancelledNow else { return -5 }
        guard current < contentLength else { return 0 }
        let requested = min(Int(maximumLength), Int(contentLength - current))
        let semaphore = DispatchSemaphore(value: 0)
        let box = OnePlayerPiPReadBox()
        let task = Task { [session] in
            let value = try? await session.read(offset: current, length: requested)
            box.store(value)
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + 8.0) == .timedOut {
            task.cancel()
            return -5
        }
        guard let data = box.load(), !data.isEmpty else { return -5 }
        data.withUnsafeBytes { raw in if let base = raw.baseAddress { memcpy(buffer, base, data.count) } }
        lock.lock(); if !cancelled, offset == current { offset = min(contentLength, current + Int64(data.count)) }; lock.unlock()
        return Int32(data.count)
    }

    func seek(to requestedOffset: Int64, whence: Int32) -> Int64 {
        let baseWhence = whence & ~Int32(0x20000)
        if baseWhence == Int32(0x10000) { return contentLength }
        lock.lock(); defer { lock.unlock() }
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

    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
}

private let onePlayerPiPReadCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UInt8>?, Int32) -> Int32 = { opaque, buffer, size in
    guard let opaque, let buffer else { return -5 }
    return Unmanaged<OnePlayerPiPAVIOState>.fromOpaque(opaque).takeUnretainedValue().read(into: buffer, maximumLength: size)
}

private let onePlayerPiPSeekCallback: @convention(c) (UnsafeMutableRawPointer?, Int64, Int32) -> Int64 = { opaque, offset, whence in
    guard let opaque else { return -5 }
    return Unmanaged<OnePlayerPiPAVIOState>.fromOpaque(opaque).takeUnretainedValue().seek(to: offset, whence: whence)
}

private final class OnePlayerPiPOpenedInput {
    let state: OnePlayerPiPAVIOState
    var avioContext: UnsafeMutablePointer<AVIOContext>?
    var formatContext: UnsafeMutablePointer<AVFormatContext>?

    private init(state: OnePlayerPiPAVIOState, avioContext: UnsafeMutablePointer<AVIOContext>, formatContext: UnsafeMutablePointer<AVFormatContext>) {
        self.state = state
        self.avioContext = avioContext
        self.formatContext = formatContext
    }

    deinit {
        state.cancel()
        if formatContext != nil { avformat_close_input(&formatContext) }
        if avioContext != nil { avio_context_free(&avioContext) }
    }

    static func open(session: TransportDataSession, contentLength: Int64) -> (OnePlayerPiPOpenedInput?, String?) {
        guard contentLength > 0 else { return (nil, "invalid-content-length") }
        let state = OnePlayerPiPAVIOState(session: session, contentLength: contentLength)
        let bufferSize: Int32 = 256 * 1024
        guard let rawBuffer = av_malloc(Int(bufferSize)) else { return (nil, "av-malloc-failed") }
        let buffer = rawBuffer.assumingMemoryBound(to: UInt8.self)
        var avioContext = avio_alloc_context(buffer, bufferSize, 0, Unmanaged.passUnretained(state).toOpaque(), onePlayerPiPReadCallback, nil, onePlayerPiPSeekCallback)
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
        let infoStatus = avformat_find_stream_info(context, nil)
        guard infoStatus >= 0 else {
            avformat_close_input(&formatContext)
            avio_context_free(&avioContext)
            return (nil, "avformat-find-stream-info=\(infoStatus)")
        }
        return (OnePlayerPiPOpenedInput(state: state, avioContext: avio, formatContext: context), nil)
    }
}

private struct OnePlayerPiPCodecConfiguration {
    let formatDescription: CMVideoFormatDescription
    let nalLengthSize: Int
    let packetsAreAnnexB: Bool
    let codecName: String
}

private enum OnePlayerPiPCodecBuilder {
    static func make(codecParameters: UnsafeMutablePointer<AVCodecParameters>) -> OnePlayerPiPCodecConfiguration? {
        let codecID = codecParameters.pointee.codec_id
        let extradata = copyExtradata(codecParameters)
        if codecID == AV_CODEC_ID_H264 { return makeH264(extradata: extradata) }
        if codecID == AV_CODEC_ID_HEVC { return makeHEVC(extradata: extradata) }
        return nil
    }

    private static func copyExtradata(_ codecParameters: UnsafeMutablePointer<AVCodecParameters>) -> Data {
        guard let pointer = codecParameters.pointee.extradata, codecParameters.pointee.extradata_size > 0 else { return Data() }
        return Data(bytes: pointer, count: Int(codecParameters.pointee.extradata_size))
    }

    private static func makeH264(extradata: Data) -> OnePlayerPiPCodecConfiguration? {
        let parsed: (sets: [Data], nalLength: Int, annexB: Bool)?
        if extradata.first == 1 { parsed = parseAVCC(extradata) }
        else { parsed = parseAnnexBH264(extradata) }
        guard let parsed, parsed.sets.count >= 2 else { return nil }
        var formatDescription: CMVideoFormatDescription?
        let status = withParameterSetPointers(parsed.sets) { pointers, sizes in
            CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault, parameterSetCount: pointers.count, parameterSetPointers: pointers, parameterSetSizes: sizes, nalUnitHeaderLength: Int32(parsed.nalLength), formatDescriptionOut: &formatDescription)
        }
        guard status == noErr, let formatDescription else { return nil }
        return OnePlayerPiPCodecConfiguration(formatDescription: formatDescription, nalLengthSize: parsed.nalLength, packetsAreAnnexB: parsed.annexB, codecName: "h264")
    }

    private static func makeHEVC(extradata: Data) -> OnePlayerPiPCodecConfiguration? {
        let parsed: (sets: [Data], nalLength: Int, annexB: Bool)?
        if extradata.first == 1 { parsed = parseHVCC(extradata) }
        else { parsed = parseAnnexBHEVC(extradata) }
        guard let parsed, parsed.sets.count >= 3 else { return nil }
        var formatDescription: CMVideoFormatDescription?
        let status = withParameterSetPointers(parsed.sets) { pointers, sizes in
            CMVideoFormatDescriptionCreateFromHEVCParameterSets(allocator: kCFAllocatorDefault, parameterSetCount: pointers.count, parameterSetPointers: pointers, parameterSetSizes: sizes, nalUnitHeaderLength: Int32(parsed.nalLength), extensions: nil, formatDescriptionOut: &formatDescription)
        }
        guard status == noErr, let formatDescription else { return nil }
        return OnePlayerPiPCodecConfiguration(formatDescription: formatDescription, nalLengthSize: parsed.nalLength, packetsAreAnnexB: parsed.annexB, codecName: "hevc")
    }

    private static func withParameterSetPointers<T>(_ sets: [Data], _ body: ([UnsafePointer<UInt8>], [Int]) -> T) -> T {
        let buffers: [UnsafeMutablePointer<UInt8>] = sets.map { data in
            let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: max(1, data.count))
            if !data.isEmpty { data.copyBytes(to: pointer, count: data.count) }
            return pointer
        }
        defer { buffers.forEach { $0.deallocate() } }
        return body(buffers.map { UnsafePointer($0) }, sets.map(\.count))
    }

    private static func parseAVCC(_ data: Data) -> (sets: [Data], nalLength: Int, annexB: Bool)? {
        guard data.count >= 7 else { return nil }
        let bytes = [UInt8](data)
        let nalLength = Int(bytes[4] & 0x03) + 1
        var offset = 6
        let spsCount = Int(bytes[5] & 0x1F)
        var sets: [Data] = []
        for _ in 0..<spsCount {
            guard let value = readLengthPrefixedSet(bytes, offset: &offset) else { return nil }
            sets.append(value)
        }
        guard offset < bytes.count else { return nil }
        let ppsCount = Int(bytes[offset]); offset += 1
        for _ in 0..<ppsCount {
            guard let value = readLengthPrefixedSet(bytes, offset: &offset) else { return nil }
            sets.append(value)
        }
        return (sets, nalLength, false)
    }

    private static func parseHVCC(_ data: Data) -> (sets: [Data], nalLength: Int, annexB: Bool)? {
        guard data.count >= 23 else { return nil }
        let bytes = [UInt8](data)
        let nalLength = Int(bytes[21] & 0x03) + 1
        let arrayCount = Int(bytes[22])
        var offset = 23
        var vps: [Data] = []
        var sps: [Data] = []
        var pps: [Data] = []
        for _ in 0..<arrayCount {
            guard offset + 3 <= bytes.count else { return nil }
            let nalType = bytes[offset] & 0x3F; offset += 1
            let count = Int(bytes[offset]) << 8 | Int(bytes[offset + 1]); offset += 2
            for _ in 0..<count {
                guard let value = readLengthPrefixedSet(bytes, offset: &offset) else { return nil }
                if nalType == 32 { vps.append(value) }
                else if nalType == 33 { sps.append(value) }
                else if nalType == 34 { pps.append(value) }
            }
        }
        guard let firstVPS = vps.first, let firstSPS = sps.first, let firstPPS = pps.first else { return nil }
        return ([firstVPS, firstSPS, firstPPS], nalLength, false)
    }

    private static func readLengthPrefixedSet(_ bytes: [UInt8], offset: inout Int) -> Data? {
        guard offset + 2 <= bytes.count else { return nil }
        let length = Int(bytes[offset]) << 8 | Int(bytes[offset + 1]); offset += 2
        guard length > 0, offset + length <= bytes.count else { return nil }
        let value = Data(bytes[offset..<(offset + length)])
        offset += length
        return value
    }

    private static func parseAnnexBH264(_ data: Data) -> (sets: [Data], nalLength: Int, annexB: Bool)? {
        let units = annexBNALUnits(data)
        guard let sps = units.first(where: { !$0.isEmpty && ($0[0] & 0x1F) == 7 }), let pps = units.first(where: { !$0.isEmpty && ($0[0] & 0x1F) == 8 }) else { return nil }
        return ([sps, pps], 4, true)
    }

    private static func parseAnnexBHEVC(_ data: Data) -> (sets: [Data], nalLength: Int, annexB: Bool)? {
        let units = annexBNALUnits(data)
        guard let vps = units.first(where: { !$0.isEmpty && (($0[0] >> 1) & 0x3F) == 32 }), let sps = units.first(where: { !$0.isEmpty && (($0[0] >> 1) & 0x3F) == 33 }), let pps = units.first(where: { !$0.isEmpty && (($0[0] >> 1) & 0x3F) == 34 }) else { return nil }
        return ([vps, sps, pps], 4, true)
    }

    static func normalizePacket(_ data: Data, configuration: OnePlayerPiPCodecConfiguration) -> Data {
        if configuration.packetsAreAnnexB || startsWithAnnexB(data) { return annexBToLengthPrefixed(data) }
        return data
    }

    private static func startsWithAnnexB(_ data: Data) -> Bool {
        let bytes = [UInt8](data.prefix(4))
        return bytes.starts(with: [0, 0, 1]) || bytes.starts(with: [0, 0, 0, 1])
    }

    private static func annexBNALUnits(_ data: Data) -> [Data] {
        let bytes = [UInt8](data)
        var starts: [(start: Int, payload: Int)] = []
        var index = 0
        while index + 3 <= bytes.count {
            if index + 4 <= bytes.count, bytes[index] == 0, bytes[index + 1] == 0, bytes[index + 2] == 0, bytes[index + 3] == 1 {
                starts.append((index, index + 4)); index += 4; continue
            }
            if bytes[index] == 0, bytes[index + 1] == 0, bytes[index + 2] == 1 {
                starts.append((index, index + 3)); index += 3; continue
            }
            index += 1
        }
        guard !starts.isEmpty else { return [] }
        var result: [Data] = []
        for i in starts.indices {
            let payloadStart = starts[i].payload
            let payloadEnd = i + 1 < starts.count ? starts[i + 1].start : bytes.count
            if payloadEnd > payloadStart { result.append(Data(bytes[payloadStart..<payloadEnd])) }
        }
        return result
    }

    private static func annexBToLengthPrefixed(_ data: Data) -> Data {
        let units = annexBNALUnits(data)
        guard !units.isEmpty else { return data }
        var output = Data()
        output.reserveCapacity(data.count + units.count * 4)
        for unit in units {
            var length = UInt32(unit.count).bigEndian
            withUnsafeBytes(of: &length) { output.append(contentsOf: $0) }
            output.append(unit)
        }
        return output
    }
}

final class PlayerSampleBufferPiPBridge: @unchecked Sendable {
    struct SampleEnvelope: @unchecked Sendable {
        let buffer: CMSampleBuffer
        let pts: Double
        let keyframe: Bool
    }

    var onSample: ((SampleEnvelope) -> Void)?
    var onReady: ((String) -> Void)?
    var onFailure: ((String) -> Void)?

    private let session: TransportDataSession
    private let startPosition: Double
    private let queue = DispatchQueue(label: "OnePlayer.PiP.SampleBuffer", qos: .userInitiated)
    private let lock = NSLock()
    private var cancelled = false
    private var paused = false
    private var input: OnePlayerPiPOpenedInput?

    init(session: TransportDataSession, startPosition: Double) {
        self.session = session
        self.startPosition = max(0, startPosition)
    }

    func start() { queue.async { [weak self] in self?.run() } }
    func stop() { lock.lock(); cancelled = true; lock.unlock(); input?.state.cancel() }
    func setPaused(_ value: Bool) { lock.lock(); paused = value; lock.unlock() }

    private func run() {
        let resolved: TransportResolvedResource
        do {
            let semaphore = DispatchSemaphore(value: 0)
            var value: TransportResolvedResource?
            var failure: Error?
            Task { [session] in
                do { value = try await session.resolve() } catch { failure = error }
                semaphore.signal()
            }
            if semaphore.wait(timeout: .now() + 8.0) == .timedOut { fail("resolve-timeout"); return }
            if let failure { fail("resolve=\(failure.localizedDescription)"); return }
            guard let resolvedValue = value else { fail("resolve-empty"); return }
            resolved = resolvedValue
        }

        let opened = OnePlayerPiPOpenedInput.open(session: session, contentLength: resolved.contentLength)
        guard let input = opened.0, let context = input.formatContext else { fail(opened.1 ?? "open-failed"); return }
        self.input = input
        guard let streams = context.pointee.streams else { fail("streams-unavailable"); return }
        let videoIndex = av_find_best_stream(context, AVMEDIA_TYPE_VIDEO, -1, -1, nil, 0)
        guard videoIndex >= 0, let stream = streams[Int(videoIndex)], let codecParameters = stream.pointee.codecpar else { fail("video-stream-unavailable"); return }
        guard let configuration = OnePlayerPiPCodecBuilder.make(codecParameters: codecParameters) else {
            let codecName = String(cString: avcodec_get_name(codecParameters.pointee.codec_id))
            fail("unsupported-codec-or-extradata codec=\(codecName)")
            return
        }

        let timeBase = stream.pointee.time_base
        guard timeBase.den != 0, timeBase.num != 0 else { fail("invalid-timebase"); return }
        let timeScale = Double(timeBase.num) / Double(timeBase.den)
        let rawStart = stream.pointee.start_time
        let startTimestamp: Int64? = rawStart == Int64.min ? nil : rawStart
        let frameRate = rationalValue(stream.pointee.avg_frame_rate)
        let fallbackDuration = frameRate > 0 ? 1.0 / frameRate : 1.0 / 30.0

        if startPosition > 0.05 {
            let target = (startTimestamp ?? 0) + Int64((startPosition / timeScale).rounded())
            let status = av_seek_frame(context, videoIndex, target, Int32(AVSEEK_FLAG_BACKWARD))
            guard status >= 0 else { fail("seek=\(status)"); return }
            avformat_flush(context)
        }

        onReady?("codec=\(configuration.codecName) bytes=\(resolved.contentLength) start=\(String(format: "%.3f", startPosition))")
        var packet: UnsafeMutablePointer<AVPacket>? = av_packet_alloc()
        guard let packetPointer = packet else { fail("av-packet-alloc-failed"); return }
        defer { av_packet_free(&packet) }
        let wallStarted = CACurrentMediaTime()

        while !isCancelled {
            if isPaused { Thread.sleep(forTimeInterval: 0.03); continue }
            let readStatus = av_read_frame(context, packetPointer)
            guard readStatus >= 0 else { fail("av-read-frame=\(readStatus)"); return }
            guard packetPointer.pointee.stream_index == videoIndex else { av_packet_unref(packetPointer); continue }

            let rawPTS = packetPointer.pointee.pts != Int64.min ? packetPointer.pointee.pts : packetPointer.pointee.dts
            guard rawPTS != Int64.min, packetPointer.pointee.size > 0, let rawData = packetPointer.pointee.data else { av_packet_unref(packetPointer); continue }
            let ptsUnits = startTimestamp.map { rawPTS - $0 } ?? rawPTS
            let dtsRaw = packetPointer.pointee.dts
            let dtsUnits = dtsRaw == Int64.min ? ptsUnits : (startTimestamp.map { dtsRaw - $0 } ?? dtsRaw)
            let pts = max(0, Double(ptsUnits) * timeScale)
            let dts = max(0, Double(dtsUnits) * timeScale)
            let packetDuration = packetPointer.pointee.duration > 0 ? Double(packetPointer.pointee.duration) * timeScale : fallbackDuration
            let keyframe = (packetPointer.pointee.flags & Int32(AV_PKT_FLAG_KEY)) != 0
            var data = Data(bytes: rawData, count: Int(packetPointer.pointee.size))
            av_packet_unref(packetPointer)
            data = OnePlayerPiPCodecBuilder.normalizePacket(data, configuration: configuration)
            guard let sample = makeSampleBuffer(data: data, configuration: configuration, pts: pts, dts: dts, duration: packetDuration, keyframe: keyframe) else { fail("sample-buffer-create-failed pts=\(pts)"); return }

            let expected = startPosition + max(0, CACurrentMediaTime() - wallStarted)
            while !isCancelled, pts > expected + 3.0 { Thread.sleep(forTimeInterval: 0.02); break }
            onSample?(SampleEnvelope(buffer: sample, pts: pts, keyframe: keyframe))
        }
    }

    private var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    private var isPaused: Bool { lock.lock(); defer { lock.unlock() }; return paused }
    private func fail(_ message: String) { if !isCancelled { onFailure?(message) } }

    private func rationalValue(_ value: AVRational) -> Double {
        guard value.den != 0 else { return 0 }
        let result = Double(value.num) / Double(value.den)
        return result.isFinite && result > 0 ? result : 0
    }

    private func makeSampleBuffer(data: Data, configuration: OnePlayerPiPCodecConfiguration, pts: Double, dts: Double, duration: Double, keyframe: Bool) -> CMSampleBuffer? {
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateEmpty(allocator: kCFAllocatorDefault, capacity: 0, flags: 0, blockBufferOut: &blockBuffer)
        guard status == kCMBlockBufferNoErr, let blockBuffer else { return nil }
        status = CMBlockBufferAppendMemoryBlock(blockBuffer, memoryBlock: nil, length: data.count, blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0, dataLength: data.count, flags: 0)
        guard status == kCMBlockBufferNoErr else { return nil }
        let copyStatus: OSStatus = data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return -1 }
            return CMBlockBufferReplaceDataBytes(with: base, blockBuffer: blockBuffer, offsetIntoDestination: 0, dataLength: data.count)
        }
        guard copyStatus == kCMBlockBufferNoErr else { return nil }

        var timing = CMSampleTimingInfo(duration: CMTime(seconds: max(0.001, duration), preferredTimescale: 60000), presentationTimeStamp: CMTime(seconds: pts, preferredTimescale: 60000), decodeTimeStamp: CMTime(seconds: dts, preferredTimescale: 60000))
        var sampleSize = data.count
        var sampleBuffer: CMSampleBuffer?
        status = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: blockBuffer, formatDescription: configuration.formatDescription, sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize, sampleBufferOut: &sampleBuffer)
        guard status == noErr, let sampleBuffer else { return nil }
        if !keyframe, let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) as? [NSMutableDictionary], let attachment = attachments.first { attachment[kCMSampleAttachmentKey_NotSync] = true }
        return sampleBuffer
    }
}
#else
final class PlayerSampleBufferPiPBridge: @unchecked Sendable {
    struct SampleEnvelope: @unchecked Sendable { let buffer: CMSampleBuffer; let pts: Double; let keyframe: Bool }
    var onSample: ((SampleEnvelope) -> Void)?
    var onReady: ((String) -> Void)?
    var onFailure: ((String) -> Void)?
    init(session: TransportDataSession, startPosition: Double) {}
    func start() { onFailure?("ffmpeg-modules-unavailable") }
    func stop() {}
    func setPaused(_ value: Bool) {}
}
#endif
