import Foundation

private final class DownloadFirstStreamState {
    var continuation: AsyncThrowingStream<Data, Error>.Continuation?
    var session: URLSession?
    var task: URLSessionDataTask?
    var pending = Data()
    var receivedBytes: Int64 = 0
    var statusCode: Int?
    var redirectCount = 0
    var acceptedResponse = false
    var finished = false
    var metrics: URLSessionTaskMetrics?
}

final class DownloadFirstStreamLoader: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let resource: TransportResolvedResource
    private let rangeHeader: String
    private let expectedLength: Int64?
    private let label: String
    private let requestProfile: AVIORequestProfile
    private let yieldSize = 256 * 1024
    private let startedAt = Date()
    private let lock = NSLock()
    private let state = DownloadFirstStreamState()

    init(resource: TransportResolvedResource, rangeHeader: String, expectedLength: Int64?, label: String, requestProfile: AVIORequestProfile = .capturedRedirect) {
        self.resource = resource
        self.rangeHeader = rangeHeader
        self.expectedLength = expectedLength
        self.label = label
        self.requestProfile = requestProfile
    }

    func makeStream() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            lock.lock()
            state.continuation = continuation
            lock.unlock()

            continuation.onTermination = { [weak self] _ in self?.cancel() }
            start()
        }
    }

    private func start() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 3600
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
        var request = AVIORequestBuilder.request(resource: resource, rangeHeader: rangeHeader, profile: requestProfile, timeout: 3600)
        request.networkServiceType = .video
        let task = session.dataTask(with: request)
        task.priority = URLSessionTask.highPriority

        lock.lock()
        state.session = session
        state.task = task
        lock.unlock()
        task.resume()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        let original = task.originalRequest ?? request
        let sanitized = AVIORequestBuilder.sanitizeRedirect(request, response: response, originalRequest: original, resource: resource)
        lock.lock()
        state.redirectCount += 1
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

        lock.lock()
        state.statusCode = http.statusCode
        lock.unlock()

        if http.statusCode == 403 || http.statusCode == 410 {
            completionHandler(.cancel)
            finish(throwing: MediaTransportError.expiredURL(statusCode: http.statusCode))
            return
        }

        let startOffset = Self.rangeStart(rangeHeader)
        guard http.statusCode == 206 || (http.statusCode == 200 && startOffset == 0) else {
            completionHandler(.cancel)
            finish(throwing: MediaTransportError.rangeUnsupported(statusCode: http.statusCode))
            return
        }

        lock.lock()
        state.acceptedResponse = true
        lock.unlock()
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        var chunks: [Data] = []
        lock.lock()
        guard !state.finished else {
            lock.unlock()
            return
        }
        state.receivedBytes += Int64(data.count)
        state.pending.append(data)
        while state.pending.count >= yieldSize {
            chunks.append(Data(state.pending.prefix(yieldSize)))
            state.pending.removeFirst(yieldSize)
        }
        let continuation = state.continuation
        lock.unlock()
        chunks.forEach { continuation?.yield($0) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        lock.lock()
        state.metrics = metrics
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let accepted = state.acceptedResponse
        let received = state.receivedBytes
        let remainder = state.pending
        state.pending.removeAll(keepingCapacity: false)
        let continuation = state.continuation
        lock.unlock()

        if !remainder.isEmpty { continuation?.yield(remainder) }

        if let error {
            if (error as NSError).code == NSURLErrorCancelled {
                finish(throwing: CancellationError())
            } else {
                finish(throwing: error)
            }
            return
        }
        guard accepted else {
            finish(throwing: MediaTransportError.invalidResponse)
            return
        }
        if let expectedLength, received != expectedLength {
            finish(throwing: MediaTransportError.shortRead(expected: Int(expectedLength), actual: Int(received)))
            return
        }
        finish(throwing: nil)
    }

    private func finish(throwing error: Error?) {
        lock.lock()
        guard !state.finished else {
            lock.unlock()
            return
        }
        state.finished = true
        let continuation = state.continuation
        state.continuation = nil
        let session = state.session
        state.session = nil
        state.task = nil
        let received = state.receivedBytes
        let status = state.statusCode
        let redirects = state.redirectCount
        let metrics = state.metrics
        lock.unlock()

        let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
        let transaction = metrics?.transactionMetrics.last
        DiagnosticsLogger.shared.log(
            "DownloadFirstNet",
            "lane=\(label) range=\(rangeHeader) status=\(status.map(String.init) ?? "-") bytes=\(received) ms=\(Int(elapsed * 1000)) speedBps=\(Int(Double(received) / elapsed)) protocol=\(transaction?.networkProtocolName ?? "unknown") reused=\(transaction?.isReusedConnection ?? false) redirects=\(redirects) result=\(error == nil ? "completed" : "failed")"
        )

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
        guard !state.finished else {
            lock.unlock()
            return
        }
        state.finished = true
        let session = state.session
        let task = state.task
        state.session = nil
        state.task = nil
        state.continuation = nil
        lock.unlock()
        task?.cancel()
        session?.invalidateAndCancel()
    }

    private static func rangeStart(_ value: String) -> Int64 {
        guard value.lowercased().hasPrefix("bytes="), let dash = value.firstIndex(of: "-") else { return 0 }
        let start = value[value.index(value.startIndex, offsetBy: 6)..<dash]
        return Int64(start) ?? 0
    }
}
