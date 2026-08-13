from pathlib import Path

v3 = Path("Sources/UI/EmbyServerRootViewV3.swift").read_text()
project = Path("project.yml").read_text()

home = v3[v3.index("private struct V3EmbyHomeView"):v3.index("@MainActor\nprivate final class V3EmbyHomeViewModel")]
hero = v3[v3.index("private struct V3HeroCard"):v3.index("private struct V3LibraryBrowserView")]

assert "carouselBackgroundStack(size:" in home
assert "carouselBackgroundOpacity(for:" in home
assert "V3HomeCarouselPageOffsetObserver" in home
assert "carouselPageOffset" in home
assert "V3HomeScrollOffsetPreferenceKey" in v3
assert "AdaptiveHeroNativeScrollObserver" not in home
assert "V3HomeRefreshControlLayerBridge" not in v3
assert "homeRefreshIndicator(topInset:" in home and ".zIndex(50)" in home
assert ".refreshable { await refreshHome() }" in home
assert "preferredPrimaryImageItemId" in home
assert "imageType: item.backdropImageTags.isEmpty" not in home
assert "V3RemoteImage" not in hero
assert "Text(heroTitle)" in hero
assert "V3HomeCarouselBackgroundTint" in v3
assert "EmbyPosterDetailLink(item: item, client: client)" in home
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print("Home carousel architecture v2 checks passed")
