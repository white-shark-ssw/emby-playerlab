from pathlib import Path

v3 = Path("Sources/UI/EmbyServerRootViewV3.swift").read_text()
project = Path("project.yml").read_text()

home = v3[v3.index("private struct V3EmbyHomeView"):v3.index("@MainActor\nprivate final class V3EmbyHomeViewModel")]
hero = v3[v3.index("private struct V3HeroCard"):v3.index("private struct V3LibraryBrowserView")]
root = v3[v3.index("struct EmbyServerRootViewV3"):v3.index("private enum V3ServerTab")]

# v7 round 3 architecture: one carousel state drives clear Hero + persistent blurred backdrop.
assert "currentCarouselItemID" in home
assert "transitionFromID" in home and "transitionToID" in home and "transitionProgress" in home
assert "carouselOpacity(for:" in home
assert "persistentCarouselBackdrop(size:" in home
assert "immersiveCarouselHero(width:" in home
assert "PageTabViewStyle" not in home
assert "carouselPageOffset" not in home
assert "V3HomeCarouselPageOffsetObserver" not in v3

# Vertical Hero physics reuse the detail page's proven metric functions, but Home owns its observer.
assert "AdaptiveHeroRevealMetrics.detailCropResponseFactor" in home
assert "AdaptiveHeroRevealMetrics.backdropPinOffset" in home
assert "AdaptiveHeroRevealMetrics.clearImageBottom" in home
assert "AdaptiveHeroNativeScrollObserver" not in home
assert "V3HomeNativeScrollObserver" in home

# Refresh is native and independent from carousel/hero progress.
assert "UIRefreshControl" in v3
assert ".refreshable { await refreshHome() }" not in home
assert "homeRefreshIndicator" not in home
assert "V3HomeScrollOffsetPreferenceKey" not in v3

# The hard material seam from '我的媒体' downward is gone; blurred Persistent Backdrop owns the page tone.
assert "homeContentMaterial" not in home
assert ".blur(radius: 30)" in home
assert "preferredPrimaryImageItemId" in home
assert "imageType: item.backdropImageTags.isEmpty" not in home

# Dock geometry is invariant. Carousel may alter material only, never height/safe-area padding.
assert "serverTabBar(bottomInset:" not in root
assert "46 + bottomInset" not in root
assert ".frame(height: 46)" not in root
assert "ImmersiveUIMetrics.serverDockHeight" in root
assert "Color.clear.frame(height: bottomInset)" not in root
assert ".offset(y: 7)" in root

# Existing poster routing and deployment target remain intact.
assert "EmbyPosterDetailLink(item: item, client: client)" in home
assert "V3RemoteImage" not in hero
assert "Text(heroTitle)" in hero
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print("Home carousel architecture v3 checks passed")
