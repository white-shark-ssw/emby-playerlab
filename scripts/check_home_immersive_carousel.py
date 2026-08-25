from pathlib import Path

root = Path('Sources/UI/EmbyServerRootViewV3.swift').read_text()
core = Path('Sources/UI/EmbyHomeCoreV3.swift').read_text()
carousel = Path('Sources/UI/EmbyHomeCarouselStateV3.swift').read_text()
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

# v7 round 3 architecture: one carousel state drives clear Hero + persistent blurred backdrop.
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

# Manual drag starts from the first meaningful movement, locks one axis for the gesture, and remains continuous through reversal.
assert 'DragGesture(minimumDistance: 0, coordinateSpace: .local)' in carousel
assert 'guard max(abs(horizontal), abs(vertical)) >= 0.5 else { return }' in carousel
assert 'carouselTransitionState.dragAxis = abs(horizontal) >= abs(vertical) ? .horizontal : .vertical' in carousel
assert 'guard carouselTransitionState.dragAxis == .horizontal else { return }' in carousel
assert 'abs(vertical) * 1.08' not in carousel
assert 'abs(horizontal) > 4' not in carousel
assert 'func carouselBackdropBlendProgress(_ rawProgress: CGFloat) -> CGFloat { min(1, max(0, rawProgress)) }' in carousel
assert '(raw - 0.08)' not in carousel

# Preserve the established foreground slide interaction: Logo/rating/year/type/overview travel with their carousel page.
assert 'if let fromID = transitionFromID, let toID = transitionToID { return itemID == fromID || itemID == toID ? 1 : 0 }' in carousel
assert 'if itemID == fromID { return -direction * progress * width }' in carousel
assert 'if itemID == toID { return direction * (1 - progress) * width }' in carousel
assert 'func carouselForegroundOffset(for itemID: String, width: CGFloat) -> CGFloat { 0 }' not in carousel

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

# The hard material seam from “我的媒体” downward is gone; blurred Persistent Backdrop owns the page tone.
assert 'homeContentMaterial' not in home
assert '.blur(radius: 30)' in home
assert 'preferredPrimaryImageItemId' in home

# Dock geometry is invariant. Carousel may alter material only, never height/safe-area padding.
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
