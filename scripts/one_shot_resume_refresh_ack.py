from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, got {count}")
    return text.replace(old, new, 1)


core = Path("Sources/Core/EmbyUserDataChange.swift")
text = core.read_text()
if "playbackStoppedReason" not in text:
    text = replace_once(
        text,
        '''enum EmbyUserDataChange {
    static let notification = Notification.Name("com.embyplayerlab.userDataDidChange")
    static let itemIDKey = "itemID"
}
''',
        '''enum EmbyUserDataChange {
    static let notification = Notification.Name("com.embyplayerlab.userDataDidChange")
    static let itemIDKey = "itemID"
    static let reasonKey = "reason"
    static let manualPlayedReason = "manualPlayed"
    static let playbackStoppedReason = "playbackStopped"
}
''',
        "core notification metadata",
    )
    core.write_text(text)

api = Path("Sources/Networking/EmbyAPIClient.swift")
text = api.read_text()
if "@discardableResult func reportStopped" not in text:
    text = replace_once(
        text,
        '''    func reportStart(source: ResolvedPlaybackSource, position: Double, paused: Bool) async { await report(path: "Sessions/Playing", eventName: nil, source: source, position: position, paused: paused) }
    func reportProgress(source: ResolvedPlaybackSource, position: Double, paused: Bool, eventName: String? = nil) async { await report(path: "Sessions/Playing/Progress", eventName: eventName, source: source, position: position, paused: paused) }
    func reportStopped(source: ResolvedPlaybackSource, position: Double) async { await report(path: "Sessions/Playing/Stopped", eventName: nil, source: source, position: position, paused: true) }
''',
        '''    func reportStart(source: ResolvedPlaybackSource, position: Double, paused: Bool) async { _ = await report(path: "Sessions/Playing", eventName: nil, source: source, position: position, paused: paused) }
    func reportProgress(source: ResolvedPlaybackSource, position: Double, paused: Bool, eventName: String? = nil) async { _ = await report(path: "Sessions/Playing/Progress", eventName: eventName, source: source, position: position, paused: paused) }
    @discardableResult func reportStopped(source: ResolvedPlaybackSource, position: Double) async -> Bool { await report(path: "Sessions/Playing/Stopped", eventName: nil, source: source, position: position, paused: true) }
''',
        "api report signatures",
    )
if "paused: Bool) async -> Bool" not in text:
    text = replace_once(
        text,
        '''    private func report(path: String, eventName: String?, source: ResolvedPlaybackSource, position: Double, paused: Bool) async {
''',
        '''    private func report(path: String, eventName: String?, source: ResolvedPlaybackSource, position: Double, paused: Bool) async -> Bool {
''',
        "api report return type",
    )
report_start = text.index("    private func report(path: String")
report_end = text.index("    private func send<Response", report_start)
report_block = text[report_start:report_end]
if "return true" not in report_block:
    report_block = replace_once(
        report_block,
        '''        do { let _: EmptyResponse = try await send(path: path, method: "POST", body: body) }
        catch { DiagnosticsLogger.shared.log("Emby", "Report \\(path) failed: \\(error.localizedDescription)") }
''',
        '''        do {
            let _: EmptyResponse = try await send(path: path, method: "POST", body: body)
            return true
        } catch {
            DiagnosticsLogger.shared.log("Emby", "Report \\(path) failed: \\(error.localizedDescription)")
            return false
        }
''',
        "api report body",
    )
    text = text[:report_start] + report_block + text[report_end:]
api.write_text(text)

player = Path("Sources/Player/PlayerController.swift")
text = player.read_text()
if "let stoppedSource = source" not in text[: text.index("    func togglePlayPause")]:
    text = replace_once(
        text,
        '''        Task {
            await client.reportStopped(source: source, position: position)
        }
''',
        '''        let stoppedSource = source
        let stoppedClient = client
        Task {
            let succeeded = await stoppedClient.reportStopped(source: stoppedSource, position: position)
            guard succeeded else { return }
            await MainActor.run {
                NotificationCenter.default.post(
                    name: EmbyUserDataChange.notification,
                    object: stoppedClient,
                    userInfo: [
                        EmbyUserDataChange.itemIDKey: stoppedSource.itemId,
                        EmbyUserDataChange.reasonKey: EmbyUserDataChange.playbackStoppedReason,
                    ]
                )
            }
        }
''',
        "player stop acknowledgement",
    )
if "let stoppedPosition = snapshot.position" not in text:
    text = replace_once(
        text,
        '''            Task { await client.reportStopped(source: source, position: snapshot.position) }
            return
''',
        '''            let stoppedSource = source
            let stoppedClient = client
            let stoppedPosition = snapshot.position
            Task {
                let succeeded = await stoppedClient.reportStopped(source: stoppedSource, position: stoppedPosition)
                guard succeeded else { return }
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: EmbyUserDataChange.notification,
                        object: stoppedClient,
                        userInfo: [
                            EmbyUserDataChange.itemIDKey: stoppedSource.itemId,
                            EmbyUserDataChange.reasonKey: EmbyUserDataChange.playbackStoppedReason,
                        ]
                    )
                }
            }
            return
''',
        "player natural end acknowledgement",
    )
player.write_text(text)

detail = Path("Sources/UI/EmbyMediaDetailView.swift")
text = detail.read_text()
if "refreshPlaybackUserData(itemID: itemID)" not in text:
    text = replace_once(
        text,
        '''        .task { await model.load() }
''',
        '''        .task { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: EmbyUserDataChange.notification)) { notification in
            guard let source = notification.object as? EmbyAPIClient, source === client,
                  notification.userInfo?[EmbyUserDataChange.reasonKey] as? String == EmbyUserDataChange.playbackStoppedReason,
                  let itemID = notification.userInfo?[EmbyUserDataChange.itemIDKey] as? String else { return }
            Task { await model.refreshPlaybackUserData(itemID: itemID) }
        }
''',
        "detail playback acknowledgement receiver",
    )
if "EmbyUserDataChange.manualPlayedReason" not in text:
    text = replace_once(
        text,
        '''                NotificationCenter.default.post(name: EmbyUserDataChange.notification, object: client, userInfo: [EmbyUserDataChange.itemIDKey: changedItemID])
''',
        '''                NotificationCenter.default.post(
                    name: EmbyUserDataChange.notification,
                    object: client,
                    userInfo: [
                        EmbyUserDataChange.itemIDKey: changedItemID,
                        EmbyUserDataChange.reasonKey: EmbyUserDataChange.manualPlayedReason,
                    ]
                )
''',
        "detail manual played reason",
    )
if "func refreshPlaybackUserData(itemID: String)" not in text:
    text = replace_once(
        text,
        '''    func play(_ mediaItem: LibraryItem) async {
''',
        '''    func refreshPlaybackUserData(itemID: String) async {
        do {
            let refreshed = try await client.libraryItem(itemId: itemID)
            if item.id == itemID {
                item = refreshed
                hasPlaybackPositionOverride = false
                playbackPositionOverrideTicks = nil
                syncedPlayed = refreshed.isPlayed
                desiredPlayed = refreshed.isPlayed
            } else if let index = episodes.firstIndex(where: { $0.id == itemID }) {
                episodes[index] = refreshed
            }
            DiagnosticsLogger.shared.log("EmbyDetail", "playback userdata refreshed item=\\(itemID) positionTicks=\\(refreshed.userData?.playbackPositionTicks ?? 0)")
        } catch {
            if !isEmbyRequestCancellation(error) { DiagnosticsLogger.shared.log("EmbyDetail", "playback userdata refresh failed item=\\(itemID): \\(error.localizedDescription)") }
        }
    }

    func play(_ mediaItem: LibraryItem) async {
''',
        "detail playback userdata refresh",
    )
detail.write_text(text)

home = Path("Sources/UI/EmbyServerRootViewV3.swift")
text = home.read_text()
text = text.replace('.refreshable { await model.refresh() }', '.refreshable { await model.refresh(userInitiated: true) }', 1)
text = text.replace('.onChange(of: refreshToken) { _ in Task { await model.refresh() } }', '.onChange(of: refreshToken) { _ in Task { await model.refresh(userInitiated: true) } }', 1)
text = text.replace('Button { Task { await model.refresh() } } label: { Label("刷新首页", systemImage: "arrow.clockwise") }', 'Button { Task { await model.refresh(userInitiated: true) } } label: { Label("刷新首页", systemImage: "arrow.clockwise") }', 1)
if "else { await model.refreshResumeIfNeeded() }" not in text:
    text = replace_once(
        text,
        '''            .onAppear { if !model.hasLoaded { Task { await model.refresh() } } }
''',
        '''            .onAppear {
                Task {
                    if !model.hasLoaded { await model.refresh() }
                    else { await model.refreshResumeIfNeeded() }
                }
            }
''',
        "home onAppear dirty refresh",
    )
if "model.markResumeDirty(itemID)" not in text:
    text = replace_once(
        text,
        '''                model.invalidateResumeItem(itemID)
                Task { await model.refresh() }
''',
        '''                model.markResumeDirty(itemID)
''',
        "home notification behavior",
    )
model_marker = "private final class V3EmbyHomeViewModel: ObservableObject {"
model_index = text.index(model_marker)
head = text[:model_index]
tail = text[model_index:]
if "private var resumeDirty = false" not in tail:
    tail = replace_once(
        tail,
        '''    private(set) var hasLoaded = false
''',
        '''    private(set) var hasLoaded = false
    private var resumeDirty = false
    private var dirtyResumeItemIDs = Set<String>()
''',
        "home dirty state",
    )
if "func markResumeDirty(_ itemID: String)" not in tail:
    tail = replace_once(
        tail,
        '''    func invalidateResumeItem(_ itemID: String) {
        resumeItems.removeAll { $0.id == itemID || $0.seriesId == itemID }
    }

    func refresh() async {
        guard !isLoading else { return }
''',
        '''    func markResumeDirty(_ itemID: String) {
        resumeDirty = true
        dirtyResumeItemIDs.insert(itemID)
        DiagnosticsLogger.shared.log("HomeRefresh", "resume dirty item=\\(itemID)")
    }

    func refreshResumeIfNeeded() async {
        guard resumeDirty else { return }
        await refresh(userInitiated: true)
    }

    func refresh(userInitiated: Bool = false) async {
        if isLoading {
            guard userInitiated else { return }
            DiagnosticsLogger.shared.log("HomeRefresh", "user refresh waiting for active refresh")
            while isLoading { try? await Task.sleep(nanoseconds: 50_000_000) }
        }
        if userInitiated {
            try? await Task.sleep(nanoseconds: 250_000_000)
            await refreshResumeOnly()
        }
        guard !isLoading else { return }
''',
        "home refresh serialization",
    )
if "private func refreshResumeOnly() async" not in tail:
    tail = replace_once(
        tail,
        '''    private static func browseItemTypes(for library: LibraryItem) -> [String] {
''',
        '''    private func refreshResumeOnly() async {
        do {
            let resume = try await client.resumeItems(limit: 18)
            resumeItems = uniqueItems(resume).filter { ["movie", "episode"].contains($0.type?.lowercased() ?? "") }
            DiagnosticsLogger.shared.log("HomeRefresh", "resume refreshed count=\\(resumeItems.count) dirty=\\(resumeDirty) ids=\\(dirtyResumeItemIDs.sorted().joined(separator: ","))")
            resumeDirty = false
            dirtyResumeItemIDs.removeAll()
        } catch {
            if !isEmbyRequestCancellation(error) { errorMessage = error.localizedDescription }
        }
    }

    private static func browseItemTypes(for library: LibraryItem) -> [String] {
''',
        "home resume-only refresh",
    )
# Clear dirty markers when the full refresh succeeds.
full_marker = '''            resumeItems = uniqueItems(resume).filter { ["movie", "episode"].contains($0.type?.lowercased() ?? "") }
'''
if "resumeDirty = false" not in tail[tail.index("func refresh(userInitiated"):tail.index("private func refreshResumeOnly")]:
    tail = replace_once(
        tail,
        full_marker,
        full_marker + '''            resumeDirty = false
            dirtyResumeItemIDs.removeAll()
''',
        "home full resume assignment",
    )
text = head + tail
home.write_text(text)

for path in [
    Path(".github/workflows/one-shot-resume-refresh-ack.yml"),
    Path(".github/workflows/one-shot-resume-refresh-ack-v2.yml"),
    Path("scripts/one_shot_resume_refresh_ack.py"),
]:
    if path.exists():
        path.unlink()
