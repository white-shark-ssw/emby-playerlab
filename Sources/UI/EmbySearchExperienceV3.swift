import SwiftUI
import Combine
import UIKit

private enum V3SearchExperienceStorage {
    static let historyKey = "oneplayer.search.history.v1"
    static let globalSearchEnabledKey = "oneplayer.search.global-enabled.v1"
    static let recommendationsEnabledKey = "oneplayer.search.recommendations-enabled.v1"
    static let selectedServerIDsKey = "oneplayer.search.selected-server-ids.v1"
}

struct V3GlobalSearchServerResult: Identifiable {
    let session: EmbySession
    let client: EmbyAPIClient
    let items: [LibraryItem]
    let totalRecordCount: Int?
    var id: String { session.id }
}

@MainActor
final class V3GlobalSearchViewModel: ObservableObject {
    @Published private(set) var history: [String]
    @Published private(set) var globalSearchEnabled: Bool
    @Published private(set) var recommendationsEnabled: Bool
    @Published private(set) var selectedServerIDs: Set<String>
    @Published private(set) var serverResults: [V3GlobalSearchServerResult] = []
    @Published private(set) var recommendationItems: [LibraryItem] = []
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingRecommendations = false
    @Published private(set) var hasMoreRecommendations = true
    @Published private(set) var hasSubmittedSearch = false
    private(set) var currentTerm = ""

    private let searchItemTypes = ["Movie", "Series", "BoxSet"]
    private var searchGeneration = 0
    private var recommendationGeneration = 0
    private var isLoadingMoreRecommendations = false
    private(set) var recommendationRevision = 0
    private var hasStoredServerSelection: Bool

    init() {
        let defaults = UserDefaults.standard
        history = defaults.stringArray(forKey: V3SearchExperienceStorage.historyKey) ?? []
        globalSearchEnabled = defaults.object(forKey: V3SearchExperienceStorage.globalSearchEnabledKey) as? Bool ?? true
        recommendationsEnabled = defaults.object(forKey: V3SearchExperienceStorage.recommendationsEnabledKey) as? Bool ?? true
        let storedServerIDs = defaults.stringArray(forKey: V3SearchExperienceStorage.selectedServerIDsKey)
        selectedServerIDs = Set(storedServerIDs ?? [])
        hasStoredServerSelection = storedServerIDs != nil
    }

    func reconcileServers(_ sessions: [EmbySession]) {
        let validIDs = Set(sessions.map(\.id))
        if !hasStoredServerSelection {
            selectedServerIDs = validIDs
            hasStoredServerSelection = true
            persistServerSelection()
            return
        }
        let reconciled = selectedServerIDs.intersection(validIDs)
        guard reconciled != selectedServerIDs else { return }
        selectedServerIDs = reconciled
        persistServerSelection()
    }

    func toggleGlobalSearch() {
        globalSearchEnabled.toggle()
        UserDefaults.standard.set(globalSearchEnabled, forKey: V3SearchExperienceStorage.globalSearchEnabledKey)
    }

    func toggleRecommendations() {
        recommendationsEnabled.toggle()
        UserDefaults.standard.set(recommendationsEnabled, forKey: V3SearchExperienceStorage.recommendationsEnabledKey)
        if !recommendationsEnabled {
            recommendationGeneration += 1
            isLoadingRecommendations = false
            isLoadingMoreRecommendations = false
        } else {
            hasMoreRecommendations = true
        }
    }

    func toggleServer(_ sessionID: String) {
        if selectedServerIDs.contains(sessionID) { selectedServerIDs.remove(sessionID) }
        else { selectedServerIDs.insert(sessionID) }
        persistServerSelection()
    }

    func clearHistory() {
        history.removeAll()
        UserDefaults.standard.removeObject(forKey: V3SearchExperienceStorage.historyKey)
    }

    func cancelDisplayedSearch() {
        searchGeneration += 1
        currentTerm = ""
        serverResults = []
        isSearching = false
        hasSubmittedSearch = false
    }

    func search(_ term: String, sessions: [EmbySession], currentSession: EmbySession, currentClient: EmbyAPIClient, sessionStore: SessionStore) async -> V3GlobalSearchServerResult? {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { cancelDisplayedSearch(); return nil }
        recordHistory(trimmed)
        searchGeneration += 1
        let generation = searchGeneration
        currentTerm = trimmed
        serverResults = []
        isSearching = true
        hasSubmittedSearch = true

        let targets: [EmbySession]
        if globalSearchEnabled { targets = sessions.filter { selectedServerIDs.contains($0.id) } }
        else { targets = [currentSession] }

        if targets.count == 1, let stored = targets.first {
            do {
                let targetClient = stored.id == currentSession.id ? currentClient : try await sessionStore.clientForBestRoute(for: stored)
                guard generation == searchGeneration, currentTerm == trimmed else { return nil }
                isSearching = false
                hasSubmittedSearch = false
                return V3GlobalSearchServerResult(session: stored, client: targetClient, items: [], totalRecordCount: nil)
            } catch {
                guard generation == searchGeneration else { return nil }
                isSearching = false
                if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("Search", "single-server route failed server=\(stored.serverName): \(error.localizedDescription)") }
                return nil
            }
        }

        for stored in targets {
            guard generation == searchGeneration else { return nil }
            do {
                let targetClient = stored.id == currentSession.id ? currentClient : try await sessionStore.clientForBestRoute(for: stored)
                let page = try await targetClient.searchPosterItemsPage(term: trimmed, limit: 18, startIndex: 0, includeItemTypes: searchItemTypes)
                guard generation == searchGeneration, currentTerm == trimmed else { return nil }
                if !page.items.isEmpty { serverResults.append(V3GlobalSearchServerResult(session: stored, client: targetClient, items: page.items, totalRecordCount: page.totalRecordCount)) }
            } catch {
                guard generation == searchGeneration else { return nil }
                if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("Search", "server search failed server=\(stored.serverName): \(error.localizedDescription)") }
            }
        }

        guard generation == searchGeneration else { return nil }
        isSearching = false
        return nil
    }

    func loadRecommendations(session: EmbySession, client: EmbyAPIClient) async {
        guard recommendationsEnabled, recommendationItems.isEmpty, !isLoadingRecommendations else { return }
        recommendationGeneration += 1
        let generation = recommendationGeneration
        isLoadingRecommendations = true
        defer { if generation == recommendationGeneration { isLoadingRecommendations = false } }

        do {
            let items = try await V3SearchRecommendationPreloader.shared.recommendations(for: session, client: client)
            guard generation == recommendationGeneration, recommendationsEnabled else { return }
            recommendationItems = items
            recommendationRevision += 1
            hasMoreRecommendations = items.count >= V3SearchRecommendationPolicy.preloadLimit
        } catch {
            guard generation == recommendationGeneration else { return }
            hasMoreRecommendations = false
            if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("Search", "recommendations failed: \(error.localizedDescription)") }
        }
    }

    func loadMoreRecommendations(client: EmbyAPIClient) async {
        guard recommendationsEnabled, hasMoreRecommendations, !isLoadingRecommendations, !isLoadingMoreRecommendations, !recommendationItems.isEmpty else { return }
        let generation = recommendationGeneration
        let excludedIDs = recommendationItems.map(\.id)
        isLoadingMoreRecommendations = true
        defer { if generation == recommendationGeneration { isLoadingMoreRecommendations = false } }

        do {
            let batch = try await V3SearchRecommendationPreloader.shared.moreRecommendations(client: client, excluding: excludedIDs)
            guard generation == recommendationGeneration, recommendationsEnabled else { return }
            let existingIDs = Set(recommendationItems.map(\.id))
            let newItems = batch.filter { !existingIDs.contains($0.id) }
            recommendationItems.append(contentsOf: newItems)
            if !newItems.isEmpty { recommendationRevision += 1 }
            hasMoreRecommendations = batch.count == V3SearchRecommendationPolicy.loadMoreLimit && newItems.count == batch.count
            DiagnosticsLogger.shared.log("Search", "recommendation load-more appended=\(newItems.count) total=\(recommendationItems.count) hasMore=\(hasMoreRecommendations)")
        } catch {
            guard generation == recommendationGeneration else { return }
            if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("Search", "recommendation load-more failed: \(error.localizedDescription)") }
        }
    }

    private func recordHistory(_ term: String) {
        history.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        history.insert(term, at: 0)
        UserDefaults.standard.set(history, forKey: V3SearchExperienceStorage.historyKey)
    }

    private func persistServerSelection() {
        UserDefaults.standard.set(Array(selectedServerIDs).sorted(), forKey: V3SearchExperienceStorage.selectedServerIDsKey)
    }
}


struct V3EmbyGlobalSearchView: View {
    @Environment(\.serverDockBottomInset) private var dockBottomInset
    @EnvironmentObject private var sessionStore: SessionStore
    let currentSession: EmbySession
    let currentClient: EmbyAPIClient
    let onClose: () -> Void
    @ObservedObject private var model: V3GlobalSearchViewModel
    @State private var searchText = ""
    @State private var showClearHistoryAlert = false
    @State private var directSearchDestination: V3GlobalSearchServerResult?
    @State private var previewItem: LibraryItem?
    @State private var previewClient: EmbyAPIClient?
    @State private var previewMore: V3GlobalSearchServerResult?
    @FocusState private var searchFieldFocused: Bool

    init(currentSession: EmbySession, currentClient: EmbyAPIClient, model: V3GlobalSearchViewModel, onClose: @escaping () -> Void) {
        self.currentSession = currentSession
        self.currentClient = currentClient
        self.model = model
        self.onClose = onClose
    }

    private var horizontalPosterWidth: CGFloat {
        let available = UIScreen.main.bounds.width - 32 - EmbyPosterGridMetrics.columnSpacing * 2
        return floor(available / 3)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if model.hasSubmittedSearch {
                    compactSearchHeader
                    searchResults.padding(.top, 20)
                } else {
                    searchHeader
                    searchField.padding(.horizontal, 20).padding(.top, 8)
                    searchLanding.padding(.top, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .serverDockPage()
            .background(directSearchLink)
            .navigationBarHidden(true)
            .alert("清除搜索历史", isPresented: $showClearHistoryAlert) {
                Button("取消", role: .cancel) {}
                Button("全部清除", role: .destructive) { model.clearHistory() }
            } message: {
                Text("确定要清除所有搜索历史吗？此操作无法撤销。")
            }
            .task {
                model.reconcileServers(sessionStore.sessions)
                await model.loadRecommendations(session: currentSession, client: currentClient)
            }
            .onChange(of: sessionStore.sessions) { model.reconcileServers($0) }
            .onChange(of: searchText) { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed != model.currentTerm && model.hasSubmittedSearch { model.cancelDisplayedSearch() }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                searchSettingsMenu
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color(uiColor: .secondarySystemBackground)).clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            Text("搜索").font(.system(size: 32, weight: .bold)).foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var compactSearchHeader: some View {
        HStack(spacing: 10) {
            searchField
            Button("取消") {
                searchText = ""
                searchFieldFocused = false
                model.cancelDisplayedSearch()
            }
            .font(.system(size: 16))
            .foregroundColor(.blue)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var searchSettingsMenu: some View {
        Menu {
            Button {
                model.toggleGlobalSearch()
                refreshSubmittedSearchIfNeeded()
            } label: { menuCheckLabel("全局搜索", selected: model.globalSearchEnabled) }

            Divider()

            Button {
                model.toggleRecommendations()
                if model.recommendationsEnabled { Task { await model.loadRecommendations(session: currentSession, client: currentClient) } }
            } label: { menuCheckLabel("显示推荐观看", selected: model.recommendationsEnabled) }

            if model.globalSearchEnabled {
                Divider()
                Section(header: Text("Emby 服务器")) {
                    ForEach(sessionStore.sessions) { stored in
                        Button {
                            model.toggleServer(stored.id)
                            refreshSubmittedSearchIfNeeded()
                        } label: { menuCheckLabel(stored.serverName, selected: model.selectedServerIDs.contains(stored.id)) }
                    }
                }
            }
        } label: {
            Image(systemName: "gearshape.circle").font(.system(size: 18.6, weight: .medium)).foregroundColor(.blue).frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("搜索设置")
    }

    @ViewBuilder
    private func menuCheckLabel(_ title: String, selected: Bool) -> some View {
        if selected { Label(title, systemImage: "checkmark") }
        else { Text(title) }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 16)).foregroundColor(.secondary)
            TextField("搜索", text: $searchText)
                .focused($searchFieldFocused)
                .font(.system(size: 16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { submitSearch(searchText) }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    model.cancelDisplayedSearch()
                } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundColor(.secondary) }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var searchLanding: some View {
        EmbyPosterSearchLanding(items: model.recommendationItems, revision: model.recommendationRevision, history: model.history, recommendationsEnabled: model.recommendationsEnabled, isLoading: model.isLoadingRecommendations, client: currentClient, bottomPadding: ServerDockMetrics.contentBottomPadding(bottomInset: dockBottomInset), isActive: directSearchDestination == nil, onHistory: { term in
            searchText = term
            submitSearch(term)
        }, onClearHistory: { showClearHistoryAlert = true }, onApproachingEnd: {
            guard model.hasMoreRecommendations else { return }
            Task { await model.loadMoreRecommendations(client: currentClient) }
        })
    }

    private var searchResults: some View {
        EmbyPosterSections(sections: searchPosterSections, queryIdentity: "multi-search|\(model.currentTerm)", sectionGap: 30, bottomPadding: ServerDockMetrics.contentBottomPadding(bottomInset: dockBottomInset), isLoading: model.isSearching, emptyText: "未找到相关内容", isActive: directSearchDestination == nil && previewItem == nil && previewMore == nil, top: EmptyView())
            .background(searchPreviewNavigation)
    }

    private var searchPosterSections: [EmbyPosterSection] {
        model.serverResults.map { result in
            EmbyPosterSection(id: result.id, title: result.session.serverName, items: result.items, client: result.client, width: horizontalPosterWidth, spacing: EmbyPosterGridMetrics.columnSpacing, onMore: { previewMore = result }, onSelect: { item in
                previewClient = result.client; previewItem = item
            })
        }
    }

    private var searchPreviewNavigation: some View {
        ZStack {
            NavigationLink(isActive: Binding(get: { previewItem != nil }, set: { if !$0 { previewItem = nil; previewClient = nil } })) {
                if let item = previewItem, let client = previewClient { EmbyPosterDetailDestination(item: item, client: client) } else { EmptyView() }
            } label: { EmptyView() }
            NavigationLink(isActive: Binding(get: { previewMore != nil }, set: { if !$0 { previewMore = nil } })) {
                if let result = previewMore { V3GlobalSearchServerGridView(serverName: result.session.serverName, term: model.currentTerm, client: result.client) } else { EmptyView() }
            } label: { EmptyView() }
        }
        .frame(width: 0, height: 0).hidden().allowsHitTesting(false)
    }

    private var directSearchLink: some View {
        NavigationLink(isActive: Binding(get: { directSearchDestination != nil }, set: { if !$0 { directSearchDestination = nil } })) {
            if let result = directSearchDestination {
                V3GlobalSearchServerGridView(serverName: result.session.serverName, term: searchText, client: result.client)
            } else {
                EmptyView()
            }
        } label: {
            EmptyView()
        }
        .hidden()
    }

    private func submitSearch(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchText = trimmed
        searchFieldFocused = false
        Task {
            if let direct = await model.search(trimmed, sessions: sessionStore.sessions, currentSession: currentSession, currentClient: currentClient, sessionStore: sessionStore) {
                directSearchDestination = direct
            }
        }
    }

    private func refreshSubmittedSearchIfNeeded() {
        guard model.hasSubmittedSearch else { return }
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        Task {
            if let direct = await model.search(term, sessions: sessionStore.sessions, currentSession: currentSession, currentClient: currentClient, sessionStore: sessionStore) {
                directSearchDestination = direct
            }
        }
    }
}

private struct V3GlobalSearchServerGridView: View {
    @Environment(\.serverDockBottomInset) private var dockBottomInset
    let serverName: String
    let term: String
    let client: EmbyAPIClient
    @StateObject private var model: V3GlobalSearchServerGridViewModel

    init(serverName: String, term: String, client: EmbyAPIClient) {
        self.serverName = serverName
        self.term = term
        self.client = client
        _model = StateObject(wrappedValue: V3GlobalSearchServerGridViewModel(term: term, client: client))
    }

    var body: some View {
        EmbyPosterResultsPage(items: model.items, revision: model.posterRevision, replacement: 0, client: client, queryIdentity: "search|\(term)", isLoading: model.isInitialLoading, hasLoaded: model.hasLoaded, error: model.errorMessage, emptyText: "未找到相关内容", bottomPadding: ServerDockMetrics.contentBottomPadding(bottomInset: dockBottomInset), onApproachingEnd: {
            guard model.hasMore else { return }
            Task { await model.loadNextPage() }
        })
        .navigationTitle(serverName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .serverDockPage()
        .nativeInteractivePop()
        .onAppear { if !model.hasLoaded { Task { await model.loadNextPage() } } }
    }
}

@MainActor
private final class V3GlobalSearchServerGridViewModel: ObservableObject {
    @Published private(set) var items: [LibraryItem] = []
    @Published private(set) var isInitialLoading = false
    @Published private(set) var errorMessage: String?
    private(set) var hasMore = true
    private(set) var hasLoaded = false
    private(set) var posterRevision = 0
    private let term: String
    private let client: EmbyAPIClient
    private let pageSize = 18
    private let includeItemTypes = ["Movie", "Series", "BoxSet"]
    private var nextStartIndex = 0
    private var isFetching = false
    private var seenItemIDs = Set<String>()

    init(term: String, client: EmbyAPIClient) { self.term = term; self.client = client }

    func loadNextPage() async {
        guard hasMore, !isFetching else { return }
        isFetching = true
        if items.isEmpty { isInitialLoading = true }
        errorMessage = nil
        let start = nextStartIndex
        defer { isFetching = false; isInitialLoading = false; hasLoaded = true }
        do {
            let page = try await client.searchPosterItemsPage(term: term, limit: pageSize, startIndex: start, includeItemTypes: includeItemTypes)
            let newItems = page.items.filter { seenItemIDs.insert($0.id).inserted }
            if !newItems.isEmpty { items.append(contentsOf: newItems); posterRevision += 1 }
            nextStartIndex = start + page.items.count
            if let total = page.totalRecordCount { hasMore = nextStartIndex < total }
            else { hasMore = page.items.count == pageSize }
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
            hasMore = false
        }
    }
}
