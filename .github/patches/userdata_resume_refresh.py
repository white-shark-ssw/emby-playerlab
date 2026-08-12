from pathlib import Path


def replace(path, old, new):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"missing expected block in {path}: {old[:100]!r}")
    p.write_text(text.replace(old, new, 1))


replace(
    "Sources/Networking/EmbyAPIClient.swift",
    '''        var request = URLRequest(url: url)\n        request.httpMethod = method\n        request.timeoutInterval = 30\n''',
    '''        var request = URLRequest(url: url)\n        request.httpMethod = method\n        request.timeoutInterval = 30\n        if method.caseInsensitiveCompare("GET") == .orderedSame {\n            request.cachePolicy = .reloadIgnoringLocalCacheData\n            request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")\n            request.setValue("no-cache", forHTTPHeaderField: "Pragma")\n        }\n'''
)

Path("Sources/Core/EmbyUserDataChange.swift").write_text('''import Foundation\n\nenum EmbyUserDataChange {\n    static let notification = Notification.Name("com.embyplayerlab.userDataDidChange")\n    static let itemIDKey = "itemID"\n}\n''')

detail = "Sources/UI/EmbyMediaDetailView.swift"
replace(
    detail,
    '''    @Published private var desiredFavorite: Bool\n    @Published private var desiredPlayed: Bool\n    private var syncedFavorite: Bool\n''',
    '''    @Published private var desiredFavorite: Bool\n    @Published private var desiredPlayed: Bool\n    @Published private var hasPlaybackPositionOverride = false\n    @Published private var playbackPositionOverrideTicks: Int64?\n    private var syncedFavorite: Bool\n'''
)
replace(
    detail,
    '''    var primaryPlayButtonShowsResume: Bool {\n        guard !displayedPlayed, let playable = primaryPlayableItem else { return false }\n        return playable.playbackProgress > 0.001\n    }\n\n    var primaryPlayButtonProgress: Double {\n        guard primaryPlayButtonShowsResume, let playable = primaryPlayableItem else { return 0 }\n        return min(1, max(0, playable.playbackProgress))\n    }\n\n    var primaryPlayButtonPositionText: String? {\n        guard primaryPlayButtonShowsResume, let ticks = primaryPlayableItem?.userData?.playbackPositionTicks, ticks > 0 else { return nil }\n        let total = max(0, Int(Double(ticks) / AppIdentity.ticksPerSecond))\n''',
    '''    var primaryPlayButtonShowsResume: Bool {\n        guard !displayedPlayed, let playable = primaryPlayableItem else { return false }\n        return effectivePlaybackProgress(for: playable) > 0.001\n    }\n\n    var primaryPlayButtonProgress: Double {\n        guard primaryPlayButtonShowsResume, let playable = primaryPlayableItem else { return 0 }\n        return min(1, max(0, effectivePlaybackProgress(for: playable)))\n    }\n\n    var primaryPlayButtonPositionText: String? {\n        guard primaryPlayButtonShowsResume, let playable = primaryPlayableItem, let ticks = effectivePlaybackPositionTicks(for: playable), ticks > 0 else { return nil }\n        let total = max(0, Int(Double(ticks) / AppIdentity.ticksPerSecond))\n'''
)
replace(
    detail,
    '''    var primaryPlayButtonTitle: String {\n        if isResolvingPlayback { return "正在准备播放…" }\n        return primaryPlayButtonShowsResume ? "继续播放" : "播放"\n    }\n''',
    '''    private func effectivePlaybackPositionTicks(for playable: LibraryItem) -> Int64? {\n        if playable.id == item.id && hasPlaybackPositionOverride { return playbackPositionOverrideTicks }\n        return playable.userData?.playbackPositionTicks\n    }\n\n    private func effectivePlaybackProgress(for playable: LibraryItem) -> Double {\n        guard let runTimeTicks = playable.runTimeTicks, runTimeTicks > 0, let position = effectivePlaybackPositionTicks(for: playable), position > 0 else { return 0 }\n        return min(1, max(0, Double(position) / Double(runTimeTicks)))\n    }\n\n    var primaryPlayButtonTitle: String {\n        if isResolvingPlayback { return "正在准备播放…" }\n        return primaryPlayButtonShowsResume ? "继续播放" : "播放"\n    }\n'''
)
replace(
    detail,
    '''    func togglePlayed() {\n        desiredPlayed.toggle()\n        DetailHaptics.selection()\n        startPlayedSyncIfNeeded()\n    }\n''',
    '''    func togglePlayed() {\n        desiredPlayed.toggle()\n        if !desiredPlayed {\n            hasPlaybackPositionOverride = true\n            playbackPositionOverrideTicks = 0\n        }\n        DetailHaptics.selection()\n        startPlayedSyncIfNeeded()\n    }\n'''
)
replace(
    detail,
    '''            do {\n                try await client.setPlayed(itemId: item.id, played: target)\n                syncedPlayed = target\n            } catch {\n''',
    '''            do {\n                let changedItemID = item.id\n                try await client.setPlayed(itemId: changedItemID, played: target)\n                syncedPlayed = target\n                if let refreshed = try? await client.libraryItem(itemId: changedItemID) { item = refreshed }\n                if !target || !desiredPlayed {\n                    hasPlaybackPositionOverride = true\n                    playbackPositionOverrideTicks = 0\n                } else {\n                    hasPlaybackPositionOverride = false\n                    playbackPositionOverrideTicks = nil\n                }\n                NotificationCenter.default.post(name: EmbyUserDataChange.notification, object: client, userInfo: [EmbyUserDataChange.itemIDKey: changedItemID])\n            } catch {\n'''
)

home = "Sources/UI/EmbyServerRootViewV3.swift"
replace(
    home,
    '''            .overlay(alignment: .bottom) { dock }\n            .onAppear { if !model.hasLoaded { Task { await model.refresh() } } }\n            .sheet(isPresented: $isMediaManagementPresented) {\n''',
    '''            .overlay(alignment: .bottom) { dock }\n            .onAppear { if !model.hasLoaded { Task { await model.refresh() } } }\n            .onReceive(NotificationCenter.default.publisher(for: EmbyUserDataChange.notification)) { notification in\n                guard let source = notification.object as? EmbyAPIClient, source === client, let itemID = notification.userInfo?[EmbyUserDataChange.itemIDKey] as? String else { return }\n                model.invalidateResumeItem(itemID)\n                Task { await model.refresh() }\n            }\n            .sheet(isPresented: $isMediaManagementPresented) {\n'''
)
replace(
    home,
    '''    func refresh() async {\n        guard !isLoading else { return }\n''',
    '''    func invalidateResumeItem(_ itemID: String) {\n        resumeItems.removeAll { $0.id == itemID || $0.seriesId == itemID }\n    }\n\n    func refresh() async {\n        guard !isLoading else { return }\n'''
)

Path("scripts/check_user_data_refresh.py").write_text(r'''from pathlib import Path

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
''')
