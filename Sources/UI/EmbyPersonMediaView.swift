import SwiftUI
import UIKit

struct EmbyPersonMediaView: View {
    let person: EmbyPerson
    let client: EmbyAPIClient
    @StateObject private var model: EmbyPersonMediaViewModel

    init(person: EmbyPerson, client: EmbyAPIClient) {
        self.person = person
        self.client = client
        _model = StateObject(wrappedValue: EmbyPersonMediaViewModel(person: person, client: client))
    }

    var body: some View {
        EmbyPosterResultsPage(items: model.items, revision: model.posterRevision, replacement: model.posterReplacement, client: client, content: .plainMedia, queryIdentity: "person|\(person.itemId ?? "")", isLoading: model.isInitialLoading, hasLoaded: model.hasLoaded, error: model.errorMessage, emptyText: person.itemId?.isEmpty == false ? "暂无作品" : "该演职人员缺少 Emby PersonId，暂时无法按人物精确筛选。", bottomPadding: 24, onApproachingEnd: {
            guard model.hasMore else { return }
            Task { await model.loadNextPage() }
        })
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .nativeInteractivePop()
        .onAppear { if !model.hasLoaded { Task { await model.reload() } } }
    }
}


@MainActor
private final class EmbyPersonMediaViewModel: ObservableObject {
    @Published var items: [LibraryItem] = []
    @Published var isInitialLoading = false
    @Published var errorMessage: String?
    private(set) var hasMore = true
    private let person: EmbyPerson
    private let client: EmbyAPIClient
    private let pageSize = 60
    private var nextStartIndex = 0
    private var isFetching = false
    private var seenItemIDs = Set<String>()
    private(set) var hasLoaded = false
    private(set) var posterRevision = 0
    private(set) var posterReplacement = 0

    init(person: EmbyPerson, client: EmbyAPIClient) { self.person = person; self.client = client }

    func reload() async {
        guard !isFetching else { return }
        items = []
        posterReplacement += 1; posterRevision += 1
        seenItemIDs.removeAll(keepingCapacity: true)
        nextStartIndex = 0
        hasMore = true
        hasLoaded = false
        await fetchNextPage()
    }

    func loadNextPage() async {
        guard hasLoaded, hasMore, !isFetching else { return }
        await fetchNextPage()
    }

    private func fetchNextPage() async {
        guard !isFetching, hasMore else { return }
        guard let personId = person.itemId, !personId.isEmpty else { hasLoaded = true; hasMore = false; return }
        isFetching = true
        if items.isEmpty { isInitialLoading = true }
        if errorMessage != nil { errorMessage = nil }
        let start = nextStartIndex
        defer {
            isFetching = false
            if isInitialLoading { isInitialLoading = false }
            hasLoaded = true
        }
        do {
            let page = try await client.personMediaItems(personId: personId, limit: pageSize, startIndex: start)
            let newItems = page.items.filter { seenItemIDs.insert($0.id).inserted }
            if !newItems.isEmpty { items.append(contentsOf: newItems); posterRevision += 1 }
            nextStartIndex = start + page.items.count
            if let total = page.totalRecordCount { hasMore = nextStartIndex < total }
            else { hasMore = page.items.count == pageSize }
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
        }
    }
}
