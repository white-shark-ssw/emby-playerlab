import Foundation

private func isSensitiveTransportHeader(_ key: String) -> Bool {
    let lower = key.lowercased()
    return lower == "authorization" || lower == "cookie" || lower == "set-cookie" || lower.hasPrefix("x-emby-") || lower.hasPrefix("x-mediabrowser-")
}

private func applyTransportHeaders(resource: TransportResolvedResource, to request: inout URLRequest) {
    let blocked = Set(["range", "host", "content-length"])
    for (key, value) in resource.requestHeaders where !blocked.contains(key.lowercased()) && !isSensitiveTransportHeader(key) {
        request.setValue(value, forHTTPHeaderField: key)
    }

    let sharedCookie: String? = {
        guard let cookies = HTTPCookieStorage.shared.cookies(for: resource.finalURL), !cookies.isEmpty else { return nil }
        return HTTPCookie.requestHeaderFields(with: cookies)["Cookie"]
    }()
    let capturedCookie = resource.requestHeaders.first { $0.key.caseInsensitiveCompare("Cookie") == .orderedSame }?.value
    if let cookie = sharedCookie ?? capturedCookie, !cookie.isEmpty { request.setValue(cookie, forHTTPHeaderField: "Cookie") }
}

enum RangeRequestLane: Equatable {
    case playback
    case preload(worker: Int)

    var label: String {
        switch self {
        case .playback: return "playback"
        case .preload(let worker): return "preload-\(worker)"
        }
    }
}

final class RangeHTTPClient {
    private let sessions: [URLSession]
    private let streamLanes: [PersistentRangeStreamLane]

    init(maximumConnections: Int) {
        let count = min(max(2, maximumConnections), 8)
        sessions = (0..<count).map { _ in Self.makeSession() }
        streamLanes = (0..<count).map { PersistentRangeStreamLane(index: $0) }
        DiagnosticsLogger.shared.log("TransportV3", "persistent range pool created lanes=\(count)")
    }

    deinit {
        sessions.forEach { $0.invalidateAndCancel() }
        streamLanes.forEach { $0.invalidate() }
    }

    func fetch(resource: TransportResolvedResource, range: Range<Int64>, lane: RangeRequestLane) async throws -> Data {
        guard !range.isEmpty else { return Data() }

        let session = sessions[sessionIndex(for: lane)]
        var request = makeRequest(resource: resource, range: range)
        request.timeoutInterval = 60

        let startedAt = Date()
        let delegate = RedirectCaptureDelegate(initialOrigin: resource.finalURL)
        let (data, response) = try await session.data(for: request, delegate: delegate)
        guard let http = response as? HTTPURLResponse else { throw MediaTransportError.invalidResponse }

        if http.statusCode == 403 || http.statusCode == 410 {
            DiagnosticsLogger.shared.log("TransportRange", "lane=\(lane.label) start=\(range.lowerBound) length=\(range.count) status=\(http.statusCode) expired=true redirects=\(delegate.redirects.count)")
            throw MediaTransportError.expiredURL(statusCode: http.statusCode)
        }
        guard http.statusCode == 206 else { throw MediaTransportError.rangeUnsupported(statusCode: http.statusCode) }

        let expected = Int(range.upperBound - range.lowerBound)
        guard data.count == expected else { throw MediaTransportError.shortRead(expected: expected, actual: data.count) }

        let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
        let speed = Double(data.count) / elapsed
        DiagnosticsLogger.shared.log("TransportRange", "lane=\(lane.label) start=\(range.lowerBound) length=\(data.count) status=\(http.statusCode) ms=\(Int(elapsed * 1000)) speedBps=\(Int(speed)) redirects=\(delegate.redirects.count)")
        return data
    }

    func stream(resource: TransportResolvedResource, range: Range<Int64>, worker: Int) -> AsyncThrowingStream<Data, Error> {
        let index = abs(worker) % streamLanes.count
        return streamLanes[index].makeStream(resource: resource, range: range, lane: .preload(worker: worker))
    }

    private func makeRequest(resource: TransportResolvedResource, range: Range<Int64>) -> URLRequest {
        var request = URLRequest(url: resource.finalURL)
        request.httpMethod = "GET"
        request.networkServiceType = .video
        request.allowsConstrainedNetworkAccess = true
        request.allowsExpensiveNetworkAccess = true
        request.setValue("bytes=\(range.lowerBound)-\(range.upperBound - 1)", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        applyTransportHeaders(resource: resource, to: &request)
        return request
    }

    private func sessionIndex(for lane: RangeRequestLane) -> Int {
        switch lane {
        case .playback: return 0
        case .preload(let worker): return abs(worker) % sessions.count
        }
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 180
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.httpShouldUsePipelining = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }
}

private final class PersistentRangeStreamLane: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private final class StreamState {
        let resource: TransportResolvedResource
        let range: Range<Int64>
        let lane: RangeRequestLane
        let continuation: AsyncThrowingStream<Data, Error>.Continuation
        var pending = Data()
        var pendingReadOffset = 0
        var receivedBytes = 0
        var redirectCount = 0
        var acceptedResponse = false
        var terminalError: Error?

        init(resource: TransportResolvedResource, range: Range<Int64>, lane: RangeRequestLane, continuation: AsyncThrowingStream<Data, Error>.Continuation) {
            self.resource = resource
            self.range = range
            self.lane = lane
            self.continuation = continuation
        }
    }

    private let index: Int
    private let yieldSize = 1 * 1_048_576
    private let lock = NSLock()
    private let delegateQueue: OperationQueue
    private var states: [Int: StreamState] = [:]
    private var invalidated = false
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 180
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.httpShouldUsePipelining = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
    }()

    init(index: Int) {
        self.index = index
        delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.qualityOfService = .userInitiated
        delegateQueue.name = "com.embyplayerlab.transport-v3.lane-\(index)"
        super.init()
    }

    func makeStream(resource: TransportResolvedResource, range: Range<Int64>, lane: RangeRequestLane) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            guard !range.isEmpty else {
                continuation.finish()
                return
            }

            var request = URLRequest(url: resource.finalURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 180
            request.networkServiceType = .video
            request.allowsConstrainedNetworkAccess = true
            request.allowsExpensiveNetworkAccess = true
            request.setValue("bytes=\(range.lowerBound)-\(range.upperBound - 1)", forHTTPHeaderField: "Range")
            request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
            applyTransportHeaders(resource: resource, to: &request)

            lock.lock()
            guard !invalidated else {
                lock.unlock()
                continuation.finish(throwing: MediaTransportError.cancelled)
                return
            }
            let task = session.dataTask(with: request)
            let identifier = task.taskIdentifier
            states[identifier] = StreamState(resource: resource, range: range, lane: lane, continuation: continuation)
            lock.unlock()

            continuation.onTermination = { [weak self, weak task] _ in self?.cancel(taskIdentifier: identifier, task: task) }
            DiagnosticsLogger.shared.log("TransportV3", "lane=\(index) task=\(identifier) start range=\(range.lowerBound)-\(range.upperBound) host=\(resource.finalURL.host ?? "unknown") session=persistent")
            task.priority = URLSessionTask.highPriority
            task.resume()
        }
    }

    func invalidate() {
        lock.lock()
        guard !invalidated else { lock.unlock(); return }
        invalidated = true
        let active = Array(states.values)
        states.removeAll()
        lock.unlock()
        active.forEach { $0.continuation.finish(throwing: MediaTransportError.cancelled) }
        session.invalidateAndCancel()
        DiagnosticsLogger.shared.log("TransportV3", "lane=\(index) session invalidated")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        lock.lock()
        guard let state = states[task.taskIdentifier] else {
            lock.unlock()
            completionHandler(nil)
            return
        }
        state.redirectCount += 1
        let range = state.range
        let resource = state.resource
        lock.unlock()

        guard let target = request.url else {
            completionHandler(request)
            return
        }
        var sanitized = request
        let sourceURL = response.url ?? resource.finalURL
        if !Self.sameOrigin(sourceURL, target) && !Self.same115Family(sourceURL, target) {
            for key in sanitized.allHTTPHeaderFields?.keys ?? [] where isSensitiveTransportHeader(key) { sanitized.setValue(nil, forHTTPHeaderField: key) }
        }
        sanitized.setValue("bytes=\(range.lowerBound)-\(range.upperBound - 1)", forHTTPHeaderField: "Range")
        sanitized.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        if Self.same115Family(sourceURL, target), let cookies = HTTPCookieStorage.shared.cookies(for: target), !cookies.isEmpty, let cookie = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"] {
            sanitized.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        completionHandler(sanitized)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse else {
            setTerminalError(MediaTransportError.invalidResponse, taskIdentifier: dataTask.taskIdentifier)
            completionHandler(.cancel)
            return
        }

        lock.lock()
        guard let state = states[dataTask.taskIdentifier] else {
            lock.unlock()
            completionHandler(.cancel)
            return
        }
        let lane = state.lane.label
        let redirects = state.redirectCount
        lock.unlock()

        if http.statusCode == 403 || http.statusCode == 410 {
            DiagnosticsLogger.shared.log("TransportBulk", "lane=\(lane) status=\(http.statusCode) expired=true redirects=\(redirects)")
            setTerminalError(MediaTransportError.expiredURL(statusCode: http.statusCode), taskIdentifier: dataTask.taskIdentifier)
            completionHandler(.cancel)
            return
        }
        guard http.statusCode == 206 else {
            DiagnosticsLogger.shared.log("TransportBulk", "lane=\(lane) status=\(http.statusCode) expected=206 redirects=\(redirects)")
            setTerminalError(MediaTransportError.rangeUnsupported(statusCode: http.statusCode), taskIdentifier: dataTask.taskIdentifier)
            completionHandler(.cancel)
            return
        }

        lock.lock()
        states[dataTask.taskIdentifier]?.acceptedResponse = true
        lock.unlock()
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        var chunks: [Data] = []
        var continuation: AsyncThrowingStream<Data, Error>.Continuation?

        lock.lock()
        guard let state = states[dataTask.taskIdentifier] else { lock.unlock(); return }
        state.receivedBytes += data.count
        state.pending.append(data)
        while state.pending.count - state.pendingReadOffset >= yieldSize {
            let end = state.pendingReadOffset + yieldSize
            chunks.append(state.pending.subdata(in: state.pendingReadOffset..<end))
            state.pendingReadOffset = end
        }
        if state.pendingReadOffset >= 4 * 1_048_576 || state.pendingReadOffset * 2 >= state.pending.count {
            state.pending.removeSubrange(0..<state.pendingReadOffset)
            state.pendingReadOffset = 0
        }
        continuation = state.continuation
        lock.unlock()

        chunks.forEach { continuation?.yield($0) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        guard let state = states.removeValue(forKey: task.taskIdentifier) else { lock.unlock(); return }
        let terminal = state.terminalError
        let accepted = state.acceptedResponse
        let received = state.receivedBytes
        let remainder = state.pendingReadOffset < state.pending.count ? state.pending.subdata(in: state.pendingReadOffset..<state.pending.count) : Data()
        let redirects = state.redirectCount
        lock.unlock()

        if let terminal {
            state.continuation.finish(throwing: terminal)
            return
        }
        if let error {
            if (error as NSError).code == NSURLErrorCancelled { state.continuation.finish(throwing: MediaTransportError.cancelled) }
            else { state.continuation.finish(throwing: error) }
            return
        }
        guard accepted else {
            state.continuation.finish(throwing: MediaTransportError.invalidResponse)
            return
        }
        let expected = Int(state.range.count)
        guard received == expected else {
            state.continuation.finish(throwing: MediaTransportError.shortRead(expected: expected, actual: received))
            return
        }
        if !remainder.isEmpty { state.continuation.yield(remainder) }
        DiagnosticsLogger.shared.log("TransportV3", "lane=\(index) task=\(task.taskIdentifier) finish bytes=\(received) redirects=\(redirects) session=persistent")
        state.continuation.finish()
    }

    private func setTerminalError(_ error: Error, taskIdentifier: Int) {
        lock.lock()
        states[taskIdentifier]?.terminalError = error
        lock.unlock()
    }

    private func cancel(taskIdentifier: Int, task: URLSessionTask?) {
        lock.lock()
        guard let state = states.removeValue(forKey: taskIdentifier) else { lock.unlock(); return }
        lock.unlock()
        task?.cancel()
        state.continuation.finish(throwing: MediaTransportError.cancelled)
        DiagnosticsLogger.shared.log("TransportV3", "lane=\(index) task=\(taskIdentifier) cancelled taskOnly=true sessionKept=true")
    }

    private static func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == rhs.scheme?.lowercased() && lhs.host?.lowercased() == rhs.host?.lowercased() && lhs.port == rhs.port
    }

    private static func same115Family(_ lhs: URL, _ rhs: URL) -> Bool { is115Host(lhs.host) && is115Host(rhs.host) }

    private static func is115Host(_ host: String?) -> Bool {
        let value = host?.lowercased() ?? ""
        return value == "115.com" || value.hasSuffix(".115.com") || value.contains("115cdn")
    }
}
