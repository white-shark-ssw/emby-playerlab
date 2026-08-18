from pathlib import Path


def patch_once(path: str, marker: str, old: str, new: str) -> bool:
    file = Path(path)
    text = file.read_text()
    if marker in text:
        return False
    if old not in text:
        raise SystemExit(f"anchor not found: {path} / {marker}")
    file.write_text(text.replace(old, new, 1))
    return True


changed = False

# 1) A cancelled localhost response must not leave a global worker blocked in
# DownloadFirstSparseStore for the full 20-45 second read timeout.
changed |= patch_once(
    "Sources/Transport/DownloadFirstSparseStore.swift",
    "private final class ReadCancellationState",
    "final class DownloadFirstSparseStore: @unchecked Sendable {\n    enum StoreError: LocalizedError {",
    """final class DownloadFirstSparseStore: @unchecked Sendable {
    private final class ReadCancellationState: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }
    }

    enum StoreError: LocalizedError {"""
)

changed |= patch_once(
    "Sources/Transport/DownloadFirstSparseStore.swift",
    "withTaskCancellationHandler(operation:",
    """    func readWhenAvailable(offset: Int64, maximumLength: Int, timeout: TimeInterval = 30) async throws -> Data {
        guard maximumLength > 0, offset < contentLength else { return Data() }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: StoreError.closed)
                    return
                }
                do {
                    continuation.resume(returning: try self.blockingRead(offset: offset, maximumLength: maximumLength, timeout: timeout))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
""",
    """    func readWhenAvailable(offset: Int64, maximumLength: Int, timeout: TimeInterval = 30) async throws -> Data {
        guard maximumLength > 0, offset < contentLength else { return Data() }
        let cancellation = ReadCancellationState()
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self else {
                        continuation.resume(throwing: StoreError.closed)
                        return
                    }
                    do {
                        continuation.resume(returning: try self.blockingRead(offset: offset, maximumLength: maximumLength, timeout: timeout, cancellation: cancellation))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }, onCancel: { [weak self] in
            cancellation.cancel()
            guard let self else { return }
            self.condition.lock()
            self.condition.broadcast()
            self.condition.unlock()
        })
    }
"""
)

changed |= patch_once(
    "Sources/Transport/DownloadFirstSparseStore.swift",
    "cancellation: ReadCancellationState",
    """    private func blockingRead(offset: Int64, maximumLength: Int, timeout: TimeInterval) throws -> Data {
        let deadline = Date().addingTimeInterval(timeout)
        var readableLength: Int64 = 0
        var fd: Int32 = -1

        condition.lock()
        defer { condition.unlock() }
        while !closed {
            readableLength = rangeSet.contiguousLength(from: offset, maximumLength: Int64(maximumLength))
            if readableLength > 0 {
                fd = fileDescriptor
                break
            }
            if !condition.wait(until: deadline) { break }
        }

        if closed || fd < 0 { throw StoreError.closed }
        guard readableLength > 0 else { throw StoreError.timeout(offset: offset) }
""",
    """    private func blockingRead(offset: Int64, maximumLength: Int, timeout: TimeInterval, cancellation: ReadCancellationState) throws -> Data {
        let deadline = Date().addingTimeInterval(timeout)
        var readableLength: Int64 = 0
        var fd: Int32 = -1

        condition.lock()
        defer { condition.unlock() }
        while !closed && !cancellation.isCancelled {
            readableLength = rangeSet.contiguousLength(from: offset, maximumLength: Int64(maximumLength))
            if readableLength > 0 {
                fd = fileDescriptor
                break
            }
            let wakeDeadline = min(deadline, Date().addingTimeInterval(0.25))
            _ = condition.wait(until: wakeDeadline)
            if Date() >= deadline { break }
        }

        if cancellation.isCancelled { throw CancellationError() }
        if closed || fd < 0 { throw StoreError.closed }
        guard readableLength > 0 else { throw StoreError.timeout(offset: offset) }
"""
)

# 2) Localhost is a byte bridge, not an unbounded request queue. MDK/FFmpeg may
# briefly issue many open-ended ranges while re-establishing A/V sample heads.
changed |= patch_once(
    "Sources/Transport/TransportHTTPServer.swift",
    "private let maximumClientStreams = 8",
    """    private let queue = DispatchQueue(label: \"com.embyplayerlab.transport.http-server\", qos: .userInitiated)
    private let lock = NSLock()
    private var listener: NWListener?
""",
    """    private let queue = DispatchQueue(label: \"com.embyplayerlab.transport.http-server\", qos: .userInitiated)
    private let lock = NSLock()
    private let maximumClientStreams = 8
    private var listener: NWListener?
"""
)

changed |= patch_once(
    "Sources/Transport/TransportHTTPServer.swift",
    "private var connectionOrder: [ObjectIdentifier] = []",
    """    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var connectionTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var lastLoggedRequestStart: Int64?
""",
    """    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var connectionTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var connectionOrder: [ObjectIdentifier] = []
    private var streamGuardEvictionCount = 0
    private var lastStreamGuardLogAt = Date.distantPast
    private var lastLoggedRequestStart: Int64?
"""
)

changed |= patch_once(
    "Sources/Transport/TransportHTTPServer.swift",
    "hintBytes = min(responseRange.length, 1 * 1_048_576)",
    """            let responseRange = requestedRange ?? ByteRange(lowerBound: 0, upperBound: resource.contentLength - 1)
            await session.noteDemand(range: responseRange.lowerBound..<(responseRange.upperBound + 1))
            let status = requestedRange == nil ? 200 : 206
""",
    """            let responseRange = requestedRange ?? ByteRange(lowerBound: 0, upperBound: resource.contentLength - 1)
            let hintBytes = min(responseRange.length, 1 * 1_048_576)
            let hintUpper = min(resource.contentLength, responseRange.lowerBound + hintBytes)
            if hintUpper > responseRange.lowerBound { await session.noteDemand(range: responseRange.lowerBound..<hintUpper) }
            let status = requestedRange == nil ? 200 : 206
"""
)

changed |= patch_once(
    "Sources/Transport/TransportHTTPServer.swift",
    "while cursor <= responseRange.upperBound, !Task.isCancelled, !isStopped",
    """            while cursor <= responseRange.upperBound, !Task.isCancelled {
""",
    """            while cursor <= responseRange.upperBound, !Task.isCancelled, !isStopped {
"""
)

changed |= patch_once(
    "Sources/Transport/TransportHTTPServer.swift",
    "action=evict-oldest",
    """    private func registerConnection(_ connection: NWConnection) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !stopped else { return false }
        connections[ObjectIdentifier(connection)] = connection
        return true
    }
""",
    """    private func registerConnection(_ connection: NWConnection) -> Bool {
        let identifier = ObjectIdentifier(connection)
        var evictedConnection: NWConnection?
        var evictedTask: Task<Void, Never>?
        var shouldLogEviction = false
        var evictionCount = 0
        var activeCount = 0

        lock.lock()
        guard !stopped else {
            lock.unlock()
            return false
        }
        while connections.count >= maximumClientStreams, let oldest = connectionOrder.first {
            connectionOrder.removeFirst()
            guard let staleConnection = connections.removeValue(forKey: oldest) else { continue }
            evictedConnection = staleConnection
            evictedTask = connectionTasks.removeValue(forKey: oldest)
            streamGuardEvictionCount += 1
            evictionCount = streamGuardEvictionCount
            let now = Date()
            if now.timeIntervalSince(lastStreamGuardLogAt) >= 1 {
                lastStreamGuardLogAt = now
                shouldLogEviction = true
            }
            break
        }
        connections[identifier] = connection
        connectionOrder.append(identifier)
        activeCount = connections.count
        lock.unlock()

        evictedTask?.cancel()
        evictedConnection?.cancel()
        if shouldLogEviction {
            DiagnosticsLogger.shared.playback("TransportHTTPGuard", "server=\(logID) action=evict-oldest active=\(activeCount) limit=\(maximumClientStreams) evictions=\(evictionCount)")
        }
        return true
    }
"""
)

changed |= patch_once(
    "Sources/Transport/TransportHTTPServer.swift",
    "connectionOrder.removeAll { $0 == identifier }",
    """        guard connections[identifier] === connection else { return nil }
        connections[identifier] = nil
        return connectionTasks.removeValue(forKey: identifier)
""",
    """        guard connections[identifier] === connection else { return nil }
        connections[identifier] = nil
        connectionOrder.removeAll { $0 == identifier }
        return connectionTasks.removeValue(forKey: identifier)
"""
)

for function_name in ["takeClientStateForReset", "takeServerStateForStop", "takeServerStateForRestart"]:
    marker = f"connectionOrder.removeAll() // {function_name}"
    file = Path("Sources/Transport/TransportHTTPServer.swift")
    text = file.read_text()
    if marker not in text:
        if function_name == "takeClientStateForReset":
            old = """        let currentConnections = Array(connections.values)
        connections.removeAll()
        let currentTasks = Array(connectionTasks.values)
"""
        else:
            old = """        let currentConnections = Array(connections.values)
        connections.removeAll()
        let currentTasks = Array(connectionTasks.values)
"""
        # There are three identical blocks; patch the first remaining block each pass and leave a
        # source comment so idempotency and CI can distinguish them.
        new = f"""        let currentConnections = Array(connections.values)
        connections.removeAll()
        connectionOrder.removeAll() // {function_name}
        let currentTasks = Array(connectionTasks.values)
"""
        if old not in text:
            raise SystemExit(f"connection reset anchor not found for {function_name}")
        file.write_text(text.replace(old, new, 1))
        changed = True

# 3) A real user seek creates a new MDK demux generation. Drop all old localhost
# streams before arming the transport seek token so stale blocked reads cannot compete.
changed |= patch_once(
    "MDKLab/App/MDKKSAVIOPlayerEngine.swift",
    "resetClientStreams(reason: \"mdk-seek-",
    """        if let session = sharedTransportSession {
            Task { @MainActor [weak self, weak player] in
                await session.prioritizeSeek(position: intent.target, duration: intent.duration)
""",
    """        if let session = sharedTransportSession {
            transportHTTPServer?.resetClientStreams(reason: "mdk-seek-\(intent.id)")
            Task { @MainActor [weak self, weak player] in
                await session.prioritizeSeek(position: intent.target, duration: intent.duration)
"""
)

# 4) Closing the player must stop consumers before waiting for portrait/dismiss.
changed |= patch_once(
    "Sources/UI/PlayerScreen.swift",
    "close stop issued before orientation restore",
    """        controller.pausePlayback()
        pictureInPictureController.stopAndDetach()
        DiagnosticsLogger.shared.playback("Lifecycle", "close button tapped; keep opaque player cover and persistent surface until portrait settles")
        AppOrientationCoordinator.shared.restoreMainInterfaceOrientation()
""",
    """        controller.stop()
        pictureInPictureController.stopAndDetach()
        DiagnosticsLogger.shared.app("PlayerLifecycle", "close stop issued before orientation restore")
        DiagnosticsLogger.shared.playback("Lifecycle", "close button tapped; playback/transport stopped before portrait wait")
        AppOrientationCoordinator.shared.restoreMainInterfaceOrientation()
"""
)

changed |= patch_once(
    "Sources/UI/PlayerScreen.swift",
    "onDisappear immediate stop",
    """            controller.pausePlayback()
            let closingController = controller
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { closingController.stop() }
""",
    """            DiagnosticsLogger.shared.app("PlayerLifecycle", "onDisappear immediate stop closing=\(isClosing)")
            controller.stop()
"""
)

# 5) Version only. Deployment target intentionally remains iOS 15.0.
project = Path("project.mdklab.yml")
text = project.read_text()
if 'MARKETING_VERSION: "0.13.15"' not in text:
    text = text.replace('MARKETING_VERSION: "0.13.14"', 'MARKETING_VERSION: "0.13.15"')
    text = text.replace('CURRENT_PROJECT_VERSION: "81"', 'CURRENT_PROJECT_VERSION: "82"')
    project.write_text(text)
    changed = True

print("materialized transport stream guard 0.13.15 build82" if changed else "already materialized")
