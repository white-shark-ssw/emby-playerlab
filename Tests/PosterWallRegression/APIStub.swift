    // Only the network boundary is controlled; tests run the production Library model and cache.
    struct Request { let sort: String; let start: Int; let continuation: CheckedContinuation<EmbyItemPage, Error> }
    @MainActor var requests: [Request] = []
    @MainActor func libraryHubItemsPage(parentId: String, limit: Int, startIndex: Int, recursive: Bool, sortBy: String, includeItemTypes: [String], filters: [String]) async throws -> EmbyItemPage {
        try await withCheckedThrowingContinuation { requests.append(Request(sort: sortBy, start: startIndex, continuation: $0)) }
    }
    func libraryResumeItems(parentId: String, limit: Int, includeItemTypes: [String]) async throws -> [LibraryItem] { [] }
    func latestItems(parentId: String, limit: Int, includeItemTypes: [String]) async throws -> [LibraryItem] { [] }
    func librarySuggestions(parentId: String, limit: Int, includeItemTypes: [String]) async throws -> [LibraryItem] { [] }
    func movieRecommendations(parentId: String, categoryLimit: Int, itemLimit: Int) async throws -> [EmbyLibraryRecommendationSection] { [] }
    func libraryGenres(parentId: String, includeItemTypes: [String]) async throws -> [LibraryItem] { [] }
    func libraryFolderChildren(parentId: String) async throws -> [LibraryItem] { [] }
    func libraryItem(itemId: String) async throws -> LibraryItem { throw URLError(.badServerResponse) }

}

func isEmbyRequestCancellation(_ error: Error) -> Bool { (error as? URLError)?.code == .cancelled }
extension EmbyAPIClient {
