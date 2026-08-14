import SwiftUI
import Combine
import UIKit

struct V3LibraryBrowserView: View {
    let library: LibraryItem
    let client: EmbyAPIClient
    let dock: AnyView
    @StateObject private var model: V3LibraryBrowserViewModel

    init(library: LibraryItem, client: EmbyAPIClient, dock: AnyView) {
        self.library = library
        self.client = client
        self.dock = dock
        _model = StateObject(wrappedValue: V3LibraryBrowserViewModel(library: library, client: client))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(contentTitle).font(.headline).foregroundColor(.blue)
                    Spacer()
                    Menu {
                        sortButton("加入日期", key: "DateCreated")
                        sortButton("标题", key: "SortName")
                        sortButton("发行日期", key: "PremiereDate")
                        sortButton("播放日期", key: "DatePlayed")
                        sortButton("播放次数", key: "PlayCount")
                        sortButton("播放时长", key: "Runtime")
                        sortButton("随机", key: "Random")
                    } label: { Image(systemName: "arrow.up.arrow.down").font(.system(size: 20)) }
                }
                .padding(.horizontal, EmbyPosterGridMetrics.horizontalPadding)

                if model.isInitialLoading && model.items.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    EmbyPosterGrid(items: model.items, onApproachingEnd: {
                        guard model.hasMore else { return }
                        Task { await model.loadNextPage() }
                    }) { item in
                        EmbyPosterDetailLink(item: item, client: client) {
                            V3PosterCard(item: item, client: client, width: nil)
                        }
                    }
                }

                if let error = model.errorMessage { Text(error).foregroundColor(.red).font(.footnote).padding(.horizontal, EmbyPosterGridMetrics.horizontalPadding) }
            }
            .padding(.bottom, 86)
        }
        .navigationTitle(library.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .overlay(alignment: .bottom) { dock }
        .nativeInteractivePop()
        .onAppear { if !model.hasLoaded { Task { await model.reload() } } }
    }

    private var contentTitle: String {
        switch library.collectionType?.lowercased() { case "tvshows": return "节目"; case "movies": return "电影"; default: return "内容" }
    }

    private func sortButton(_ title: String, key: String) -> some View {
        Button { Task { await model.changeSort(to: key) } } label: { if model.sortBy == key { Label(title, systemImage: "checkmark") } else { Text(title) } }
    }
}

@MainActor
private final class V3LibraryBrowserViewModel: ObservableObject {
    @Published var items: [LibraryItem] = []
    @Published var isInitialLoading = false
    @Published var errorMessage: String?
    @Published var sortBy = "DateCreated"
    private(set) var hasMore = true
    private let library: LibraryItem
    private let client: EmbyAPIClient
    private let pageSize = 60
    private var nextStartIndex = 0
    private var isFetching = false
    private var seenItemIDs = Set<String>()
    private(set) var hasLoaded = false

    init(library: LibraryItem, client: EmbyAPIClient) { self.library = library; self.client = client }

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

    func changeSort(to key: String) async {
        guard key != sortBy else { return }
        sortBy = key
        await reload()
    }

    private func fetchNextPage() async {
        guard !isFetching, hasMore else { return }
        isFetching = true
        if items.isEmpty { isInitialLoading = true }
        if errorMessage != nil { errorMessage = nil }
        let requestedStartIndex = nextStartIndex
        defer {
            isFetching = false
            if isInitialLoading { isInitialLoading = false }
            hasLoaded = true
        }
        do {
            let expectedTypes: [String]
            switch library.collectionType?.lowercased() {
            case "movies": expectedTypes = ["Movie"]
            case "tvshows": expectedTypes = ["Series"]
            case "homevideos": expectedTypes = ["Video"]
            case "mixed": expectedTypes = ["Movie", "Series", "Video"]
            default: expectedTypes = []
            }
            let page = try await client.libraryItems(parentId: library.id, limit: pageSize, startIndex: requestedStartIndex, sortBy: sortBy, includeItemTypes: expectedTypes)
            let allowed = Set(expectedTypes.map { $0.lowercased() })
            let filtered = page.items.filter { allowed.isEmpty || allowed.contains($0.type?.lowercased() ?? "") }
            let newItems = filtered.filter { seenItemIDs.insert($0.id).inserted }
            if !newItems.isEmpty { items.append(contentsOf: newItems) }
            nextStartIndex = requestedStartIndex + page.items.count
            if let totalRecordCount = page.totalRecordCount {
                hasMore = nextStartIndex < totalRecordCount
            } else {
                hasMore = page.items.count == pageSize
            }
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
        }
    }
}

struct V3EmbyFavoritesView: View {
    let client: EmbyAPIClient
    let onClose: () -> Void
    let dock: AnyView
    @StateObject private var model: V3FavoritesViewModel

    init(client: EmbyAPIClient, onClose: @escaping () -> Void, dock: AnyView) {
        self.client = client
        self.onClose = onClose
        self.dock = dock
        _model = StateObject(wrappedValue: V3FavoritesViewModel(client: client))
    }

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 28) {
                    V3PageHeader(title: "收藏", onClose: onClose)
                    favoriteMediaSection("电影", items: model.sections.movies, includeItemType: "Movie")
                    favoriteMediaSection("剧集", items: model.sections.series, includeItemType: "Series")
                    favoriteMediaSection("集", items: model.sections.episodes, includeItemType: "Episode")
                    favoritePeopleSection
                    if model.isLoading { ProgressView().frame(maxWidth: .infinity) }
                    if let error = model.errorMessage { Text(error).font(.footnote).foregroundColor(.red).padding(.horizontal, 16) }
                }
                .padding(.bottom, 86)
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .overlay(alignment: .bottom) { dock }
            .refreshable { await model.load() }
            .onAppear { if !model.hasLoaded { Task { await model.load() } } }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    @ViewBuilder
    private func favoriteMediaSection(_ title: String, items: [LibraryItem], includeItemType: String) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                favoriteSectionHeader(title: title, includeItemType: includeItemType, isPeople: false)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(items.prefix(20)) { item in
                            EmbyPosterDetailLink(item: item, client: client) { V3PosterCard(item: item, client: client, width: 118) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private var favoritePeopleSection: some View {
        if !model.sections.people.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                favoriteSectionHeader(title: "演员", includeItemType: "Person", isPeople: true)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(model.sections.people.prefix(20)) { person in V3FavoritePersonLink(item: person, client: client, width: 118) }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func favoriteSectionHeader(title: String, includeItemType: String, isPeople: Bool) -> some View {
        HStack {
            Text(title).font(.system(size: 20, weight: .bold))
            Spacer()
            NavigationLink(destination: V3FavoriteCategoryGridView(title: title, includeItemType: includeItemType, client: client, dock: dock, isPeople: isPeople)) {
                Text("更多").font(.system(size: 16, weight: .regular)).foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
}

private struct V3FavoriteCategoryGridView: View {
    let title: String
    let includeItemType: String
    let client: EmbyAPIClient
    let dock: AnyView
    let isPeople: Bool
    @StateObject private var model: V3FavoriteCategoryGridViewModel

    init(title: String, includeItemType: String, client: EmbyAPIClient, dock: AnyView, isPeople: Bool) {
        self.title = title
        self.includeItemType = includeItemType
        self.client = client
        self.dock = dock
        self.isPeople = isPeople
        _model = StateObject(wrappedValue: V3FavoriteCategoryGridViewModel(includeItemType: includeItemType, client: client))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if model.isInitialLoading && model.items.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 44)
                } else {
                    EmbyPosterGrid(items: model.items, onApproachingEnd: {
                        guard model.hasMore else { return }
                        Task { await model.loadNextPage() }
                    }) { item in
                        if isPeople { V3FavoritePersonLink(item: item, client: client, width: nil) }
                        else { EmbyPosterDetailLink(item: item, client: client) { V3PosterCard(item: item, client: client, width: nil) } }
                    }
                }
                if let error = model.errorMessage { Text(error).font(.footnote).foregroundColor(.red).padding(.horizontal, EmbyPosterGridMetrics.horizontalPadding) }
            }
            .padding(.top, 8)
            .padding(.bottom, 86)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .overlay(alignment: .bottom) { dock }
        .nativeInteractivePop()
        .onAppear { if !model.hasLoaded { Task { await model.reload() } } }
    }
}

@MainActor
private final class V3FavoriteCategoryGridViewModel: ObservableObject {
    @Published var items: [LibraryItem] = []
    @Published var isInitialLoading = false
    @Published var errorMessage: String?
    private(set) var hasMore = true
    private let includeItemType: String
    private let client: EmbyAPIClient
    private let pageSize = 60
    private var nextStartIndex = 0
    private var isFetching = false
    private var seenItemIDs = Set<String>()
    private(set) var hasLoaded = false

    init(includeItemType: String, client: EmbyAPIClient) { self.includeItemType = includeItemType; self.client = client }

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
            let page = try await client.favoriteBrowsePage(includeItemTypes: [includeItemType], limit: pageSize, startIndex: start)
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

private struct V3FavoritePersonLink: View {
    @Environment(\.embyPosterGridCellWidth) private var gridCellWidth
    let item: LibraryItem
    let client: EmbyAPIClient
    let width: CGFloat?

    private var resolvedWidth: CGFloat { width ?? gridCellWidth ?? 118 }
    private var posterHeight: CGFloat { floor(resolvedWidth / EmbyPosterGridMetrics.posterAspectRatio) }
    private var person: EmbyPerson { EmbyPerson(itemId: item.id, name: item.name, role: nil, type: item.type, primaryImageTag: item.primaryImageTag) }

    var body: some View {
        NavigationLink(destination: EmbyPersonMediaView(person: person, client: client)) {
            VStack(alignment: .leading, spacing: 4) {
                V3RemoteImage(url: client.imageURL(itemId: item.id, maxWidth: max(1, Int(ceil(resolvedWidth * UIScreen.main.scale))), tag: item.primaryImageTag), contentMode: .fill)
                    .frame(width: resolvedWidth, height: posterHeight)
                    .clipped()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(item.name).font(.subheadline).foregroundColor(.primary).lineLimit(1).frame(width: resolvedWidth, height: 20, alignment: .leading)
            }
            .frame(width: resolvedWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct V3FavoriteSections {
    var movies: [LibraryItem] = []
    var series: [LibraryItem] = []
    var episodes: [LibraryItem] = []
    var people: [LibraryItem] = []
}

@MainActor
private final class V3FavoritesViewModel: ObservableObject {
    @Published private(set) var sections = V3FavoriteSections()
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let client: EmbyAPIClient
    private(set) var hasLoaded = false

    init(client: EmbyAPIClient) { self.client = client }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasLoaded = true }
        do {
            let items = try await client.favoriteBrowseItems(includeItemTypes: ["Movie", "Series", "Episode", "Person"])
            sections = V3FavoriteSections(
                movies: items.filter { $0.type?.caseInsensitiveCompare("Movie") == .orderedSame },
                series: items.filter { $0.type?.caseInsensitiveCompare("Series") == .orderedSame },
                episodes: items.filter { $0.type?.caseInsensitiveCompare("Episode") == .orderedSame },
                people: items.filter { $0.type?.caseInsensitiveCompare("Person") == .orderedSame }
            )
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
        }
    }
}

private enum V3SearchDefaults {
    static let detailedSearchEnabled = false
}

struct V3EmbySearchView: View {
    let client: EmbyAPIClient
    let onClose: () -> Void
    let dock: AnyView
    @StateObject private var model: V3SearchViewModel
    @State private var searchText = ""

    init(client: EmbyAPIClient, onClose: @escaping () -> Void, dock: AnyView) {
        self.client = client
        self.onClose = onClose
        self.dock = dock
        _model = StateObject(wrappedValue: V3SearchViewModel(client: client, detailedSearchEnabled: V3SearchDefaults.detailedSearchEnabled))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                V3PageHeader(title: "搜索", onClose: onClose)
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("搜索当前 Emby", text: $searchText, onCommit: { Task { await model.search(searchText) } }).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if !searchText.isEmpty { Button { searchText = ""; model.clear() } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) } }
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        if model.isInitialLoading && model.items.isEmpty {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 44)
                        } else {
                            EmbyPosterGrid(items: model.items, onApproachingEnd: {
                                guard model.hasMore else { return }
                                Task { await model.loadNextPage() }
                            }) { item in
                                EmbyPosterDetailLink(item: item, client: client) { V3PosterCard(item: item, client: client, width: nil) }
                            }
                        }
                    }
                    .padding(.bottom, 86)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .overlay(alignment: .bottom) { dock }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

@MainActor
private final class V3SearchViewModel: ObservableObject {
    @Published private(set) var items: [LibraryItem] = []
    @Published var isInitialLoading = false
    private(set) var hasMore = false
    private let client: EmbyAPIClient
    private let detailedSearchEnabled: Bool
    private let pageSize = 60
    private var nextStartIndex = 0
    private var currentTerm = ""
    private var isFetching = false
    private var seenItemIDs = Set<String>()
    private var generation = 0

    init(client: EmbyAPIClient, detailedSearchEnabled: Bool) { self.client = client; self.detailedSearchEnabled = detailedSearchEnabled }

    private var includeItemTypes: [String] { detailedSearchEnabled ? ["Movie", "Series", "Episode", "BoxSet"] : ["Movie", "Series", "BoxSet"] }

    func search(_ term: String) async {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { clear(); return }
        generation += 1
        currentTerm = trimmed
        items = []
        seenItemIDs.removeAll(keepingCapacity: true)
        nextStartIndex = 0
        hasMore = true
        isFetching = false
        await fetchNextPage(generation: generation)
    }

    func loadNextPage() async {
        guard !currentTerm.isEmpty, hasMore, !isFetching else { return }
        await fetchNextPage(generation: generation)
    }

    func clear() {
        generation += 1
        currentTerm = ""
        items = []
        seenItemIDs.removeAll(keepingCapacity: true)
        nextStartIndex = 0
        hasMore = false
        isInitialLoading = false
        isFetching = false
    }

    private func fetchNextPage(generation requestGeneration: Int) async {
        guard requestGeneration == generation, !isFetching, hasMore, !currentTerm.isEmpty else { return }
        isFetching = true
        if items.isEmpty { isInitialLoading = true }
        let start = nextStartIndex
        let term = currentTerm
        defer {
            if requestGeneration == generation {
                isFetching = false
                if isInitialLoading { isInitialLoading = false }
            }
        }
        do {
            let page = try await client.searchItemsPage(term: term, limit: pageSize, startIndex: start, includeItemTypes: includeItemTypes)
            guard requestGeneration == generation, term == currentTerm else { return }
            let newItems = page.items.filter { seenItemIDs.insert($0.id).inserted }
            if !newItems.isEmpty { items.append(contentsOf: newItems) }
            nextStartIndex = start + page.items.count
            if let total = page.totalRecordCount { hasMore = nextStartIndex < total }
            else { hasMore = page.items.count == pageSize }
        } catch {
            guard requestGeneration == generation else { return }
            if !isEmbyRequestCancellation(error) { items = [] }
            hasMore = false
        }
    }
}

struct V3EmbyServerSettingsView: View {
    let session: EmbySession
    let onClose: () -> Void
    let dock: AnyView
    @State private var shareURL: URL?

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    V3PageHeader(title: "设置", onClose: onClose).padding(.horizontal, -16)
                    V3SettingsCard {
                        settingRow("服务器", value: session.serverName, systemImage: "externaldrive")
                        Divider().padding(.leading, 46)
                        settingRow("用户", value: session.user.name, systemImage: "person")
                        Divider().padding(.leading, 46)
                        settingRow("版本", value: session.serverVersion, systemImage: "info.circle")
                    }
                    V3SettingsCard {
                        NavigationLink(destination: PlayerSettingsView()) { settingRow("播放设置", value: nil, systemImage: "playpause") }
                        Divider().padding(.leading, 46)
                        NavigationLink(destination: CacheSettingsView()) { settingRow("缓存管理", value: nil, systemImage: "externaldrive") }
                        Divider().padding(.leading, 46)
                        NavigationLink(destination: PlaybackLabView()) { settingRow("播放器实验室", value: nil, systemImage: "wrench.and.screwdriver") }
                    }
                    V3SettingsCard {
                        Button { do { shareURL = try DiagnosticsLogger.shared.export() } catch {} } label: { settingRow("导出播放日志", value: nil, systemImage: "doc.text") }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 86)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .overlay(alignment: .bottom) { dock }
            .navigationBarHidden(true)
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) { if let shareURL { ActivityView(items: [shareURL]) } }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func settingRow(_ title: String, value: String?, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage).foregroundColor(.blue).frame(width: 26)
            Text(title).foregroundColor(.primary)
            Spacer()
            if let value { Text(value).foregroundColor(.secondary).lineLimit(1) }
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(Color(uiColor: .tertiaryLabel))
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

private struct V3SettingsCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { VStack(spacing: 0) { content }.background(Color(uiColor: .secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous)) }
}
