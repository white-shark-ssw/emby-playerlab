import SwiftUI
import Combine
import UIKit

private enum V3SearchExperienceStorage {
    static let historyKey = "oneplayer.search.history.v1"
    static let globalSearchEnabledKey = "oneplayer.search.global-enabled.v1"
    static let recommendationsEnabledKey = "oneplayer.search.recommendations-enabled.v1"
    static let selectedServerIDsKey = "oneplayer.search.selected-server-ids.v1"
}

private struct V3GlobalSearchServerResult: Identifiable {
    let session: EmbySession
    let client: EmbyAPIClient
    let items: [LibraryItem]
    let totalRecordCount: Int?
    var id: String { session.id }
}

@MainActor
private final class V3GlobalSearchViewModel: ObservableObject {
    @Published private(set) var history: [String]
    @Published private(set) var globalSearchEnabled: Bool
    @Published private(set) var recommendationsEnabled: Bool
    @Published private(set) var selectedServerIDs: Set<String>
    @Published private(set) var serverResults: [V3GlobalSearchServerResult] = []
    @Published private(set) var recommendationItems: [LibraryItem] = []
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingRecommendations = false
    @Published private(set) var hasSubmittedSearch = false
    private(set) var currentTerm = ""

    private let searchItemTypes = ["Movie", "Series", "BoxSet"]
    private var searchGeneration = 0
    private var recommendationGeneration = 0
    private var recommendationsLoaded = false
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
        if !recommendationsEnabled { recommendationGeneration += 1; isLoadingRecommendations = false }
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

    func search(_ term: String, sessions: [EmbySession], currentSession: EmbySession, currentClient: EmbyAPIClient, sessionStore: SessionStore) async {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { cancelDisplayedSearch(); return }
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

        for stored in targets {
            guard generation == searchGeneration else { return }
            do {
                let targetClient = stored.id == currentSession.id ? currentClient : try await sessionStore.clientForBestRoute(for: stored)
                let page = try await targetClient.searchItemsPage(term: trimmed, limit: 20, startIndex: 0, includeItemTypes: searchItemTypes)
                guard generation == searchGeneration, currentTerm == trimmed else { return }
                if !page.items.isEmpty { serverResults.append(V3GlobalSearchServerResult(session: stored, client: targetClient, items: page.items, totalRecordCount: page.totalRecordCount)) }
            } catch {
                guard generation == searchGeneration else { return }
                if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("Search", "server search failed server=\(stored.serverName): \(error.localizedDescription)") }
            }
        }

        guard generation == searchGeneration else { return }
        isSearching = false
    }

    func loadRecommendations(client: EmbyAPIClient) async {
        guard recommendationsEnabled, !recommendationsLoaded, !isLoadingRecommendations else { return }
        recommendationGeneration += 1
        let generation = recommendationGeneration
        isLoadingRecommendations = true
        defer {
            if generation == recommendationGeneration {
                isLoadingRecommendations = false
                recommendationsLoaded = true
            }
        }

        do {
            let libraries = try await client.userViews()
            var seen = Set<String>()
            var result: [LibraryItem] = []
            for library in libraries {
                guard generation == recommendationGeneration, recommendationsEnabled else { return }
                let itemTypes = recommendationItemTypes(for: library)
                guard !itemTypes.isEmpty else { continue }
                do {
                    let suggestions = try await client.librarySuggestions(parentId: library.id, limit: 9, includeItemTypes: itemTypes)
                    for item in suggestions where seen.insert(item.id).inserted {
                        result.append(item)
                        if result.count == 9 { break }
                    }
                } catch {
                    if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("Search", "recommendations failed library=\(library.name): \(error.localizedDescription)") }
                }
                if result.count == 9 { break }
            }
            guard generation == recommendationGeneration, recommendationsEnabled else { return }
            recommendationItems = result
        } catch {
            guard generation == recommendationGeneration else { return }
            if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("Search", "recommendation libraries failed: \(error.localizedDescription)") }
        }
    }

    private func recommendationItemTypes(for library: LibraryItem) -> [String] {
        switch library.collectionType?.lowercased() {
        case "movies": return ["Movie"]
        case "tvshows": return ["Series"]
        case "homevideos": return ["Video"]
        case "mixed": return ["Movie", "Series", "Video"]
        default: return []
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
    @EnvironmentObject private var sessionStore: SessionStore
    let currentSession: EmbySession
    let currentClient: EmbyAPIClient
    let onClose: () -> Void
    let dock: AnyView
    @StateObject private var model = V3GlobalSearchViewModel()
    @State private var searchText = ""
    @State private var showClearHistoryAlert = false
    @FocusState private var searchFieldFocused: Bool

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
                    searchField.padding(.horizontal, 20).padding(.top, 12)
                    searchLanding.padding(.top, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .overlay(alignment: .bottom) { dock }
            .navigationBarHidden(true)
            .alert("清除搜索历史", isPresented: $showClearHistoryAlert) {
                Button("取消", role: .cancel) {}
                Button("全部清除", role: .destructive) { model.clearHistory() }
            } message: {
                Text("确定要清除所有搜索历史吗？此操作无法撤销。")
            }
            .task {
                model.reconcileServers(sessionStore.sessions)
                await model.loadRecommendations(client: currentClient)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                searchSettingsMenu
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundColor(.primary)
                        .frame(width: 38, height: 38)
                        .background(Color(uiColor: .secondarySystemBackground)).clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            Text("搜索").font(.system(size: 38, weight: .bold)).foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var compactSearchHeader: some View {
        HStack(spacing: 12) {
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
                if model.recommendationsEnabled { Task { await model.loadRecommendations(client: currentClient) } }
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
            Image(systemName: "gearshape.circle").font(.system(size: 27, weight: .medium)).foregroundColor(.blue).frame(width: 38, height: 38)
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
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").font(.system(size: 18)).foregroundColor(.secondary)
            TextField("搜索", text: $searchText)
                .focused($searchFieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { submitSearch(searchText) }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    model.cancelDisplayedSearch()
                } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundColor(.secondary) }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 48)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var searchLanding: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 28) {
                if !model.history.isEmpty { searchHistorySection }
                if model.recommendationsEnabled && (model.isLoadingRecommendations || !model.recommendationItems.isEmpty) { recommendationsSection }
            }
            .padding(.bottom, 86)
        }
    }

    private var searchHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("搜索历史").font(.system(size: 20, weight: .bold))
                Spacer()
                Button { showClearHistoryAlert = true } label: { Image(systemName: "trash").font(.system(size: 19)).foregroundColor(.blue).frame(width: 34, height: 34) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除搜索历史")
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(model.history, id: \.self) { term in
                        Button {
                            searchText = term
                            submitSearch(term)
                        } label: {
                            Text(term).font(.system(size: 14)).foregroundColor(.primary).lineLimit(1)
                                .padding(.horizontal, 14).frame(height: 34)
                                .background(Color(uiColor: .secondarySystemBackground)).clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("推荐观看").font(.system(size: 20, weight: .bold)).padding(.horizontal, 16)
            if model.isLoadingRecommendations && model.recommendationItems.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 18)
            } else {
                EmbyPosterGrid(items: Array(model.recommendationItems.prefix(9))) { item in
                    EmbyPosterDetailLink(item: item, client: currentClient) { V3PosterCard(item: item, client: currentClient, width: nil) }
                }
            }
        }
    }

    private var searchResults: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 30) {
                ForEach(model.serverResults) { result in serverResultSection(result) }
                if model.isSearching { ProgressView().frame(maxWidth: .infinity).padding(.top, model.serverResults.isEmpty ? 34 : 0) }
                else if model.serverResults.isEmpty { Text("未找到相关内容").font(.subheadline).foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.top, 34) }
            }
            .padding(.bottom, 86)
        }
    }

    private func serverResultSection(_ result: V3GlobalSearchServerResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(result.session.serverName).font(.system(size: 20, weight: .bold)).lineLimit(1)
                Spacer()
                NavigationLink(destination: V3GlobalSearchServerGridView(serverName: result.session.serverName, term: model.currentTerm, client: result.client, dock: dock)) {
                    Text("更多").font(.system(size: 16)).foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: EmbyPosterGridMetrics.columnSpacing) {
                    ForEach(result.items) { item in
                        EmbyPosterDetailLink(item: item, client: result.client) { V3PosterCard(item: item, client: result.client, width: horizontalPosterWidth) }
                            .frame(width: horizontalPosterWidth, alignment: .topLeading)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func submitSearch(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        searchText = trimmed
        searchFieldFocused = false
        Task { await model.search(trimmed, sessions: sessionStore.sessions, currentSession: currentSession, currentClient: currentClient, sessionStore: sessionStore) }
    }

    private func refreshSubmittedSearchIfNeeded() {
        guard model.hasSubmittedSearch else { return }
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        Task { await model.search(term, sessions: sessionStore.sessions, currentSession: currentSession, currentClient: currentClient, sessionStore: sessionStore) }
    }
}

private struct V3GlobalSearchServerGridView: View {
    let serverName: String
    let term: String
    let client: EmbyAPIClient
    let dock: AnyView
    @StateObject private var model: V3GlobalSearchServerGridViewModel

    init(serverName: String, term: String, client: EmbyAPIClient, dock: AnyView) {
        self.serverName = serverName
        self.term = term
        self.client = client
        self.dock = dock
        _model = StateObject(wrappedValue: V3GlobalSearchServerGridViewModel(term: term, client: client))
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
                        EmbyPosterDetailLink(item: item, client: client) { V3PosterCard(item: item, client: client, width: nil) }
                    }
                }
                if let errorMessage = model.errorMessage { Text(errorMessage).font(.footnote).foregroundColor(.red).padding(.horizontal, EmbyPosterGridMetrics.horizontalPadding) }
            }
            .padding(.top, 8)
            .padding(.bottom, 86)
        }
        .navigationTitle(serverName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .overlay(alignment: .bottom) { dock }
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
    private let term: String
    private let client: EmbyAPIClient
    private let pageSize = 60
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
            let page = try await client.searchItemsPage(term: term, limit: pageSize, startIndex: start, includeItemTypes: includeItemTypes)
            let newItems = page.items.filter { seenItemIDs.insert($0.id).inserted }
            if !newItems.isEmpty { items.append(contentsOf: newItems) }
            nextStartIndex = start + page.items.count
            if let total = page.totalRecordCount { hasMore = nextStartIndex < total }
            else { hasMore = page.items.count == pageSize }
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
            hasMore = false
        }
    }
}
