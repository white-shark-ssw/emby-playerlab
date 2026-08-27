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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if model.isInitialLoading && model.items.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 44)
                } else if let itemId = person.itemId, !itemId.isEmpty {
                    EmbyPosterGrid(items: model.items, onApproachingEnd: {
                        guard model.hasMore else { return }
                        Task { await model.loadNextPage() }
                    }) { item in
                        EmbyPosterDetailLink(item: item, client: client) { EmbyPersonResultPoster(item: item, client: client) }
                    }
                } else {
                    Text("该演职人员缺少 Emby PersonId，暂时无法按人物精确筛选。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(20)
                }

                if let error = model.errorMessage { Text(error).font(.footnote).foregroundColor(.red).padding(.horizontal, EmbyPosterGridMetrics.horizontalPadding) }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .nativeInteractivePop()
        .onAppear { if !model.hasLoaded { Task { await model.reload() } } }
    }
}

private struct EmbyPersonResultPoster: View {
    @Environment(\.embyPosterGridCellWidth) private var gridCellWidth
    let item: LibraryItem
    let client: EmbyAPIClient

    private var width: CGFloat { gridCellWidth ?? 118 }
    private var height: CGFloat { floor(width / EmbyPosterGridMetrics.posterAspectRatio) }
    private var imageMaxWidth: Int { min(440, max(1, Int(ceil(width * UIScreen.main.scale)))) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            EmbyCachedRemoteImage(url: client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: imageMaxWidth, tag: item.preferredPrimaryImageTag), contentMode: .fill, showsLoadingIndicator: false)
                .frame(width: width, height: height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(item.name).font(.subheadline).lineLimit(1).frame(width: width, height: 20, alignment: .leading)
            Text(item.productionYear.map(String.init) ?? " ").font(.caption).foregroundColor(.secondary).lineLimit(1).frame(width: width, height: 16, alignment: .leading).opacity(item.productionYear == nil ? 0 : 1)
        }
        .frame(width: width, alignment: .leading)
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

    init(person: EmbyPerson, client: EmbyAPIClient) { self.person = person; self.client = client }

    func reload() async {
        guard !isFetching else { return }
        items = []
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
            if !newItems.isEmpty { items.append(contentsOf: newItems) }
            nextStartIndex = start + page.items.count
            if let total = page.totalRecordCount { hasMore = nextStartIndex < total }
            else { hasMore = page.items.count == pageSize }
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
        }
    }
}
