import Foundation

extension EmbyAPIClient {
    func detailItems(filter: String, isGenre: Bool, limit: Int = 60, startIndex: Int = 0) async throws -> EmbyItemPage {
        try await detailBrowseItems(extraQuery: [URLQueryItem(name: isGenre ? "Genres" : "Tags", value: filter)], limit: limit, startIndex: startIndex)
    }

    func personMediaItems(personId: String, limit: Int = 60, startIndex: Int = 0) async throws -> EmbyItemPage {
        try await detailBrowseItems(extraQuery: [URLQueryItem(name: "PersonIds", value: personId)], limit: limit, startIndex: startIndex)
    }

    private func detailBrowseItems(extraQuery: [URLQueryItem], limit: Int, startIndex: Int) async throws -> EmbyItemPage {
        guard let userId else { throw EmbyAPIError.missingSession }
        guard var components = URLComponents(url: baseURL.appendingPathComponent("Users/\(userId)/Items"), resolvingAgainstBaseURL: false) else { throw EmbyAPIError.invalidServerURL }

        components.queryItems = [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie,Series,Video"),
            URLQueryItem(name: "StartIndex", value: String(startIndex)),
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
            URLQueryItem(name: "Fields", value: "Overview,PrimaryImageAspectRatio,CommunityRating,OfficialRating,PremiereDate,RunTimeTicks,UserData,ProductionYear,SeriesName,SeriesId,IndexNumber,ParentIndexNumber,ChildCount,Genres,Tags,People,Studios"),
            URLQueryItem(name: "EnableImages", value: "true"),
            URLQueryItem(name: "ImageTypeLimit", value: "1"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop"),
            URLQueryItem(name: "EnableUserData", value: "true"),
        ] + extraQuery
        guard let url = components.url else { throw EmbyAPIError.invalidServerURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(detailAuthorizationHeader, forHTTPHeaderField: "X-Emby-Authorization")
        request.setValue(detailAuthorizationHeader, forHTTPHeaderField: "Authorization")
        if let accessToken, !accessToken.isEmpty { request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token") }

        DiagnosticsLogger.shared.log("HTTP", "GET \(SensitiveRedactor.redact(url: url) ?? url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw EmbyAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw EmbyAPIError.http(http.statusCode, SensitiveRedactor.redact(String(data: data, encoding: .utf8) ?? "")) }
        return try JSONDecoder().decode(EmbyItemPage.self, from: data)
    }

    private var detailAuthorizationHeader: String {
        var values = [#"Client="\#(AppIdentity.clientName)""#, #"Device="\#(AppIdentity.deviceName)""#, #"DeviceId="\#(AppIdentity.deviceId)""#, #"Version="\#(AppIdentity.version)""#]
        if let userId, !userId.isEmpty { values.insert(#"UserId="\#(userId)""#, at: 0) }
        if let accessToken, !accessToken.isEmpty { values.append(#"Token="\#(accessToken)""#) }
        return "Emby " + values.joined(separator: ", ")
    }
}
