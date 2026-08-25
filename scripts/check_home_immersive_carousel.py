from pathlib import Path

root = Path('Sources/UI/EmbyServerRootViewV3.swift').read_text()
core = Path('Sources/UI/EmbyHomeCoreV3.swift').read_text()
carousel = Path('Sources/UI/EmbyHomeCarouselStateV3.swift').read_text()
native = Path('Sources/UI/EmbyHomeCarouselNativeDragV3.swift').read_text()
home_files = [
    'Sources/UI/EmbyHomeCoreV3.swift',
    'Sources/UI/EmbyHomeHeroV3.swift',
    'Sources/UI/EmbyHomeCarouselStateV3.swift',
    'Sources/UI/EmbyHomeRowsV3.swift',
    'Sources/UI/EmbyHomeModelV3.swift',
    'Sources/UI/EmbyServerSharedV3.swift',
]
home = '\n'.join(Path(path).read_text() for path in home_files)
hero = Path('Sources/UI/EmbyHomeHeroV3.swift').read_text()
project = Path('project.yml').read_text()

# One carousel state drives clear Hero + persistent blurred backdrop.
assert 'currentCarouselItemID' in home
assert 'transitionFromID' in home and 'transitionToID' in home and 'transitionProgress' in home
assert 'carouselOpacity(for:' in home
assert 'persistentCarouselBackdrop(size:' in home
assert 'immersiveCarouselHero(width:' in home
assert 'PageTabViewStyle' not in home
assert 'carouselPageOffset' not in home
assert 'V3HomeCarouselPageOffsetObserver' not in home

# High-frequency manual drag state is isolated from the root home tree while remaining a single owner.
assert '@State var transitionProgress' not in core
assert '@State var carouselTapSuppressedUntil' not in core
assert '@State var carouselTransitionState = V3HomeCarouselTransitionState()' in core
assert 'V3HomeCarouselTransitionScope(state: carouselTransitionState)' in core
assert 'final class V3HomeCarouselTransitionState: ObservableObject' in carousel
assert 'var dragAxis: V3HomeCarouselDragAxis?' in carousel
assert 'var tapSuppressedUntil = Date.distantPast' in carousel

# Build190 movement ownership: native raw/coalesced samples alone drive progress; SwiftUI only owns release prediction/settle.
assert 'event.coalescedTouches(for: touch) ?? [touch]' in native
assert 'guard max(abs(horizontal), abs(vertical)) >= 0.5 else { return nil }' in native
assert 'carouselTransitionState.dragAxis = abs(horizontal) >= abs(vertical) ? .horizontal : .vertical' in native
assert 'guard carouselTransitionState.dragAxis == .horizontal else { return carouselTransitionState.dragAxis }' in native
assert 'transitionProgress = min(1, max(0, abs(horizontal) / max(1, width)))' in native
assert 'if axis == .horizontal { state = .began }' not in native
assert 'state = .changed' not in native
assert 'override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }' in native
assert 'override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }' in native
assert 'override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }' in native
assert 'DragGesture(minimumDistance: 0, coordinateSpace: .local)' in carousel
assert '.onChanged {' not in carousel[carousel.index('func carouselDragGesture'):carousel.index('func suppressCarouselTap')]
assert 'value.predictedEndTranslation.width' in carousel
assert 'transitionProgress >= 0.28 || predicted >= width * 0.48' in carousel
assert 'abs(vertical) * 1.08' not in native
assert 'abs(horizontal) > 4' not in native
assert 'func carouselBackdropBlendProgress(_ rawProgress: CGFloat) -> CGFloat { min(1, max(0, rawProgress)) }' in carousel
assert '(raw - 0.08)' not in carousel

# Preserve the established foreground slide interaction: Logo/rating/year/type/overview travel with their carousel page.
assert 'if let fromID = transitionFromID, let toID = transitionToID { return itemID == fromID || itemID == toID ? 1 : 0 }' in carousel
assert 'if itemID == fromID { return -direction * progress * width }' in carousel
assert 'if itemID == toID { return direction * (1 - progress) * width }' in carousel
assert 'func carouselForegroundOffset(for itemID: String, width: CGFloat) -> CGFloat { 0 }' not in carousel

# Drag diagnostics remain passive and exported through the existing playback-log flow.
assert 'carouselTransitionState.recordDragSample(translation)' in native
assert 'carouselTransitionState.recordDragAxisLock(translation)' in native
assert 'carouselTransitionState.recordDragTransitionStart(translation)' in native
assert 'carouselTransitionState.finishDragDiagnostics(axis: dragAxis, endTranslation: value.translation)' in carousel
assert 'HomeCarouselDragTiming' in carousel
assert 'avgHz=' in carousel and 'maxGapMs=' in carousel and 'first=' in carousel and 'lock=' in carousel and 'transition=' in carousel
assert carousel.count('DiagnosticsLogger.shared.playback("HomeCarouselDragTiming"') == 1
assert 'DiagnosticsLogger.shared.log("HomeCarouselDragTiming"' not in carousel

# Vertical Hero physics reuse the detail page's proven metric functions, but Home owns its observer.
assert 'AdaptiveHeroRevealMetrics.detailCropResponseFactor' in home
assert 'let backdropPinOffset = min(upwardScroll, cropPhaseDistance)' in home
assert 'AdaptiveHeroRevealMetrics.clearImageBottom' in home
assert 'AdaptiveHeroNativeScrollObserver' not in home
assert 'V3HomeNativeScrollObserver' in home

# Refresh is native and independent from carousel/hero progress.
assert 'UIRefreshControl' in home
assert '.refreshable { await refreshHome() }' not in home
assert 'homeRefreshIndicator' not in home
assert 'V3HomeScrollOffsetPreferenceKey' not in home

# Persistent backdrop and high-refresh product contracts remain intact.
assert 'homeContentMaterial' not in home
assert '.blur(radius: 30)' in home
assert 'preferredPrimaryImageItemId' in home

# Dock geometry is invariant.
assert 'serverTabBar(bottomInset:' not in root
assert '46 + bottomInset' not in root
assert '.frame(height: 46)' not in root
assert 'ImmersiveUIMetrics.serverDockHeight' in root
assert 'Color.clear.frame(height: bottomInset)' not in root
assert '.offset(y: 8)' in root

# Existing poster routing and deployment target remain intact.
assert 'EmbyPosterDetailLink(item: item, client: client)' in home
assert 'Text(carouselHeroTitle(item))' in hero
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print('Home carousel architecture v3 checks passed')
