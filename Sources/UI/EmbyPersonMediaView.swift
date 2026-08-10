import SwiftUI

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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if model.isLoading && model.items.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 44)
                } else if let itemId = person.itemId, !itemId.isEmpty {
                    EmbyPosterGrid(items: model.items, onApproachingEnd: {
                        guard model.hasMore else { return }
                        Task { await model.loadNextPage() }
                    }) { item in
                        NavigationLink(destination: EmbyMediaDetailView(item: item, client: client)) {
                            EmbyPersonResultPoster(item: item, client: client)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("该演职人员缺少 Emby PersonId，暂时无法按人物精确筛选。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(20)
                }

                if model.isLoading && !model.items.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12) }
                if let error = model.errorMessage { Text(error).font(.footnote).foregroundColor(.red).padding(.horizontal, EmbyPosterGridMetrics.horizontalPadding) }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .onAppear { if !model.hasLoaded { Task { await model.reload() } } }
    }
}

private struct EmbyPersonResultPoster: View {
    @Environment(\.embyPosterGridCellWidth) private var gridCellWidth
    let item: LibraryItem
    let client: EmbyAPIClient

    private var width: CGFloat { gridCellWidth ?? 118 }
    private var height: CGFloat { floor(width / EmbyPosterGridMetrics.posterAspectRatio) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AsyncImage(url: client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: 440, tag: item.preferredPrimaryImageTag)) { phase in
                switch phase {
                case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                default: Color(uiColor: .secondarySystemBackground).overlay(Image(systemName: "photo").foregroundColor(.secondary))
                }
            }
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
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var hasMore = true
    private let person: EmbyPerson
    private let client: EmbyAPIClient
    private let pageSize = 60
    private var nextStartIndex = 0
    private(set) var hasLoaded = false

    init(person: EmbyPerson, client: EmbyAPIClient) {
        self.person = person
        self.client = client
    }

    func reload() async {
        guard !isLoading else { return }
        items = []
        nextStartIndex = 0
        hasMore = true
        hasLoaded = false
        await fetchNextPage()
    }

    func loadNextPage() async {
        guard hasLoaded, hasMore, !isLoading else { return }
        await fetchNextPage()
    }

    private func fetchNextPage() async {
        guard !isLoading, hasMore else { return }
        guard let personId = person.itemId, !personId.isEmpty else { hasLoaded = true; hasMore = false; return }
        isLoading = true
        errorMessage = nil
        let start = nextStartIndex
        defer { isLoading = false; hasLoaded = true }
        do {
            let page = try await client.personMediaItems(personId: personId, limit: pageSize, startIndex: start)
            var seen = Set(items.map(\.id))
            items.append(contentsOf: page.items.filter { seen.insert($0.id).inserted })
            nextStartIndex = start + page.items.count
            if let total = page.totalRecordCount { hasMore = nextStartIndex < total }
            else { hasMore = page.items.count == pageSize }
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
        }
    }
}
