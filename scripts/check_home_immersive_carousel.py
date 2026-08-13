from pathlib import Path

v3 = Path("Sources/UI/EmbyServerRootViewV3.swift").read_text()
project = Path("project.yml").read_text()

assert "@State private var homeCarouselActive = false" in v3
assert "onCarouselActiveChanged" in v3
assert "selectedTab == .home && homeCarouselActive" in v3
assert "Rectangle().fill(.ultraThinMaterial)" in v3
assert "homeScroll(heroHeight: heroHeight)" in v3
assert ".ignoresSafeArea(.container, edges: .top)" in v3
assert "header(immersive: true)" in v3
assert "header(immersive: true)\n                                .padding(.top, geometry.safeAreaInsets.top)" not in v3
assert "private func heroCarousel(height: CGFloat)" in v3
assert ".frame(height: height)" in v3
assert ".clipShape(RoundedRectangle(cornerRadius: 18" not in v3
assert "Capsule().fill(.ultraThinMaterial)" in v3
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in project
print("Immersive home carousel checks passed")
