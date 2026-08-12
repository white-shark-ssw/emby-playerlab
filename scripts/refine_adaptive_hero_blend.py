from pathlib import Path


def replace_between(text: str, start: str, end: str, replacement: str, label: str) -> str:
    start_index = text.find(start)
    if start_index < 0:
        raise SystemExit(f"{label}: start marker missing")
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise SystemExit(f"{label}: end marker missing")
    return text[:start_index] + replacement + text[end_index:]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count < 1:
        raise SystemExit(f"{label}: no match")
    return text.replace(old, new, 1)


metrics_path = Path("Sources/UI/ImmersiveUIComponents.swift")
metrics = metrics_path.read_text()
metrics_block = '''struct AdaptiveHeroRevealMetrics {
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
        guard imageAspect > viewportAspect else { return 1 }
        return min(1, max(minimumRevealScale, viewportAspect / imageAspect))
    }

    static func progress(upwardScroll: CGFloat, revealDistance: CGFloat) -> CGFloat {
        guard revealDistance > 0 else { return 1 }
        return min(1, max(0, upwardScroll / revealDistance))
    }

    static func scale(fullRevealScale: CGFloat, progress: CGFloat) -> CGFloat {
        initialScale + (fullRevealScale - initialScale) * eased(progress)
    }

    static func topPinOffset(imageSize: CGSize?, viewportSize: CGSize, scale: CGFloat) -> CGFloat {
        guard let coverHeight = coverHeight(imageSize: imageSize, viewportSize: viewportSize) else { return -max(0, viewportSize.height * (1 - scale) * 0.5) }
        let coverTop = (viewportSize.height - coverHeight) * 0.5
        let scaledTop = viewportSize.height * 0.5 + scale * (coverTop - viewportSize.height * 0.5)
        return -max(0, scaledTop)
    }

    static func clearImageBottom(imageSize: CGSize?, viewportSize: CGSize, scale: CGFloat) -> CGFloat {
        guard let coverHeight = coverHeight(imageSize: imageSize, viewportSize: viewportSize), viewportSize.height > 1 else { return 1 }
        let offset = topPinOffset(imageSize: imageSize, viewportSize: viewportSize, scale: scale)
        let coverBottom = (viewportSize.height + coverHeight) * 0.5
        let scaledBottom = viewportSize.height * 0.5 + scale * (coverBottom - viewportSize.height * 0.5) + offset
        return min(1, max(0.05, scaledBottom / viewportSize.height))
    }

    private static func coverHeight(imageSize: CGSize?, viewportSize: CGSize) -> CGFloat? {
        guard let imageSize, imageSize.width > 1, imageSize.height > 1, viewportSize.width > 1, viewportSize.height > 1 else { return nil }
        let imageAspect = imageSize.width / imageSize.height
        let viewportAspect = viewportSize.width / viewportSize.height
        return imageAspect >= viewportAspect ? viewportSize.height : viewportSize.width / imageAspect
    }

    private static func eased(_ value: CGFloat) -> CGFloat {
        let clamped = min(1, max(0, value))
        let remaining = 1 - clamped
        return 1 - remaining * remaining
    }
}

'''
metrics = replace_between(metrics, "struct AdaptiveHeroRevealMetrics {", "struct DetailPressButtonStyle: ButtonStyle {", metrics_block, "metrics")
metrics_path.write_text(metrics)


detail_path = Path("Sources/UI/EmbyMediaDetailView.swift")
detail = detail_path.read_text()
detail_metrics = '''            let heroViewport = CGSize(width: width, height: baseHeight)
            let fullRevealScale = AdaptiveHeroRevealMetrics.fullRevealScale(imageSize: heroSourceSize, viewportSize: heroViewport)
            let revealScale = AdaptiveHeroRevealMetrics.scale(fullRevealScale: fullRevealScale, progress: revealProgress)
            let topPinOffset = AdaptiveHeroRevealMetrics.topPinOffset(imageSize: heroSourceSize, viewportSize: heroViewport, scale: revealScale)
            let clearImageBottom = AdaptiveHeroRevealMetrics.clearImageBottom(imageSize: heroSourceSize, viewportSize: heroViewport, scale: revealScale)
            let maskFadeSpan = min(0.34, clearImageBottom * 0.46)
            let maskStart = max(0.10, clearImageBottom - maskFadeSpan)
            let maskFirstMid = maskStart + (clearImageBottom - maskStart) * 0.29
            let maskSecondMid = maskStart + (clearImageBottom - maskStart) * 0.71
            let contrastScrim = heroUsesLightForeground ? Color.black.opacity(0.22) : Color.white.opacity(0.16)

'''
detail = replace_between(detail, "            let fullRevealScale = AdaptiveHeroRevealMetrics.fullRevealScale(imageSize: heroSourceSize", "            ZStack(alignment: .bottom) {", detail_metrics, "detail metrics")
detail = replace_once(detail, ".init(color: .black, location: 0.66),", ".init(color: .black, location: maskStart),", "detail mask start")
detail = replace_once(detail, ".init(color: .black.opacity(0.92), location: 0.76),", ".init(color: .black.opacity(0.92), location: maskFirstMid),", "detail mask mid1")
detail = replace_once(detail, ".init(color: .black.opacity(0.52), location: 0.90),", ".init(color: .black.opacity(0.52), location: maskSecondMid),", "detail mask mid2")
detail = replace_once(detail, ".init(color: .clear, location: 1.00)\n                        ],", ".init(color: .clear, location: clearImageBottom)\n                        ],", "detail mask end")
detail_path.write_text(detail)


picker_path = Path("Sources/UI/EmbyEpisodePickerView.swift")
picker = picker_path.read_text()
picker_metrics = '''            let heroViewport = CGSize(width: width, height: baseHeight)
            let fullRevealScale = AdaptiveHeroRevealMetrics.fullRevealScale(imageSize: pickerHeroSourceSize, viewportSize: heroViewport)
            let revealScale = AdaptiveHeroRevealMetrics.scale(fullRevealScale: fullRevealScale, progress: revealProgress)
            let topPinOffset = AdaptiveHeroRevealMetrics.topPinOffset(imageSize: pickerHeroSourceSize, viewportSize: heroViewport, scale: revealScale)
            let clearImageBottom = AdaptiveHeroRevealMetrics.clearImageBottom(imageSize: pickerHeroSourceSize, viewportSize: heroViewport, scale: revealScale)
            let maskFadeSpan = min(0.67, clearImageBottom * 0.67)
            let maskStart = max(0.08, clearImageBottom - maskFadeSpan)
            let maskMid = maskStart + (clearImageBottom - maskStart) * 0.50

'''
picker = replace_between(picker, "            let fullRevealScale = AdaptiveHeroRevealMetrics.fullRevealScale(imageSize: pickerHeroSourceSize", "            ZStack(alignment: .bottomLeading) {", picker_metrics, "picker metrics")
picker = replace_once(picker, ".init(color: .black, location: 0.64),", ".init(color: .black, location: maskStart),", "picker mask start")
picker = replace_once(picker, ".init(color: .black.opacity(0.82), location: 0.80),", ".init(color: .black.opacity(0.80), location: maskMid),", "picker mask mid")
picker = replace_once(picker, ".init(color: .clear, location: 1.00)\n                        ],", ".init(color: .clear, location: clearImageBottom)\n                        ],", "picker mask end")
picker_path.write_text(picker)


Path("scripts/check_adaptive_hero_reveal.py").write_text('''from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"::error::{message}")


metrics = Path("Sources/UI/ImmersiveUIComponents.swift").read_text()
detail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()
picker = Path("Sources/UI/EmbyEpisodePickerView.swift").read_text()
project = Path("project.yml").read_text()

require("struct AdaptiveHeroRevealMetrics" in metrics, "shared adaptive Hero reveal metrics are missing")
require("imageAspect" in metrics and "viewportAspect" in metrics and "viewportAspect / imageAspect" in metrics, "reveal endpoint must use source and viewport aspect ratios")
require("heroHeight * 0.16" in metrics and "viewportHeight * 0.085" in metrics, "reveal distance must respond to live layout geometry")
require("UIScreen.main.bounds" not in metrics and "iPhone 15" not in metrics, "adaptive Hero must not depend on a device model or physical screen resolution")
require("initialScale: CGFloat = 1.10" in metrics, "tested 0% Hero crop must remain unchanged")
require("guard imageAspect > viewportAspect else { return 1 }" in metrics, "portrait/narrow sources must not shrink into side gutters")

require("heroSourceSize" in detail, "detail Hero must retain actual source image dimensions")
require("AdaptiveHeroRevealMetrics.fullRevealScale" in detail, "detail Hero must calculate a real crop-release endpoint")
require("AdaptiveHeroRevealMetrics.topPinOffset" in detail and "AdaptiveHeroRevealMetrics.clearImageBottom" in detail, "detail Hero reveal and fade must follow actual clear-image geometry")
require("location: clearImageBottom" in detail, "detail clear image must fade before its real bottom edge")
require("stretch > 0 ? -stretch : 0" in detail, "tested detail elastic overscroll behavior must remain")
require("contentMode: .fill" in detail and "contentMode: .fit, onImageLoaded:" not in detail, "detail reveal must stay continuous instead of switching content modes")

require("emby-episode-picker-scroll" in picker, "episode picker must observe its native ScrollView offset")
require("pickerHeroSourceSize" in picker, "episode picker must retain source image dimensions")
require("AdaptiveHeroRevealMetrics.fullRevealScale" in picker and "AdaptiveHeroRevealMetrics.clearImageBottom" in picker, "episode picker must share adaptive crop-release and continuous blending")
require("location: clearImageBottom" in picker, "episode picker clear image must fade before its real bottom edge")
require("stretch > 0 ? -stretch : 0" in picker, "episode picker must share elastic top behavior")
require("EmbyCachedRemoteImage(url: pickerHeroURL" in picker, "episode picker Hero should use the shared cached image path")

for forbidden in ["interactivePopGestureRecognizer", "UIGestureRecognizerDelegate", "transitionCoordinator", "popViewController("]:
    require(forbidden not in metrics, f"Hero visual geometry must never own native navigation: {forbidden}")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
print("adaptive Hero reveal invariants: OK")
''')

print("adaptive blend refinement applied")
