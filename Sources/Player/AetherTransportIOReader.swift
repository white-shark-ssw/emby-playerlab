#if canImport(AetherEngine)
import AetherEngine
import Darwin
import Foundation

final class AetherTransportIOReader: IOReader, @unchecked Sendable {
    private static let avSeekSize: Int32 = 0x10000
    private static let avSeekForce: Int32 = 0x20000

    private let session: UnifiedMediaTransportSession
    private let contentLength: Int64
    private let lock = NSLock()
    private var offset: Int64
    private var closed = false
    private var activeReadTask: Task<Data, Error>?

    init(session: UnifiedMediaTransportSession, contentLength: Int64, offset: Int64 = 0) {
        self.session = session
        self.contentLength = max(0, contentLength)
        self.offset = min(max(0, offset), max(0, contentLength))
    }

    var currentByteOffset: Int64 {
        lock.lock(); defer { lock.unlock() }
        return offset
    }

    func read(_ buffer: UnsafeMutablePointer<UInt8>?, size: Int32) -> Int32 {
        guard let buffer, size > 0 else { return 0 }
        lock.lock()
        let current = offset
        let isClosed = closed
        lock.unlock()
        guard !isClosed else { return -1 }
        guard current < contentLength else { return 0 }

        let requested = min(Int(size), Int(contentLength - current))
        let semaphore = DispatchSemaphore(value: 0)
        let result = AetherBlockingReadResult()
        let task = Task<Data, Error> { [session] in try await session.read(offset: current, length: requested) }
        lock.lock(); activeReadTask = task; lock.unlock()
        Task {
            do { result.set(.success(try await task.value)) }
            catch { result.set(.failure(error)) }
            semaphore.signal()
        }
        semaphore.wait()

        lock.lock()
        activeReadTask = nil
        let closedNow = closed
        lock.unlock()
        guard !closedNow, let completed = result.get() else { return -1 }

        switch completed {
        case .success(let data):
            guard !data.isEmpty else { return current >= contentLength ? 0 : -1 }
            data.copyBytes(to: buffer, count: data.count)
            lock.lock(); offset = min(contentLength, current + Int64(data.count)); lock.unlock()
            return Int32(data.count)
        case .failure(let error):
            DiagnosticsLogger.shared.playback("AetherIO", "read failed offset=\(current) length=\(requested) error=\(error.localizedDescription)")
            return -1
        }
    }

    func seek(offset delta: Int64, whence: Int32) -> Int64 {
        let baseWhence = whence & ~Self.avSeekForce
        if baseWhence == Self.avSeekSize { return contentLength }

        lock.lock()
        let current = offset
        let isClosed = closed
        lock.unlock()
        guard !isClosed else { return -1 }

        let base: Int64
        switch baseWhence {
        case SEEK_SET: base = 0
        case SEEK_CUR: base = current
        case SEEK_END: base = contentLength
        default: return -1
        }
        let (candidate, overflow) = base.addingReportingOverflow(delta)
        guard !overflow, candidate >= 0, candidate <= contentLength else { return -1 }

        lock.lock(); offset = candidate; lock.unlock()
        Task { [session] in await session.prioritizeOffset(candidate) }
        DiagnosticsLogger.shared.playback("AetherIO", "seek byte=\(candidate) whence=\(baseWhence)")
        return candidate
    }

    func cancel() {
        lock.lock(); let task = activeReadTask; lock.unlock()
        task?.cancel()
    }

    func close() {
        lock.lock()
        guard !closed else { lock.unlock(); return }
        closed = true
        let task = activeReadTask
        lock.unlock()
        task?.cancel()
        DiagnosticsLogger.shared.playback("AetherIO", "close byte=\(currentByteOffset)")
    }

    func makeIndependentReader() -> IOReader? { AetherTransportIOReader(session: session, contentLength: contentLength) }
    var discImageProbeEnabled: Bool { false }

    func reprioritizeCurrentOffset() {
        let current = currentByteOffset
        Task { [session] in await session.prioritizeOffset(current) }
        DiagnosticsLogger.shared.playback("AetherIO", "recover exactByte=\(current) byteGuess=disabled")
    }
}

private final class AetherBlockingReadResult: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Result<Data, Error>?

    func set(_ value: Result<Data, Error>) { lock.lock(); self.value = value; lock.unlock() }
    func get() -> Result<Data, Error>? { lock.lock(); defer { lock.unlock() }; return value }
}
#endif
