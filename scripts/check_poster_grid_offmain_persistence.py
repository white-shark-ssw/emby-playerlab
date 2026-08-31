from pathlib import Path

identity = Path("Sources/Core/AppIdentity.swift").read_text()
cache = Path("Sources/UI/EmbyPagePersistentCache.swift").read_text()
browse = Path("Sources/UI/EmbyServerBrowseV3.swift").read_text()
native = Path("Sources/UI/EmbyNativePosterCollectionView.swift").read_text()
for value in ['static let sourceVersion = "0.15.16"', '?? "0.15.16"']:
    assert value in identity, f"missing Build283 identity: {value}"
for value in ['DispatchQueue(label: "OnePlayer.PagePersistentCache.Write", qos: .utility)', 'func storeLibrarySnapshot(_ snapshot: V3LibraryPersistentSnapshot, client: EmbyAPIClient, libraryID: String) async', 'await withCheckedContinuation', 'writeQueue.async', 'event=library-snapshot', 'event=store', 'main_thread=', 'try data.write(to: url, options: .atomic)']:
    assert value in cache, f"missing Build280 off-main persistence contract: {value}"
assert cache.count('main_thread=') >= 2
assert 'private func persistSnapshot() async' in browse
assert 'await V3PagePersistentCache.shared.storeLibrarySnapshot(snapshot, client: client, libraryID: library.id)' in browse
assert browse.count('await persistSnapshot()') >= 5
assert "    @ViewBuilder\n    private var nativePosterNavigationLink" not in browse
for value in [
    'private var nativePosterNavigationLink: some View',
    'destination: Group {',
    'if let item = nativePosterSelection { EmbyPosterDetailDestination(item: item, client: client) }',
    'get: { nativePosterSelection != nil }',
]:
    assert value in browse, f"missing Build283 persistent native navigation contract: {value}"
for value in ['event=display-gap', 'insert_events=', 'reconfigure_events=', 'display_interval_p95_ms=', 'event=reverse']:
    assert value in native, f"Build276 native diagnostic inheritance missing: {value}"
for forbidden in ['DispatchQueue.global', 'Task.detached', 'decelerationRate =', 'targetTime / duration', 'fileSize']:
    assert forbidden not in cache, f"forbidden Build280 behavior: {forbidden}"
print("Build283 off-main persistence + native navigation checker: PASS")
