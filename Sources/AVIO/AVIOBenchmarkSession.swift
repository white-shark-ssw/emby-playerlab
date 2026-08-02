import Foundation

private final class AVIOBenchmarkLaneState {
    let id: String
    let label: String
    let requestedRange: String
    let startedAt: Date
    let fileURL: URL?
    var fileHandle: FileHandle?
    var firstByteAt: Date?
    var completedAt: Date?
    var bytesReceived: Int64 = 0
    var statusCode: Int?
    var redirectCount = 0
    var networkProtocol: String?
    var reusedConnection: Bool?
    var connectMilliseconds: Double?
    var completed = false
    var error: String?

    init(id: String, label: String, requestedRange: String, startedAt: Date, fileURL: URL?) {
        self.id = id
        self.label = label
        self.requestedRange = requestedRange
        self.startedAt = startedAt
        self.fileURL = fileURL
        if let fileURL {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            fileHandle = try? FileHandle(forWritingTo: fileURL)
        }
    }

    func closeFile() {
        try? fileHandle?.close()
        fileHandle = nil
    }
}

final class AVIOBenchmarkSessionDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let resource: TransportResolvedResource
    private let lock = NSLock()
    private var states: [Int: AVIOBenchmarkLaneState] = [:]
    private var stoppedByRunner = false

    init(resource: TransportResolvedResource) {
        self.resource = resource
    }

    func register(task: URLSessionDataTask, label: String, requestedRange: String, fileURL: URL?) {
        lock.lock()
        states[task.taskIdentifier] = AVIOBenchmarkLaneState(
            id: "\(ObjectIdentifier(task).hashValue)-\(task.taskIdentifier)",
            label: label,
            requestedRange: requestedRange,
            startedAt: Date(),
            fileURL: fileURL
        )
        lock.unlock()
    }

    func markStoppedByRunner() {
        lock.lock()
        stoppedByRunner = true
        lock.unlock()
    }

    func snapshot(now: Date = Date()) -> [AVIOBenchmarkLaneResult] {
        lock.lock()
        defer { lock.unlock() }
        return states.values.sorted { $0.label < $1.label }.map { state in
            let finishedAt = state.completedAt ?? now
            let elapsed = max(finishedAt.timeIntervalSince(state.startedAt), 0.001)
            let firstByte = state.firstByteAt.map { $0.timeIntervalSince(state.startedAt) * 1000 }
            return AVIOBenchmarkLaneResult(
                id: state.id,
                label: state.label,
                requestedRange: state.requestedRange,
                bytesReceived: state.bytesReceived,
                elapsedSeconds: elapsed,
                firstByteMilliseconds: firstByte,
                statusCode: state.statusCode,
                redirectCount: state.redirectCount,
                networkProtocol: state.networkProtocol,
                reusedConnection: state.reusedConnection,
                connectMilliseconds: state.connectMilliseconds,
                completed: state.completed,
                error: state.error
            )
        }
    }

    func finishFiles(removeTemporaryFiles: Bool) {
        lock.lock()
        let fileURLs = states.values.compactMap { state -> URL? in
            state.closeFile()
            return state.fileURL
        }
        lock.unlock()
        if removeTemporaryFiles {
            fileURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        lock.lock()
        states[task.taskIdentifier]?.redirectCount += 1
        lock.unlock()
        let original = task.originalRequest ?? request
        completionHandler(AVIORequestBuilder.sanitizeRedirect(request, response: response, originalRequest: original, resource: resource))
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            recordError(taskIdentifier: dataTask.taskIdentifier, message: MediaTransportError.invalidResponse.localizedDescription)
            completionHandler(.cancel)
            return
        }

        lock.lock()
        states[dataTask.taskIdentifier]?.statusCode = http.statusCode
        lock.unlock()

        guard http.statusCode == 206 else {
            recordError(taskIdentifier: dataTask.taskIdentifier, message: "HTTP \(http.statusCode)")
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard let state = states[dataTask.taskIdentifier] else {
            lock.unlock()
            return
        }
        if state.firstByteAt == nil { state.firstByteAt = Date() }
        state.bytesReceived += Int64(data.count)
        let fileHandle = state.fileHandle
        lock.unlock()

        if let fileHandle {
            do {
                try fileHandle.write(contentsOf: data)
            } catch {
                recordError(taskIdentifier: dataTask.taskIdentifier, message: "磁盘写入失败：\(error.localizedDescription)")
                dataTask.cancel()
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let transaction = metrics.transactionMetrics.last else { return }
        let connectMilliseconds: Double? = {
            guard let start = transaction.connectStartDate, let end = transaction.connectEndDate else { return nil }
            return end.timeIntervalSince(start) * 1000
        }()

        lock.lock()
        if let state = states[task.taskIdentifier] {
            state.networkProtocol = transaction.networkProtocolName
            state.reusedConnection = transaction.isReusedConnection
            state.connectMilliseconds = connectMilliseconds
        }
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        guard let state = states[task.taskIdentifier] else {
            lock.unlock()
            return
        }
        state.completed = true
        state.completedAt = Date()
        state.closeFile()
        let runnerStopped = stoppedByRunner
        if let error = error as NSError?, !(runnerStopped && error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) {
            state.error = error.localizedDescription
        }
        lock.unlock()
    }

    private func recordError(taskIdentifier: Int, message: String) {
        lock.lock()
        states[taskIdentifier]?.error = message
        lock.unlock()
    }
}

struct AVIOBenchmarkSessionFactory {
    static func make(delegate: AVIOBenchmarkSessionDelegate, maximumConnections: Int) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = max(1, maximumConnections)
        configuration.httpShouldUsePipelining = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.urlCache = nil

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
    }
}
