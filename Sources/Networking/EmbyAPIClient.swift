import Foundation

final class EmbyAPIClient {
    let baseURL: URL
    let accessToken: String?
    let userId: String?

    init(baseURL: URL, accessToken: String? = nil, userId: String? = nil) {
        self.baseURL = baseURL
        self.accessToken = accessToken
        self.userId = userId
    }

    func publicInfo() async throws -> PublicSystemInfo {
        try await send(path: "System/Info/Public", method: "GET", authenticated: false)
    }

    func authenticate(username: String, password: String) async throws -> AuthenticationResult {
        struct Body: Encodable {
            let Username: String
            let Pw: String
        }
        return try await send(path: "Users/AuthenticateByName", method: "POST", body: Body(Username: username, Pw: password), authenticated: false)
    }

    func playbackInfo(itemId: String) async throws -> PlaybackInfoResponse {
        guard let userId else { throw EmbyAPIError.missingSession }
        let query = [
            URLQueryItem(name: "UserId", value: userId),
            URLQueryItem(name: "AutoOpenLiveStream", value: "true"),
            URLQueryItem(name: "IsPlayback", value: "true"),
        ]
        return try await send(path: "Items/\(itemId)/PlaybackInfo", method: "GET", query: query)
    }

    func resolvePlaybackSource(itemId: String, mediaSource: MediaSource, playSessionId: String?) throws -> ResolvedPlaybackSource {
        var url: URL?

        if let direct = mediaSource.directStreamURL, !direct.isEmpty {
            if let absolute = URL(string: direct), absolute.scheme != nil {
                url = absolute
            } else {
                let trimmed = direct.hasPrefix("/") ? String(direct.dropFirst()) : direct
                url = baseURL.appendingPathComponent(trimmed)
            }
        }

        if url == nil {
            var components = URLComponents(url: baseURL.appendingPathComponent("Videos/\(itemId)/stream"), resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "Static", value: "true"),
                URLQueryItem(name: "MediaSourceId", value: mediaSource.id),
                URLQueryItem(name: "DeviceId", value: AppIdentity.deviceId),
            ]
            url = components?.url
        }

        guard var components = url.flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) else {
            throw EmbyAPIError.invalidPlaybackURL
        }

        var items = components.queryItems ?? []
        if let candidateURL = components.url, isSameOrigin(candidateURL, baseURL) {
            if let accessToken, !items.contains(where: { $0.name.caseInsensitiveCompare("api_key") == .orderedSame }) {
                items.append(URLQueryItem(name: "api_key", value: accessToken))
            }
            if let playSessionId, !items.contains(where: { $0.name == "PlaySessionId" }) {
                items.append(URLQueryItem(name: "PlaySessionId", value: playSessionId))
            }
        }
        components.queryItems = items

        guard let finalURL = components.url else { throw EmbyAPIError.invalidPlaybackURL }
        return ResolvedPlaybackSource(
            itemId: itemId,
            mediaSource: mediaSource,
            playSessionId: playSessionId,
            url: finalURL,
            headers: safeMediaHeaders(mediaSource.requiredHTTPHeaders ?? [:])
        )
    }

    func reportStart(source: ResolvedPlaybackSource, position: Double, paused: Bool) async {
        await report(path: "Sessions/Playing", eventName: nil, source: source, position: position, paused: paused)
    }

    func reportProgress(source: ResolvedPlaybackSource, position: Double, paused: Bool, eventName: String? = nil) async {
        await report(path: "Sessions/Playing/Progress", eventName: eventName, source: source, position: position, paused: paused)
    }

    func reportStopped(source: ResolvedPlaybackSource, position: Double) async {
        await report(path: "Sessions/Playing/Stopped", eventName: nil, source: source, position: position, paused: true)
    }

    func logout() async {
        do {
            let _: EmptyResponse = try await send(path: "Sessions/Logout", method: "POST")
        } catch {
            DiagnosticsLogger.shared.log("Emby", "Logout failed: \(error.localizedDescription)")
        }
    }

    private func report(path: String, eventName: String?, source: ResolvedPlaybackSource, position: Double, paused: Bool) async {
        struct Body: Encodable {
            let ItemId: String
            let MediaSourceId: String
            let PlaySessionId: String?
            let PositionTicks: Int64
            let IsPaused: Bool
            let IsMuted: Bool
            let CanSeek: Bool
            let PlayMethod: String
            let EventName: String?
        }

        let body = Body(
            ItemId: source.itemId,
            MediaSourceId: source.mediaSource.id,
            PlaySessionId: source.playSessionId,
            PositionTicks: Int64(max(0, position) * AppIdentity.ticksPerSecond),
            IsPaused: paused,
            IsMuted: false,
            CanSeek: true,
            PlayMethod: "DirectPlay",
            EventName: eventName
        )

        do {
            let _: EmptyResponse = try await send(path: path, method: "POST", body: body)
        } catch {
            DiagnosticsLogger.shared.log("Emby", "Report \(path) failed: \(error.localizedDescription)")
        }
    }

    private func send<Response: Decodable>(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        authenticated: Bool = true
    ) async throws -> Response {
        try await send(path: path, method: method, query: query, bodyData: nil, authenticated: authenticated)
    }

    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Body,
        authenticated: Bool = true
    ) async throws -> Response {
        let bodyData = try JSONEncoder().encode(body)
        return try await send(path: path, method: method, query: query, bodyData: bodyData, authenticated: authenticated)
    }

    private func send<Response: Decodable>(
        path: String,
        method: String,
        query: [URLQueryItem],
        bodyData: Data?,
        authenticated: Bool
    ) async throws -> Response {
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(url: baseURL.appendingPathComponent(trimmedPath), resolvingAgainstBaseURL: false) else {
            throw EmbyAPIError.invalidServerURL
        }
        if !query.isEmpty {
            components.queryItems = (components.queryItems ?? []) + query
        }
        guard let url = components.url else { throw EmbyAPIError.invalidServerURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authorizationHeader, forHTTPHeaderField: "X-Emby-Authorization")
        request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        if authenticated, let accessToken {
            request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")
        }
        request.httpBody = bodyData

        DiagnosticsLogger.shared.log("HTTP", "\(method) \(SensitiveRedactor.redact(url: url) ?? url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw EmbyAPIError.invalidResponse }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw EmbyAPIError.http(http.statusCode, SensitiveRedactor.redact(body))
        }

        if Response.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            if Response.self == EmptyResponse.self {
                return EmptyResponse() as! Response
            }
            DiagnosticsLogger.shared.log("Decode", "\(path): \(error.localizedDescription)")
            throw error
        }
    }

    private var authorizationHeader: String {
        var values = [
            #"Client="\#(AppIdentity.clientName)""#,
            #"Device="\#(AppIdentity.deviceName)""#,
            #"DeviceId="\#(AppIdentity.deviceId)""#,
            #"Version="\#(AppIdentity.version)""#,
        ]
        if let userId, !userId.isEmpty {
            values.insert(#"UserId="\#(userId)""#, at: 0)
        }
        if let accessToken, !accessToken.isEmpty {
            values.append(#"Token="\#(accessToken)""#)
        }
        return "Emby " + values.joined(separator: ", ")
    }

    private func isSameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
            && lhs.host?.lowercased() == rhs.host?.lowercased()
            && lhs.port == rhs.port
    }

    private func safeMediaHeaders(_ headers: [String: String]) -> [String: String] {
        let blocked = ["authorization", "x-emby-token", "x-mediabrowser-token", "cookie", "set-cookie"]
        return headers.filter { key, _ in
            !blocked.contains(key.lowercased())
        }
    }
}

struct EmptyResponse: Codable {
    init() {}
}
