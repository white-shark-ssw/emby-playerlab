from pathlib import Path

root = Path(".")
p = root / "Sources/UI/EmbyServerRootViewV3.swift"
s = p.read_text()
parts = root / "scripts/home-carousel-v2"

hero = (parts / "HeroCarousel.swiftpart").read_text() + "\n" + (parts / "BackgroundFunctions.swiftpart").read_text()
start = s.index("    private func heroCarousel(height: CGFloat) -> some View {")
end = s.index("    private func sectionTitle", start)
s = s[:start] + hero + "\n" + s[end:]

card = (parts / "HeroCardTransparent.swiftpart").read_text()
start = s.index("private struct V3HeroCard: View {")
end = s.index("private struct V3LibraryBrowserView", start)
s = s[:start] + card + "\n\n" + s[end:]

helpers = (parts / "BackgroundTint.swiftpart").read_text() + "\n" + (parts / "V3HomeCarouselHelpers.swiftpart").read_text()
start = s.index("private final class V3HomeRefreshControlProbeView")
end = s.index("private struct V3PageHeader", start)
s = s[:start] + helpers + "\n" + s[end:]

needle = "carouselBackgroundStack(size: CGSize(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.bottom)).zIndex(0)"
replacement = "carouselBackgroundStack(size: CGSize(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.bottom)).overlay(V3HomeCarouselBackgroundTint(colorScheme: colorScheme)).zIndex(0)"
if s.count(needle) != 1:
    raise SystemExit("background tint insertion point mismatch")
s = s.replace(needle, replacement, 1)
p.write_text(s)

check = (parts / "check_home_immersive_carousel_v2.py").read_text()
(root / "scripts/check_home_immersive_carousel.py").write_text(check)
