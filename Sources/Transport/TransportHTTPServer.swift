import Foundation
import Network

final class TransportHTTPServer {
    enum ServerError: LocalizedError {
        case failedToStart(String)
        case missingPort
        case malformedRequest
        case invalidRange

        var errorDescription: String? {
            switch self {
            case .failedToStart(let message): return "本地传输服务启动失败：\(message)"
            case .missingPort: return "本地传输服务没有可用端口。"
            case .malformedRequest: return "本地传输服务收到无效 HTTP 请求。"
            case .invalidRange: return "本地传输服务收到无效 Range。"
            }
        }
    }

    private struct HTTPRequest {
        let method: String
        let path: String
        let headers: [String: String]
    }

    private struct ByteRange {
        let lowerBound: Int64
        let upperBound: Int64

        var length: Int64 { upperBound - lowerBound + 1 }
    }

    private let session: TransportDataSession
    private let fileExtension: String
    private let stopSessionOnStop: Bool
    private let token = UUID().uuidString.lowercased()
    private let logID = String(UUID().uuidString.lowercased().prefix(6))
    private let queue = DispatchQueue(label: "com.embyplayerlab.transport.http-server", qos: .userInitiated)
    private let lock = NSLock()
    private let maximumClientStreams = 8
    private var listener: NWListener?
    private var localURL: URL?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var connectionTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var connectionOrder: [ObjectIdentifier] = []
    private var streamGuardEvictionCount = 0
    private var lastStreamGuardLogAt = Date.distantPast
    private var httpActivityRequests = 0
    private var httpActivityCancels = 0
    private var httpActivityLastStart: Int64?
    private var httpActivityWindowStartedAt = Date.distantPast
    private var stopped = false

    init(session: TransportDataSession, fileExtension: String, stopSessionOnStop: Bool = true) {
        self.session = session
        self.fileExtension = fileExtension.isEmpty ? "mp4" : fileExtension
        self.stopSessionOnStop = stopSessionOnStop
    }

    func start() async throws -> URL {
        if let url = currentLocalURL() { return url }
        guard !isStopped else { throw ServerError.failedToStart("服务已经停止") }

        Task { [session] in
            _ = try? await session.resolve()
        }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: ServerError.failedToStart("服务对象已释放"))
                    return
                }
                do {
                    let parameters = NWParameters.tcp
                    parameters.allowLocalEndpointReuse = true
                    parameters.includePeerToPeer = false
                    parameters.requiredLocalEndpoint = .hostPort(
                        host: NWEndpoint.Host("127.0.0.1"),
                        port: .any
                    )

                    let listener = try NWListener(using: parameters, on: .any)
                    guard self.installListener(listener) else {
                        listener.cancel()
                        continuation.resume(throwing: ServerError.failedToStart("服务已经停止"))
                        return
                    }
                    var resumed = false

                    listener.stateUpdateHandler = { [weak self, weak listener] state in
                        guard let self else { return }
                        switch state {
                        case .ready:
                            guard !resumed else { return }
                            resumed = true
                            guard let port = listener?.port,
                                  let url = URL(string: "http://127.0.0.1:\(port.rawValue)/\(self.token)/media.\(self.fileExtension)") else {
                                continuation.resume(throwing: ServerError.missingPort)
                                return
                            }
                            self.setLocalURL(url)
                            DiagnosticsLogger.shared.playback(
                                "TransportHTTP",
                                "server=\(self.logID) ready port=\(port.rawValue) pathToken=redacted"
                            )
                            continuation.resume(returning: url)
                        case .failed(let error):
                            guard !resumed else { return }
                            resumed = true
                            continuation.resume(throwing: ServerError.failedToStart(error.localizedDescription))
                        case .cancelled:
                            guard !resumed else { return }
                            resumed = true
                            continuation.resume(throwing: ServerError.failedToStart("listener cancelled"))
                        default:
                            break
                        }
                    }

                    listener.newConnectionHandler = { [weak self] connection in
                        self?.accept(connection)
                    }
                    listener.start(queue: self.queue)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func metrics() async -> TransportMetricsSnapshot {
        await session.metrics()
    }

    func prioritizeSeek(position: Double, duration: Double) async {
        await session.prioritizeSeek(position: position, duration: duration)
    }

    func recoverStall(position: Double, duration: Double) async {
        await session.recoverStall(position: position, duration: duration)
    }

    func restartListener() async throws -> URL {
        let state = takeServerStateForRestart()
        guard state.canRestart else { throw ServerError.failedToStart("服务已经停止") }
        state.listener?.cancel()
        state.tasks.forEach { $0.cancel() }
        state.connections.forEach { $0.cancel() }
        DiagnosticsLogger.shared.playback(
            "TransportHTTP",
            "server=\(logID) restarting listener connections=\(state.connections.count) tasks=\(state.tasks.count)"
        )
        return try await start()
    }

    func resetClientStreams(reason: String) {
        let state = takeClientStateForReset()
        state.tasks.forEach { $0.cancel() }
        state.connections.forEach { $0.cancel() }
        guard !state.connections.isEmpty || !state.tasks.isEmpty else { return }
        DiagnosticsLogger.shared.playback(
            "TransportHTTP",
            "server=\(logID) reset streams connections=\(state.connections.count) tasks=\(state.tasks.count) reason=\(reason)"
        )
    }

    func stop() {
        let state = takeServerStateForStop()
        state.listener?.cancel()
        state.tasks.forEach { $0.cancel() }
        state.connections.forEach { $0.cancel() }
        if stopSessionOnStop { Task { await session.stop() } }
        DiagnosticsLogger.shared.playback("TransportHTTP", "server=\(logID) stopped sharedSession=\(!stopSessionOnStop)")
    }

    private func accept(_ connection: NWConnection) {
        guard registerConnection(connection) else {
            connection.cancel()
            return
        }

        let identifier = ObjectIdentifier(connection)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .failed(let error):
                if !self.isClientDisconnect(error) {
                    DiagnosticsLogger.shared.playback("TransportHTTP", "server=\(self.logID) connection failed: \(error.localizedDescription)")
                }
                self.removeConnection(identifier, matching: connection)?.cancel()
            case .cancelled:
                self.removeConnection(identifier, matching: connection)?.cancel()
            default:
                break
            }
        }

        connection.start(queue: queue)
        receiveHeaders(on: connection, buffer: Data())
    }

    private func receiveHeaders(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }
            if let error {
                DiagnosticsLogger.shared.playback("TransportHTTP", "server=\(self.logID) receive failed: \(error.localizedDescription)")
                connection.cancel()
                return
            }

            var accumulated = buffer
            if let data { accumulated.append(data) }
            if accumulated.count > 128 * 1024 {
                self.sendSimpleError(status: 431, reason: "Request Header Fields Too Large", on: connection)
                return
            }

            if let headerEnd = accumulated.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = accumulated.subdata(in: accumulated.startIndex..<headerEnd.upperBound)
                do {
                    let request = try self.parseRequest(headerData)
                    let identifier = ObjectIdentifier(connection)
                    let task = Task { [weak self, weak connection] in
                        guard let self, let connection else { return }
                        await self.serve(request, on: connection)
                        self.removeConnection(identifier, matching: connection)?.cancel()
                        connection.cancel()
                    }
                    self.storeTask(task, for: identifier, matching: connection)
                } catch {
                    self.sendSimpleError(status: 400, reason: "Bad Request", on: connection)
                }
                return
            }

            if isComplete {
                self.sendSimpleError(status: 400, reason: "Bad Request", on: connection)
            } else {
                self.receiveHeaders(on: connection, buffer: accumulated)
            }
        }
    }

    private func serve(_ request: HTTPRequest, on connection: NWConnection) async {
        guard request.path == "/\(token)/media.\(fileExtension)" else {
            await sendError(status: 404, reason: "Not Found", on: connection)
            return
        }
        guard request.method == "GET" || request.method == "HEAD" else {
            await sendError(status: 405, reason: "Method Not Allowed", on: connection)
            return
        }

        var responseStarted = false
        do {
            let resource = try await session.resolve()
            let requestedRange = try parseRange(request.headers["range"], contentLength: resource.contentLength)
            let responseRange = requestedRange ?? ByteRange(lowerBound: 0, upperBound: resource.contentLength - 1)
            let hintBytes = min(responseRange.length, 1 * 1_048_576)
            let hintUpper = min(resource.contentLength, responseRange.lowerBound + hintBytes)
            if hintUpper > responseRange.lowerBound { await session.noteDemand(range: responseRange.lowerBound..<hintUpper) }
            let status = requestedRange == nil ? 200 : 206
            let reason = status == 206 ? "Partial Content" : "OK"
            let contentType = resource.contentType ?? "video/mp4"

            var headers = "HTTP/1.1 \(status) \(reason)\r\n"
            headers += "Content-Type: \(contentType)\r\n"
            headers += "Accept-Ranges: bytes\r\n"
            headers += "Content-Length: \(responseRange.length)\r\n"
            headers += "Cache-Control: no-store\r\n"
            headers += "Connection: close\r\n"
            if status == 206 {
                headers += "Content-Range: bytes \(responseRange.lowerBound)-\(responseRange.upperBound)/\(resource.contentLength)\r\n"
            }
            headers += "\r\n"

            let logRequest = recordHTTPActivity(requestStart: responseRange.lowerBound, cancelled: false)
            if logRequest {
                DiagnosticsLogger.shared.playback("TransportHTTPActivity", activitySummary())
            }

            try await send(Data(headers.utf8), on: connection)
            responseStarted = true
            guard request.method == "GET" else { return }

            var cursor = responseRange.lowerBound
            let chunkSize = 512 * 1024
            var terminationReason = "complete"
            while cursor <= responseRange.upperBound {
                if Task.isCancelled { terminationReason = "task-cancelled"; break }
                if isStopped { terminationReason = "server-stopped"; break }
                let length = min(chunkSize, Int(responseRange.upperBound - cursor + 1))
                let data = try await session.read(offset: cursor, length: length)
                if data.isEmpty { terminationReason = "empty-read"; break }
                try await send(data, on: connection)
                cursor += Int64(data.count)
            }

            let sentBytes = max(0, cursor - responseRange.lowerBound)
            if sentBytes < responseRange.length {
                DiagnosticsLogger.shared.playback("TransportHTTPIntegrity", "server=\(logID) start=\(responseRange.lowerBound) expected=\(responseRange.length) sent=\(sentBytes) remaining=\(responseRange.length - sentBytes) reason=\(terminationReason)")
            }
            if logRequest || sentBytes >= 8 * 1_048_576 {
                DiagnosticsLogger.shared.playback(
                    "TransportHTTP",
                    "server=\(logID) response finished start=\(responseRange.lowerBound) sent=\(sentBytes)"
                )
            }
        } catch is CancellationError {
            if recordHTTPActivity(requestStart: nil, cancelled: true) { DiagnosticsLogger.shared.playback("TransportHTTPActivity", activitySummary()) }
        } catch {
            if isClientDisconnect(error) {
                return
            }
            DiagnosticsLogger.shared.playback("TransportHTTP", "server=\(logID) response failed: \(error.localizedDescription)")
            if !responseStarted {
                await sendError(status: 502, reason: "Bad Gateway", on: connection)
            }
        }
    }

    private func recordHTTPActivity(requestStart: Int64?, cancelled: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        if httpActivityWindowStartedAt == .distantPast { httpActivityWindowStartedAt = now }
        if requestStart != nil { httpActivityRequests += 1 }
        if cancelled { httpActivityCancels += 1 }
        if let requestStart { httpActivityLastStart = requestStart }
        return now.timeIntervalSince(httpActivityWindowStartedAt) >= 1
    }

    private func activitySummary() -> String {
        lock.lock()
        let now = Date()
        let elapsed = max(0.001, now.timeIntervalSince(httpActivityWindowStartedAt))
        let requests = httpActivityRequests
        let cancels = httpActivityCancels
        let lastStart = httpActivityLastStart ?? -1
        let active = connections.count
        httpActivityRequests = 0
        httpActivityCancels = 0
        httpActivityWindowStartedAt = now
        lock.unlock()
        return "server=\(logID) windowMs=\(Int(elapsed * 1000)) requests=\(requests) cancels=\(cancels) requestRate=\(String(format: "%.1f", Double(requests) / elapsed))/s active=\(active) lastStart=\(lastStart)"
    }

    private func send(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                content: data,
                contentContext: .defaultMessage,
                isComplete: true,
                completion: .contentProcessed { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            )
        }
    }

    private func sendError(status: Int, reason: String, on connection: NWConnection) async {
        let body = Data("\(status) \(reason)".utf8)
        let response = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: text/plain\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        try? await send(Data(response.utf8) + body, on: connection)
    }

    private func sendSimpleError(status: Int, reason: String, on connection: NWConnection) {
        let body = Data("\(status) \(reason)".utf8)
        let response = Data("HTTP/1.1 \(status) \(reason)\r\nContent-Type: text/plain\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8) + body
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }

    private func parseRequest(_ data: Data) throws -> HTTPRequest {
        guard let text = String(data: data, encoding: .utf8) else { throw ServerError.malformedRequest }
        let lines = text.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { throw ServerError.malformedRequest }
        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { throw ServerError.malformedRequest }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            headers[key] = value
        }

        let target = String(parts[1])
        let path = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? target
        return HTTPRequest(method: String(parts[0]).uppercased(), path: path, headers: headers)
    }

    private func parseRange(_ value: String?, contentLength: Int64) throws -> ByteRange? {
        guard let value, !value.isEmpty else { return nil }
        guard value.lowercased().hasPrefix("bytes=") else { throw ServerError.invalidRange }
        let specification = value.dropFirst(6)
        guard !specification.contains(","), let dash = specification.firstIndex(of: "-") else {
            throw ServerError.invalidRange
        }

        let lowerText = specification[..<dash]
        let upperText = specification[specification.index(after: dash)...]
        let lower: Int64
        let upper: Int64

        if lowerText.isEmpty {
            guard let suffix = Int64(upperText), suffix > 0 else { throw ServerError.invalidRange }
            lower = max(0, contentLength - suffix)
            upper = contentLength - 1
        } else {
            guard let parsedLower = Int64(lowerText), parsedLower >= 0, parsedLower < contentLength else {
                throw ServerError.invalidRange
            }
            lower = parsedLower
            if upperText.isEmpty {
                upper = contentLength - 1
            } else {
                guard let parsedUpper = Int64(upperText), parsedUpper >= lower else {
                    throw ServerError.invalidRange
                }
                upper = min(contentLength - 1, parsedUpper)
            }
        }

        guard upper >= lower else { throw ServerError.invalidRange }
        return ByteRange(lowerBound: lower, upperBound: upper)
    }

    private func isClientDisconnect(_ error: Error) -> Bool {
        guard let networkError = error as? NWError else { return false }
        switch networkError {
        case .posix(let code):
            return code == .ECONNRESET || code == .EPIPE || code == .ENOTCONN || code == .ECANCELED
        default:
            return false
        }
    }

    private func currentLocalURL() -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return localURL
    }

    private var isStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    private func installListener(_ listener: NWListener) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !stopped else { return false }
        self.listener = listener
        return true
    }

    private func setLocalURL(_ url: URL) {
        lock.lock()
        localURL = url
        lock.unlock()
    }

    private func registerConnection(_ connection: NWConnection) -> Bool {
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

    private func storeTask(_ task: Task<Void, Never>, for identifier: ObjectIdentifier, matching connection: NWConnection) {
        lock.lock()
        if connections[identifier] === connection {
            connectionTasks[identifier] = task
        } else {
            task.cancel()
        }
        lock.unlock()
    }

    @discardableResult
    private func removeConnection(_ identifier: ObjectIdentifier, matching connection: NWConnection) -> Task<Void, Never>? {
        lock.lock()
        defer { lock.unlock() }
        guard connections[identifier] === connection else { return nil }
        connections[identifier] = nil
        connectionOrder.removeAll { $0 == identifier }
        return connectionTasks.removeValue(forKey: identifier)
    }

    private func takeClientStateForReset() -> (connections: [NWConnection], tasks: [Task<Void, Never>]) {
        lock.lock()
        defer { lock.unlock() }
        guard !stopped else { return ([], []) }
        let currentConnections = Array(connections.values)
        connections.removeAll()
        connectionOrder.removeAll() // takeClientStateForReset
        let currentTasks = Array(connectionTasks.values)
        connectionTasks.removeAll()
        return (currentConnections, currentTasks)
    }

    private func takeServerStateForStop() -> (listener: NWListener?, connections: [NWConnection], tasks: [Task<Void, Never>]) {
        lock.lock()
        defer { lock.unlock() }
        guard !stopped else { return (nil, [], []) }
        stopped = true
        let currentListener = listener
        listener = nil
        localURL = nil
        let currentConnections = Array(connections.values)
        connections.removeAll()
        connectionOrder.removeAll() // takeServerStateForStop
        let currentTasks = Array(connectionTasks.values)
        connectionTasks.removeAll()
        return (currentListener, currentConnections, currentTasks)
    }

    private func takeServerStateForRestart() -> (canRestart: Bool, listener: NWListener?, connections: [NWConnection], tasks: [Task<Void, Never>]) {
        lock.lock()
        defer { lock.unlock() }
        guard !stopped else { return (false, nil, [], []) }
        let currentListener = listener
        listener = nil
        localURL = nil
        let currentConnections = Array(connections.values)
        connections.removeAll()
        connectionOrder.removeAll() // takeServerStateForRestart
        let currentTasks = Array(connectionTasks.values)
        connectionTasks.removeAll()
        return (true, currentListener, currentConnections, currentTasks)
    }
}
