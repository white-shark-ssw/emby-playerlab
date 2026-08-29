from pathlib import Path

root = Path('Sources/App/RootView.swift')
text = root.read_text()
old = '            V3SearchRecommendationPreloader.shared.start(sessions: sessionStore.sessions, sessionStore: sessionStore)\n'
if text.count(old) != 1:
    raise SystemExit('RootView startup Search warm call not found exactly once')
root.write_text(text.replace(old, '', 1))

preloader = Path('Sources/UI/EmbySearchRecommendationPreloader.swift')
text = preloader.read_text()
start = text.index('@MainActor\nfinal class V3SearchRecommendationPreloader')
replacement = '''@MainActor
final class V3SearchRecommendationPreloader {
    static let shared = V3SearchRecommendationPreloader()

    private init() {}

    func recommendations(for stored: EmbySession, client: EmbyAPIClient) async throws -> [LibraryItem] {
        let items = try await client.searchLandingRecommendations(limit: V3SearchRecommendationPolicy.preloadLimit, includeItemTypes: V3SearchRecommendationPolicy.itemTypes)
        let types = Dictionary(grouping: items, by: { $0.type ?? "nil" }).mapValues(\.count).sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        let accepted = Array(items.prefix(V3SearchRecommendationPolicy.preloadLimit))
        warmPosterImages(accepted.compactMap { item in client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: V3SearchRecommendationPolicy.posterImageMaxWidth, tag: item.preferredPrimaryImageTag) })
        DiagnosticsLogger.shared.log("Search", "recommendation initial random-items server=\(stored.serverName) requested=\(V3SearchRecommendationPolicy.itemTypes.joined(separator: ",")) returned=\(items.count) types=\(types)")
        return accepted
    }

    func moreRecommendations(client: EmbyAPIClient, excluding itemIDs: [String]) async throws -> [LibraryItem] {
        let requestedTypes = V3SearchRecommendationPolicy.itemTypes
        let items = try await client.searchLandingRecommendations(limit: V3SearchRecommendationPolicy.loadMoreLimit, includeItemTypes: requestedTypes, excludeItemIds: itemIDs)
        let urls = items.compactMap { item in client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: V3SearchRecommendationPolicy.posterImageMaxWidth, tag: item.preferredPrimaryImageTag) }
        warmPosterImages(urls)
        DiagnosticsLogger.shared.log("Search", "recommendation load-more random-items excluded=\(itemIDs.count) returned=\(items.count)")
        return Array(items.prefix(V3SearchRecommendationPolicy.loadMoreLimit))
    }

    private func warmPosterImages(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                for url in urls {
                    group.addTask {
                        var data = await EmbyImageDiskCache.shared.data(for: url)
                        if data == nil, let response = try? await URLSession.shared.data(from: url) {
                            data = response.0
                            await EmbyImageDiskCache.shared.store(response.0, for: url)
                        }
                        if let data, let image = UIImage(data: data) { EmbyDecodedImageRenderPool.shared.store(image, for: url) }
                    }
                }
                await group.waitForAll()
            }
        }
    }
}
'''
preloader.write_text(text[:start] + replacement)

experience = Path('Sources/UI/EmbySearchExperienceV3.swift')
text = experience.read_text()
replacements = {
    'private struct V3GlobalSearchServerResult: Identifiable {': 'struct V3GlobalSearchServerResult: Identifiable {',
    'private final class V3GlobalSearchViewModel: ObservableObject {': 'final class V3GlobalSearchViewModel: ObservableObject {',
    '        guard recommendationsEnabled, !isLoadingRecommendations else { return }': '        guard recommendationsEnabled, recommendationItems.isEmpty, !isLoadingRecommendations else { return }',
    '    @StateObject private var model = V3GlobalSearchViewModel()': '    @ObservedObject private var model: V3GlobalSearchViewModel',
}
for old, new in replacements.items():
    if text.count(old) != 1:
        raise SystemExit(f'Expected one Search source match: {old}')
    text = text.replace(old, new, 1)
anchor = '    @FocusState private var searchFieldFocused: Bool\n\n    private var horizontalPosterWidth: CGFloat {'
init_block = '''    @FocusState private var searchFieldFocused: Bool

    init(currentSession: EmbySession, currentClient: EmbyAPIClient, model: V3GlobalSearchViewModel, onClose: @escaping () -> Void, dock: AnyView) {
        self.currentSession = currentSession
        self.currentClient = currentClient
        self.model = model
        self.onClose = onClose
        self.dock = dock
    }

    private var horizontalPosterWidth: CGFloat {'''
if text.count(anchor) != 1:
    raise SystemExit('Search view initializer anchor not found')
experience.write_text(text.replace(anchor, init_block, 1))

server_root = Path('Sources/UI/EmbyServerRootViewV3.swift')
text = server_root.read_text()
old = '    @State private var selectedTab: V3ServerTab = .home\n'
new = '    @State private var selectedTab: V3ServerTab = .home\n    @State private var searchModel: V3GlobalSearchViewModel?\n'
if text.count(old) != 1:
    raise SystemExit('selectedTab state anchor not found')
text = text.replace(old, new, 1)
old = '                        if selectedTab == .search { V3EmbyGlobalSearchView(currentSession: session, currentClient: client, onClose: close, dock: emptyDock) }'
new = '                        if selectedTab == .search, let searchModel { V3EmbyGlobalSearchView(currentSession: session, currentClient: client, model: searchModel, onClose: close, dock: emptyDock) }'
if text.count(old) != 1:
    raise SystemExit('Search view mount source not found')
text = text.replace(old, new, 1)
old = '''            } else {
                selectedTab = tab
                if tab == .home { lastHomeTap = Date() }
            }
'''
new = '''            } else {
                if selectedTab != tab {
                    if selectedTab == .search { searchModel = nil }
                    if tab == .search { searchModel = V3GlobalSearchViewModel() }
                }
                selectedTab = tab
                if tab == .home { lastHomeTap = Date() }
            }
'''
if text.count(old) != 1:
    raise SystemExit('Dock tab switch source not found')
server_root.write_text(text.replace(old, new, 1))

checkpoint = Path('docs/project/current/dev/DEV-search-page-optimization.md')
text = checkpoint.read_text().rstrip()
lines = text.splitlines()
for i, line in enumerate(lines):
    if line.startswith('- Status:'):
        lines[i] = '- Status: Active — Build255 target-device exposes recommendation lifetime reset after detail return; Build256 lifetime correction implementation/CI in progress'
        break
text = '\n'.join(lines).rstrip()
marker = '## Build255 target-device result → Build256 Search-tab lifetime correction — 2026-08-30'
if marker not in text:
    text += f'''\n\n{marker}\n\nBuild255 / OnePlayer 0.14.88 is target-device tested. After loading recommendation batches beyond the initial 9, opening a movie detail and returning causes Search to return to the initial state: the appended recommendation items are lost and only 9 remain. This is a lifecycle/state-ownership rejection; Build255 is not stable.\n\nSource inspection identifies two concrete owners that conflict with the requested behavior: app startup calls `V3SearchRecommendationPreloader.shared.start(...)` and the shared preloader retains initial recommendation metadata by session; meanwhile `V3EmbyGlobalSearchView` owns its `V3GlobalSearchViewModel` locally and its `.task` calls `loadRecommendations` without guarding already-loaded items. Build256 reserves OnePlayer 0.14.89 / Build256 and changes those exact owners: no app-start Search recommendation fetch; a fresh Search model is created only when Dock enters Search; the server root retains that model while Search pushes/pops detail; initial load runs only while the retained model has no recommendation items; manually switching Dock away from Search sets the model to nil, so recommendation metadata is destroyed; re-entering Search creates a fresh model and fetches a new initial 9. The shared preloader no longer retains recommendation metadata/tasks across Search lifetimes. Existing image disk/decoded caches remain shared and unchanged.\n'''
checkpoint.write_text(text.rstrip() + '\n')

changelog = Path('docs/changelog/CHANGELOG_v0_14_89_build256.md')
changelog.write_text('''# OnePlayer 0.14.89 / Build256

- Remove Search recommendation fetching from app startup. The initial 9 are requested only when the user enters the Search Dock page.
- Move Search recommendation view-model lifetime to the server Dock root: detail push/pop keeps the same model and all already-appended recommendation items; manually switching away from Search destroys that model.
- Re-entering Search after a Dock switch creates a fresh model and performs a fresh initial-9 request.
- Prevent Search `.task` re-entry from replacing an already-populated recommendation list with the initial 9.
- Remove session-global recommendation metadata/task retention from `V3SearchRecommendationPreloader`; shared image disk/decoded caches remain unchanged.
- Preserve Build253/254 recommendation query semantics, +6 `ExcludeItemIds` loading, Build255 non-lazy outer section owner and Build248 Dock/keyboard behavior.
- No Player, MPV, STRM/302/115 Transport, playback Session Cache, Resume/progress, PiP, credentials or Deployment Target changes.

Evidence pending dedicated Xcode 16.4 Release CI/IPA and target-device validation.
''')
