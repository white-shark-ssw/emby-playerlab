from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, got {count}")
    return text.replace(old, new, 1)


def replace_between(text: str, start: str, end: str, replacement: str, label: str) -> str:
    start_index = text.find(start)
    if start_index < 0:
        raise SystemExit(f"{label}: start marker not found")
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise SystemExit(f"{label}: end marker not found")
    return text[:start_index] + replacement + text[end_index:]


# Shared adaptive reveal geometry. It responds to current viewport geometry and actual source-image aspect ratio,
# never to an iPhone model or hard-coded physical pixel resolution.
path = Path("Sources/UI/ImmersiveUIComponents.swift")
text = path.read_text()
helper = '''struct AdaptiveHeroRevealMetrics {
    static let initialScale: CGFloat = 1.10
    private static let minimumRevealScale: CGFloat = 0.30

    static func detailBaseHeight(width: CGFloat) -> CGFloat { min(488, max(430, width * 1.08)) }
    static func compactBaseHeight(width: CGFloat) -> CGFloat { min(252, max(206, width * 0.51)) }

    static func revealDistance(heroHeight: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        let geometryDriven = min(heroHeight * 0.16, viewportHeight * 0.085)
        return min(96, max(56, geometryDriven))
    }

    static func fullRevealScale(imageSize: CGSize?, viewportSize: CGSize) -> CGFloat {
        guard let imageSize, imageSize.width > 1, imageSize.height > 1, viewportSize.width > 1, viewportSize.height > 1 else { return 1 }
        let imageAspect = imageSize.width / imageSize.height
        let viewportAspect = viewportSize.width / viewportSize.height
        let fitFromFillScale = min(viewportAspect / imageAspect, imageAspect / viewportAspect)
        return min(1, max(minimumRevealScale, fitFromFillScale))
    }

    static func progress(upwardScroll: CGFloat, revealDistance: CGFloat) -> CGFloat {
        guard revealDistance > 0 else { return 1 }
        return min(1, max(0, upwardScroll / revealDistance))
    }

    static func scale(fullRevealScale: CGFloat, progress: CGFloat) -> CGFloat {
        initialScale + (fullRevealScale - initialScale) * eased(progress)
    }

    static func topPinOffset(heroHeight: CGFloat, scale: CGFloat) -> CGFloat { -max(0, heroHeight * (1 - scale) * 0.5) }

    private static func eased(_ value: CGFloat) -> CGFloat {
        let clamped = min(1, max(0, value))
        let remaining = 1 - clamped
        return 1 - remaining * remaining
    }
}

'''
marker = "struct DetailPressButtonStyle: ButtonStyle {\n"
if "struct AdaptiveHeroRevealMetrics" not in text:
    text = replace_once(text, marker, helper + marker, "insert adaptive reveal metrics")
path.write_text(text)


# Detail page: keep tested 0% appearance and elastic overscroll, but turn the first short upward-scroll segment
# into a real crop-release based on source aspect ratio and current viewport geometry.
path = Path("Sources/UI/EmbyMediaDetailView.swift")
text = path.read_text()
text = replace_once(
    text,
    "    @State private var heroUsesLightForeground = true\n",
    "    @State private var heroUsesLightForeground = true\n    @State private var heroSourceSize: CGSize?\n",
    "detail hero source size state",
)
text = replace_once(text, "                        hero(width: geometry.size.width)\n", "                        hero(width: geometry.size.width, viewportHeight: viewportHeight)\n", "detail hero call")

hero = '''    private func hero(width: CGFloat, viewportHeight: CGFloat) -> some View {
        let baseHeight = AdaptiveHeroRevealMetrics.detailBaseHeight(width: width)
        let contentWidth = max(0, width - 40)
        let revealDistance = AdaptiveHeroRevealMetrics.revealDistance(heroHeight: baseHeight, viewportHeight: viewportHeight)
        return GeometryReader { proxy in
            let minY = proxy.frame(in: .named("emby-detail-scroll")).minY
            let stretch = max(0, minY)
            let upwardScroll = max(0, -minY)
            let revealProgress = AdaptiveHeroRevealMetrics.progress(upwardScroll: upwardScroll, revealDistance: revealDistance)
            let visualHeight = baseHeight + stretch
            let fullRevealScale = AdaptiveHeroRevealMetrics.fullRevealScale(imageSize: heroSourceSize, viewportSize: CGSize(width: width, height: baseHeight))
            let revealScale = AdaptiveHeroRevealMetrics.scale(fullRevealScale: fullRevealScale, progress: revealProgress)
            let topPinOffset = AdaptiveHeroRevealMetrics.topPinOffset(heroHeight: baseHeight, scale: revealScale)
            let contrastScrim = heroUsesLightForeground ? Color.black.opacity(0.22) : Color.white.opacity(0.16)

            ZStack(alignment: .bottom) {
                ZStack {
                    EmbyCachedRemoteImage(url: heroImageURL, contentMode: .fill, onImageLoaded: { image in updateHeroImageMetrics(image) })
                        .frame(width: width, height: visualHeight)
                        .scaleEffect(revealScale, anchor: .center)
                        .offset(y: topPinOffset)
                }
                .frame(width: width, height: visualHeight)
                .clipped()
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0.00),
                            .init(color: .black, location: 0.66),
                            .init(color: .black.opacity(0.92), location: 0.76),
                            .init(color: .black.opacity(0.52), location: 0.90),
                            .init(color: .clear, location: 1.00)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: .clear, location: 0.48),
                        .init(color: contrastScrim.opacity(0.48), location: 0.67),
                        .init(color: contrastScrim, location: 0.82),
                        .init(color: .clear, location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 9) {
                    heroIdentity(width: contentWidth)

                    Text(heroMetadataLine)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(heroSecondaryForeground)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(width: contentWidth)

                    if !model.detailFilters.isEmpty { heroTagScroller(width: width) }

                    if let playableItem = model.primaryPlayableItem {
                        Button { Task { await model.play(playableItem) } } label: {
                            HStack(spacing: 9) {
                                if model.isResolvingPlayback { ProgressView().tint(.white) }
                                else { Image(systemName: "play.fill").font(.system(size: 15, weight: .bold)) }
                                Text(model.primaryPlayButtonTitle).font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(width: contentWidth, height: 50)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        }
                        .buttonStyle(DetailPressButtonStyle())
                        .disabled(model.isResolvingPlayback)
                    }

                    detailActionRow(width: contentWidth)
                }
                .frame(width: width)
                .padding(.bottom, 6)
            }
            .frame(width: width, height: visualHeight)
            .offset(y: stretch > 0 ? -stretch : 0)
        }
        .frame(width: width, height: baseHeight)
    }

'''
text = replace_between(text, "    private func hero(width: CGFloat) -> some View {", "    @ViewBuilder\n    private func heroIdentity", hero, "replace detail hero")

# The old local easing function is superseded by the shared geometry model.
old_easing = '''    private func easedReveal(_ value: CGFloat) -> CGFloat {
        let clamped = min(1, max(0, value))
        let remaining = 1 - clamped
        return 1 - remaining * remaining
    }

'''
if old_easing in text:
    text = text.replace(old_easing, "", 1)

old_analysis = '''    private func updateHeroImageAnalysis(_ image: UIImage) {
        let prefersLight = EmbyImageContrastAnalyzer.prefersLightForeground(for: image)
        if heroUsesLightForeground != prefersLight {
            withAnimation(.easeOut(duration: 0.18)) { heroUsesLightForeground = prefersLight }
        }
    }

'''
new_analysis = '''    private func updateHeroImageMetrics(_ image: UIImage) {
        if heroSourceSize != image.size { heroSourceSize = image.size }
        let prefersLight = EmbyImageContrastAnalyzer.prefersLightForeground(for: image)
        if heroUsesLightForeground != prefersLight {
            withAnimation(.easeOut(duration: 0.18)) { heroUsesLightForeground = prefersLight }
        }
    }

'''
text = replace_once(text, old_analysis, new_analysis, "detail image metrics")
path.write_text(text)


# Full episode picker: reuse the exact same adaptive crop-release and elastic top behavior.
path = Path("Sources/UI/EmbyEpisodePickerView.swift")
text = path.read_text()
text = replace_once(
    text,
    "    @State private var lastHapticTime: TimeInterval = 0\n",
    "    @State private var lastHapticTime: TimeInterval = 0\n    @State private var pickerHeroSourceSize: CGSize?\n",
    "picker hero source size state",
)
text = replace_once(text, "                            pickerHero(width: geometry.size.width)\n", "                            pickerHero(width: geometry.size.width, viewportHeight: viewportHeight)\n", "picker hero call")
text = replace_once(
    text,
    "                    .background(Color.clear)\n                    .ignoresSafeArea(edges: [.top, .bottom])\n",
    "                    .background(Color.clear)\n                    .coordinateSpace(name: \"emby-episode-picker-scroll\")\n                    .ignoresSafeArea(edges: [.top, .bottom])\n",
    "picker scroll coordinate space",
)

picker_hero = '''    private func pickerHero(width: CGFloat, viewportHeight: CGFloat) -> some View {
        let baseHeight = AdaptiveHeroRevealMetrics.compactBaseHeight(width: width)
        let revealDistance = AdaptiveHeroRevealMetrics.revealDistance(heroHeight: baseHeight, viewportHeight: viewportHeight)
        return GeometryReader { proxy in
            let minY = proxy.frame(in: .named("emby-episode-picker-scroll")).minY
            let stretch = max(0, minY)
            let upwardScroll = max(0, -minY)
            let revealProgress = AdaptiveHeroRevealMetrics.progress(upwardScroll: upwardScroll, revealDistance: revealDistance)
            let visualHeight = baseHeight + stretch
            let fullRevealScale = AdaptiveHeroRevealMetrics.fullRevealScale(imageSize: pickerHeroSourceSize, viewportSize: CGSize(width: width, height: baseHeight))
            let revealScale = AdaptiveHeroRevealMetrics.scale(fullRevealScale: fullRevealScale, progress: revealProgress)
            let topPinOffset = AdaptiveHeroRevealMetrics.topPinOffset(heroHeight: baseHeight, scale: revealScale)

            ZStack(alignment: .bottomLeading) {
                ZStack {
                    EmbyCachedRemoteImage(url: pickerHeroURL, contentMode: .fill, onImageLoaded: { image in
                        if pickerHeroSourceSize != image.size { pickerHeroSourceSize = image.size }
                    })
                    .frame(width: width, height: visualHeight)
                    .scaleEffect(revealScale, anchor: .center)
                    .offset(y: topPinOffset)
                }
                .frame(width: width, height: visualHeight)
                .clipped()
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0.00),
                            .init(color: .black, location: 0.64),
                            .init(color: .black.opacity(0.82), location: 0.80),
                            .init(color: .clear, location: 1.00)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.item.name).font(.headline).lineLimit(1)
                    Text(model.selectedSeasonTitle).font(.title2.weight(.bold))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
            }
            .frame(width: width, height: visualHeight)
            .offset(y: stretch > 0 ? -stretch : 0)
        }
        .frame(width: width, height: baseHeight)
    }

'''
text = replace_between(text, "    private func pickerHero(width: CGFloat) -> some View {", "    private var pickerHeroURL", picker_hero, "replace picker hero")
path.write_text(text)


# Regression guard: adaptive geometry, shared behavior, and previous navigation/elastic fixes must coexist.
regression = '''from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"::error::{message}")


metrics = Path("Sources/UI/ImmersiveUIComponents.swift").read_text()
detail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()
picker = Path("Sources/UI/EmbyEpisodePickerView.swift").read_text()
project = Path("project.yml").read_text()

require("struct AdaptiveHeroRevealMetrics" in metrics, "shared adaptive Hero reveal metrics are missing")
require("imageAspect" in metrics and "viewportAspect" in metrics and "fitFromFillScale" in metrics, "reveal endpoint must use source and viewport aspect ratios")
require("heroHeight * 0.16" in metrics and "viewportHeight * 0.085" in metrics, "reveal distance must respond to live layout geometry")
require("UIScreen.main.bounds" not in metrics and "iPhone 15" not in metrics, "adaptive Hero must not depend on a device model or physical screen resolution")
require("initialScale: CGFloat = 1.10" in metrics, "tested 0% Hero crop must remain unchanged")

require("heroSourceSize" in detail, "detail Hero must retain actual source image dimensions")
require("AdaptiveHeroRevealMetrics.fullRevealScale" in detail, "detail Hero must calculate a real crop-release endpoint")
require("AdaptiveHeroRevealMetrics.topPinOffset" in detail, "detail Hero reveal must remain attached to the top edge")
require("stretch > 0 ? -stretch : 0" in detail, "tested detail elastic overscroll behavior must remain")
require("contentMode: .fill" in detail and "contentMode: .fit, onImageLoaded:" not in detail, "detail reveal must stay continuous instead of switching content modes")

require("emby-episode-picker-scroll" in picker, "episode picker must observe its native ScrollView offset")
require("pickerHeroSourceSize" in picker, "episode picker must retain source image dimensions")
require("AdaptiveHeroRevealMetrics.fullRevealScale" in picker, "episode picker must share adaptive crop-release")
require("stretch > 0 ? -stretch : 0" in picker, "episode picker must share elastic top behavior")
require("EmbyCachedRemoteImage(url: pickerHeroURL" in picker, "episode picker Hero should use the shared cached image path")

for forbidden in ["interactivePopGestureRecognizer", "UIGestureRecognizerDelegate", "transitionCoordinator", "popViewController("]:
    require(forbidden not in metrics, f"Hero visual geometry must never own native navigation: {forbidden}")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
print("adaptive Hero reveal invariants: OK")
'''
Path("scripts/check_adaptive_hero_reveal.py").write_text(regression)

print("adaptive Hero reveal source patch prepared")
