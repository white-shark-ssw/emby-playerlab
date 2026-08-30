from pathlib import Path

root = Path(__file__).resolve().parents[1]

def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    assert count == 1, f"{path}: expected one match, got {count}"
    path.write_text(text.replace(old, new, 1))

identity = root / "Sources/Core/AppIdentity.swift"
text = identity.read_text()
assert text.count('0.14.94') == 2
identity.write_text(text.replace('0.14.94', '0.14.96'))

grid = root / "Sources/UI/EmbyPosterGrid.swift"
replace_once(
    grid,
    '''extension EnvironmentValues {
    var embyPosterGridCellWidth: CGFloat? {
        get { self[EmbyPosterGridCellWidthKey.self] }
        set { self[EmbyPosterGridCellWidthKey.self] = newValue }
    }
}
''',
    '''extension EnvironmentValues {
    var embyPosterGridCellWidth: CGFloat? {
        get { self[EmbyPosterGridCellWidthKey.self] }
        set { self[EmbyPosterGridCellWidthKey.self] = newValue }
    }
}

private struct EmbyPosterGridDiagnosticOwnerIDKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var embyPosterGridDiagnosticOwnerID: UUID? {
        get { self[EmbyPosterGridDiagnosticOwnerIDKey.self] }
        set { self[EmbyPosterGridDiagnosticOwnerIDKey.self] = newValue }
    }
}
'''
)
replace_once(
    grid,
    '''                content(item)
                    .environment(\\.embyPosterGridNavigationState, navigationState)
                    .environment(\\.embyPosterGridCellWidth, cellWidth)
''',
    '''                content(item)
                    .environment(\\.embyPosterGridNavigationState, navigationState)
                    .environment(\\.embyPosterGridCellWidth, cellWidth)
                    .environment(\\.embyPosterGridDiagnosticOwnerID, diagnosticOwnerID)
'''
)

shared = root / "Sources/UI/EmbyServerSharedV3.swift"
replace_once(
    shared,
    '''struct V3PosterCard: View {
    @Environment(\\.embyPosterGridCellWidth) private var gridCellWidth
''',
    '''struct V3PosterCard: View {
    @Environment(\\.embyPosterGridCellWidth) private var gridCellWidth
    @Environment(\\.embyPosterGridDiagnosticOwnerID) private var gridDiagnosticOwnerID
'''
)
replace_once(
    shared,
    '''                V3RemoteImage(url: client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: posterImageMaxWidth, tag: item.preferredPrimaryImageTag), contentMode: .fill)
                    .frame(width: resolvedWidth, height: posterHeight)
''',
    '''                V3RemoteImage(
                    url: client.imageURL(itemId: item.preferredPrimaryImageItemId, maxWidth: posterImageMaxWidth, tag: item.preferredPrimaryImageTag),
                    contentMode: .fill,
                    onImageLoaded: { _ in
                        if let ownerID = gridDiagnosticOwnerID { EmbyPosterGridCadenceDiagnostics.shared.imageDidPublish(ownerID: ownerID) }
                    }
                )
                    .frame(width: resolvedWidth, height: posterHeight)
'''
)
replace_once(
    shared,
    '''struct V3RemoteImage: View {
    let url: URL?
    let contentMode: ContentMode
    var body: some View { EmbyCachedRemoteImage(url: url, contentMode: contentMode, placeholderSystemImage: "play.rectangle", showsLoadingIndicator: false) }
}
''',
    '''struct V3RemoteImage: View {
    let url: URL?
    let contentMode: ContentMode
    let onImageLoaded: ((UIImage) -> Void)?

    init(url: URL?, contentMode: ContentMode, onImageLoaded: ((UIImage) -> Void)? = nil) {
        self.url = url
        self.contentMode = contentMode
        self.onImageLoaded = onImageLoaded
    }

    var body: some View { EmbyCachedRemoteImage(url: url, contentMode: contentMode, placeholderSystemImage: "play.rectangle", showsLoadingIndicator: false, onImageLoaded: onImageLoaded) }
}
'''
)

diag = root / "Sources/UI/EmbyPosterGridCadenceDiagnostics.swift"
replace_once(diag, 'import Foundation\n', 'import CoreFoundation\nimport Foundation\n')
replace_once(
    diag,
    '''        var lastDisplayCellAppearCount = 0
        var lastDisplayCellDisappearCount = 0
        var lastDisplayLoadAheadCount = 0
        var lastDisplayItemCountChanges = 0
        var longDisplayGapCount = 0
        var longDisplayGapWithCellChurnCount = 0
        var longDisplayGapWithLoadAheadCount = 0
        var longDisplayGapWithItemCountChangeCount = 0
        var longDisplayGapWithNoTrackedGridWorkCount = 0
        var longDisplayGapMaxCellAppearDelta = 0
        var longDisplayGapMaxCellDisappearDelta = 0
        var longDisplayGapMaxOffsetChanges = 0
''',
    '''        var imagePublishCount = 0
        var lastDisplayCellAppearCount = 0
        var lastDisplayCellDisappearCount = 0
        var lastDisplayLoadAheadCount = 0
        var lastDisplayItemCountChanges = 0
        var lastDisplayImagePublishCount = 0
        var lastDisplayRunLoopBeforeWaitingCount = 0
        var longDisplayGapCount = 0
        var longDisplayGapWithCellChurnCount = 0
        var longDisplayGapWithImagePublishCount = 0
        var longDisplayGapWithLoadAheadCount = 0
        var longDisplayGapWithItemCountChangeCount = 0
        var longDisplayGapWithNoTrackedGridWorkCount = 0
        var longDisplayGapMaxCellAppearDelta = 0
        var longDisplayGapMaxCellDisappearDelta = 0
        var longDisplayGapMaxImagePublishDelta = 0
        var longDisplayGapMaxOffsetChanges = 0
        var severe25GapCount = 0
        var severe25WithCellChurnCount = 0
        var severe25WithImagePublishCount = 0
        var severe25WithLoadAheadCount = 0
        var severe25WithItemCountChangeCount = 0
        var severe25WithNoTrackedGridWorkCount = 0
        var severe25WithoutRunLoopWaitCount = 0
        var severe25WithRunLoopWaitCount = 0
        var severe33GapCount = 0
        var severe33WithCellChurnCount = 0
        var severe33WithImagePublishCount = 0
        var severe33WithLoadAheadCount = 0
        var severe33WithItemCountChangeCount = 0
        var severe33WithNoTrackedGridWorkCount = 0
        var severe33WithoutRunLoopWaitCount = 0
        var severe33WithRunLoopWaitCount = 0
'''
)
replace_once(
    diag,
    '''    private var displayLink: CADisplayLink?
    private var lastDisplayTimestamp: CFTimeInterval?
    private var refreshRequestActive = false
''',
    '''    private var displayLink: CADisplayLink?
    private var lastDisplayTimestamp: CFTimeInterval?
    private var refreshRequestActive = false
    private var runLoopObserver: CFRunLoopObserver?
    private var runLoopBeforeWaitingCount = 0
'''
)
replace_once(
    diag,
    '''    func cellDidDisappear(ownerID: UUID) {
        precondition(Thread.isMainThread)
        guard var session = owners[ownerID]?.session else { return }
        session.cellDisappearCount += 1
        owners[ownerID]?.session = session
    }

    func loadAheadDidTrigger(ownerID: UUID) {
''',
    '''    func cellDidDisappear(ownerID: UUID) {
        precondition(Thread.isMainThread)
        guard var session = owners[ownerID]?.session else { return }
        session.cellDisappearCount += 1
        owners[ownerID]?.session = session
    }

    func imageDidPublish(ownerID: UUID) {
        precondition(Thread.isMainThread)
        guard var session = owners[ownerID]?.session else { return }
        session.imagePublishCount += 1
        owners[ownerID]?.session = session
    }

    func loadAheadDidTrigger(ownerID: UUID) {
'''
)
replace_once(
    diag,
    '''        if owner.session == nil, isUserMotion {
            owner.session = MotionSession(startedAt: now, startItemCount: owner.itemCount)
            owner.lastOffsetTimestamp = now
        }
''',
    '''        if owner.session == nil, isUserMotion {
            var session = MotionSession(startedAt: now, startItemCount: owner.itemCount)
            session.lastDisplayRunLoopBeforeWaitingCount = runLoopBeforeWaitingCount
            owner.session = session
            owner.lastOffsetTimestamp = now
        }
'''
)
replace_once(
    diag,
    '''    private func ensureDisplayLink() {
        guard displayLink == nil else { return }
        lastDisplayTimestamp = nil
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        lastDisplayTimestamp = nil
        refreshRequestActive = false
    }
''',
    '''    private func ensureDisplayLink() {
        guard displayLink == nil else { return }
        ensureRunLoopObserver()
        lastDisplayTimestamp = nil
        let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        lastDisplayTimestamp = nil
        refreshRequestActive = false
        stopRunLoopObserver()
    }

    private func ensureRunLoopObserver() {
        guard runLoopObserver == nil else { return }
        guard let observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.beforeWaiting.rawValue, true, 0, { [weak self] _, _ in self?.runLoopBeforeWaitingCount += 1 }) else { return }
        runLoopObserver = observer
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
    }

    private func stopRunLoopObserver() {
        guard let runLoopObserver else { return }
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), runLoopObserver, CFRunLoopMode.commonModes)
        self.runLoopObserver = nil
        runLoopBeforeWaitingCount = 0
    }
'''
)
old_gap = '''            if let previousDisplayTimestamp {
                let intervalMS = max(0, (link.timestamp - previousDisplayTimestamp) * 1000)
                if intervalMS > 0, intervalMS < 200 {
                    session.displayIntervalsMS.append(intervalMS)
                    if intervalMS >= 12.5 {
                        let cellAppearDelta = max(0, session.cellAppearCount - session.lastDisplayCellAppearCount)
                        let cellDisappearDelta = max(0, session.cellDisappearCount - session.lastDisplayCellDisappearCount)
                        let loadAheadDelta = max(0, session.loadAheadCount - session.lastDisplayLoadAheadCount)
                        let itemCountChangeDelta = max(0, session.itemCountChanges - session.lastDisplayItemCountChanges)
                        session.longDisplayGapCount += 1
                        if cellAppearDelta > 0 || cellDisappearDelta > 0 { session.longDisplayGapWithCellChurnCount += 1 }
                        if loadAheadDelta > 0 { session.longDisplayGapWithLoadAheadCount += 1 }
                        if itemCountChangeDelta > 0 { session.longDisplayGapWithItemCountChangeCount += 1 }
                        if cellAppearDelta == 0 && cellDisappearDelta == 0 && loadAheadDelta == 0 && itemCountChangeDelta == 0 { session.longDisplayGapWithNoTrackedGridWorkCount += 1 }
                        session.longDisplayGapMaxCellAppearDelta = max(session.longDisplayGapMaxCellAppearDelta, cellAppearDelta)
                        session.longDisplayGapMaxCellDisappearDelta = max(session.longDisplayGapMaxCellDisappearDelta, cellDisappearDelta)
                        session.longDisplayGapMaxOffsetChanges = max(session.longDisplayGapMaxOffsetChanges, session.offsetChangesSinceLastDisplay)
                    }
                }
            }
            session.lastDisplayCellAppearCount = session.cellAppearCount
            session.lastDisplayCellDisappearCount = session.cellDisappearCount
            session.lastDisplayLoadAheadCount = session.loadAheadCount
            session.lastDisplayItemCountChanges = session.itemCountChanges
            session.offsetChangesSinceLastDisplay = 0
'''
new_gap = '''            if let previousDisplayTimestamp {
                let intervalMS = max(0, (link.timestamp - previousDisplayTimestamp) * 1000)
                if intervalMS > 0, intervalMS < 200 {
                    session.displayIntervalsMS.append(intervalMS)
                    let cellAppearDelta = max(0, session.cellAppearCount - session.lastDisplayCellAppearCount)
                    let cellDisappearDelta = max(0, session.cellDisappearCount - session.lastDisplayCellDisappearCount)
                    let loadAheadDelta = max(0, session.loadAheadCount - session.lastDisplayLoadAheadCount)
                    let itemCountChangeDelta = max(0, session.itemCountChanges - session.lastDisplayItemCountChanges)
                    let imagePublishDelta = max(0, session.imagePublishCount - session.lastDisplayImagePublishCount)
                    let runLoopBeforeWaitingDelta = max(0, runLoopBeforeWaitingCount - session.lastDisplayRunLoopBeforeWaitingCount)
                    let hasCellChurn = cellAppearDelta > 0 || cellDisappearDelta > 0
                    let hasTrackedGridWork = hasCellChurn || imagePublishDelta > 0 || loadAheadDelta > 0 || itemCountChangeDelta > 0
                    if intervalMS >= 12.5 {
                        session.longDisplayGapCount += 1
                        if hasCellChurn { session.longDisplayGapWithCellChurnCount += 1 }
                        if imagePublishDelta > 0 { session.longDisplayGapWithImagePublishCount += 1 }
                        if loadAheadDelta > 0 { session.longDisplayGapWithLoadAheadCount += 1 }
                        if itemCountChangeDelta > 0 { session.longDisplayGapWithItemCountChangeCount += 1 }
                        if !hasTrackedGridWork { session.longDisplayGapWithNoTrackedGridWorkCount += 1 }
                        session.longDisplayGapMaxCellAppearDelta = max(session.longDisplayGapMaxCellAppearDelta, cellAppearDelta)
                        session.longDisplayGapMaxCellDisappearDelta = max(session.longDisplayGapMaxCellDisappearDelta, cellDisappearDelta)
                        session.longDisplayGapMaxImagePublishDelta = max(session.longDisplayGapMaxImagePublishDelta, imagePublishDelta)
                        session.longDisplayGapMaxOffsetChanges = max(session.longDisplayGapMaxOffsetChanges, session.offsetChangesSinceLastDisplay)
                    }
                    if intervalMS >= 25.0 {
                        session.severe25GapCount += 1
                        if hasCellChurn { session.severe25WithCellChurnCount += 1 }
                        if imagePublishDelta > 0 { session.severe25WithImagePublishCount += 1 }
                        if loadAheadDelta > 0 { session.severe25WithLoadAheadCount += 1 }
                        if itemCountChangeDelta > 0 { session.severe25WithItemCountChangeCount += 1 }
                        if !hasTrackedGridWork { session.severe25WithNoTrackedGridWorkCount += 1 }
                        if runLoopBeforeWaitingDelta == 0 { session.severe25WithoutRunLoopWaitCount += 1 }
                        else { session.severe25WithRunLoopWaitCount += 1 }
                    }
                    if intervalMS >= 33.3 {
                        session.severe33GapCount += 1
                        if hasCellChurn { session.severe33WithCellChurnCount += 1 }
                        if imagePublishDelta > 0 { session.severe33WithImagePublishCount += 1 }
                        if loadAheadDelta > 0 { session.severe33WithLoadAheadCount += 1 }
                        if itemCountChangeDelta > 0 { session.severe33WithItemCountChangeCount += 1 }
                        if !hasTrackedGridWork { session.severe33WithNoTrackedGridWorkCount += 1 }
                        if runLoopBeforeWaitingDelta == 0 { session.severe33WithoutRunLoopWaitCount += 1 }
                        else { session.severe33WithRunLoopWaitCount += 1 }
                    }
                }
            }
            session.lastDisplayCellAppearCount = session.cellAppearCount
            session.lastDisplayCellDisappearCount = session.cellDisappearCount
            session.lastDisplayLoadAheadCount = session.loadAheadCount
            session.lastDisplayItemCountChanges = session.itemCountChanges
            session.lastDisplayImagePublishCount = session.imagePublishCount
            session.lastDisplayRunLoopBeforeWaitingCount = runLoopBeforeWaitingCount
            session.offsetChangesSinceLastDisplay = 0
'''
replace_once(diag, old_gap, new_gap)
replace_once(
    diag,
    '''long_gap_ge12_5=\\(session.longDisplayGapCount) long_gap_cell_churn=\\(session.longDisplayGapWithCellChurnCount) long_gap_load_ahead=\\(session.longDisplayGapWithLoadAheadCount) long_gap_item_change=\\(session.longDisplayGapWithItemCountChangeCount) long_gap_untracked=\\(session.longDisplayGapWithNoTrackedGridWorkCount) long_gap_max_cell_appear=\\(session.longDisplayGapMaxCellAppearDelta) long_gap_max_cell_disappear=\\(session.longDisplayGapMaxCellDisappearDelta) long_gap_max_offset_updates=\\(session.longDisplayGapMaxOffsetChanges)''',
    '''image_publish=\\(session.imagePublishCount) long_gap_ge12_5=\\(session.longDisplayGapCount) long_gap_cell_churn=\\(session.longDisplayGapWithCellChurnCount) long_gap_image_publish=\\(session.longDisplayGapWithImagePublishCount) long_gap_load_ahead=\\(session.longDisplayGapWithLoadAheadCount) long_gap_item_change=\\(session.longDisplayGapWithItemCountChangeCount) long_gap_untracked=\\(session.longDisplayGapWithNoTrackedGridWorkCount) long_gap_max_cell_appear=\\(session.longDisplayGapMaxCellAppearDelta) long_gap_max_cell_disappear=\\(session.longDisplayGapMaxCellDisappearDelta) long_gap_max_image_publish=\\(session.longDisplayGapMaxImagePublishDelta) long_gap_max_offset_updates=\\(session.longDisplayGapMaxOffsetChanges) severe25_ge25=\\(session.severe25GapCount) severe25_cell_churn=\\(session.severe25WithCellChurnCount) severe25_image_publish=\\(session.severe25WithImagePublishCount) severe25_load_ahead=\\(session.severe25WithLoadAheadCount) severe25_item_change=\\(session.severe25WithItemCountChangeCount) severe25_untracked=\\(session.severe25WithNoTrackedGridWorkCount) severe25_no_runloop_wait=\\(session.severe25WithoutRunLoopWaitCount) severe25_with_runloop_wait=\\(session.severe25WithRunLoopWaitCount) severe33_ge33_3=\\(session.severe33GapCount) severe33_cell_churn=\\(session.severe33WithCellChurnCount) severe33_image_publish=\\(session.severe33WithImagePublishCount) severe33_load_ahead=\\(session.severe33WithLoadAheadCount) severe33_item_change=\\(session.severe33WithItemCountChangeCount) severe33_untracked=\\(session.severe33WithNoTrackedGridWorkCount) severe33_no_runloop_wait=\\(session.severe33WithoutRunLoopWaitCount) severe33_with_runloop_wait=\\(session.severe33WithRunLoopWaitCount)'''
)

checker = root / "scripts/check_poster_grid_cadence.py"
text = checker.read_text()
text = text.replace('static let sourceVersion = "0.14.94"', 'static let sourceVersion = "0.14.96"')
insert_after = '''assert 'long_gap_max_cell_appear=' in diag and 'long_gap_max_cell_disappear=' in diag and 'long_gap_max_offset_updates=' in diag
'''
assert text.count(insert_after) == 1
text = text.replace(insert_after, insert_after + '''assert 'embyPosterGridDiagnosticOwnerID' in grid
shared = (root / "Sources/UI/EmbyServerSharedV3.swift").read_text()
assert '@Environment(\\.embyPosterGridDiagnosticOwnerID)' in shared
assert 'onImageLoaded: { _ in' in shared and 'imageDidPublish(ownerID: ownerID)' in shared
assert 'image_publish=' in diag and 'long_gap_image_publish=' in diag and 'long_gap_max_image_publish=' in diag
assert 'severe25_ge25=' in diag and 'severe25_image_publish=' in diag and 'severe25_untracked=' in diag
assert 'severe33_ge33_3=' in diag and 'severe33_image_publish=' in diag and 'severe33_untracked=' in diag
assert diag.count('CFRunLoopObserverCreateWithHandler') == 1
assert 'CFRunLoopActivity.beforeWaiting.rawValue' in diag and 'CFRunLoopMode.commonModes' in diag
assert 'severe25_no_runloop_wait=' in diag and 'severe25_with_runloop_wait=' in diag
assert 'severe33_no_runloop_wait=' in diag and 'severe33_with_runloop_wait=' in diag
''')
checker.write_text(text)

changelog = root / "docs/changelog/CHANGELOG_v0_14_96_build263.md"
assert not changelog.exists()
changelog.write_text('''# OnePlayer 0.14.96 / Build263\n\n- Diagnostic-only continuation of Build261 on the exact poster-smoothness lineage.\n- Keeps the already effective shared 3×3 80→device-max refresh request unchanged.\n- Attributes severe `>=25 ms` and `>=33.3 ms` display gaps to cell lifecycle churn, grid poster image publication, load-ahead/item-count changes, or still-untracked work.\n- Adds a main-run-loop `beforeWaiting` discriminator so severe gaps can show whether the main run loop reached a wait point between display ticks.\n- Reuses the existing grid `CADisplayLink`; no timer, second display link, scroll-physics change, Grid geometry change, Search behavior change, image-cache policy change, or Player/Transport change.\n- Deployment Target remains iOS 15.0.\n''')

print('Build263 patch applied')
