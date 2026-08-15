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
    let dock: AnyView
    @StateObject private var model: V3LibraryBrowserViewModel
    @State private var selectedTab = V3LibraryTab.items

    init(library: LibraryItem, client: EmbyAPIClient, dock: AnyView) {
        self.library = library
        self.client = client
        self.dock = dock
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
        .overlay(alignment: .bottom) { dock }
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
            HStack(spacing: 26) {
                ForEach(V3LibraryTab.allCases) { tab in
                    Button {
                        guard selectedTab != tab else { return }
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 6) {
                            Text(tab.title(contentTitle: contentTitle))
                                .font(.system(size: 17, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .blue : .secondary)
                                .fixedSize(horizontal: true, vertical: false)
                            Capsule()
                                .fill(selectedTab == tab ? Color.blue : Color.clear)
                                .frame(height: 2.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 48)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .items, .trailers, .collections, .favorites:
            pagedPosterTab(selectedTab)
        case .suggestions:
            suggestionsTab
        case .genres:
            genresTab
        case .folders:
            foldersTab
        }
    }

    private func pagedPosterTab(_ tab: V3LibraryTab) -> some View {
        let items = model.items(for: tab)
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if model.isLoading(tab: tab) && items.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 44)
                } else if model.hasLoaded(tab: tab) && items.isEmpty {
                    emptyState(text: tab == .favorites ? "这个媒体库还没有收藏内容" : "暂无\(tab.title(contentTitle: contentTitle))内容")
                } else {
                    EmbyPosterGrid(items: items, onApproachingEnd: {
                        guard model.hasMore(tab: tab) else { return }
                        Task { await model.loadNextPage(tab: tab) }
                    }) { item in
                        EmbyPosterDetailLink(item: item, client: client) { V3PosterCard(item: item, client: client, width: nil) }
                    }
                }
                if let error = model.errorMessage(for: tab) { errorText(error) }
            }
            .padding(.top, 8)
            .padding(.bottom, 86)
        }
        .refreshable { await model.refresh(tab: tab) }
    }

    private var suggestionsTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 28) {
                if model.isLoading(tab: .suggestions) && !model.hasSuggestionContent {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 44)
                } else if model.hasLoaded(tab: .suggestions) && !model.hasSuggestionContent {
                    emptyState(text: "暂无建议内容")
                } else {
                    if !model.suggestionResumeItems.isEmpty { suggestionSectionTitle("继续观看"); landscapeRow(model.suggestionResumeItems) }
                    if !model.suggestionLatestItems.isEmpty { suggestionSectionTitle(model.latestSuggestionTitle); posterRow(model.suggestionLatestItems) }
                    ForEach(model.recommendationSections) { section in
                        suggestionSectionTitle(model.title(for: section))
                        posterRow(section.items)
                    }
                    if model.recommendationSections.isEmpty && !model.genericSuggestionItems.isEmpty { suggestionSectionTitle("推荐"); posterRow(model.genericSuggestionItems) }
                }
                if let error = model.errorMessage(for: .suggestions) { errorText(error) }
            }
            .padding(.top, 8)
            .padding(.bottom, 86)
        }
        .refreshable { await model.refresh(tab: .suggestions) }
    }

    private var genresTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if model.isLoading(tab: .genres) && model.genres.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 44)
                } else if model.hasLoaded(tab: .genres) && model.genres.isEmpty {
                    emptyState(text: "这个媒体库暂无类别")
                } else {
                    EmbyPosterGrid(items: model.genres) { genre in
                        NavigationLink(destination: V3LibraryGenreGridView(library: library, genre: genre, client: client, dock: dock)) {
                            V3LibraryGenreCard(item: genre, client: client)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let error = model.errorMessage(for: .genres) { errorText(error) }
            }
            .padding(.top, 8)
            .padding(.bottom, 86)
        }
        .refreshable { await model.refresh(tab: .genres) }
    }

    private var foldersTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if model.isLoading(tab: .folders) && model.folderItems.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 44)
                } else if model.hasLoaded(tab: .folders) && model.folderItems.isEmpty {
                    emptyState(text: "这个媒体库暂无文件夹内容")
                } else {
                    V3LibraryFolderGrid(items: model.folderItems, client: client, dock: dock)
                }
                if let error = model.errorMessage(for: .folders) { errorText(error) }
            }
            .padding(.top, 8)
            .padding(.bottom, 86)
        }
        .refreshable { await model.refresh(tab: .folders) }
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

    private func suggestionSectionTitle(_ title: String) -> some View { Text(title).font(.system(size: 20, weight: .bold)).padding(.horizontal, 16) }

    private func landscapeRow(_ items: [LibraryItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(items) { item in EmbyPosterDetailLink(item: item, client: client) { V3LandscapeCard(item: item, client: client) }.frame(width: 212, alignment: .leading) }
            }
            .padding(.horizontal, 16)
        }
    }

    private func posterRow(_ items: [LibraryItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(items) { item in EmbyPosterDetailLink(item: item, client: client) { V3PosterCard(item: item, client: client, width: 118) }.frame(width: 118, alignment: .leading) }
            }
            .padding(.horizontal, 16)
        }
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
    @Published private var tabItems: [V3LibraryTab: [LibraryItem]] = [:]
    @Published var suggestionResumeItems: [LibraryItem] = []
    @Published var suggestionLatestItems: [LibraryItem] = []
    @Published var genericSuggestionItems: [LibraryItem] = []
    @Published var recommendationSections: [EmbyLibraryRecommendationSection] = []
    @Published var genres: [LibraryItem] = []
    @Published var folderItems: [LibraryItem] = []
    @Published var sortBy = "DateCreated"
    @Published private var loadingTabs = Set<V3LibraryTab>()
    @Published private var loadedTabs = Set<V3LibraryTab>()
    @Published private var errorMessages: [V3LibraryTab: String] = [:]

    private let library: LibraryItem
    private let client: EmbyAPIClient
    private let pageSize = 60
    private var pageStates: [V3LibraryTab: V3LibraryPageState] = [:]

    init(library: LibraryItem, client: EmbyAPIClient) { self.library = library; self.client = client }

    var hasSuggestionContent: Bool { !suggestionResumeItems.isEmpty || !suggestionLatestItems.isEmpty || !genericSuggestionItems.isEmpty || !recommendationSections.isEmpty }
    var latestSuggestionTitle: String { library.collectionType?.caseInsensitiveCompare("tvshows") == .orderedSame ? "最新剧集" : "最新电影" }

    func items(for tab: V3LibraryTab) -> [LibraryItem] { tabItems[tab] ?? [] }
    func isLoading(tab: V3LibraryTab) -> Bool { loadingTabs.contains(tab) }
    func hasLoaded(tab: V3LibraryTab) -> Bool { loadedTabs.contains(tab) }
    func errorMessage(for tab: V3LibraryTab) -> String? { errorMessages[tab] }
    func hasMore(tab: V3LibraryTab) -> Bool { pageStates[tab]?.hasMore ?? false }

    func load(tab: V3LibraryTab) async {
        guard !hasLoaded(tab: tab), !isLoading(tab: tab) else { return }
        switch tab {
        case .items, .trailers, .collections, .favorites: await fetchPage(tab: tab, reset: true)
        case .suggestions: await loadSuggestions()
        case .genres: await loadGenres()
        case .folders: await loadFolders()
        }
    }

    func refresh(tab: V3LibraryTab) async {
        guard !isLoading(tab: tab) else { return }
        switch tab {
        case .items, .trailers, .collections, .favorites: await fetchPage(tab: tab, reset: true)
        case .suggestions: await loadSuggestions(force: true)
        case .genres: await loadGenres(force: true)
        case .folders: await loadFolders(force: true)
        }
    }

    func loadNextPage(tab: V3LibraryTab) async {
        guard [.items, .trailers, .collections, .favorites].contains(tab), hasLoaded(tab: tab), hasMore(tab: tab), !isLoading(tab: tab) else { return }
        await fetchPage(tab: tab, reset: false)
    }

    func changeSort(to key: String, tab: V3LibraryTab) async {
        guard tab.supportsSorting, key != sortBy else { return }
        sortBy = key
        await fetchPage(tab: tab, reset: true)
    }

    func refreshUserData(itemID: String) async {
        guard !loadedTabs.isEmpty else { return }
        do {
            let refreshed = try await client.libraryItem(itemId: itemID)
            replaceEverywhere(refreshed)
            if let seriesID = refreshed.seriesId, seriesID != refreshed.id, let refreshedSeries = try? await client.libraryItem(itemId: seriesID) { replaceEverywhere(refreshedSeries) }
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
        default: return []
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

    private func fetchPage(tab: V3LibraryTab, reset: Bool) async {
        guard !loadingTabs.contains(tab) else { return }
        var state = pageStates[tab] ?? V3LibraryPageState()
        guard reset || state.hasMore else { return }
        loadingTabs.insert(tab)
        errorMessages[tab] = nil
        let start = reset ? 0 : state.nextStartIndex
        defer { loadingTabs.remove(tab); loadedTabs.insert(tab) }
        do {
            let query = spec(for: tab)
            let page = try await client.libraryHubItemsPage(parentId: library.id, limit: pageSize, startIndex: start, recursive: true, sortBy: sortBy, includeItemTypes: query.types, filters: query.filters)
            let allowed = Set(query.types.map { $0.lowercased() })
            let filtered = page.items.filter { allowed.isEmpty || allowed.contains($0.type?.lowercased() ?? "") }
            if reset {
                var seen = Set<String>()
                let unique = filtered.filter { seen.insert($0.id).inserted }
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
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessages[tab] = error.localizedDescription }
        }
    }

    private func loadSuggestions(force: Bool = false) async {
        guard force || !loadedTabs.contains(.suggestions) else { return }
        loadingTabs.insert(.suggestions)
        errorMessages[.suggestions] = nil
        defer { loadingTabs.remove(.suggestions); loadedTabs.insert(.suggestions) }

        async let resumeTask: [LibraryItem]? = try? client.libraryResumeItems(parentId: library.id, limit: 20, includeItemTypes: suggestionResumeTypes)
        async let latestTask: [LibraryItem]? = try? client.latestItems(parentId: library.id, limit: 20, includeItemTypes: suggestionLatestTypes)
        async let genericTask: [LibraryItem]? = try? client.librarySuggestions(parentId: library.id, limit: 20, includeItemTypes: expectedItemTypes)
        var recommendations: [EmbyLibraryRecommendationSection] = []
        if library.collectionType?.caseInsensitiveCompare("movies") == .orderedSame { recommendations = (try? await client.movieRecommendations(parentId: library.id, categoryLimit: 4, itemLimit: 16)) ?? [] }
        let (resume, latest, generic) = await (resumeTask, latestTask, genericTask)
        suggestionResumeItems = resume ?? []
        suggestionLatestItems = latest ?? []
        genericSuggestionItems = generic ?? []
        recommendationSections = recommendations
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
        do { genres = try await client.libraryGenres(parentId: library.id, includeItemTypes: expectedItemTypes) }
        catch { if !isEmbyRequestCancellation(error) { errorMessages[.genres] = error.localizedDescription } }
    }

    private func loadFolders(force: Bool = false) async {
        guard force || !loadedTabs.contains(.folders), !loadingTabs.contains(.folders) else { return }
        loadingTabs.insert(.folders)
        errorMessages[.folders] = nil
        defer { loadingTabs.remove(.folders); loadedTabs.insert(.folders) }
        do { folderItems = try await client.libraryFolderChildren(parentId: library.id) }
        catch { if !isEmbyRequestCancellation(error) { errorMessages[.folders] = error.localizedDescription } }
    }

    private func replaceEverywhere(_ refreshed: LibraryItem) {
        for tab in [V3LibraryTab.items, .trailers, .collections, .favorites] {
            guard var values = tabItems[tab], let index = values.firstIndex(where: { $0.id == refreshed.id }) else { continue }
            values[index] = refreshed
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

private struct V3LibraryGenreCard: View {
    @Environment(\.embyPosterGridCellWidth) private var gridCellWidth
    let item: LibraryItem
    let client: EmbyAPIClient
    private var width: CGFloat { gridCellWidth ?? 118 }
    private var height: CGFloat { floor(width / EmbyPosterGridMetrics.posterAspectRatio) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            EmbyCachedRemoteImage(url: client.imageURL(itemId: item.id, maxWidth: max(1, Int(ceil(width * UIScreen.main.scale))), tag: item.primaryImageTag), contentMode: .fill, placeholderSystemImage: "rectangle.stack.fill", showsLoadingIndicator: false)
                .frame(width: width, height: height)
                .clipped()
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(item.name).font(.subheadline).foregroundColor(.primary).lineLimit(1).frame(width: width, height: 20, alignment: .leading)
        }
        .frame(width: width, alignment: .leading)
    }
}

private struct V3LibraryGenreGridView: View {
    let library: LibraryItem
    let genre: LibraryItem
    let client: EmbyAPIClient
    let dock: AnyView
    @StateObject private var model: V3LibraryGenreGridViewModel

    init(library: LibraryItem, genre: LibraryItem, client: EmbyAPIClient, dock: AnyView) {
        self.library = library
        self.genre = genre
        self.client = client
        self.dock = dock
        _model = StateObject(wrappedValue: V3LibraryGenreGridViewModel(library: library, genre: genre, client: client))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if model.isLoading && model.items.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(.top, 44) }
                else {
                    EmbyPosterGrid(items: model.items, onApproachingEnd: { guard model.hasMore else { return }; Task { await model.loadNextPage() } }) { item in
                        EmbyPosterDetailLink(item: item, client: client) { V3PosterCard(item: item, client: client, width: nil) }
                    }
                }
                if let error = model.errorMessage { Text(error).foregroundColor(.red).font(.footnote).padding(.horizontal, EmbyPosterGridMetrics.horizontalPadding) }
            }
            .padding(.top, 8)
            .padding(.bottom, 86)
        }
        .navigationTitle(genre.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .overlay(alignment: .bottom) { dock }
        .nativeInteractivePop()
        .refreshable { await model.refresh() }
        .onAppear { if !model.hasLoaded { Task { await model.refresh() } } }
    }
}

@MainActor
private final class V3LibraryGenreGridViewModel: ObservableObject {
    @Published var items: [LibraryItem] = []
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

private struct V3LibraryFolderGrid: View {
    let items: [LibraryItem]
    let client: EmbyAPIClient
    let dock: AnyView

    var body: some View {
        EmbyPosterGrid(items: items) { item in
            if v3LibraryIsBrowsableFolder(item) {
                NavigationLink(destination: V3LibraryFolderBrowserView(folder: item, client: client, dock: dock)) { V3LibraryFolderCard(item: item, client: client) }.buttonStyle(.plain)
            } else {
                EmbyPosterDetailLink(item: item, client: client) { V3PosterCard(item: item, client: client, width: nil) }
            }
        }
    }
}

private struct V3LibraryFolderCard: View {
    @Environment(\.embyPosterGridCellWidth) private var gridCellWidth
    let item: LibraryItem
    let client: EmbyAPIClient
    private var width: CGFloat { gridCellWidth ?? 118 }
    private var height: CGFloat { floor(width / EmbyPosterGridMetrics.posterAspectRatio) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                EmbyCachedRemoteImage(url: client.imageURL(itemId: item.id, maxWidth: max(1, Int(ceil(width * UIScreen.main.scale))), tag: item.primaryImageTag), contentMode: .fill, placeholderSystemImage: "folder.fill", showsLoadingIndicator: false)
                    .frame(width: width, height: height)
                    .clipped()
                Image(systemName: "folder.fill").font(.caption.weight(.semibold)).foregroundColor(.white).padding(6).background(Color.black.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous)).padding(6)
            }
            .frame(width: width, height: height)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(item.name).font(.subheadline).foregroundColor(.primary).lineLimit(1).frame(width: width, height: 20, alignment: .leading)
        }
        .frame(width: width, alignment: .leading)
    }
}

private struct V3LibraryFolderBrowserView: View {
    let folder: LibraryItem
    let client: EmbyAPIClient
    let dock: AnyView
    @StateObject private var model: V3LibraryFolderBrowserViewModel

    init(folder: LibraryItem, client: EmbyAPIClient, dock: AnyView) {
        self.folder = folder
        self.client = client
        self.dock = dock
        _model = StateObject(wrappedValue: V3LibraryFolderBrowserViewModel(folder: folder, client: client))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if model.isLoading && model.items.isEmpty { ProgressView().frame(maxWidth: .infinity).padding(.top, 44) }
                else { V3LibraryFolderGrid(items: model.items, client: client, dock: dock) }
                if let error = model.errorMessage { Text(error).foregroundColor(.red).font(.footnote).padding(.horizontal, EmbyPosterGridMetrics.horizontalPadding) }
            }
            .padding(.top, 8)
            .padding(.bottom, 86)
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .overlay(alignment: .bottom) { dock }
        .nativeInteractivePop()
        .refreshable { await model.load(force: true) }
        .onAppear { if !model.hasLoaded { Task { await model.load() } } }
    }
}

@MainActor
private final class V3LibraryFolderBrowserViewModel: ObservableObject {
    @Published var items: [LibraryItem] = []
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
