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
    @Published private(set) var hasMoreRecommendations = true
    @Published private(set) var hasSubmittedSearch = false
    private(set) var currentTerm = ""

    private let searchItemTypes = ["Movie", "Series", "BoxSet"]
    private var searchGeneration = 0
    private var recommendationGeneration = 0
    private var recommendationPosterImages: [String: UIImage] = [:]
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
        guard recommendationsEnabled, !isLoadingRecommendations else { return }
        recommendationGeneration += 1
        let generation = recommendationGeneration
        isLoadingRecommendations = true
        defer { if generation == recommendationGeneration { isLoadingRecommendations = false } }

        do {
            let items = try await V3SearchRecommendationPreloader.shared.recommendations(for: session, client: client)
            guard generation == recommendationGeneration, recommendationsEnabled else { return }
            recommendationItems = items
            hasMoreRecommendations = false
        } catch {
            guard generation == recommendationGeneration else { return }
            hasMoreRecommendations = false
            if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("Search", "recommendations failed: \(error.localizedDescription)") }
        }
    }

    func recommendationPosterImage(for itemID: String) -> UIImage? { recommendationPosterImages[itemID] }
    func pinRecommendationPosterImage(_ image: UIImage, for itemID: String) { recommendationPosterImages[itemID] = image }

    private func recordHistory(_ term: String) {
        history.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        history.insert(term, at: 0)
        UserDefaults.standard.set(history, forKey: V3SearchExperienceStorage.historyKey)
    }

    private func persistServerSelection() {
        UserDefaults.standard.set(Array(selectedServerIDs).sorted(), forKey: V3SearchExperienceStorage.selectedServerIDsKey)
    }
}

private struct V3SearchRecommendationPosterCard: View {
    @Environment(\.embyPosterGridCellWidth) private var gridCellWidth
    let item: LibraryItem
    let client: EmbyAPIClient
    let pinnedImage: UIImage?
    let onImageLoaded: (UIImage) -> Void

    private var resolvedWidth: CGFloat { gridCellWidth ?? 118 }
    private var posterHeight: CGFloat { floor(resolvedWidth / EmbyPosterGridMetrics.posterAspectRatio) }
    private var posterImageMaxWidth: Int { V3SearchRecommendationPolicy.posterImageMaxWidth }
    private var yearText: String { item.productionYear.map(String.init) ?? " " }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let pinnedImage { Image(uiImage: pinnedImage).resizable().aspectRatio(contentMode: .fill) }
                    else {
                        EmbyCachedRemoteImage(url: client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: posterImageMaxWidth, tag: item.preferredPrimaryImageTag), contentMode: .fill, onImageLoaded: onImageLoaded)
                    }
                }
                .frame(width: resolvedWidth, height: posterHeight)
                .clipped()
                if item.playbackProgress > 0 { GeometryReader { proxy in VStack { Spacer(); Rectangle().fill(Color.blue).frame(width: proxy.size.width * item.playbackProgress, height: 3) } } }
                if let count = item.userData?.unplayedItemCount, count > 0 {
                    VStack { HStack { Spacer(); Text("\(count)").font(.caption2.weight(.bold)).foregroundColor(.white).padding(6).background(Color.blue).clipShape(Circle()) }; Spacer() }.padding(5)
                } else if item.isPlayed {
                    VStack { HStack { Spacer(); Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundColor(.white).padding(6).background(Color.green).clipShape(Circle()) }; Spacer() }.padding(5)
                }
            }
            .frame(width: resolvedWidth, height: posterHeight)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline).lineLimit(1).frame(width: resolvedWidth, height: 20, alignment: .leading)
                Text(yearText).font(.caption).foregroundColor(.secondary).lineLimit(1).frame(width: resolvedWidth, height: 16, alignment: .leading).opacity(item.productionYear == nil ? 0 : 1)
            }
            .frame(width: resolvedWidth, height: 38, alignment: .topLeading)
        }
    }
}

struct V3EmbyGlobalSearchView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    let currentSession: EmbySession
    let currentClient: EmbyAPIClient
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    @StateObject private var model = V3GlobalSearchViewModel()
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var showClearHistoryAlert = false
    @State private var singleServerResult: V3GlobalSearchServerResult?

    private let contentInset: CGFloat = 20

    var body: some View {
        NavigationView {
            Group {
                if let singleServerResult {
                    V3GlobalSearchServerGridView(result: singleServerResult, term: model.currentTerm, onClose: { self.singleServerResult = nil })
                } else if model.hasSubmittedSearch {
                    resultsBody
                } else {
                    landingBody
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                model.reconcileServers(sessionStore.sessions)
                if model.recommendationsEnabled { Task { await model.loadRecommendations(session: currentSession, client: currentClient) } }
            }
            .onChange(of: sessionStore.sessions) { sessions in model.reconcileServers(sessions) }
            .onChange(of: model.recommendationsEnabled) { enabled in if enabled { Task { await model.loadRecommendations(session: currentSession, client: currentClient) } } }
            .alert("清除搜索历史", isPresented: $showClearHistoryAlert) {
                Button("取消", role: .cancel) {}
                Button("全部清除", role: .destructive) { model.clearHistory() }
            } message: {
                Text("确定要清除所有搜索历史吗？此操作无法撤销。")
            }
        }
        .navigationViewStyle(.stack)
    }

    private var landingBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                landingHeader
                searchField
                    .padding(.top, 18)

                if !model.history.isEmpty {
                    historySection
                        .padding(.top, 18)
                }

                if model.recommendationsEnabled, model.isLoadingRecommendations || !model.recommendationItems.isEmpty {
                    recommendationSection
                        .padding(.top, model.history.isEmpty ? 18 : 24)
                }
            }
            .padding(.horizontal, contentInset)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var landingHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                settingsMenu
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 42, height: 42)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Text("搜索")
                .font(.system(size: 32, weight: .bold))
        }
    }

    private var settingsMenu: some View {
        Menu {
            Button(action: model.toggleGlobalSearch) {
                Label("全局搜索", systemImage: model.globalSearchEnabled ? "checkmark" : "")
            }
            Button(action: model.toggleRecommendations) {
                Label("显示推荐观看", systemImage: model.recommendationsEnabled ? "checkmark" : "")
            }
            if model.globalSearchEnabled {
                Section(header: Text("Emby 服务器")) {
                    ForEach(sessionStore.sessions) { session in
                        Button { model.toggleServer(session.id) } label: {
                            Label(session.serverName, systemImage: model.selectedServerIDs.contains(session.id) ? "checkmark" : "")
                        }
                    }
                }
            }
            Button(action: onOpenSettings) { Label("设置", systemImage: "gearshape") }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 18.6, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 18)).foregroundColor(.secondary)
            TextField("搜索", text: $searchText)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .onSubmit { submitSearch() }
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("搜索历史").font(.title3.weight(.bold))
                Spacer()
                Button { showClearHistoryAlert = true } label: { Image(systemName: "trash").font(.system(size: 19)).foregroundColor(.blue) }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(model.history, id: \.self) { term in
                        Button {
                            searchText = term
                            submitSearch()
                        } label: {
                            Text(term)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推荐观看").font(.title3.weight(.bold))
            if model.recommendationItems.isEmpty, model.isLoadingRecommendations {
                HStack { Spacer(); ProgressView(); Spacer() }.frame(height: 90)
            } else {
                EmbyPosterGrid(items: model.recommendationItems) { item in
                    EmbyPosterDetailLink(item: item, client: currentClient) {
                        V3SearchRecommendationPosterCard(item: item, client: currentClient, pinnedImage: model.recommendationPosterImage(for: item.id), onImageLoaded: { model.pinRecommendationPosterImage($0, for: item.id) })
                    }
                }
            }
        }
    }

    private var resultsBody: some View {
        VStack(spacing: 0) {
            compactSearchHeader
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if model.isSearching {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    }
                    ForEach(model.serverResults) { result in serverResultSection(result) }
                    if !model.isSearching, model.serverResults.isEmpty {
                        Text("没有找到结果").foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding(.vertical, 18)
            }
        }
    }

    private var compactSearchHeader: some View {
        HStack(spacing: 12) {
            searchField
            Button("取消") {
                searchFocused = false
                model.cancelDisplayedSearch()
            }
            .foregroundColor(.blue)
        }
        .padding(.horizontal, contentInset)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func serverResultSection(_ result: V3GlobalSearchServerResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.session.serverName).font(.title3.weight(.bold))
                Spacer()
                NavigationLink {
                    V3GlobalSearchServerGridView(result: result, term: model.currentTerm, onClose: nil)
                } label: {
                    Text("更多").foregroundColor(.blue)
                }
            }
            .padding(.horizontal, contentInset)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: EmbyPosterGridMetrics.columnSpacing) {
                    ForEach(result.items) { item in
                        EmbyPosterDetailLink(item: item, client: result.client) {
                            V3PosterCard(item: item, client: result.client)
                                .frame(width: horizontalPosterWidth)
                        }
                    }
                }
                .padding(.horizontal, contentInset)
            }
        }
    }

    private var horizontalPosterWidth: CGFloat {
        let available = UIScreen.main.bounds.width - contentInset * 2 - EmbyPosterGridMetrics.columnSpacing * 2
        return floor(available / 3)
    }

    private func submitSearch() {
        searchFocused = false
        Task {
            if let result = await model.search(searchText, sessions: sessionStore.sessions, currentSession: currentSession, currentClient: currentClient, sessionStore: sessionStore) {
                singleServerResult = result
            }
        }
    }
}

private struct V3GlobalSearchServerGridView: View {
    let result: V3GlobalSearchServerResult
    let term: String
    let onClose: (() -> Void)?

    @State private var items: [LibraryItem] = []
    @State private var totalRecordCount: Int?
    @State private var loading = false
    @State private var didLoad = false
    @State private var loadError: String?

    private let pageSize = 60
    private let searchTypes = ["Movie", "Series", "BoxSet"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let loadError, items.isEmpty {
                    Text(loadError).foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    EmbyPosterGrid(items: items) { item in
                        EmbyPosterDetailLink(item: item, client: result.client) { V3PosterCard(item: item, client: result.client) }
                    }
                    if canLoadMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .onAppear { Task { await loadNextPage() } }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(result.session.serverName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .navigationBarLeading) { Button("取消", action: onClose) }
            }
        }
        .task { if !didLoad { await loadNextPage() } }
    }

    private var canLoadMore: Bool {
        guard !loading else { return false }
        if let totalRecordCount { return items.count < totalRecordCount }
        return didLoad && !items.isEmpty
    }

    @MainActor
    private func loadNextPage() async {
        guard !loading else { return }
        loading = true
        defer { loading = false; didLoad = true }
        do {
            let page = try await result.client.searchPosterItemsPage(term: term, limit: pageSize, startIndex: items.count, includeItemTypes: searchTypes)
            var seen = Set(items.map(\.id))
            items.append(contentsOf: page.items.filter { seen.insert($0.id).inserted })
            totalRecordCount = page.totalRecordCount
            loadError = nil
        } catch {
            if !isEmbyRequestCancellation(error) { loadError = error.localizedDescription }
        }
    }
}
