import SwiftUI
import Combine
import UIKit

private enum V3LibraryTab: String, CaseIterable, Identifiable {
    case items
    case suggestions
    case trailers
    case collections
    case genres
    case favorites
    case folders

    var id: String { rawValue }
    var supportsSorting: Bool { [.items, .trailers, .collections, .favorites].contains(self) }

    func title(contentTitle: String) -> String {
        switch self {
        case .items: return contentTitle
        case .suggestions: return "建议"
        case .trailers: return "预告片"
        case .collections: return "合集"
        case .genres: return "类别"
        case .favorites: return "我的收藏"
        case .folders: return "文件夹"
        }
    }
}

private struct V3LibraryPageState {
    var nextStartIndex = 0
    var hasMore = true
    var isFetching = false
    var hasLoaded = false
    var seenItemIDs = Set<String>()
}

struct V3LibraryBrowserView: View {
    let library: LibraryItem
    let client: EmbyAPIClient
    @StateObject private var model: V3LibraryBrowserViewModel
    @State private var selectedTab = V3LibraryTab.items
    @State private var nativePosterSelection: LibraryItem?
    @State private var suggestionSelection: LibraryItem?
    @Environment(\.serverDockBottomInset) private var dockBottomInset

    init(library: LibraryItem, client: EmbyAPIClient) {
        self.library = library
        self.client = client
        _model = StateObject(wrappedValue: V3LibraryBrowserViewModel(library: library, client: client))
    }

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            tabContent
        }
        .navigationTitle(library.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { sortMenu.disabled(!selectedTab.supportsSorting).opacity(selectedTab.supportsSorting ? 1 : 0.35) }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .serverDockPage()
        .nativeInteractivePop()
        .task(id: selectedTab) { await model.load(tab: selectedTab) }
        .onReceive(NotificationCenter.default.publisher(for: EmbyUserDataChange.notification)) { notification in
            guard let source = notification.object as? EmbyAPIClient, source === client, let itemID = notification.userInfo?[EmbyUserDataChange.itemIDKey] as? String else { return }
            Task { await model.refreshUserData(itemID: itemID) }
        }
    }

    private var contentTitle: String {
        switch library.collectionType?.lowercased() {
        case "tvshows": return "节目"
        case "movies": return "电影"
        case "homevideos": return "视频"
        default: return "内容"
        }
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(V3LibraryTab.allCases) { tab in
                    Button {
                        guard selectedTab != tab else { return }
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 5) {
                            Text(tab.title(contentTitle: contentTitle))
                                .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .blue : .secondary)
                                .fixedSize(horizontal: true, vertical: false)
                            Capsule()
                                .fill(selectedTab == tab ? Color.blue : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 44)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .items: nativeItemsTab
        case .trailers, .collections, .favorites:
            pagedPosterTab(selectedTab)
        case .suggestions:
            suggestionsTab
        case .genres:
            genresTab
        case .folders:
            foldersTab
        }
    }

    private var nativeItemsTab: some View {
        EmbyPosterWall(items: model.items(for: .items), revision: model.posterRevision, replacement: model.posterReplacement, client: client,
            isLoading: model.isLoading(tab: .items), hasLoaded: model.hasLoaded(tab: .items), error: model.errorMessage(for: .items),
            emptyText: "暂无\(contentTitle)内容", bottomPadding: ServerDockMetrics.contentBottomPadding(bottomInset: dockBottomInset), isActive: nativePosterSelection == nil,
            onApproachingEnd: { if model.hasMore(tab: .items) { Task { await model.loadNextPage(tab: .items) } } },
            onRefresh: { Task { await model.refresh(tab: .items) } },
            onSelect: { item in if nativePosterSelection == nil { nativePosterSelection = item } })
            .background(nativePosterNavigationLink)
    }

    // Keep the link mounted before selection, so native taps produce false → true system activation.
    private var nativePosterNavigationLink: some View {
        NavigationLink(destination: Group {
            if let item = nativePosterSelection {
                if v3LibraryIsBrowsableFolder(item) { V3LibraryFolderBrowserView(folder: item, client: client) }
                else { EmbyPosterDetailDestination(item: item, client: client) }
            } else { EmptyView() }
        }, isActive: Binding(get: { nativePosterSelection != nil }, set: { if !$0 { nativePosterSelection = nil } })) { EmptyView() }
            .frame(width: 0, height: 0).hidden()
    }

    private func pagedPosterTab(_ tab: V3LibraryTab) -> some View {
        V3LibraryPosterPage(items: model.items(for: tab), revision: model.revision(for: tab), replacement: model.replacement(for: tab), client: client,
            queryIdentity: "\(library.id)|\(tab.rawValue)", isLoading: model.isLoading(tab: tab), hasLoaded: model.hasLoaded(tab: tab), error: model.errorMessage(for: tab),
            emptyText: tab == .favorites ? "这个媒体库还没有收藏内容" : "暂无\(tab.title(contentTitle: contentTitle))内容",
            onApproachingEnd: { if model.hasMore(tab: tab) { Task { await model.loadNextPage(tab: tab) } } },
            onRefresh: { Task { await model.refresh(tab: tab) } })
            .id(tab)
    }

    private var suggestionsTab: some View {
        EmbyPosterSections(sections: suggestionPosterSections, queryIdentity: "suggestions|\(library.id)", topPadding: 8, sectionGap: 28, bottomPadding: ServerDockMetrics.contentBottomPadding(bottomInset: dockBottomInset), isLoading: model.isLoading(tab: .suggestions) && !model.hasSuggestionContent, emptyText: model.hasLoaded(tab: .suggestions) ? "暂无建议内容" : nil, error: model.errorMessage(for: .suggestions), isActive: suggestionSelection == nil, onRefresh: { completion in Task { await model.refresh(tab: .suggestions); completion() } }, top: EmptyView())
            .background(
                NavigationLink(isActive: Binding(get: { suggestionSelection != nil }, set: { if !$0 { suggestionSelection = nil } })) {
                    if let item = suggestionSelection { EmbyPosterDetailDestination(item: item, client: client) }
                    else { EmptyView() }
                } label: { EmptyView() }
                .hidden()
            )
    }

    private var suggestionPosterSections: [EmbyPosterSection] {
        var sections: [EmbyPosterSection] = []
        if !model.suggestionResumeItems.isEmpty {
            sections.append(EmbyPosterSection(id: "resume", title: "继续观看", items: model.suggestionResumeItems, client: client, style: .landscape, titleGap: 28, onSelect: { suggestionSelection = $0 }))
        }
        if !model.suggestionLatestItems.isEmpty {
            sections.append(EmbyPosterSection(id: "latest", title: model.latestSuggestionTitle, items: model.suggestionLatestItems, client: client, titleGap: 28, onSelect: { suggestionSelection = $0 }))
        }
        for section in model.recommendationSections {
            sections.append(EmbyPosterSection(id: "recommendation|\(section.id)", title: model.title(for: section), items: section.items, client: client, titleGap: 28, onSelect: { suggestionSelection = $0 }))
        }
        if model.recommendationSections.isEmpty && !model.genericSuggestionItems.isEmpty {
            sections.append(EmbyPosterSection(id: "generic", title: "推荐", items: model.genericSuggestionItems, client: client, titleGap: 28, onSelect: { suggestionSelection = $0 }))
        }
        return sections
    }

    private var genresTab: some View {
        V3LibraryPosterPage(items: model.genres, revision: model.genreRevision, replacement: model.genreRevision, client: client,
            destination: .genre(library: library), queryIdentity: "\(library.id)|genres", isLoading: model.isLoading(tab: .genres), hasLoaded: model.hasLoaded(tab: .genres),
            error: model.errorMessage(for: .genres), emptyText: "这个媒体库暂无类别", onRefresh: { Task { await model.refresh(tab: .genres) } })
            .id(V3LibraryTab.genres)
    }

    private var foldersTab: some View {
        V3LibraryPosterPage(items: model.folderItems, revision: model.folderRevision, replacement: model.folderRevision, client: client,
            destination: .folders, queryIdentity: "\(library.id)|folders", isLoading: model.isLoading(tab: .folders), hasLoaded: model.hasLoaded(tab: .folders),
            error: model.errorMessage(for: .folders), emptyText: "这个媒体库暂无文件夹内容", onRefresh: { Task { await model.refresh(tab: .folders) } })
            .id(V3LibraryTab.folders)
    }

    private var sortMenu: some View {
        Menu {
            sortButton("加入日期", key: "DateCreated")
            sortButton("标题", key: "SortName")
            sortButton("发行日期", key: "PremiereDate")
            sortButton("播放日期", key: "DatePlayed")
            sortButton("播放次数", key: "PlayCount")
            sortButton("播放时长", key: "Runtime")
            sortButton("随机", key: "Random")
        } label: {
            Image(systemName: "arrow.up.arrow.down").font(.system(size: 20))
        }
        .accessibilityLabel("排序")
    }

    private func sortButton(_ title: String, key: String) -> some View {
        Button { Task { await model.changeSort(to: key, tab: selectedTab) } } label: { if model.sortBy == key { Label(title, systemImage: "checkmark") } else { Text(title) } }
    }

    private func emptyState(text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.stack").font(.system(size: 28)).foregroundColor(.secondary)
            Text(text).font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    private func errorText(_ message: String) -> some View { Text(message).foregroundColor(.red).font(.footnote).padding(.horizontal, EmbyPosterGridMetrics.horizontalPadding) }
}

@MainActor
private final class V3LibraryBrowserViewModel: ObservableObject {
    @Published private var tabItems: [V3LibraryTab: [LibraryItem]] = [:] { didSet { posterRevision += 1 } }
    private(set) var posterRevision = 0
    private(set) var posterReplacement = 0
    @Published var suggestionResumeItems: [LibraryItem] = []
    @Published var suggestionLatestItems: [LibraryItem] = []
    @Published var genericSuggestionItems: [LibraryItem] = []
    @Published var recommendationSections: [EmbyLibraryRecommendationSection] = []
    @Published var genres: [LibraryItem] = [] { didSet { genreRevision += 1 } }
    @Published var folderItems: [LibraryItem] = [] { didSet { folderRevision += 1 } }
    private(set) var genreRevision = 0
    private(set) var folderRevision = 0
    private var tabRevisions: [V3LibraryTab: Int] = [:]
    private var tabReplacements: [V3LibraryTab: Int] = [:]
    private var liveTabSortBy: [V3LibraryTab: String] = [:]
    private var liveCoverTabs = Set<V3LibraryTab>()
    private var lastRequestedTab: V3LibraryTab?
    @Published var sortBy = "DateCreated"
    @Published private var loadingTabs = Set<V3LibraryTab>()
    @Published private var loadedTabs = Set<V3LibraryTab>()
    @Published private var errorMessages: [V3LibraryTab: String] = [:]

    private let library: LibraryItem
    private let client: EmbyAPIClient
    private let pageSize = 60
    private var pageStates: [V3LibraryTab: V3LibraryPageState] = [:]
    private var fetchGenerations: [V3LibraryTab: Int] = [:]
    // Disk restoration and failed requests also populate loadedTabs; only a successful live response for this sort
    // makes this page's ordinary reappearance safe to skip. Explicit refresh/sort keep their reset path.
    private var liveItemsSortBy: String?
    private let pageTraceID = String(UUID().uuidString.prefix(8))
    private var pageTraceEvents = 0

    init(library: LibraryItem, client: EmbyAPIClient) {
        self.library = library
        self.client = client
        restoration = Task { await V3PagePersistentCache.shared.restoreLibrary(client: client, libraryID: library.id) }
    }

    private var restoration: Task<(V3LibraryPersistentSnapshot, [String: Set<String>])?, Never>?

    private func restoreIfNeeded() async {
        guard let task = restoration else { return }
        let restored = await task.value
        guard restoration != nil else { return }
        // Drop the completed future so the pre-refresh metadata snapshot is not retained for the page lifetime.
        restoration = nil
        guard let (snapshot, seen) = restored else { return }
        posterReplacement += 1
        for tab in [V3LibraryTab.trailers, .collections, .favorites] { tabRevisions[tab, default: 0] += 1; tabReplacements[tab, default: 0] += 1 }
        tabItems = Dictionary(uniqueKeysWithValues: snapshot.tabItems.compactMap { key, items in V3LibraryTab(rawValue: key).map { ($0, items) } })
        suggestionResumeItems = snapshot.suggestionResumeItems
        suggestionLatestItems = snapshot.suggestionLatestItems
        genericSuggestionItems = snapshot.genericSuggestionItems
        recommendationSections = snapshot.recommendationSections
        genres = snapshot.genres
        folderItems = snapshot.folderItems
        sortBy = snapshot.sortBy
        loadedTabs = Set(snapshot.loadedTabs.compactMap(V3LibraryTab.init(rawValue:)))
        for (rawTab, persisted) in snapshot.pageStates {
            guard let tab = V3LibraryTab(rawValue: rawTab) else { continue }
            pageStates[tab] = V3LibraryPageState(nextStartIndex: persisted.nextStartIndex, hasMore: persisted.hasMore, isFetching: false, hasLoaded: loadedTabs.contains(tab), seenItemIDs: seen[rawTab] ?? [])
        }
    }

    var hasSuggestionContent: Bool { !suggestionResumeItems.isEmpty || !suggestionLatestItems.isEmpty || !genericSuggestionItems.isEmpty || !recommendationSections.isEmpty }
    var latestSuggestionTitle: String { library.collectionType?.caseInsensitiveCompare("tvshows") == .orderedSame ? "最新剧集" : "最新电影" }

    func revision(for tab: V3LibraryTab) -> Int { tab == .items ? posterRevision : tabRevisions[tab] ?? 0 }
    func replacement(for tab: V3LibraryTab) -> Int { tab == .items ? posterReplacement : tabReplacements[tab] ?? 0 }

    func items(for tab: V3LibraryTab) -> [LibraryItem] { tabItems[tab] ?? [] }
    func isLoading(tab: V3LibraryTab) -> Bool { loadingTabs.contains(tab) }
    func hasLoaded(tab: V3LibraryTab) -> Bool { loadedTabs.contains(tab) }
    func errorMessage(for tab: V3LibraryTab) -> String? { errorMessages[tab] }
    func hasMore(tab: V3LibraryTab) -> Bool { pageStates[tab]?.hasMore ?? false }

    func load(tab: V3LibraryTab) async {
        await restoreIfNeeded()
        guard !isLoading(tab: tab) else { return }
        let samePage = lastRequestedTab == tab
        lastRequestedTab = tab
        if tab == .items && liveItemsSortBy == sortBy { return }
        // A push/pop keeps this successful query, while an explicit tab switch retains its original reload.
        if samePage && (liveTabSortBy[tab] == sortBy || liveCoverTabs.contains(tab)) { return }
        switch tab {
        case .items, .trailers, .collections, .favorites: await fetchPage(tab: tab, reset: true)
        case .suggestions: await loadSuggestions(force: true)
        case .genres: await loadGenres(force: true)
        case .folders: await loadFolders(force: true)
        }
    }

    func refresh(tab: V3LibraryTab) async {
        await restoreIfNeeded()
        guard !isLoading(tab: tab) else { return }
        switch tab {
        case .items, .trailers, .collections, .favorites: await fetchPage(tab: tab, reset: true)
        case .suggestions: await loadSuggestions(force: true)
        case .genres: await loadGenres(force: true)
        case .folders: await loadFolders(force: true)
        }
    }

    func loadNextPage(tab: V3LibraryTab) async {
        await restoreIfNeeded()
        guard [.items, .trailers, .collections, .favorites].contains(tab), hasLoaded(tab: tab), hasMore(tab: tab), !isLoading(tab: tab) else { return }
        await fetchPage(tab: tab, reset: false)
    }

    func changeSort(to key: String, tab: V3LibraryTab) async {
        await restoreIfNeeded()
        guard tab.supportsSorting, key != sortBy else { return }
        sortBy = key
        await fetchPage(tab: tab, reset: true, supersede: true)
    }

    func refreshUserData(itemID: String) async {
        await restoreIfNeeded()
        guard !loadedTabs.isEmpty else { return }
        do {
            let refreshed = try await client.libraryItem(itemId: itemID)
            replaceEverywhere(refreshed)
            if let seriesID = refreshed.seriesId, seriesID != refreshed.id, let refreshedSeries = try? await client.libraryItem(itemId: seriesID) { replaceEverywhere(refreshedSeries) }
            await persistSnapshot()
        } catch {
            if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("Library", "userdata refresh failed item=\(itemID): \(error.localizedDescription)") }
        }
    }

    func title(for section: EmbyLibraryRecommendationSection) -> String {
        if let baseline = section.baselineItemName?.trimmingCharacters(in: .whitespacesAndNewlines), !baseline.isEmpty { return "因为您喜欢 \(baseline)" }
        return "推荐"
    }

    private var expectedItemTypes: [String] {
        switch library.collectionType?.lowercased() {
        case "movies": return ["Movie"]
        case "tvshows": return ["Series"]
        case "homevideos": return ["Video"]
        case "mixed": return ["Movie", "Series", "Video"]
        default: return ["Movie", "Series", "Video"]
        }
    }

    private func spec(for tab: V3LibraryTab) -> (types: [String], filters: [String]) {
        switch tab {
        case .items: return (expectedItemTypes, [])
        case .trailers: return (["Trailer"], [])
        case .collections: return (["BoxSet"], [])
        case .favorites: return (expectedItemTypes, ["IsFavorite"])
        default: return ([], [])
        }
    }

    private func fetchPage(tab: V3LibraryTab, reset: Bool, supersede: Bool = false) async {
        guard !loadingTabs.contains(tab) || supersede else { return }
        let generation = (fetchGenerations[tab] ?? 0) + 1
        fetchGenerations[tab] = generation
        var state = pageStates[tab] ?? V3LibraryPageState()
        guard reset || state.hasMore else { return }
        loadingTabs.insert(tab)
        errorMessages[tab] = nil
        let start = reset ? 0 : state.nextStartIndex
        let started = ProcessInfo.processInfo.systemUptime
        let tracePage: (String) -> Void = { [self] stage in
            guard tab == .items, pageTraceEvents < 2048 else { return }
            pageTraceEvents += 1
            let now = ProcessInfo.processInfo.systemUptime
            DiagnosticsLogger.shared.log("PosterWall", "event=page-\(stage) model=\(pageTraceID) generation=\(generation) current=\(fetchGenerations[tab] == generation ? 1 : 0) uptime=\(now) elapsed_ms=\((now - started) * 1000) start=\(start) reset=\(reset ? 1 : 0) count=\(tabItems[tab]?.count ?? 0) revision=\(posterRevision) replacement=\(posterReplacement) loading=\(loadingTabs.contains(tab) ? 1 : 0) frontier=\(pageStates[tab]?.nextStartIndex ?? 0)")
        }
        tracePage("request")
        defer {
            if fetchGenerations[tab] == generation { loadingTabs.remove(tab); loadedTabs.insert(tab) }
            tracePage("finish")
        }
        do {
            let query = spec(for: tab)
            let requestedSortBy = sortBy
            let page = try await client.libraryHubItemsPage(parentId: library.id, limit: pageSize, startIndex: start, recursive: true, sortBy: requestedSortBy, includeItemTypes: query.types, filters: query.filters)
            tracePage("response")
            guard fetchGenerations[tab] == generation else { return }
            let allowed = Set(query.types.map { $0.lowercased() })
            let filtered = page.items.filter { allowed.isEmpty || allowed.contains($0.type?.lowercased() ?? "") }
            if reset {
                var seen = Set<String>()
                let unique = filtered.filter { seen.insert($0.id).inserted }
                if tab == .items { posterReplacement += 1 }
                else { tabReplacements[tab, default: 0] += 1 }
                tabItems[tab] = unique
                state = V3LibraryPageState(nextStartIndex: page.items.count, hasMore: page.totalRecordCount.map { page.items.count < $0 } ?? (page.items.count == pageSize), isFetching: false, hasLoaded: true, seenItemIDs: seen)
            } else {
                let newItems = filtered.filter { state.seenItemIDs.insert($0.id).inserted }
                if !newItems.isEmpty { tabItems[tab, default: []].append(contentsOf: newItems) }
                state.nextStartIndex = start + page.items.count
                state.hasMore = page.totalRecordCount.map { state.nextStartIndex < $0 } ?? (page.items.count == pageSize)
                state.hasLoaded = true
            }
            pageStates[tab] = state
            loadedTabs.insert(tab)
            if tab == .items { liveItemsSortBy = requestedSortBy }
            else { tabRevisions[tab, default: 0] += 1; liveTabSortBy[tab] = requestedSortBy }
            tracePage("published")
            await persistSnapshot()
            tracePage("persisted")
        } catch {
            tracePage("error")
            guard fetchGenerations[tab] == generation else { return }
            if !isEmbyRequestCancellation(error) { errorMessages[tab] = error.localizedDescription }
        }
    }

    private func loadSuggestions(force: Bool = false) async {
        guard force || !loadedTabs.contains(.suggestions), !loadingTabs.contains(.suggestions) else { return }
        loadingTabs.insert(.suggestions)
        errorMessages[.suggestions] = nil
        defer { loadingTabs.remove(.suggestions); loadedTabs.insert(.suggestions) }

        async let resumeTask: [LibraryItem]? = try? client.libraryResumeItems(parentId: library.id, limit: 20, includeItemTypes: suggestionResumeTypes)
        async let latestTask: [LibraryItem]? = try? client.latestItems(parentId: library.id, limit: 20, includeItemTypes: suggestionLatestTypes)
        async let genericTask: [LibraryItem]? = try? client.librarySuggestions(parentId: library.id, limit: 20, includeItemTypes: expectedItemTypes)
        let recommendations: [EmbyLibraryRecommendationSection]?
        if library.collectionType?.caseInsensitiveCompare("movies") == .orderedSame { recommendations = try? await client.movieRecommendations(parentId: library.id, categoryLimit: 4, itemLimit: 16) }
        else { recommendations = [] }
        let (resume, latest, generic) = await (resumeTask, latestTask, genericTask)
        var didUpdate = false
        if let resume { suggestionResumeItems = resume; didUpdate = true }
        if let latest { suggestionLatestItems = latest; didUpdate = true }
        if let generic { genericSuggestionItems = generic; didUpdate = true }
        if let recommendations { recommendationSections = recommendations; didUpdate = true }
        if didUpdate { loadedTabs.insert(.suggestions); await persistSnapshot() }
    }

    private var suggestionResumeTypes: [String] {
        switch library.collectionType?.lowercased() {
        case "tvshows": return ["Episode"]
        case "movies": return ["Movie"]
        default: return ["Movie", "Episode", "Video"]
        }
    }

    private var suggestionLatestTypes: [String] {
        switch library.collectionType?.lowercased() {
        case "tvshows": return ["Series"]
        case "movies": return ["Movie"]
        case "homevideos": return ["Video"]
        default: return expectedItemTypes
        }
    }

    private func loadGenres(force: Bool = false) async {
        guard force || !loadedTabs.contains(.genres), !loadingTabs.contains(.genres) else { return }
        loadingTabs.insert(.genres)
        errorMessages[.genres] = nil
        defer { loadingTabs.remove(.genres); loadedTabs.insert(.genres) }
        do {
            genres = try await client.libraryGenres(parentId: library.id, includeItemTypes: expectedItemTypes)
            liveCoverTabs.insert(.genres)
            loadedTabs.insert(.genres)
            await persistSnapshot()
        } catch { if !isEmbyRequestCancellation(error) { errorMessages[.genres] = error.localizedDescription } }
    }

    private func loadFolders(force: Bool = false) async {
        guard force || !loadedTabs.contains(.folders), !loadingTabs.contains(.folders) else { return }
        loadingTabs.insert(.folders)
        errorMessages[.folders] = nil
        defer { loadingTabs.remove(.folders); loadedTabs.insert(.folders) }
        do {
            folderItems = try await client.libraryFolderChildren(parentId: library.id)
            liveCoverTabs.insert(.folders)
            loadedTabs.insert(.folders)
            await persistSnapshot()
        } catch { if !isEmbyRequestCancellation(error) { errorMessages[.folders] = error.localizedDescription } }
    }

    private func persistSnapshot() async {
        let persistedItems = Dictionary(uniqueKeysWithValues: tabItems.map { ($0.key.rawValue, $0.value) })
        let persistedStates = Dictionary(uniqueKeysWithValues: pageStates.map { ($0.key.rawValue, V3PersistedPageState(nextStartIndex: $0.value.nextStartIndex, hasMore: $0.value.hasMore)) })
        let snapshot = V3LibraryPersistentSnapshot(
            tabItems: persistedItems,
            suggestionResumeItems: suggestionResumeItems,
            suggestionLatestItems: suggestionLatestItems,
            genericSuggestionItems: genericSuggestionItems,
            recommendationSections: recommendationSections,
            genres: genres,
            folderItems: folderItems,
            sortBy: sortBy,
            loadedTabs: Set(loadedTabs.map(\.rawValue)),
            pageStates: persistedStates
        )
        await V3PagePersistentCache.shared.storeLibrarySnapshot(snapshot, client: client, libraryID: library.id)
    }

    private func replaceEverywhere(_ refreshed: LibraryItem) {
        for tab in [V3LibraryTab.items, .trailers, .collections, .favorites] {
            guard var values = tabItems[tab], let index = values.firstIndex(where: { $0.id == refreshed.id }) else { continue }
            values[index] = refreshed
            if tab == .items { posterReplacement += 1 }
            else { tabReplacements[tab, default: 0] += 1; tabRevisions[tab, default: 0] += 1 }
            tabItems[tab] = values
        }
        if let index = suggestionResumeItems.firstIndex(where: { $0.id == refreshed.id }) { suggestionResumeItems[index] = refreshed }
        if let index = suggestionLatestItems.firstIndex(where: { $0.id == refreshed.id }) { suggestionLatestItems[index] = refreshed }
        if let index = genericSuggestionItems.firstIndex(where: { $0.id == refreshed.id }) { genericSuggestionItems[index] = refreshed }
        for sectionIndex in recommendationSections.indices {
            if let index = recommendationSections[sectionIndex].items.firstIndex(where: { $0.id == refreshed.id }) {
                var items = recommendationSections[sectionIndex].items
                items[index] = refreshed
                let section = recommendationSections[sectionIndex]
                recommendationSections[sectionIndex] = EmbyLibraryRecommendationSection(items: items, recommendationType: section.recommendationType, baselineItemName: section.baselineItemName, categoryId: section.categoryId)
            }
        }
    }
}

private enum V3LibraryPosterDestination {
    case media
    case genre(library: LibraryItem)
    case folders

    var content: EmbyPosterWallContent {
        switch self { case .media: return .media; case .genre: return .genres; case .folders: return .folders }
    }
}

private struct V3LibraryPosterPage: View {
    let items: [LibraryItem]
    let revision: Int
    let replacement: Int
    let client: EmbyAPIClient
    var destination: V3LibraryPosterDestination = .media
    let queryIdentity: String
    let isLoading: Bool
    let hasLoaded: Bool
    let error: String?
    let emptyText: String
    var onApproachingEnd: () -> Void = {}
    let onRefresh: () -> Void
    @State private var selection: LibraryItem?
    @Environment(\.serverDockBottomInset) private var dockBottomInset

    var body: some View {
        EmbyPosterWall(items: items, revision: revision, replacement: replacement, client: client, content: destination.content, queryIdentity: queryIdentity,
            isLoading: isLoading, hasLoaded: hasLoaded, error: error, emptyText: emptyText,
            bottomPadding: ServerDockMetrics.contentBottomPadding(bottomInset: dockBottomInset), isActive: selection == nil,
            onApproachingEnd: onApproachingEnd, onRefresh: onRefresh, onSelect: { if selection == nil { selection = $0 } })
            .background(NavigationLink(destination: Group {
                if let item = selection {
                    switch destination {
                    case .genre(let library): V3LibraryGenreGridView(library: library, genre: item, client: client)
                    case .folders:
                        if v3LibraryIsBrowsableFolder(item) { V3LibraryFolderBrowserView(folder: item, client: client) }
                        else { EmbyPosterDetailDestination(item: item, client: client) }
                    case .media: EmbyPosterDetailDestination(item: item, client: client)
                    }
                } else { EmptyView() }
            }, isActive: Binding(get: { selection != nil }, set: { if !$0 { selection = nil } })) { EmptyView() }.frame(width: 0, height: 0).hidden())
    }
}

private struct V3LibraryGenreGridView: View {
    let library: LibraryItem
    let genre: LibraryItem
    let client: EmbyAPIClient
    @StateObject private var model: V3LibraryGenreGridViewModel

    init(library: LibraryItem, genre: LibraryItem, client: EmbyAPIClient) {
        self.library = library
        self.genre = genre
        self.client = client
        _model = StateObject(wrappedValue: V3LibraryGenreGridViewModel(library: library, genre: genre, client: client))
    }

    var body: some View {
        V3LibraryPosterPage(items: model.items, revision: model.posterRevision, replacement: model.posterReplacement, client: client,
            queryIdentity: "\(library.id)|genre|\(genre.name)", isLoading: model.isLoading, hasLoaded: model.hasLoaded, error: model.errorMessage, emptyText: "这个类别暂无内容",
            onApproachingEnd: { if model.hasMore { Task { await model.loadNextPage() } } }, onRefresh: { Task { await model.refresh() } })
        .navigationTitle(genre.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .serverDockPage()
        .nativeInteractivePop()
        .onAppear { if !model.hasLoaded { Task { await model.refresh() } } }
    }
}

@MainActor
private final class V3LibraryGenreGridViewModel: ObservableObject {
    @Published var items: [LibraryItem] = [] { didSet { posterRevision += 1 } }
    private(set) var posterRevision = 0
    private(set) var posterReplacement = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    private(set) var hasMore = true
    private(set) var hasLoaded = false
    private let library: LibraryItem
    private let genre: LibraryItem
    private let client: EmbyAPIClient
    private let pageSize = 60
    private var nextStartIndex = 0
    private var seen = Set<String>()

    init(library: LibraryItem, genre: LibraryItem, client: EmbyAPIClient) { self.library = library; self.genre = genre; self.client = client }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasLoaded = true }
        do {
            let page = try await client.libraryHubItemsPage(parentId: library.id, limit: pageSize, startIndex: 0, recursive: true, sortBy: "SortName", sortOrder: "Ascending", includeItemTypes: expectedTypes, genres: [genre.name])
            var refreshedSeen = Set<String>()
            posterReplacement += 1
            items = page.items.filter { refreshedSeen.insert($0.id).inserted }
            seen = refreshedSeen
            nextStartIndex = page.items.count
            hasMore = page.totalRecordCount.map { nextStartIndex < $0 } ?? (page.items.count == pageSize)
        } catch { if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription } }
    }

    func loadNextPage() async {
        guard hasLoaded, hasMore, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        let start = nextStartIndex
        defer { isLoading = false }
        do {
            let page = try await client.libraryHubItemsPage(parentId: library.id, limit: pageSize, startIndex: start, recursive: true, sortBy: "SortName", sortOrder: "Ascending", includeItemTypes: expectedTypes, genres: [genre.name])
            items.append(contentsOf: page.items.filter { seen.insert($0.id).inserted })
            nextStartIndex = start + page.items.count
            hasMore = page.totalRecordCount.map { nextStartIndex < $0 } ?? (page.items.count == pageSize)
        } catch { if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription } }
    }

    private var expectedTypes: [String] {
        switch library.collectionType?.lowercased() {
        case "movies": return ["Movie"]
        case "tvshows": return ["Series"]
        case "homevideos": return ["Video"]
        default: return ["Movie", "Series", "Video"]
        }
    }
}

private func v3LibraryIsBrowsableFolder(_ item: LibraryItem) -> Bool { ["folder", "collectionfolder"].contains(item.type?.lowercased() ?? "") }

private struct V3LibraryFolderBrowserView: View {
    let folder: LibraryItem
    let client: EmbyAPIClient
    @StateObject private var model: V3LibraryFolderBrowserViewModel

    init(folder: LibraryItem, client: EmbyAPIClient) {
        self.folder = folder
        self.client = client
        _model = StateObject(wrappedValue: V3LibraryFolderBrowserViewModel(folder: folder, client: client))
    }

    var body: some View {
        V3LibraryPosterPage(items: model.items, revision: model.posterRevision, replacement: model.posterRevision, client: client,
            destination: .folders, queryIdentity: "folder|\(folder.id)", isLoading: model.isLoading, hasLoaded: model.hasLoaded, error: model.errorMessage,
            emptyText: "这个文件夹暂无内容", onRefresh: { Task { await model.load(force: true) } })
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .serverDockPage()
        .nativeInteractivePop()
        .onAppear { if !model.hasLoaded { Task { await model.load() } } }
    }
}

@MainActor
private final class V3LibraryFolderBrowserViewModel: ObservableObject {
    @Published var items: [LibraryItem] = [] { didSet { posterRevision += 1 } }
    private(set) var posterRevision = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    private(set) var hasLoaded = false
    private let folder: LibraryItem
    private let client: EmbyAPIClient

    init(folder: LibraryItem, client: EmbyAPIClient) { self.folder = folder; self.client = client }

    func load(force: Bool = false) async {
        guard (force || !hasLoaded), !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasLoaded = true }
        do { items = try await client.libraryFolderChildren(parentId: folder.id) }
        catch { if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription } }
    }
}

struct V3EmbyFavoritesView: View {
    @Environment(\.serverDockBottomInset) private var dockBottomInset
    let client: EmbyAPIClient
    let onClose: () -> Void
    @StateObject private var model: V3FavoritesViewModel
    @State private var selectedItem: LibraryItem?
    @State private var selectedPerson: LibraryItem?
    @State private var selectedCategory: String?

    init(client: EmbyAPIClient, onClose: @escaping () -> Void) {
        self.client = client
        self.onClose = onClose
        _model = StateObject(wrappedValue: V3FavoritesViewModel(client: client))
    }

    var body: some View {
        NavigationView {
            EmbyPosterSections(sections: favoritePosterSections, queryIdentity: "favorites", topHeight: V3ServerHeaderMetrics.controlHeight + V3ServerHeaderMetrics.bottomPadding, topPadding: 28, sectionGap: 28, bottomPadding: ServerDockMetrics.contentBottomPadding(bottomInset: dockBottomInset), isLoading: model.isLoading, error: model.errorMessage, isActive: selectedItem == nil && selectedPerson == nil && selectedCategory == nil, onRefresh: { completion in Task { await model.load(); completion() } }, top: V3PageHeader(title: "收藏", onClose: onClose))
                .background(favoritePosterNavigation)
                .background(Color(uiColor: .systemBackground).ignoresSafeArea())
                .serverDockPage()
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .toolbar(.hidden, for: .navigationBar)
                .onAppear { Task { await model.load() } }
        }
        .navigationViewStyle(.stack)
    }

    private var favoritePosterNavigation: some View {
        Group {
            NavigationLink(isActive: Binding(get: { selectedItem != nil }, set: { if !$0 { selectedItem = nil } })) {
                if let item = selectedItem { EmbyPosterDetailDestination(item: item, client: client) }
                else { EmptyView() }
            } label: { EmptyView() }
            .hidden()
            NavigationLink(isActive: Binding(get: { selectedPerson != nil }, set: { if !$0 { selectedPerson = nil } })) {
                if let person = selectedPerson { EmbyPersonMediaView(person: person, client: client) }
                else { EmptyView() }
            } label: { EmptyView() }
            .hidden()
            NavigationLink(isActive: Binding(get: { selectedCategory != nil }, set: { if !$0 { selectedCategory = nil } })) {
                if let category = selectedCategory { V3FavoriteCategoryGridView(title: category, category: category, client: client) }
                else { EmptyView() }
            } label: { EmptyView() }
            .hidden()
        }
    }

    private var favoritePosterSections: [EmbyPosterSection] {
        var sections: [EmbyPosterSection] = []
        if !model.favoriteMovies.isEmpty { sections.append(EmbyPosterSection(id: "movies", title: "电影", items: Array(model.favoriteMovies.prefix(12)), client: client, onSelect: { selectedItem = $0 }, trailingActionTitle: model.favoriteMovies.count > 12 ? "更多" : nil, trailingAction: model.favoriteMovies.count > 12 ? { selectedCategory = "Movie" } : nil)) }
        if !model.favoriteSeries.isEmpty { sections.append(EmbyPosterSection(id: "series", title: "节目", items: Array(model.favoriteSeries.prefix(12)), client: client, onSelect: { selectedItem = $0 }, trailingActionTitle: model.favoriteSeries.count > 12 ? "更多" : nil, trailingAction: model.favoriteSeries.count > 12 ? { selectedCategory = "Series" } : nil)) }
        if !model.favoriteCollections.isEmpty { sections.append(EmbyPosterSection(id: "collections", title: "合集", items: Array(model.favoriteCollections.prefix(12)), client: client, onSelect: { selectedItem = $0 }, trailingActionTitle: model.favoriteCollections.count > 12 ? "更多" : nil, trailingAction: model.favoriteCollections.count > 12 ? { selectedCategory = "BoxSet" } : nil)) }
        if !model.favoritePeople.isEmpty { sections.append(EmbyPosterSection(id: "people", title: "演员和工作人员", items: Array(model.favoritePeople.prefix(12)), client: client, onSelect: { selectedPerson = $0 }, trailingActionTitle: model.favoritePeople.count > 12 ? "更多" : nil, trailingAction: model.favoritePeople.count > 12 ? { selectedCategory = "Person" } : nil)) }
        return sections
    }
}

@MainActor
private final class V3FavoritesViewModel: ObservableObject {
    @Published var favoriteMovies: [LibraryItem] = []
    @Published var favoriteSeries: [LibraryItem] = []
    @Published var favoriteCollections: [LibraryItem] = []
    @Published var favoritePeople: [LibraryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let client: EmbyAPIClient

    init(client: EmbyAPIClient) { self.client = client }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let items = try await client.favoriteItems(limit: 120)
            favoriteMovies = items.filter { $0.type?.caseInsensitiveCompare("Movie") == .orderedSame }
            favoriteSeries = items.filter { $0.type?.caseInsensitiveCompare("Series") == .orderedSame }
            favoriteCollections = items.filter { $0.type?.caseInsensitiveCompare("BoxSet") == .orderedSame }
            favoritePeople = items.filter { $0.type?.caseInsensitiveCompare("Person") == .orderedSame }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct V3FavoriteCategoryGridView: View {
    let title: String
    let category: String
    let client: EmbyAPIClient
    @StateObject private var model: V3FavoriteCategoryGridViewModel

    init(title: String, category: String, client: EmbyAPIClient) {
        self.title = title
        self.category = category
        self.client = client
        _model = StateObject(wrappedValue: V3FavoriteCategoryGridViewModel(category: category, client: client))
    }

    var body: some View {
        EmbyPosterResultsPage(items: model.items, revision: model.posterRevision, replacement: model.posterReplacement, client: client,
            queryIdentity: "favorites|\(category)", isLoading: model.isLoading, hasLoaded: model.hasLoaded, error: model.errorMessage, emptyText: "暂无内容",
            onApproachingEnd: { if model.hasMore { Task { await model.loadNextPage() } } }, onRefresh: { Task { await model.refresh() } })
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .serverDockPage()
            .nativeInteractivePop()
            .onAppear { if !model.hasLoaded { Task { await model.refresh() } } }
    }
}

@MainActor
private final class V3FavoriteCategoryGridViewModel: ObservableObject {
    @Published private(set) var items: [LibraryItem] = [] { didSet { posterRevision += 1 } }
    private(set) var posterRevision = 0
    private(set) var posterReplacement = 0
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?
    private(set) var hasMore = true
    private let category: String
    private let client: EmbyAPIClient
    private let pageSize = 60
    private var nextStartIndex = 0
    private var seen = Set<String>()

    init(category: String, client: EmbyAPIClient) { self.category = category; self.client = client }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasLoaded = true }
        do {
            let page = try await client.libraryHubItemsPage(parentId: "", limit: pageSize, startIndex: 0, recursive: true, sortBy: "SortName", sortOrder: "Ascending", includeItemTypes: [category], filters: ["IsFavorite"])
            var refreshedSeen = Set<String>()
            posterReplacement += 1
            items = page.items.filter { refreshedSeen.insert($0.id).inserted }
            seen = refreshedSeen
            nextStartIndex = page.items.count
            hasMore = page.totalRecordCount.map { nextStartIndex < $0 } ?? (page.items.count == pageSize)
        } catch { if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription } }
    }

    func loadNextPage() async {
        guard hasLoaded, hasMore, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        let start = nextStartIndex
        defer { isLoading = false }
        do {
            let page = try await client.libraryHubItemsPage(parentId: "", limit: pageSize, startIndex: start, recursive: true, sortBy: "SortName", sortOrder: "Ascending", includeItemTypes: [category], filters: ["IsFavorite"])
            items.append(contentsOf: page.items.filter { seen.insert($0.id).inserted })
            nextStartIndex = start + page.items.count
            hasMore = page.totalRecordCount.map { nextStartIndex < $0 } ?? (page.items.count == pageSize)
        } catch { if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription } }
    }
}

private struct V3FavoritePersonLink: View {
    let item: LibraryItem
    let client: EmbyAPIClient

    var body: some View { EmbyPersonMediaView(person: item, client: client) }
}

private enum V3SearchDefaults {
    static let pageSize = 60
    static let includeItemTypes = ["Movie", "Series", "Episode", "BoxSet"]
}

struct V3GlobalSearchServerGridView: View {
    let term: String
    let client: EmbyAPIClient
    @StateObject private var model: V3GlobalSearchServerGridViewModel

    init(term: String, client: EmbyAPIClient) {
        self.term = term
        self.client = client
        _model = StateObject(wrappedValue: V3GlobalSearchServerGridViewModel(term: term, client: client))
    }

    var body: some View {
        EmbyPosterResultsPage(items: model.items, revision: model.posterRevision, replacement: model.posterReplacement, client: client,
            queryIdentity: "search|\(term)", isLoading: model.isLoading, hasLoaded: model.hasLoaded, error: model.errorMessage, emptyText: "没有找到相关内容",
            onApproachingEnd: { if model.hasMore { Task { await model.loadNextPage() } } }, onRefresh: { Task { await model.refresh() } })
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .serverDockPage()
            .nativeInteractivePop()
            .onAppear { if !model.hasLoaded { Task { await model.refresh() } } }
    }
}

@MainActor
private final class V3GlobalSearchServerGridViewModel: ObservableObject {
    @Published private(set) var items: [LibraryItem] = [] { didSet { posterRevision += 1 } }
    private(set) var posterRevision = 0
    private(set) var posterReplacement = 0
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?
    private(set) var hasMore = true
    private let term: String
    private let client: EmbyAPIClient
    private let pageSize = V3SearchDefaults.pageSize
    private var nextStartIndex = 0
    private var seen = Set<String>()

    init(term: String, client: EmbyAPIClient) { self.term = term; self.client = client }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasLoaded = true }
        do {
            let page = try await client.searchPosterItemsPage(term: term, limit: pageSize, startIndex: 0, includeItemTypes: V3SearchDefaults.includeItemTypes)
            var refreshedSeen = Set<String>()
            posterReplacement += 1
            items = page.items.filter { refreshedSeen.insert($0.id).inserted }
            seen = refreshedSeen
            nextStartIndex = page.items.count
            hasMore = page.totalRecordCount.map { nextStartIndex < $0 } ?? (page.items.count == pageSize)
        } catch { if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription } }
    }

    func loadNextPage() async {
        guard hasLoaded, hasMore, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        let start = nextStartIndex
        defer { isLoading = false }
        do {
            let page = try await client.searchPosterItemsPage(term: term, limit: pageSize, startIndex: start, includeItemTypes: V3SearchDefaults.includeItemTypes)
            items.append(contentsOf: page.items.filter { seen.insert($0.id).inserted })
            nextStartIndex = start + page.items.count
            hasMore = page.totalRecordCount.map { nextStartIndex < $0 } ?? (page.items.count == pageSize)
        } catch { if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription } }
    }
}

private struct V3EmbySettingsView: View {
    let client: EmbyAPIClient
    @EnvironmentObject private var store: ServerStore
    @State private var settings = PlayerSettingsStore.load()

    var body: some View {
        Form {
            Section("播放") {
                Picker("播放内核", selection: $settings.enginePreference) {
                    ForEach(PlayerEnginePreference.allCases) { preference in Text(preference.displayName).tag(preference) }
                }
                .pickerStyle(.menu)
                Stepper("快退 \(settings.rewindSeconds) 秒", value: $settings.rewindSeconds, in: 5...60, step: 5)
                Stepper("快进 \(settings.forwardSeconds) 秒", value: $settings.forwardSeconds, in: 5...60, step: 5)
            }
        }
    }
}
