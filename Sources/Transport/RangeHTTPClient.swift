import Foundation

final class RangeHTTPClient {
    private let session: URLSession

    init(maximumConnections: Int) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 90
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = min(max(1, maximumConnections), 8)
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    deinit {
        session.invalidateAndCancel()
    }

    func fetch(resource: TransportResolvedResource, range: Range<Int64>) async throws -> Data {
        guard !range.isEmpty else { return Data() }

        var request = URLRequest(url: resource.finalURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 45
        request.setValue("bytes=\(range.lowerBound)-\(range.upperBound - 1)", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("EmbyPlayerLab/\(AppIdentity.sourceVersion)", forHTTPHeaderField: "User-Agent")
        resource.requestHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let startedAt = Date()
        let delegate = RedirectCaptureDelegate(initialOrigin: resource.finalURL)
        let (data, response) = try await session.data(for: request, delegate: delegate)
        guard let http = response as? HTTPURLResponse else { throw MediaTransportError.invalidResponse }

        if http.statusCode == 403 || http.statusCode == 410 {
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
            "start=\(range.lowerBound) length=\(data.count) status=\(http.statusCode) ms=\(Int(elapsed * 1000)) speedBps=\(Int(speed)) redirects=\(delegate.redirects.count)"
        )
        return data
    }
}
