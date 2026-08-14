import Foundation

extension EmbyAPIClient {
    func favoriteBrowsePage(includeItemTypes: [String], limit: Int = 60, startIndex: Int = 0) async throws -> EmbyItemPage {
        guard let userId else { throw EmbyAPIError.missingSession }
        let safeLimit = max(1, min(500, limit))
        var components = URLComponents(url: baseURL.appendingPathComponent("Users/\(userId)/Items"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "Fields", value: "PrimaryImageAspectRatio,DateCreated,CommunityRating,OfficialRating,PremiereDate,RunTimeTicks,UserData,ProductionYear,SeriesName,SeriesId,SeasonId,ParentId,IndexNumber,ParentIndexNumber"),
            URLQueryItem(name: "EnableImages", value: "true"),
            URLQueryItem(name: "ImageTypeLimit", value: "1"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop"),
            URLQueryItem(name: "EnableUserData", value: "true"),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Filters", value: "IsFavorite"),
            URLQueryItem(name: "IncludeItemTypes", value: includeItemTypes.joined(separator: ",")),
            URLQueryItem(name: "StartIndex", value: String(startIndex)),
            URLQueryItem(name: "Limit", value: String(safeLimit)),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
        ]
        guard let url = components?.url else { throw EmbyAPIError.invalidServerURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let authorization = favoriteAuthorizationHeader
        request.setValue(authorization, forHTTPHeaderField: "X-Emby-Authorization")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        if let accessToken, !accessToken.isEmpty { request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token") }

        DiagnosticsLogger.shared.log("HTTP", "GET \(SensitiveRedactor.redact(url: url) ?? url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw EmbyAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw EmbyAPIError.http(http.statusCode, SensitiveRedactor.redact(String(data: data, encoding: .utf8) ?? "")) }
        return try JSONDecoder().decode(EmbyItemPage.self, from: data)
    }

    func favoriteBrowseItems(includeItemTypes: [String], pageSize: Int = 500) async throws -> [LibraryItem] {
        let safePageSize = max(50, min(500, pageSize))
        var all: [LibraryItem] = []
        var seen = Set<String>()
        var startIndex = 0
        while true {
            let page = try await favoriteBrowsePage(includeItemTypes: includeItemTypes, limit: safePageSize, startIndex: startIndex)
            all.append(contentsOf: page.items.filter { seen.insert($0.id).inserted })
            startIndex += page.items.count
            if page.items.isEmpty { break }
            if let total = page.totalRecordCount, startIndex >= total { break }
            if page.items.count < safePageSize { break }
        }
        return all
    }

    private var favoriteAuthorizationHeader: String {
        var values = [#"Client="\#(AppIdentity.clientName)""#, #"Device="\#(AppIdentity.deviceName)""#, #"DeviceId="\#(AppIdentity.deviceId)""#, #"Version="\#(AppIdentity.version)""#]
        if let userId, !userId.isEmpty { values.insert(#"UserId="\#(userId)""#, at: 0) }
        if let accessToken, !accessToken.isEmpty { values.append(#"Token="\#(accessToken)""#) }
        return "Emby " + values.joined(separator: ", ")
    }
}
