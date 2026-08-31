from pathlib import Path
import subprocess

TESTED = "39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6"

def show(path: str) -> str:
    return subprocess.check_output(["git", "show", f"{TESTED}:{path}"], text=True)

Path("Sources/UI/EmbyNativePosterCollectionView.swift").write_text(show("Sources/UI/EmbyNativePosterCollectionView.swift"))
Path("Sources/UI/EmbyPagePersistentCache.swift").write_text(show("Sources/UI/EmbyPagePersistentCache.swift"))
Path("Sources/UI/EmbySharedImageAndNavigation.swift").write_text(show("Sources/UI/EmbySharedImageAndNavigation.swift"))

identity_path = Path("Sources/Core/AppIdentity.swift")
identity = identity_path.read_text()
if identity.count("0.14.49") != 2:
    raise SystemExit(f"unexpected AppIdentity 0.14.49 count={identity.count('0.14.49')}")
identity_path.write_text(identity.replace("0.14.49", "0.15.18"))

browse_path = Path("Sources/UI/EmbyServerBrowseV3.swift")
browse = browse_path.read_text()
state_old = "    @StateObject private var model: V3LibraryBrowserViewModel\n    @State private var selectedTab = V3LibraryTab.items\n"
state_new = state_old + "    @State private var nativePosterSelection: LibraryItem?\n"
if browse.count(state_old) != 1: raise SystemExit("Browse state anchor mismatch")
browse = browse.replace(state_old, state_new, 1)

switch_old = "        switch selectedTab {\n        case .items, .trailers, .collections, .favorites:\n            pagedPosterTab(selectedTab)\n"
switch_new = "        switch selectedTab {\n        case .items:\n            nativeItemsTab\n        case .trailers, .collections, .favorites:\n            pagedPosterTab(selectedTab)\n"
if browse.count(switch_old) != 1: raise SystemExit("Browse tab switch anchor mismatch")
browse = browse.replace(switch_old, switch_new, 1)

native_block = (
    "    private var nativeItemsTab: some View {\n"
    "        let items = model.items(for: .items)\n"
    "        return Group {\n"
    "            if model.isLoading(tab: .items) && items.isEmpty {\n"
    "                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 44)\n"
    "            } else if model.hasLoaded(tab: .items) && items.isEmpty {\n"
    "                emptyState(text: \"暂无\\(V3LibraryTab.items.title(contentTitle: contentTitle))内容\").frame(maxWidth: .infinity, maxHeight: .infinity)\n"
    "            } else {\n"
    "                EmbyNativePosterCollectionView(\n"
    "                    items: items,\n"
    "                    client: client,\n"
    "                    isLoading: model.isLoading(tab: .items),\n"
    "                    hasMore: model.hasMore(tab: .items),\n"
    "                    onApproachingEnd: {\n"
    "                        guard model.hasMore(tab: .items) else { return }\n"
    "                        Task { await model.loadNextPage(tab: .items) }\n"
    "                    },\n"
    "                    onRefresh: { Task { await model.refresh(tab: .items) } },\n"
    "                    onSelect: { item in\n"
    "                        guard nativePosterSelection == nil else { return }\n"
    "                        nativePosterSelection = item\n"
    "                    }\n"
    "                )\n"
    "                .frame(maxWidth: .infinity, maxHeight: .infinity)\n"
    "            }\n"
    "        }\n"
    "        .frame(maxWidth: .infinity, maxHeight: .infinity)\n"
    "        .background(nativePosterNavigationLink)\n"
    "        .overlay(alignment: .top) {\n"
    "            if let error = model.errorMessage(for: .items) { errorText(error).padding(.top, 8) }\n"
    "        }\n"
    "    }\n\n"
    "    private var nativePosterNavigationLink: some View {\n"
    "        NavigationLink(\n"
    "            destination: Group {\n"
    "                if let item = nativePosterSelection { EmbyPosterDetailDestination(item: item, client: client) }\n"
    "                else { EmptyView() }\n"
    "            },\n"
    "            isActive: Binding(\n"
    "                get: { nativePosterSelection != nil },\n"
    "                set: { active in if !active { nativePosterSelection = nil } }\n"
    "            )\n"
    "        ) { EmptyView() }\n"
    "        .frame(width: 0, height: 0)\n"
    "        .hidden()\n"
    "    }\n\n"
)
paged_anchor = "    private func pagedPosterTab(_ tab: V3LibraryTab) -> some View {\n"
if browse.count(paged_anchor) != 1: raise SystemExit("Browse paged anchor mismatch")
browse = browse.replace(paged_anchor, native_block + paged_anchor, 1)

bare_line = "            persistSnapshot()\n"
if browse.count(bare_line) != 4: raise SystemExit(f"unexpected persistence call count={browse.count(bare_line)}")
browse = browse.replace(bare_line, "            await persistSnapshot()\n")
inline_old = "if didUpdate { loadedTabs.insert(.suggestions); persistSnapshot() }"
if browse.count(inline_old) != 1: raise SystemExit("suggestion persistence anchor mismatch")
browse = browse.replace(inline_old, "if didUpdate { loadedTabs.insert(.suggestions); await persistSnapshot() }", 1)
if browse.count("    private func persistSnapshot() {") != 1: raise SystemExit("persistSnapshot definition mismatch")
browse = browse.replace("    private func persistSnapshot() {", "    private func persistSnapshot() async {", 1)
store_call = "        V3PagePersistentCache.shared.storeLibrarySnapshot(snapshot, client: client, libraryID: library.id)"
if browse.count(store_call) != 1: raise SystemExit("Library store call mismatch")
browse = browse.replace(store_call, "        await V3PagePersistentCache.shared.storeLibrarySnapshot(snapshot, client: client, libraryID: library.id)", 1)
browse_path.write_text(browse)

shared_path = Path("Sources/UI/EmbyServerSharedV3.swift")
shared = shared_path.read_text()
poster_old = "                V3RemoteImage(url: client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: posterImageMaxWidth, tag: item.preferredPrimaryImageTag), contentMode: .fill)"
poster_new = "                V3RemoteImage(url: client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: posterImageMaxWidth, tag: item.preferredPrimaryImageTag), contentMode: .fill, publishesLoadingState: width != nil)"
if shared.count(poster_old) != 1: raise SystemExit("V3PosterCard image anchor mismatch")
shared = shared.replace(poster_old, poster_new, 1)
remote_old = (
    "struct V3RemoteImage: View {\n"
    "    let url: URL?\n"
    "    let contentMode: ContentMode\n"
    "    var body: some View { EmbyCachedRemoteImage(url: url, contentMode: contentMode, placeholderSystemImage: \"play.rectangle\", showsLoadingIndicator: false) }\n"
    "}\n"
)
remote_new = (
    "struct V3RemoteImage: View {\n"
    "    let url: URL?\n"
    "    let contentMode: ContentMode\n"
    "    let publishesLoadingState: Bool\n\n"
    "    init(url: URL?, contentMode: ContentMode, publishesLoadingState: Bool = true) {\n"
    "        self.url = url\n"
    "        self.contentMode = contentMode\n"
    "        self.publishesLoadingState = publishesLoadingState\n"
    "    }\n\n"
    "    var body: some View { EmbyCachedRemoteImage(url: url, contentMode: contentMode, placeholderSystemImage: \"play.rectangle\", showsLoadingIndicator: false, publishesLoadingState: publishesLoadingState) }\n"
    "}\n"
)
if shared.count(remote_old) != 1: raise SystemExit("V3RemoteImage block mismatch")
shared_path.write_text(shared.replace(remote_old, remote_new, 1))

Path("docs/changelog/CHANGELOG_v0_15_18_build285.md").write_text("\n".join([
    "# OnePlayer 0.15.18 / Build285",
    "",
    "- Clean integration of the target-device-accepted Library poster result onto current main; Build283 remains the real-device behavior authority.",
    "- Library `.items` uses the accepted iOS 15-compatible native `UICollectionView` 3-column path with native append insertion and device-max refresh request during motion.",
    "- Suppresses unused loading-state publication for grid-sized poster cells.",
    "- Preserves Build213 cached-first/write-through semantics while moving full Library snapshot object construction, JSON serialization and atomic write to the accepted serial utility queue.",
    "- Keeps the hidden Library detail `NavigationLink` mounted so system-owned push activation transitions false→true; no custom UIKit push or second navigation owner.",
    "- Search Build256, Home carousel, Player/MPV/PiP, UnifiedTransport, playback Cache/Session, STRM/302/115/CDN and Deployment Target are unchanged.",
    "- Deployment Target remains iOS 15.0.",
    "",
]))

Path("scripts/check_poster_grid_integration_build285.py").write_text("\n".join([
    "from pathlib import Path",
    "identity = Path('Sources/Core/AppIdentity.swift').read_text()",
    "native = Path('Sources/UI/EmbyNativePosterCollectionView.swift').read_text()",
    "browse = Path('Sources/UI/EmbyServerBrowseV3.swift').read_text()",
    "cache = Path('Sources/UI/EmbyPagePersistentCache.swift').read_text()",
    "shared = Path('Sources/UI/EmbyServerSharedV3.swift').read_text()",
    "nav = Path('Sources/UI/EmbySharedImageAndNavigation.swift').read_text()",
    "assert 'static let sourceVersion = \"0.15.18\"' in identity",
    "assert 'UICollectionViewFlowLayout()' in native",
    "assert 'collectionView.performBatchUpdates' in native and 'collectionView.insertItems(at: inserted)' in native",
    "assert 'CAFrameRateRange(minimum: 80' in native",
    "assert 'decelerationRate =' not in native and 'Timer.' not in native and 'DispatchSourceTimer' not in native",
    "assert 'case .items:\\n            nativeItemsTab' in browse",
    "assert '.background(nativePosterNavigationLink)' in browse",
    "assert 'private var nativePosterNavigationLink: some View' in browse",
    "assert 'destination: Group {' in browse and 'get: { nativePosterSelection != nil }' in browse",
    "assert 'private func persistSnapshot() async' in browse",
    "assert 'await V3PagePersistentCache.shared.storeLibrarySnapshot' in browse",
    "assert 'private let writeQueue = DispatchQueue(label: \"OnePlayer.PagePersistentCache.Write\", qos: .utility)' in cache",
    "assert 'func storeLibrarySnapshot(_ snapshot: V3LibraryPersistentSnapshot, client: EmbyAPIClient, libraryID: String) async' in cache",
    "assert 'withCheckedContinuation' in cache and 'writeQueue.async' in cache",
    "assert 'publishesLoadingState: width != nil' in shared",
    "assert 'private let publishesLoadingState: Bool' in nav and 'func setLoading' in nav",
    "assert 'struct EmbyPosterDetailDestination: View {' in nav",
    "assert 'private struct EmbyPosterDetailDestination: View {' not in nav",
    "for text in (native, browse, cache, shared, nav): assert 'targetTime / duration' not in text",
    "print('Build285 clean Poster integration checker: PASS')",
    "",
]))
