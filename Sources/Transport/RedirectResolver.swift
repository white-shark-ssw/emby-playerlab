import Foundation

final class StartupRangeBootstrapCache: @unchecked Sendable {
    static let shared = StartupRangeBootstrapCache()

    private struct Entry {
        let data: Data
        let contentLength: Int64
        let etag: String?
        let lastModified: String?
        let storedAt: Date
    }

    private let lock = NSLock()
    private var armedBytes: [String: Int] = [:]
    private var entries: [String: Entry] = [:]
    private let maximumAge: TimeInterval = 30

    private init() {}

    func arm(cacheKey: String, maximumBytes: Int) {
        lock.lock()
        pruneLocked(now: Date())
        armedBytes[cacheKey] = min(4 * 1_048_576, max(64 * 1024, maximumBytes))
        entries[cacheKey] = nil
        lock.unlock()
    }

    func requestedBytes(cacheKey: String) -> Int {
        lock.lock()
        pruneLocked(now: Date())
        let value = armedBytes[cacheKey] ?? 1
        lock.unlock()
        return max(1, value)
    }

    func store(cacheKey: String, data: Data, contentLength: Int64, etag: String?, lastModified: String?) {
        guard !data.isEmpty else { return }
        lock.lock()
        entries[cacheKey] = Entry(data: data, contentLength: contentLength, etag: etag, lastModified: lastModified, storedAt: Date())
        armedBytes[cacheKey] = nil
        lock.unlock()
    }

    func take(cacheKey: String, contentLength: Int64, etag: String?, lastModified: String?) -> Data? {
        lock.lock()
        pruneLocked(now: Date())
        guard let entry = entries.removeValue(forKey: cacheKey) else {
            lock.unlock()
            return nil
        }
        let lengthMatches = entry.contentLength == contentLength
        let etagMatches = entry.etag == nil || etag == nil || entry.etag == etag
        let modifiedMatches = entry.lastModified == nil || lastModified == nil || entry.lastModified == lastModified
        let data = lengthMatches && etagMatches && modifiedMatches ? entry.data : nil
        lock.unlock()
        return data
    }

    private func pruneLocked(now: Date) {
        let expired = entries.compactMap { key, entry in now.timeIntervalSince(entry.storedAt) > maximumAge ? key : nil }
        for key in expired { entries[key] = nil }
    }
}

final class RedirectCaptureDelegate: NSObject, URLSessionTaskDelegate {
    private let initialOrigin: URL
    private let lock = NSLock()
    private var redirectURLs: [URL] = []
    private var finalHeaders: [String: String] = [:]

    init(initialOrigin: URL) {
        self.initialOrigin = initialOrigin
    }

    var redirects: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return redirectURLs
    }

    var latestHeaders: [String: String] {
        lock.lock()
        defer { lock.unlock() }
        return finalHeaders
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
        let sourceURL = response.url ?? initialOrigin
        if !Self.sameOrigin(sourceURL, target) && !Self.same115Family(sourceURL, target) {
            [
                "Authorization",
                "X-Emby-Token",
                "X-MediaBrowser-Token",
                "Cookie",
                "Set-Cookie",
            ].forEach { sanitized.setValue(nil, forHTTPHeaderField: $0) }
        }
        sanitized.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

        lock.lock()
        redirectURLs.append(target)
        finalHeaders = sanitized.allHTTPHeaderFields ?? [:]
        lock.unlock()
        completionHandler(sanitized)
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
        return value == "115.com"
            || value.hasSuffix(".115.com")
            || value.contains("115cdn")
    }
}

struct RedirectResolver {
    func resolve(source: ResolvedPlaybackSource) async throws -> TransportResolvedResource {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 45
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 4

        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        let cacheKey = TransportCacheMaintenance.stableVideoCacheKey(for: source)
        let requestedBytes = StartupRangeBootstrapCache.shared.requestedBytes(cacheKey: cacheKey)
        var request = URLRequest(url: source.url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("EmbyPlayerLab/\(AppIdentity.sourceVersion)", forHTTPHeaderField: "User-Agent")
        source.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue("bytes=0-\(requestedBytes - 1)", forHTTPHeaderField: "Range")

        let delegate = RedirectCaptureDelegate(initialOrigin: source.url)
        let began = Date()
        let (responseData, response) = try await session.data(for: request, delegate: delegate)
        guard let http = response as? HTTPURLResponse, let finalURL = http.url else {
            throw MediaTransportError.invalidResponse
        }

        if http.statusCode == 403 || http.statusCode == 410 {
            throw MediaTransportError.expiredURL(statusCode: http.statusCode)
        }
        guard http.statusCode == 206 || http.statusCode == 200 else {
            throw MediaTransportError.rangeUnsupported(statusCode: http.statusCode)
        }

        let contentLength = Self.totalLength(from: http)
        guard contentLength > 0 else { throw MediaTransportError.unavailableContentLength }
        let acceptsRanges = http.statusCode == 206
            || http.value(forHTTPHeaderField: "Accept-Ranges")?.lowercased().contains("bytes") == true

        let host = finalURL.host?.lowercased() ?? ""
        let path = finalURL.path.lowercased()
        let looksLike115 = host.contains("115") || host.contains("115cdn") || path.contains("115cdn")

        DiagnosticsLogger.shared.log(
            "TransportResolve",
            "status=\(http.statusCode) redirects=\(delegate.redirects.count) bytes=\(contentLength) range=\(acceptsRanges) looksLike115=\(looksLike115)"
        )

        var finalHeaders = delegate.latestHeaders.isEmpty ? source.headers : delegate.latestHeaders
        ["Range", "Host", "Content-Length", "Authorization", "X-Emby-Token", "X-MediaBrowser-Token"].forEach {
            finalHeaders.removeValue(forKey: $0)
        }
        if let cookieStorage = session.configuration.httpCookieStorage,
           let cookies = cookieStorage.cookies(for: finalURL),
           !cookies.isEmpty,
           let cookie = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"] {
            finalHeaders["Cookie"] = cookie
        }

        let etag = http.value(forHTTPHeaderField: "ETag")
        let lastModified = http.value(forHTTPHeaderField: "Last-Modified")
        if requestedBytes > 1, acceptsRanges, !responseData.isEmpty {
            let acceptedCount = min(responseData.count, requestedBytes, Int(contentLength))
            if acceptedCount > 0 {
                let data = acceptedCount == responseData.count ? responseData : Data(responseData.prefix(acceptedCount))
                StartupRangeBootstrapCache.shared.store(cacheKey: cacheKey, data: data, contentLength: contentLength, etag: etag, lastModified: lastModified)
                let elapsedMs = Int(max(0, Date().timeIntervalSince(began)) * 1000)
                DiagnosticsLogger.shared.playback("StartupBootstrap", "captured bytes=\(data.count) status=\(http.statusCode) redirects=\(delegate.redirects.count) total=\(contentLength) ms=\(elapsedMs) finalHost=\(finalURL.host ?? "unknown")")
            }
        }

        return TransportResolvedResource(
            originalURL: source.url,
            finalURL: finalURL,
            requestHeaders: finalHeaders,
            contentLength: contentLength,
            contentType: http.mimeType,
            supportsByteRanges: acceptsRanges,
            etag: etag,
            lastModified: lastModified,
            redirectCount: delegate.redirects.count,
            looksLike115CDN: looksLike115
        )
    }

    private static func totalLength(from response: HTTPURLResponse) -> Int64 {
        if let contentRange = response.value(forHTTPHeaderField: "Content-Range"),
           let slash = contentRange.lastIndex(of: "/") {
            let total = contentRange[contentRange.index(after: slash)...]
            if let value = Int64(total), value > 0 { return value }
        }
        return response.expectedContentLength > 0 ? response.expectedContentLength : 0
    }
}
