    // Only the network boundary is controlled; tests run the production Library model and cache.
    struct Request { let parent: String; let limit: Int; let recursive: Bool; let sort: String; let order: String; let types: [String]; let filters: [String]; let genres: [String]; let start: Int; let continuation: CheckedContinuation<EmbyItemPage, Error> }
    @MainActor var requests: [Request] = []
    @MainActor var automaticLibraryPages = false
    @MainActor func libraryHubItemsPage(parentId: String, limit: Int, startIndex: Int, recursive: Bool, sortBy: String, sortOrder: String = "Descending", includeItemTypes: [String], filters: [String] = [], genres: [String] = []) async throws -> EmbyItemPage {
        try await withCheckedThrowingContinuation { continuation in
            requests.append(Request(parent: parentId, limit: limit, recursive: recursive, sort: sortBy, order: sortOrder, types: includeItemTypes, filters: filters, genres: genres, start: startIndex, continuation: continuation))
            if automaticLibraryPages {
                let type = includeItemTypes.first ?? "Movie"
                let items = (startIndex..<min(startIndex + limit, 660)).map { ["Id": String($0), "Name": "\(type) \($0)", "Type": type] }
                let data = try! JSONSerialization.data(withJSONObject: ["Items": items, "TotalRecordCount": 660])
                continuation.resume(returning: try! JSONDecoder().decode(EmbyItemPage.self, from: data))
            }
        }
    }
    func libraryResumeItems(parentId: String, limit: Int, includeItemTypes: [String]) async throws -> [LibraryItem] { [] }
    func latestItems(parentId: String, limit: Int, includeItemTypes: [String]) async throws -> [LibraryItem] { [] }
    func librarySuggestions(parentId: String, limit: Int, includeItemTypes: [String]) async throws -> [LibraryItem] { [] }
    func movieRecommendations(parentId: String, categoryLimit: Int, itemLimit: Int) async throws -> [EmbyLibraryRecommendationSection] { [] }
    @MainActor var genreRequests: [(String, [String])] = []
    @MainActor var genreResponse: Result<[LibraryItem], Error> = .success([])
    @MainActor var folderRequests: [String] = []
    @MainActor var folderResponses: [String: Result<[LibraryItem], Error>] = [:]
    @MainActor func libraryGenres(parentId: String, includeItemTypes: [String]) async throws -> [LibraryItem] {
        genreRequests.append((parentId, includeItemTypes))
        if automaticLibraryPages { return try JSONDecoder().decode([LibraryItem].self, from: JSONSerialization.data(withJSONObject: [["Id": "genre", "Name": "Fixture Genre", "Type": "Genre"]])) }
        return try genreResponse.get()
    }
    @MainActor func libraryFolderChildren(parentId: String) async throws -> [LibraryItem] {
        folderRequests.append(parentId)
        if automaticLibraryPages {
            let children: [[String: String]] = [["Id": "\(parentId)-child", "Name": "Folder \(parentId)-child", "Type": "CollectionFolder"]] + (1..<150).map { ["Id": "\(parentId)-\($0)", "Name": "Movie \($0)", "Type": "Movie"] }
            return try JSONDecoder().decode([LibraryItem].self, from: JSONSerialization.data(withJSONObject: children))
        }
        return try (folderResponses[parentId] ?? .success([])).get()
    }
    func libraryItem(itemId: String) async throws -> LibraryItem { throw URLError(.badServerResponse) }

}

func isEmbyRequestCancellation(_ error: Error) -> Bool { (error as? URLError)?.code == .cancelled }
extension EmbyAPIClient {
