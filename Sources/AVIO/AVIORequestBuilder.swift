import Foundation

enum AVIORequestBuilder {
    static func request(resource: TransportResolvedResource, rangeHeader: String, profile: AVIORequestProfile, timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: resource.finalURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.networkServiceType = .video
        request.allowsConstrainedNetworkAccess = true
        request.allowsExpensiveNetworkAccess = true
        request.setValue(rangeHeader, forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

        if profile == .capturedRedirect {
            applyCapturedHeaders(resource: resource, to: &request)
        }
        applyCookie(resource: resource, to: &request)
        return request
    }

    static func sanitizeRedirect(_ request: URLRequest, response: HTTPURLResponse, originalRequest: URLRequest, resource: TransportResolvedResource) -> URLRequest {
        var sanitized = request
        let sourceURL = response.url ?? resource.finalURL
        let targetURL = request.url ?? resource.finalURL
        if !sameOrigin(sourceURL, targetURL) && !same115Family(sourceURL, targetURL) {
            ["Authorization", "X-Emby-Token", "X-MediaBrowser-Token", "Cookie", "Set-Cookie"].forEach {
                sanitized.setValue(nil, forHTTPHeaderField: $0)
            }
        }
        sanitized.setValue(originalRequest.value(forHTTPHeaderField: "Range"), forHTTPHeaderField: "Range")
        sanitized.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        if same115Family(sourceURL, targetURL) {
            applyCookie(resource: resource, targetURL: targetURL, to: &sanitized)
        }
        return sanitized
    }

    private static func applyCapturedHeaders(resource: TransportResolvedResource, to request: inout URLRequest) {
        let blocked = Set([
            "range", "host", "content-length", "authorization", "x-emby-token",
            "x-mediabrowser-token", "cookie", "set-cookie", "accept-encoding",
        ])
        for (key, value) in resource.requestHeaders where !blocked.contains(key.lowercased()) {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    private static func applyCookie(resource: TransportResolvedResource, targetURL: URL? = nil, to request: inout URLRequest) {
        let url = targetURL ?? resource.finalURL
        let sharedCookie: String? = {
            guard let cookies = HTTPCookieStorage.shared.cookies(for: url), !cookies.isEmpty else { return nil }
            return HTTPCookie.requestHeaderFields(with: cookies)["Cookie"]
        }()
        let capturedCookie = resource.requestHeaders.first { $0.key.caseInsensitiveCompare("Cookie") == .orderedSame }?.value
        if let cookie = sharedCookie ?? capturedCookie, !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
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
