import Foundation

private func applyTransportHeaders(resource: TransportResolvedResource, to request: inout URLRequest) {
    let blocked = Set([
        "range", "host", "content-length", "authorization", "x-emby-token",
        "x-mediabrowser-token", "cookie", "set-cookie",
    ])
    for (key, value) in resource.requestHeaders where !blocked.contains(key.lowercased()) {
        request.setValue(value, forHTTPHeaderField: key)
    }

    let sharedCookie: String? = {
        guard let cookies = HTTPCookieStorage.shared.cookies(for: resource.finalURL), !cookies.isEmpty else {
            return nil
        }
        return HTTPCookie.requestHeaderFields(with: cookies)["Cookie"]
    }()
    let capturedCookie = resource.requestHeaders.first { $0.key.caseInsensitiveCompare("Cookie") == .orderedSame }?.value
    if let cookie = sharedCookie ?? capturedCookie, !cookie.isEmpty {
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
    }
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

    init(maximumConnections: Int) {
        let count = min(max(2, maximumConnections), 8)
        sessions = (0..<count).map { _ in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 120
            configuration.waitsForConnectivity = true
            configuration.httpMaximumConnectionsPerHost = 1
            configuration.httpShouldUsePipelining = true
            configuration.httpCookieStorage = HTTPCookieStorage.shared
            configuration.httpShouldSetCookies = true
            configuration.urlCache = nil
            return URLSession(configuration: configuration)
        }
    }

    deinit {
        sessions.forEach { $0.invalidateAndCancel() }
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
            DiagnosticsLogger.shared.log(
                "TransportRange",
                "lane=\(lane.label) start=\(range.lowerBound) length=\(range.count) status=\(http.statusCode) expired=true redirects=\(delegate.redirects.count)"
            )
            throw MediaTransportError.expiredURL(statusCode: http.statusCode)
        }
        guard http.statusCode == 206 else {
            throw MediaTransportError.rangeUnsupported(statusCode: http.statusCode)
        }

        let expected = Int(range.upperBound - range.lowerBound)
        guard data.count == expected else {
            throw MediaTransportError.shortRead(expected: expected, actual: data.count)
        }

        let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
        let speed = Double(data.count) / elapsed
        DiagnosticsLogger.shared.log(
            "TransportRange",
            "lane=\(lane.label) start=\(range.lowerBound) length=\(data.count) status=\(http.statusCode) ms=\(Int(elapsed * 1000)) speedBps=\(Int(speed)) redirects=\(delegate.redirects.count)"
        )
        return data
    }

    func stream(resource: TransportResolvedResource, range: Range<Int64>, worker: Int) -> AsyncThrowingStream<Data, Error> {
        let loader = RangeStreamLoader(
            resource: resource,
            range: range,
            lane: .preload(worker: worker)
        )
        return loader.makeStream()
    }

    private func makeRequest(resource: TransportResolvedResource, range: Range<Int64>) -> URLRequest {
        var request = URLRequest(url: resource.finalURL)
        request.httpMethod = "GET"
        request.networkServiceType = .video
        request.allowsConstrainedNetworkAccess = true
        request.allowsExpensiveNetworkAccess = true
        request.setValue("bytes=\(range.lowerBound)-\(range.upperBound - 1)", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("EmbyPlayerLab/\(AppIdentity.sourceVersion)", forHTTPHeaderField: "User-Agent")
        applyTransportHeaders(resource: resource, to: &request)
        return request
    }

    private func sessionIndex(for lane: RangeRequestLane) -> Int {
        switch lane {
        case .playback:
            return 0
        case .preload(let worker):
            guard sessions.count > 1 else { return 0 }
            return 1 + abs(worker) % (sessions.count - 1)
        }
    }
}

private final class RangeStreamLoader: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let resource: TransportResolvedResource
    private let range: Range<Int64>
    private let lane: RangeRequestLane
    private let yieldSize = 1 * 1_048_576
    private let lock = NSLock()

    private var continuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var pending = Data()
    private var pendingReadOffset = 0
    private var receivedBytes = 0
    private var redirectCount = 0
    private var acceptedResponse = false
    private var finished = false

    init(resource: TransportResolvedResource, range: Range<Int64>, lane: RangeRequestLane) {
        self.resource = resource
        self.range = range
        self.lane = lane
    }

    func makeStream() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()

            continuation.onTermination = { [weak self] _ in
                self?.cancel()
            }
            start()
        }
    }

    private func start() {
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

        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.qualityOfService = .userInitiated

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
        self.session = session

        var request = URLRequest(url: resource.finalURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 180
        request.networkServiceType = .video
        request.allowsConstrainedNetworkAccess = true
        request.allowsExpensiveNetworkAccess = true
        request.setValue("bytes=\(range.lowerBound)-\(range.upperBound - 1)", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("EmbyPlayerLab/\(AppIdentity.sourceVersion)", forHTTPHeaderField: "User-Agent")
        applyTransportHeaders(resource: resource, to: &request)

        let task = session.dataTask(with: request)
        task.priority = URLSessionTask.highPriority
        self.task = task
        task.resume()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let target = request.url else {
            completionHandler(request)
            return
        }

        var sanitized = request
        let sourceURL = response.url ?? resource.finalURL
        if !Self.sameOrigin(sourceURL, target) && !Self.same115Family(sourceURL, target) {
            ["Authorization", "X-Emby-Token", "X-MediaBrowser-Token", "Cookie", "Set-Cookie"].forEach {
                sanitized.setValue(nil, forHTTPHeaderField: $0)
            }
        }
        sanitized.setValue("bytes=\(range.lowerBound)-\(range.upperBound - 1)", forHTTPHeaderField: "Range")
        sanitized.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        if Self.same115Family(sourceURL, target),
           let cookies = HTTPCookieStorage.shared.cookies(for: target),
           !cookies.isEmpty,
           let cookie = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"] {
            sanitized.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        lock.lock()
        redirectCount += 1
        lock.unlock()
        completionHandler(sanitized)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            finish(throwing: MediaTransportError.invalidResponse)
            return
        }

        if http.statusCode == 403 || http.statusCode == 410 {
            completionHandler(.cancel)
            DiagnosticsLogger.shared.log(
                "TransportBulk",
                "lane=\(lane.label) start=\(range.lowerBound) length=\(range.count) status=\(http.statusCode) expired=true redirects=\(redirectCount)"
            )
            finish(throwing: MediaTransportError.expiredURL(statusCode: http.statusCode))
            return
        }

        guard http.statusCode == 206 else {
            completionHandler(.cancel)
            finish(throwing: MediaTransportError.rangeUnsupported(statusCode: http.statusCode))
            return
        }

        lock.lock()
        acceptedResponse = true
        lock.unlock()
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        var chunks: [Data] = []

        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        receivedBytes += data.count
        pending.append(data)
        while pending.count - pendingReadOffset >= yieldSize {
            let end = pendingReadOffset + yieldSize
            chunks.append(pending.subdata(in: pendingReadOffset..<end))
            pendingReadOffset = end
        }
        if pendingReadOffset >= 4 * 1_048_576 || pendingReadOffset * 2 >= pending.count {
            pending.removeSubrange(0..<pendingReadOffset)
            pendingReadOffset = 0
        }
        let continuation = self.continuation
        lock.unlock()

        chunks.forEach { continuation?.yield($0) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(throwing: error)
            return
        }

        lock.lock()
        let accepted = acceptedResponse
        let received = receivedBytes
        let remainder = pendingReadOffset < pending.count ? pending.subdata(in: pendingReadOffset..<pending.count) : Data()
        pending.removeAll(keepingCapacity: false)
        pendingReadOffset = 0
        lock.unlock()

        guard accepted else {
            finish(throwing: MediaTransportError.invalidResponse)
            return
        }

        let expected = Int(range.count)
        guard received == expected else {
            finish(throwing: MediaTransportError.shortRead(expected: expected, actual: received))
            return
        }

        if !remainder.isEmpty {
            lock.lock()
            let continuation = self.continuation
            lock.unlock()
            continuation?.yield(remainder)
        }
        finish(throwing: nil)
    }

    private func finish(throwing error: Error?) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let continuation = self.continuation
        self.continuation = nil
        let session = self.session
        self.session = nil
        self.task = nil
        lock.unlock()

        if let error {
            continuation?.finish(throwing: error)
            session?.invalidateAndCancel()
        } else {
            continuation?.finish()
            session?.finishTasksAndInvalidate()
        }
    }

    private func cancel() {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let session = self.session
        let task = self.task
        self.session = nil
        self.task = nil
        self.continuation = nil
        lock.unlock()

        task?.cancel()
        session?.invalidateAndCancel()
    }

    private static func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
            && lhs.host?.lowercased() == rhs.host?.lowercased()
            && lhs.port == rhs.port
    }

    private static func same115Family(_ lhs: URL, _ rhs: URL) -> Bool {
        is115Host(lhs.host) && is115Host(rhs.host)
    }

    private static func is115Host(_ host: String?) -> Bool {
        let value = host?.lowercased() ?? ""
        return value == "115.com" || value.hasSuffix(".115.com") || value.contains("115cdn")
    }
}
