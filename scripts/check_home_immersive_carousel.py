from pathlib import Path

v3 = Path("Sources/UI/EmbyServerRootViewV3.swift").read_text()
project = Path("project.yml").read_text()

assert "@State private var homeCarouselActive = false" in v3
assert "onCarouselActiveChanged" in v3
assert "selectedTab == .home && homeCarouselActive" in v3
assert "Rectangle().fill(.ultraThinMaterial)" in v3
assert "homeScroll(heroHeight: heroHeight, immersive: true)" in v3
assert ".ignoresSafeArea(.container, edges: .top)" in v3
assert "header(immersive: true)" in v3
assert "header(immersive: true)\n                                .padding(.top, geometry.safeAreaInsets.top)" not in v3
assert "private func homePersistentBackdrop(item: LibraryItem)" in v3
assert "AdaptiveHeroNativeScrollObserver" in v3
assert "let resistanceSpan: CGFloat = 176" in v3
assert ".allowsHitTesting(upwardScroll < 8)" in v3
assert "V3HomeRefreshControlLayerBridge" in v3 and "bringSubviewToFront(refreshControl)" in v3
assert 'item.preferredPrimaryImageItemId, maxWidth: 1400' in v3
hero = v3[v3.index('private struct V3HeroCard'):v3.index('private struct V3LibraryBrowserView')]
assert 'imageType: item.backdropImageTags.isEmpty ? "Primary" : "Backdrop"' not in hero
assert '.clipShape(RoundedRectangle(cornerRadius: 18' not in v3
assert "Capsule().fill(.ultraThinMaterial)" in v3
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print("Immersive home carousel checks passed")
