import Foundation

enum AVIOSeekWhence {
    case start
    case current
    case end
}

protocol AVIOByteSource: AnyObject {
    var fileSize: Int64 { get }
    func read(maxLength: Int) async throws -> Data
    func seek(offset: Int64, whence: AVIOSeekWhence) async throws -> Int64
}

actor AVIOProbeContext: AVIOByteSource {
    nonisolated let fileSize: Int64

    private let resource: TransportResolvedResource
    private let requestProfile: AVIORequestProfile
    private let session: URLSession
    private var logicalPosition: Int64 = 0
    private var operations: [AVIOProbeOperation] = []

    init(resource: TransportResolvedResource, requestProfile: AVIORequestProfile) {
        self.resource = resource
        self.requestProfile = requestProfile
        fileSize = resource.contentLength

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpShouldSetCookies = true
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    deinit {
        session.invalidateAndCancel()
    }

    func read(maxLength: Int) async throws -> Data {
        let startedAt = Date()
        let requestedOffset = logicalPosition
        guard maxLength > 0, logicalPosition < fileSize else {
            operations.append(AVIOProbeOperation(
                id: UUID(),
                operation: "read-eof",
                requestedOffset: requestedOffset,
                resultingOffset: logicalPosition,
                bytesRead: 0,
                elapsedMilliseconds: 0,
                error: nil
            ))
            return Data()
        }

        let upper = min(fileSize, logicalPosition + Int64(maxLength))
        let rangeHeader = "bytes=\(logicalPosition)-\(upper - 1)"
        var request = AVIORequestBuilder.request(resource: resource, rangeHeader: rangeHeader, profile: requestProfile, timeout: 120)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let delegate = RedirectCaptureDelegate(initialOrigin: resource.finalURL)
            let (data, response) = try await session.data(for: request, delegate: delegate)
            guard let http = response as? HTTPURLResponse else { throw MediaTransportError.invalidResponse }
            guard http.statusCode == 206 else { throw MediaTransportError.rangeUnsupported(statusCode: http.statusCode) }
            logicalPosition += Int64(data.count)
            let elapsed = Date().timeIntervalSince(startedAt) * 1000
            operations.append(AVIOProbeOperation(
                id: UUID(),
                operation: "read",
                requestedOffset: requestedOffset,
                resultingOffset: logicalPosition,
                bytesRead: data.count,
                elapsedMilliseconds: elapsed,
                error: nil
            ))
            DiagnosticsLogger.shared.log("AVIORead", "offset=\(requestedOffset) bytes=\(data.count) next=\(logicalPosition) ms=\(Int(elapsed))")
            return data
        } catch {
            let elapsed = Date().timeIntervalSince(startedAt) * 1000
            operations.append(AVIOProbeOperation(
                id: UUID(),
                operation: "read",
                requestedOffset: requestedOffset,
                resultingOffset: logicalPosition,
                bytesRead: 0,
                elapsedMilliseconds: elapsed,
                error: error.localizedDescription
            ))
            throw error
        }
    }

    func seek(offset: Int64, whence: AVIOSeekWhence) async throws -> Int64 {
        let requestedOffset = offset
        let base: Int64
        switch whence {
        case .start: base = 0
        case .current: base = logicalPosition
        case .end: base = fileSize
        }
        logicalPosition = min(max(0, base + offset), fileSize)
        operations.append(AVIOProbeOperation(
            id: UUID(),
            operation: "seek",
            requestedOffset: requestedOffset,
            resultingOffset: logicalPosition,
            bytesRead: 0,
            elapsedMilliseconds: 0,
            error: nil
        ))
        DiagnosticsLogger.shared.log("AVIOSeek", "offset=\(requestedOffset) result=\(logicalPosition)")
        return logicalPosition
    }

    func report() -> AVIOProbeReport {
        AVIOProbeReport(createdAt: Date(), contentLength: fileSize, operations: operations)
    }
}
