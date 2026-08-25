from pathlib import Path

detail = Path('Sources/UI/EmbyMediaDetailView.swift').read_text()
state = Path('Sources/UI/EmbyDetailPerformanceState.swift').read_text()
project = Path('project.yml').read_text()

# High-frequency native scroll offset belongs to the Hero-only observable scope, not root @State.
assert '@State private var heroRawScrollMinY' not in detail
assert '@State private var heroScrollState = EmbyDetailHeroScrollState()' in detail
assert 'EmbyDetailHeroScrollScope(state: heroScrollState)' in detail
assert 'heroScrollState.update(value)' in detail
assert 'final class EmbyDetailHeroScrollState: ObservableObject' in state
assert '@Published private(set) var rawMinY: CGFloat = 0' in state

# Re-entered details may warm-start display metadata while the normal network load still refreshes it.
assert 'EmbyMediaDetailWarmCache.shared.snapshot' in detail
assert 'EmbyMediaDetailWarmCache.shared.store' in detail
assert 'let episodes: [LibraryItem]' in state
assert 'let seasons: [LibraryItem]' in state
assert 'let imageInfos: [EmbyImageInfo]' in state
assert 'let similarItems: [LibraryItem]' in state
assert 'let refreshed = try await client.libraryItem(itemId: item.id)' in detail
assert 'episodes = try await client.seriesEpisodes(seriesId: refreshed.id)' in detail
assert 'imageInfos = try await client.imageInfos(itemId: refreshed.id)' in detail

# Warm presentation data must never become a second playback/session/temporary-media cache.
for forbidden in ['MediaSource', 'ResolvedPlaybackSource', 'PlaySession', 'playSession', 'PlaybackInfo', 'resolvedPlayback', 'directStreamURL']:
    assert forbidden not in state

# The standard target still auto-includes Sources and remains compatible with iOS 15.
assert '- path: Sources' in project
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print('Detail page performance checks passed')
