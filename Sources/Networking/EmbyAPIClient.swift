import Foundation

final class EmbyAPIClient {
    let baseURL: URL
    let accessToken: String?
    let userId: String?
    let serverName: String?

    init(baseURL: URL, accessToken: String? = nil, userId: String? = nil, serverName: String? = nil) {
        self.baseURL = baseURL
        self.accessToken = accessToken
        self.userId = userId
        self.serverName = serverName
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

    func item(itemId: String) async throws -> BaseItem {
        guard let userId else { throw EmbyAPIError.missingSession }
        return try await send(path: "Users/\(userId)/Items/\(itemId)", method: "GET")
    }

    func libraryItem(itemId: String) async throws -> LibraryItem {
        guard let userId else { throw EmbyAPIError.missingSession }
        return try await send(path: "Users/\(userId)/Items/\(itemId)", method: "GET", query: commonBrowseFields)
    }

    func userViews() async throws -> [LibraryItem] {
        guard let userId else { throw EmbyAPIError.missingSession }
        let page: EmbyItemPage = try await send(path: "Users/\(userId)/Views", method: "GET", query: imageBrowseOptions)
        return deduplicated(page.items)
    }

    func resumeItems(limit: Int = 20) async throws -> [LibraryItem] {
        guard let userId else { throw EmbyAPIError.missingSession }
        let query = commonBrowseFields + [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "MediaTypes", value: "Video"),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie,Episode"),
        ]
        let page: EmbyItemPage = try await send(path: "Users/\(userId)/Items/Resume", method: "GET", query: query)
        return deduplicated(page.items)
    }

    func latestItems(parentId: String? = nil, limit: Int = 20, includeItemTypes: [String] = []) async throws -> [LibraryItem] {
        guard let userId else { throw EmbyAPIError.missingSession }
        var query = commonBrowseFields + [
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "GroupItems", value: "false"),
        ]
        if let parentId, !parentId.isEmpty { query.append(URLQueryItem(name: "ParentId", value: parentId)) }
        if !includeItemTypes.isEmpty { query.append(URLQueryItem(name: "IncludeItemTypes", value: includeItemTypes.joined(separator: ","))) }
        let items: [LibraryItem] = try await send(path: "Users/\(userId)/Items/Latest", method: "GET", query: query)
        return deduplicated(items)
    }

    func libraryItems(parentId: String, limit: Int = 60, startIndex: Int = 0, sortBy: String = "DateCreated", sortOrder: String = "Descending", includeItemTypes: [String] = []) async throws -> EmbyItemPage {
        guard let userId else { throw EmbyAPIError.missingSession }
        var query = commonBrowseFields + [
            URLQueryItem(name: "ParentId", value: parentId),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "StartIndex", value: String(startIndex)),
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "SortBy", value: sortBy),
            URLQueryItem(name: "SortOrder", value: sortOrder),
        ]
        if !includeItemTypes.isEmpty { query.append(URLQueryItem(name: "IncludeItemTypes", value: includeItemTypes.joined(separator: ","))) }
        let page: EmbyItemPage = try await send(path: "Users/\(userId)/Items", method: "GET", query: query)
        return EmbyItemPage(items: deduplicated(page.items), totalRecordCount: page.totalRecordCount)
    }

    func seriesEpisodes(seriesId: String, pageSize: Int = 500) async throws -> [LibraryItem] {
        guard let userId else { throw EmbyAPIError.missingSession }
        var all: [LibraryItem] = []
        var startIndex = 0
        let safePageSize = max(50, min(500, pageSize))
        while true {
            let query = commonBrowseFields + [
                URLQueryItem(name: "UserId", value: userId),
                URLQueryItem(name: "StartIndex", value: String(startIndex)),
                URLQueryItem(name: "Limit", value: String(safePageSize)),
            ]
            let page: EmbyItemPage = try await send(path: "Shows/\(seriesId)/Episodes", method: "GET", query: query)
            guard !page.items.isEmpty else { break }
            all.append(contentsOf: page.items)
            startIndex += page.items.count
            if let total = page.totalRecordCount, startIndex >= total { break }
            if page.items.count < safePageSize { break }
        }
        return deduplicated(all)
    }

    func seriesSeasons(seriesId: String, limit: Int = 100) async throws -> [LibraryItem] {
        let page = try await libraryItems(parentId: seriesId, limit: limit, sortBy: "IndexNumber", sortOrder: "Ascending", includeItemTypes: ["Season"])
        return page.items
    }

    func favoriteItems(limit: Int = 80) async throws -> [LibraryItem] {
        guard let userId else { throw EmbyAPIError.missingSession }
        let query = commonBrowseFields + [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Filters", value: "IsFavorite"),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie,Series,BoxSet,Person"),
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
        ]
        let page: EmbyItemPage = try await send(path: "Users/\(userId)/Items", method: "GET", query: query)
        return deduplicated(page.items)
    }

    func searchItems(term: String, limit: Int = 80) async throws -> [LibraryItem] {
        let page = try await searchItemsPage(term: term, limit: limit, startIndex: 0, includeItemTypes: ["Movie", "Series", "Episode", "BoxSet"])
        return page.items
    }

    func searchItemsPage(term: String, limit: Int = 60, startIndex: Int = 0, includeItemTypes: [String]) async throws -> EmbyItemPage {
        guard let userId else { throw EmbyAPIError.missingSession }
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return EmbyItemPage(items: [], totalRecordCount: 0) }
        let query = commonBrowseFields + [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "SearchTerm", value: trimmed),
            URLQueryItem(name: "IncludeItemTypes", value: includeItemTypes.joined(separator: ",")),
            URLQueryItem(name: "StartIndex", value: String(startIndex)),
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
        ]
        let page: EmbyItemPage = try await send(path: "Users/\(userId)/Items", method: "GET", query: query)
        return EmbyItemPage(items: deduplicated(page.items), totalRecordCount: page.totalRecordCount)
    }

    func similarItems(itemId: String, includeItemTypes: [String], limit: Int = 16) async throws -> [LibraryItem] {
        guard let userId else { throw EmbyAPIError.missingSession }
        var query = commonBrowseFields + [
            URLQueryItem(name: "UserId", value: userId),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Limit", value: String(limit)),
        ]
        if !includeItemTypes.isEmpty { query.append(URLQueryItem(name: "IncludeItemTypes", value: includeItemTypes.joined(separator: ","))) }
        let page: EmbyItemPage = try await send(path: "Items/\(itemId)/Similar", method: "GET", query: query)
        return deduplicated(page.items.filter { $0.id != itemId })
    }

    func imageInfos(itemId: String) async throws -> [EmbyImageInfo] {
        try await send(path: "Items/\(itemId)/Images", method: "GET")
    }

    func imageURL(itemId: String, imageType: String = "Primary", maxWidth: Int = 600, tag: String? = nil, index: Int? = nil) -> URL? {
        var path = "Items/\(itemId)/Images/\(imageType)"
        if let index { path += "/\(index)" }
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        var query = [URLQueryItem(name: "MaxWidth", value: String(maxWidth)), URLQueryItem(name: "Quality", value: "90")]
        if let tag, !tag.isEmpty { query.append(URLQueryItem(name: "Tag", value: tag)) }
        if let accessToken, !accessToken.isEmpty { query.append(URLQueryItem(name: "api_key", value: accessToken)) }
        components?.queryItems = query
        return components?.url
    }

    func setFavorite(itemId: String, favorite: Bool) async throws {
        guard let userId else { throw EmbyAPIError.missingSession }
        let _: EmptyResponse = try await send(path: "Users/\(userId)/FavoriteItems/\(itemId)", method: favorite ? "POST" : "DELETE")
    }

    func setPlayed(itemId: String, played: Bool) async throws {
        guard let userId else { throw EmbyAPIError.missingSession }
        let _: EmptyResponse = try await send(path: "Users/\(userId)/PlayedItems/\(itemId)", method: played ? "POST" : "DELETE")
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

    func resolvePlaybackSource(itemId: String, itemName: String, mediaSource: MediaSource, playSessionId: String?, initialPlaybackPositionTicks: Int64? = nil) throws -> ResolvedPlaybackSource {
        var url: URL?
        if let direct = mediaSource.directStreamURL, !direct.isEmpty {
            if let absolute = URL(string: direct), absolute.scheme != nil { url = absolute }
            else { url = baseURL.appendingPathComponent(direct.hasPrefix("/") ? String(direct.dropFirst()) : direct) }
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
        guard var components = url.flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) else { throw EmbyAPIError.invalidPlaybackURL }
        var items = components.queryItems ?? []
        if let candidateURL = components.url, isSameOrigin(candidateURL, baseURL) {
            if let accessToken, !items.contains(where: { $0.name.caseInsensitiveCompare("api_key") == .orderedSame }) { items.append(URLQueryItem(name: "api_key", value: accessToken)) }
            if let playSessionId, !items.contains(where: { $0.name == "PlaySessionId" }) { items.append(URLQueryItem(name: "PlaySessionId", value: playSessionId)) }
        }
        components.queryItems = items
        guard let finalURL = components.url else { throw EmbyAPIError.invalidPlaybackURL }
        return ResolvedPlaybackSource(itemId: itemId, itemName: itemName, mediaSource: mediaSource, playSessionId: playSessionId, initialPlaybackPositionTicks: initialPlaybackPositionTicks, url: finalURL, headers: safeMediaHeaders(mediaSource.requiredHTTPHeaders ?? [:]))
    }

    func reportStart(source: ResolvedPlaybackSource, position: Double, paused: Bool) async { _ = await report(path: "Sessions/Playing", eventName: nil, source: source, position: position, paused: paused) }
    func reportProgress(source: ResolvedPlaybackSource, position: Double, paused: Bool, eventName: String? = nil) async { _ = await report(path: "Sessions/Playing/Progress", eventName: eventName, source: source, position: position, paused: paused) }
    @discardableResult func reportStopped(source: ResolvedPlaybackSource, position: Double) async -> Bool { await report(path: "Sessions/Playing/Stopped", eventName: nil, source: source, position: position, paused: true) }

    func logout() async {
        do { let _: EmptyResponse = try await send(path: "Sessions/Logout", method: "POST") }
        catch { DiagnosticsLogger.shared.log("Emby", "Logout failed: \(error.localizedDescription)") }
    }

    private var imageBrowseOptions: [URLQueryItem] {
        [
            URLQueryItem(name: "EnableImages", value: "true"),
            URLQueryItem(name: "ImageTypeLimit", value: "1"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop"),
            URLQueryItem(name: "EnableUserData", value: "true"),
        ]
    }

    private var commonBrowseFields: [URLQueryItem] {
        [URLQueryItem(name: "Fields", value: "Overview,PrimaryImageAspectRatio,DateCreated,CommunityRating,OfficialRating,PremiereDate,RunTimeTicks,UserData,ProductionYear,SeriesName,SeriesId,SeasonId,ParentId,IndexNumber,ParentIndexNumber,ChildCount,Genres,Tags,People,Studios,Taglines,ProviderIds")] + imageBrowseOptions
    }

    private func report(path: String, eventName: String?, source: ResolvedPlaybackSource, position: Double, paused: Bool) async -> Bool {
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
        let body = Body(ItemId: source.itemId, MediaSourceId: source.mediaSource.id, PlaySessionId: source.playSessionId, PositionTicks: Int64(max(0, position) * AppIdentity.ticksPerSecond), IsPaused: paused, IsMuted: false, CanSeek: true, PlayMethod: "DirectPlay", EventName: eventName)
        do {
            let _: EmptyResponse = try await send(path: path, method: "POST", body: body)
            return true
        } catch {
            DiagnosticsLogger.shared.log("Emby", "Report \(path) failed: \(error.localizedDescription)")
            return false
        }
    }

    private func send<Response: Decodable>(path: String, method: String, query: [URLQueryItem] = [], authenticated: Bool = true) async throws -> Response {
        try await send(path: path, method: method, query: query, bodyData: nil, authenticated: authenticated)
    }

    private func send<Response: Decodable, Body: Encodable>(path: String, method: String, query: [URLQueryItem] = [], body: Body, authenticated: Bool = true) async throws -> Response {
        try await send(path: path, method: method, query: query, bodyData: try JSONEncoder().encode(body), authenticated: authenticated)
    }

    private func send<Response: Decodable>(path: String, method: String, query: [URLQueryItem], bodyData: Data?, authenticated: Bool) async throws -> Response {
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(url: baseURL.appendingPathComponent(trimmedPath), resolvingAgainstBaseURL: false) else { throw EmbyAPIError.invalidServerURL }
        if !query.isEmpty { components.queryItems = (components.queryItems ?? []) + query }
        guard let url = components.url else { throw EmbyAPIError.invalidServerURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        if method.caseInsensitiveCompare("GET") == .orderedSame {
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authorizationHeader, forHTTPHeaderField: "X-Emby-Authorization")
        request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        if authenticated, let accessToken { request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token") }
        request.httpBody = bodyData
        DiagnosticsLogger.shared.log("HTTP", "\(method) \(SensitiveRedactor.redact(url: url) ?? url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw EmbyAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw EmbyAPIError.http(http.statusCode, SensitiveRedactor.redact(String(data: data, encoding: .utf8) ?? "")) }
        if Response.self == EmptyResponse.self, data.isEmpty { return EmptyResponse() as! Response }
        do { return try JSONDecoder().decode(Response.self, from: data) }
        catch {
            if Response.self == EmptyResponse.self { return EmptyResponse() as! Response }
            DiagnosticsLogger.shared.log("Decode", "\(path): \(error.localizedDescription)")
            throw error
        }
    }

    private var authorizationHeader: String {
        var values = [#"Client="\#(AppIdentity.clientName)""#, #"Device="\#(AppIdentity.deviceName)""#, #"DeviceId="\#(AppIdentity.deviceId)""#, #"Version="\#(AppIdentity.version)""#]
        if let userId, !userId.isEmpty { values.insert(#"UserId="\#(userId)""#, at: 0) }
        if let accessToken, !accessToken.isEmpty { values.append(#"Token="\#(accessToken)""#) }
        return "Emby " + values.joined(separator: ", ")
    }

    private func isSameOrigin(_ lhs: URL, _ rhs: URL) -> Bool { lhs.scheme?.lowercased() == rhs.scheme?.lowercased() && lhs.host?.lowercased() == rhs.host?.lowercased() && lhs.port == rhs.port }

    private func safeMediaHeaders(_ headers: [String: String]) -> [String: String] {
        let blocked = ["authorization", "x-emby-token", "x-mediabrowser-token", "cookie", "set-cookie"]
        return headers.filter { key, _ in !blocked.contains(key.lowercased()) }
    }

    private func deduplicated(_ items: [LibraryItem]) -> [LibraryItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }
}

struct EmptyResponse: Codable { init() {} }
