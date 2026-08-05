import Foundation

final class SparseAVIOReadCoordinator: @unchecked Sendable {
    private final class ResultBox<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var value: T?

        func store(_ value: T) {
            lock.lock(); self.value = value; lock.unlock()
        }

        func load() -> T? {
            lock.lock(); defer { lock.unlock() }
            return value
        }
    }

    private let lock = NSLock()
    private let session: TransportDataSession
    private let contentLength: Int64
    private let stopSessionOnClose: Bool
    private var logicalOffset: Int64 = 0
    private var generation: UInt64 = 0
    private var closed = false
    private var userSeekArmed = false

    init(session: TransportDataSession, contentLength: Int64, stopSessionOnClose: Bool = true) {
        self.session = session
        self.contentLength = contentLength
        self.stopSessionOnClose = stopSessionOnClose
    }

    var fileSize: Int64 { contentLength }

    func armUserSeek() {
        lock.lock(); userSeekArmed = true; lock.unlock()
    }

    func read(maxLength: Int) -> Result<Data, Error> {
        guard maxLength > 0 else { return .success(Data()) }
        if Thread.isMainThread {
            DiagnosticsLogger.shared.log("KSAVIO", "unexpected main-thread read; refusing to block UI")
            return .failure(MediaTransportError.invalidResponse)
        }

        lock.lock()
        guard !closed else { lock.unlock(); return .failure(MediaTransportError.cancelled) }
        let offset = logicalOffset
        let readGeneration = generation
        lock.unlock()

        if offset >= contentLength { return .success(Data()) }
        let requested = min(maxLength, Int(contentLength - offset))
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox<Result<Data, Error>>()
        let task = Task.detached(priority: .userInitiated) { [session] in
            do { box.store(.success(try await session.read(offset: offset, length: requested))) }
            catch { box.store(.failure(error)) }
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + 35) == .timedOut {
            task.cancel()
            DiagnosticsLogger.shared.log("KSAVIO", "read timeout offset=\(offset) length=\(requested)")
            return .failure(MediaTransportError.cancelled)
        }

        let result = box.load() ?? .failure(MediaTransportError.invalidResponse)
        if case .success(let data) = result, !data.isEmpty {
            lock.lock()
            if !closed, generation == readGeneration, logicalOffset == offset { logicalOffset += Int64(data.count) }
            lock.unlock()
        }
        return result
    }

    func seek(offset: Int64, whence: Int32) -> Int64 {
        let seekForce: Int32 = 0x20000
        let baseWhence = whence & ~seekForce
        lock.lock()
        guard !closed else { lock.unlock(); return -1 }
        let current = logicalOffset
        let proposed: Int64
        switch baseWhence {
        case 0: proposed = offset
        case 1: proposed = current + offset
        case 2: proposed = contentLength + offset
        default: lock.unlock(); return -1
        }
        let target = min(max(0, proposed), contentLength)
        logicalOffset = target
        generation &+= 1
        let migrateMain = userSeekArmed
        userSeekArmed = false
        lock.unlock()

        DiagnosticsLogger.shared.log("KSAVIOSeek", "offset=\(offset) whence=\(baseWhence) target=\(target) user=\(migrateMain)")
        if migrateMain {
            Task { [session] in await session.prioritizeOffset(target) }
        }
        return target
    }

    func metrics() async -> TransportMetricsSnapshot { await session.metrics() }

    func recoverStall(position: Double, duration: Double) {
        Task { [session] in await session.recoverStall(position: position, duration: duration) }
    }

    func close() {
        lock.lock()
        guard !closed else { lock.unlock(); return }
        closed = true
        generation &+= 1
        lock.unlock()
        if stopSessionOnClose { Task { [session] in await session.stop() } }
    }
}
