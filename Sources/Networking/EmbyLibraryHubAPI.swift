import Foundation

struct EmbyLibraryRecommendationSection: Decodable, Identifiable, Hashable {
    let items: [LibraryItem]
    let recommendationType: String?
    let baselineItemName: String?
    let categoryId: Int64?

    var id: String { "\(recommendationType ?? "recommendation")|\(baselineItemName ?? "")|\(categoryId ?? 0)" }

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case recommendationType = "RecommendationType"
        case baselineItemName = "BaselineItemName"
        case categoryId = "CategoryId"
    }
}

extension EmbyAPIClient {
    func libraryHubItemsPage(
        parentId: String,
        limit: Int = 60,
        startIndex: Int = 0,
        recursive: Bool = true,
        sortBy: String = "DateCreated",
        sortOrder: String = "Descending",
        includeItemTypes: [String] = [],
        filters: [String] = [],
        genres: [String] = []
    ) async throws -> EmbyItemPage {
        var query = libraryHubCommonFields + [
            URLQueryItem(name: "ParentId", value: parentId),
            URLQueryItem(name: "Recursive", value: recursive ? "true" : "false"),
            URLQueryItem(name: "StartIndex", value: String(max(0, startIndex))),
            URLQueryItem(name: "Limit", value: String(max(1, min(500, limit)))),
            URLQueryItem(name: "SortBy", value: sortBy),
            URLQueryItem(name: "SortOrder", value: sortOrder),
        ]
        if !includeItemTypes.isEmpty { query.append(URLQueryItem(name: "IncludeItemTypes", value: includeItemTypes.joined(separator: ","))) }
        if !filters.isEmpty { query.append(URLQueryItem(name: "Filters", value: filters.joined(separator: ","))) }
        if !genres.isEmpty { query.append(URLQueryItem(name: "Genres", value: genres.joined(separator: "|"))) }
        return try await libraryHubRequest(path: "Users/\(try libraryHubUserID())/Items", query: query)
    }

    func libraryResumeItems(parentId: String, limit: Int = 20, includeItemTypes: [String] = []) async throws -> [LibraryItem] {
        var query = libraryHubCommonFields + [
            URLQueryItem(name: "ParentId", value: parentId),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Limit", value: String(max(1, min(100, limit)))),
            URLQueryItem(name: "MediaTypes", value: "Video"),
        ]
        if !includeItemTypes.isEmpty { query.append(URLQueryItem(name: "IncludeItemTypes", value: includeItemTypes.joined(separator: ","))) }
        let page: EmbyItemPage = try await libraryHubRequest(path: "Users/\(try libraryHubUserID())/Items/Resume", query: query)
        return libraryHubDeduplicated(page.items)
    }

    func librarySuggestions(parentId: String? = nil, limit: Int = 20, includeItemTypes: [String] = []) async throws -> [LibraryItem] {
        var query = libraryHubCommonFields + [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Limit", value: String(max(1, min(100, limit)))),
        ]
        if let parentId, !parentId.isEmpty { query.append(URLQueryItem(name: "ParentId", value: parentId)) }
        if !includeItemTypes.isEmpty { query.append(URLQueryItem(name: "IncludeItemTypes", value: includeItemTypes.joined(separator: ","))) }
        let page: EmbyItemPage = try await libraryHubRequest(path: "Users/\(try libraryHubUserID())/Suggestions", query: query)
        return libraryHubDeduplicated(page.items)
    }

    func movieRecommendations(parentId: String, categoryLimit: Int = 4, itemLimit: Int = 16) async throws -> [EmbyLibraryRecommendationSection] {
        let query = [
            URLQueryItem(name: "UserId", value: try libraryHubUserID()),
            URLQueryItem(name: "ParentId", value: parentId),
            URLQueryItem(name: "CategoryLimit", value: String(max(1, min(12, categoryLimit)))),
            URLQueryItem(name: "ItemLimit", value: String(max(1, min(50, itemLimit)))),
            URLQueryItem(name: "EnableImages", value: "true"),
            URLQueryItem(name: "ImageTypeLimit", value: "1"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop"),
            URLQueryItem(name: "EnableUserData", value: "true"),
        ]
        let sections: [EmbyLibraryRecommendationSection] = try await libraryHubRequest(path: "Movies/Recommendations", query: query)
        return sections.compactMap { section in
            let items = libraryHubDeduplicated(section.items)
            guard !items.isEmpty else { return nil }
            return EmbyLibraryRecommendationSection(items: items, recommendationType: section.recommendationType, baselineItemName: section.baselineItemName, categoryId: section.categoryId)
        }
    }

    func libraryGenres(parentId: String, includeItemTypes: [String]) async throws -> [LibraryItem] {
        var query = libraryHubCommonFields + [
            URLQueryItem(name: "UserId", value: try libraryHubUserID()),
            URLQueryItem(name: "ParentId", value: parentId),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "StartIndex", value: "0"),
            URLQueryItem(name: "Limit", value: "500"),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
        ]
        if !includeItemTypes.isEmpty { query.append(URLQueryItem(name: "IncludeItemTypes", value: includeItemTypes.joined(separator: ","))) }
        let page: EmbyItemPage = try await libraryHubRequest(path: "Genres", query: query)
        return libraryHubDeduplicated(page.items)
    }

    func libraryFolderChildren(parentId: String, limit: Int = 500) async throws -> [LibraryItem] {
        let page = try await libraryHubItemsPage(parentId: parentId, limit: limit, recursive: false, sortBy: "SortName", sortOrder: "Ascending")
        return page.items
    }

    private func libraryHubUserID() throws -> String {
        guard let userId, !userId.isEmpty else { throw EmbyAPIError.missingSession }
        return userId
    }

    private var libraryHubCommonFields: [URLQueryItem] {
        [
            URLQueryItem(name: "Fields", value: "Overview,PrimaryImageAspectRatio,DateCreated,CommunityRating,OfficialRating,PremiereDate,RunTimeTicks,UserData,ProductionYear,SeriesName,SeriesId,SeasonId,ParentId,IndexNumber,ParentIndexNumber,ChildCount,Genres,Tags,People,Studios"),
            URLQueryItem(name: "EnableImages", value: "true"),
            URLQueryItem(name: "ImageTypeLimit", value: "1"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop"),
            URLQueryItem(name: "EnableUserData", value: "true"),
        ]
    }

    private var libraryHubAuthorizationHeader: String {
        var values = [#"Client="\#(AppIdentity.clientName)""#, #"Device="\#(AppIdentity.deviceName)""#, #"DeviceId="\#(AppIdentity.deviceId)""#, #"Version="\#(AppIdentity.version)""#]
        if let userId, !userId.isEmpty { values.insert(#"UserId="\#(userId)""#, at: 0) }
        if let accessToken, !accessToken.isEmpty { values.append(#"Token="\#(accessToken)""#) }
        return "Emby " + values.joined(separator: ", ")
    }

    private func libraryHubRequest<Response: Decodable>(path: String, query: [URLQueryItem]) async throws -> Response {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else { throw EmbyAPIError.invalidServerURL }
        components.queryItems = query
        guard let url = components.url else { throw EmbyAPIError.invalidServerURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(libraryHubAuthorizationHeader, forHTTPHeaderField: "X-Emby-Authorization")
        request.setValue(libraryHubAuthorizationHeader, forHTTPHeaderField: "Authorization")
        if let accessToken, !accessToken.isEmpty { request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token") }
        DiagnosticsLogger.shared.log("HTTP", "GET \(SensitiveRedactor.redact(url: url) ?? url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw EmbyAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw EmbyAPIError.http(http.statusCode, SensitiveRedactor.redact(String(data: data, encoding: .utf8) ?? "")) }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func libraryHubDeduplicated(_ items: [LibraryItem]) -> [LibraryItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }
}