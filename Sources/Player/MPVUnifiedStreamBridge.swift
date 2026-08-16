import Foundation
#if canImport(MPVKit)
import MPVKit
#elseif canImport(_MPVKit)
import _MPVKit
#endif
#if canImport(Libmpv)
import Libmpv
#endif

#if canImport(Libmpv)
private let mpvStreamLoadingFailed: Int32 = -13
private let mpvStreamGenericError: Int64 = -20

final class MPVUnifiedStreamBridge: @unchecked Sendable {
    let session: TransportDataSession
    let contentLength: Int64
    private let lock = NSLock()
    private var cancelled = false
    private var playbackAuthorityArmed = false
    private var playbackAuthorityConfirmed = false
    private var authorityClusterStart: Int64?
    private var authorityClusterEnd: Int64 = 0
    private var authorityClusterReads = 0
    private var authorityLastSeekAt = Date.distantPast
    private let authorityMinimumSpanBytes: Int64 = 512 * 1024
    private let authorityMinimumReads = 3
    private let authorityContinuityToleranceBytes: Int64 = 256 * 1024
    private let authoritySeekSettleSeconds: TimeInterval = 0.08

    init(session: TransportDataSession, contentLength: Int64) {
        self.session = session
        self.contentLength = contentLength
    }

    func register(on handle: OpaquePointer) throws {
        let status = "embyunified".withCString { protocolName in
            mpv_stream_cb_add_ro(handle, protocolName, Unmanaged.passUnretained(self).toOpaque(), mpvUnifiedOpenCallback)
        }
        guard status >= 0 else { throw MPVUnifiedStreamError.registrationFailed(status) }
        DiagnosticsLogger.shared.log("MPVStream", "registered protocol=embyunified bytes=\(contentLength)")
    }

    func cancelAll() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    fileprivate func makeState() -> MPVUnifiedStreamState {
        MPVUnifiedStreamState(session: session, contentLength: contentLength, owner: self)
    }

    fileprivate func noteSeek(_ offset: Int64) {
        let headGuard = min(32 * 1_048_576, max(1 * 1_048_576, contentLength / 100))
        let nearTail = contentLength > 64 * 1_048_576 && offset >= contentLength - 64 * 1_048_576
        lock.lock()
        guard !cancelled, !playbackAuthorityConfirmed else { lock.unlock(); return }
        authorityClusterStart = nil
        authorityClusterEnd = 0
        authorityClusterReads = 0
        authorityLastSeekAt = Date()
        let newlyArmed = !playbackAuthorityArmed && offset >= headGuard && !nearTail
        if offset >= headGuard && !nearTail { playbackAuthorityArmed = true }
        lock.unlock()
        if newlyArmed {
            DiagnosticsLogger.shared.log("MPVStream", "playback-byte authority armed seek=\(offset) headGuard=\(headGuard) tailExcluded=\(nearTail) byteGuess=disabled")
        }
    }

    fileprivate func noteSuccessfulRead(offset: Int64, count: Int) {
        guard count > 0 else { return }
        let upper = min(contentLength, offset + Int64(count))
        let headGuard = min(32 * 1_048_576, max(1 * 1_048_576, contentLength / 100))
        let nearTail = contentLength > 64 * 1_048_576 && offset >= contentLength - 64 * 1_048_576
        var confirmedStart: Int64?
        var confirmedSpan: Int64 = 0
        var confirmedReads = 0

        lock.lock()
        if !cancelled, playbackAuthorityArmed, !playbackAuthorityConfirmed, offset >= headGuard, !nearTail, Date().timeIntervalSince(authorityLastSeekAt) >= authoritySeekSettleSeconds {
            if let start = authorityClusterStart {
                let overlapsCluster = offset <= authorityClusterEnd + authorityContinuityToleranceBytes && upper >= start
                if overlapsCluster {
                    authorityClusterEnd = max(authorityClusterEnd, upper)
                    authorityClusterReads += 1
                } else {
                    authorityClusterStart = offset
                    authorityClusterEnd = upper
                    authorityClusterReads = 1
                }
            } else {
                authorityClusterStart = offset
                authorityClusterEnd = upper
                authorityClusterReads = 1
            }
            if let start = authorityClusterStart {
                let span = max(0, authorityClusterEnd - start)
                if span >= authorityMinimumSpanBytes, authorityClusterReads >= authorityMinimumReads {
                    playbackAuthorityConfirmed = true
                    confirmedStart = start
                    confirmedSpan = span
                    confirmedReads = authorityClusterReads
                }
            }
        }
        lock.unlock()

        guard let confirmedStart else { return }
        DiagnosticsLogger.shared.log("MPVStream", "sustained playback-byte authority start=\(confirmedStart) span=\(confirmedSpan) reads=\(confirmedReads) byteGuess=disabled")
        Task { [session] in await session.confirmConcretePlaybackByte(confirmedStart) }
    }
}

private final class MPVBlockingReadResult: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Result<Data, Error>?

    func set(_ newValue: Result<Data, Error>) {
        lock.lock(); value = newValue; lock.unlock()
    }

    func get() -> Result<Data, Error>? {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}

private final class MPVUnifiedStreamState: @unchecked Sendable {
    let session: TransportDataSession
    let contentLength: Int64
    private weak var owner: MPVUnifiedStreamBridge?
    private let lock = NSLock()
    private var currentOffset: Int64 = 0
    private var cancelled = false
    private var activeReadTask: Task<Data, Error>?

    init(session: TransportDataSession, contentLength: Int64, owner: MPVUnifiedStreamBridge) {
        self.session = session
        self.contentLength = contentLength
        self.owner = owner
    }

    func read(into buffer: UnsafeMutablePointer<CChar>, maximumLength: UInt64) -> Int64 {
        guard maximumLength > 0 else { return 0 }
        lock.lock()
        let offset = currentOffset
        let isCancelled = cancelled || owner?.isCancelled == true
        lock.unlock()
        guard !isCancelled else { return mpvStreamGenericError }
        guard offset < contentLength else { return 0 }

        let length = min(Int(maximumLength), Int(contentLength - offset))
        let semaphore = DispatchSemaphore(value: 0)
        let result = MPVBlockingReadResult()
        let task = Task<Data, Error> { [session] in
            try await session.read(offset: offset, length: length)
        }
        lock.lock()
        activeReadTask = task
        lock.unlock()

        Task {
            do {
                let data = try await task.value
                result.set(.success(data))
            } catch {
                result.set(.failure(error))
            }
            semaphore.signal()
        }
        semaphore.wait()

        lock.lock()
        activeReadTask = nil
        let cancelledNow = cancelled || owner?.isCancelled == true
        lock.unlock()
        guard !cancelledNow else { return mpvStreamGenericError }

        guard let completed = result.get() else { return mpvStreamGenericError }
        switch completed {
        case .success(let data):
            guard !data.isEmpty else { return offset >= contentLength ? 0 : mpvStreamGenericError }
            data.withUnsafeBytes { raw in
                if let base = raw.baseAddress { memcpy(buffer, base, data.count) }
            }
            owner?.noteSuccessfulRead(offset: offset, count: data.count)
            lock.lock()
            currentOffset = min(contentLength, offset + Int64(data.count))
            lock.unlock()
            return Int64(data.count)
        case .failure(let error):
            DiagnosticsLogger.shared.log("MPVStream", "read failed offset=\(offset) length=\(length) error=\(error.localizedDescription)")
            return mpvStreamGenericError
        }
    }

    func seek(to offset: Int64) -> Int64 {
        guard offset >= 0, offset <= contentLength else { return mpvStreamGenericError }
        lock.lock()
        guard !cancelled, owner?.isCancelled != true else { lock.unlock(); return mpvStreamGenericError }
        currentOffset = offset
        lock.unlock()
        owner?.noteSeek(offset)
        Task { [session] in await session.prioritizeOffset(offset) }
        DiagnosticsLogger.shared.log("MPVStream", "seek byte=\(offset)")
        return offset
    }

    func size() -> Int64 { contentLength }

    func cancel() {
        lock.lock()
        cancelled = true
        let task = activeReadTask
        lock.unlock()
        task?.cancel()
    }
}

private let mpvUnifiedOpenCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<CChar>?, UnsafeMutablePointer<mpv_stream_cb_info>?) -> Int32 = { userData, _, info in
    guard let userData, let info else { return mpvStreamLoadingFailed }
    let bridge = Unmanaged<MPVUnifiedStreamBridge>.fromOpaque(userData).takeUnretainedValue()
    guard !bridge.isCancelled else { return mpvStreamLoadingFailed }
    let state = bridge.makeState()
    info.pointee.cookie = Unmanaged.passRetained(state).toOpaque()
    info.pointee.read_fn = mpvUnifiedReadCallback
    info.pointee.seek_fn = mpvUnifiedSeekCallback
    info.pointee.size_fn = mpvUnifiedSizeCallback
    info.pointee.close_fn = mpvUnifiedCloseCallback
    info.pointee.cancel_fn = mpvUnifiedCancelCallback
    DiagnosticsLogger.shared.log("MPVStream", "open bytes=\(bridge.contentLength)")
    return 0
}

private let mpvUnifiedReadCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<CChar>?, UInt64) -> Int64 = { cookie, buffer, size in
    guard let cookie, let buffer else { return mpvStreamGenericError }
    return Unmanaged<MPVUnifiedStreamState>.fromOpaque(cookie).takeUnretainedValue().read(into: buffer, maximumLength: size)
}

private let mpvUnifiedSeekCallback: @convention(c) (UnsafeMutableRawPointer?, Int64) -> Int64 = { cookie, offset in
    guard let cookie else { return mpvStreamGenericError }
    return Unmanaged<MPVUnifiedStreamState>.fromOpaque(cookie).takeUnretainedValue().seek(to: offset)
}

private let mpvUnifiedSizeCallback: @convention(c) (UnsafeMutableRawPointer?) -> Int64 = { cookie in
    guard let cookie else { return mpvStreamGenericError }
    return Unmanaged<MPVUnifiedStreamState>.fromOpaque(cookie).takeUnretainedValue().size()
}

private let mpvUnifiedCloseCallback: @convention(c) (UnsafeMutableRawPointer?) -> Void = { cookie in
    guard let cookie else { return }
    let state = Unmanaged<MPVUnifiedStreamState>.fromOpaque(cookie).takeRetainedValue()
    state.cancel()
    DiagnosticsLogger.shared.log("MPVStream", "close")
}

private let mpvUnifiedCancelCallback: @convention(c) (UnsafeMutableRawPointer?) -> Void = { cookie in
    guard let cookie else { return }
    Unmanaged<MPVUnifiedStreamState>.fromOpaque(cookie).takeUnretainedValue().cancel()
}

enum MPVUnifiedStreamError: LocalizedError {
    case registrationFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status): return "MPV 自定义字节流注册失败：\(status)。"
        }
    }
}
#endif
