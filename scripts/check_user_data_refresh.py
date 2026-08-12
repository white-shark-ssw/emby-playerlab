from pathlib import Path

api = Path("Sources/Networking/EmbyAPIClient.swift").read_text()
detail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()
home = Path("Sources/UI/EmbyServerRootViewV3.swift").read_text()
event = Path("Sources/Core/EmbyUserDataChange.swift").read_text()

required_api = [
    'request.cachePolicy = .reloadIgnoringLocalCacheData',
    'request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")',
]
required_detail = [
    'hasPlaybackPositionOverride = true',
    'playbackPositionOverrideTicks = 0',
    'effectivePlaybackProgress(for: playable)',
    'try? await client.libraryItem(itemId: changedItemID)',
    'EmbyUserDataChange.notification',
]
required_home = [
    'NotificationCenter.default.publisher(for: EmbyUserDataChange.notification)',
    'model.invalidateResumeItem(itemID)',
    'resumeItems.removeAll { $0.id == itemID || $0.seriesId == itemID }',
]
for needle in required_api:
    assert needle in api, needle
for needle in required_detail:
    assert needle in detail, needle
for needle in required_home:
    assert needle in home, needle
assert 'static let itemIDKey = "itemID"' in event
assert 'let baseOpacity = model.primaryPlayButtonShowsResume ? 0.56 : 0.82' in detail
assert '.fill(Color.white.opacity(0.42))' in detail
print("user-data refresh invariants: OK")
