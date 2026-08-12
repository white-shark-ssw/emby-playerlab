from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, got {count}")
    return text.replace(old, new, 1)


# Shared metrics: keep Picker on the tested 0.45 path, add a Detail-only geometry path.
p = Path("Sources/UI/ImmersiveUIComponents.swift")
s = p.read_text()
s = replace_once(
    s,
    """struct AdaptiveHeroRevealMetrics {\n    static let initialScale: CGFloat = 1.10\n    static let cropResponseFactor: CGFloat = 0.45\n    static func detailBaseHeight(width: CGFloat) -> CGFloat { min(488, max(430, width * 1.08)) }\n    static func compactBaseHeight(width: CGFloat) -> CGFloat { min(252, max(206, width * 0.51)) }\n""",
    """struct AdaptiveHeroRevealMetrics {\n    static let initialScale: CGFloat = 1.10\n    static let cropResponseFactor: CGFloat = 0.45\n    static let detailCropResponseFactor: CGFloat = 0.90\n    static func detailBaseHeight(width: CGFloat) -> CGFloat { min(488, max(430, width * 1.08)) }\n    static func detailBackdropViewportHeight(width: CGFloat) -> CGFloat { min(410, max(340, width * 0.88)) }\n    static func compactBaseHeight(width: CGFloat) -> CGFloat { min(252, max(206, width * 0.51)) }\n""",
    "metrics constants",
)
s = replace_once(
    s,
    """    static func consumedCropScroll(upwardScroll: CGFloat, cropTravel: CGFloat) -> CGFloat {\n        min(max(0, upwardScroll) * cropResponseFactor, max(0, cropTravel))\n    }\n\n    static func cropPhaseScrollDistance(cropTravel: CGFloat) -> CGFloat {\n        guard cropResponseFactor > 0 else { return 0 }\n        return max(0, cropTravel) / cropResponseFactor\n    }\n\n    static func backdropPinOffset(upwardScroll: CGFloat, cropTravel: CGFloat) -> CGFloat {\n        min(max(0, upwardScroll), cropPhaseScrollDistance(cropTravel: cropTravel))\n    }\n""",
    """    static func consumedCropScroll(upwardScroll: CGFloat, cropTravel: CGFloat) -> CGFloat {\n        consumedCropScroll(upwardScroll: upwardScroll, cropTravel: cropTravel, responseFactor: cropResponseFactor)\n    }\n\n    static func consumedCropScroll(upwardScroll: CGFloat, cropTravel: CGFloat, responseFactor: CGFloat) -> CGFloat {\n        min(max(0, upwardScroll) * max(0, responseFactor), max(0, cropTravel))\n    }\n\n    static func cropPhaseScrollDistance(cropTravel: CGFloat) -> CGFloat {\n        cropPhaseScrollDistance(cropTravel: cropTravel, responseFactor: cropResponseFactor)\n    }\n\n    static func cropPhaseScrollDistance(cropTravel: CGFloat, responseFactor: CGFloat) -> CGFloat {\n        guard responseFactor > 0 else { return 0 }\n        return max(0, cropTravel) / responseFactor\n    }\n\n    static func backdropPinOffset(upwardScroll: CGFloat, cropTravel: CGFloat) -> CGFloat {\n        backdropPinOffset(upwardScroll: upwardScroll, cropTravel: cropTravel, responseFactor: cropResponseFactor)\n    }\n\n    static func backdropPinOffset(upwardScroll: CGFloat, cropTravel: CGFloat, responseFactor: CGFloat) -> CGFloat {\n        min(max(0, upwardScroll), cropPhaseScrollDistance(cropTravel: cropTravel, responseFactor: responseFactor))\n    }\n""",
    "metrics response overloads",
)
p.write_text(s)

# Detail only: decouple clear backdrop crop geometry from the foreground Hero layout.
p = Path("Sources/UI/EmbyMediaDetailView.swift")
s = p.read_text()
s = replace_once(
    s,
    """        let contentWidth = max(0, width - 40)\n        let heroViewport = CGSize(width: width, height: baseHeight)\n        let cropTravel = AdaptiveHeroRevealMetrics.cropTravel(imageSize: heroSourceSize, viewportSize: heroViewport)\n        let stretch = max(0, heroRawScrollMinY)\n        let upwardScroll = max(0, -heroRawScrollMinY)\n        let consumedCropScroll = AdaptiveHeroRevealMetrics.consumedCropScroll(upwardScroll: upwardScroll, cropTravel: cropTravel)\n        let backdropPinOffset = AdaptiveHeroRevealMetrics.backdropPinOffset(upwardScroll: upwardScroll, cropTravel: cropTravel)\n        let visualHeight = baseHeight + stretch\n        let renderedImageSize = stretch > 0 ? AdaptiveHeroRevealMetrics.stretchedImageSize(imageSize: heroSourceSize, viewportSize: CGSize(width: width, height: visualHeight)) : AdaptiveHeroRevealMetrics.renderedImageSize(imageSize: heroSourceSize, viewportSize: heroViewport, consumedCropScroll: consumedCropScroll)\n""",
    """        let contentWidth = max(0, width - 40)\n        let backdropViewportHeight = AdaptiveHeroRevealMetrics.detailBackdropViewportHeight(width: width)\n        let backdropViewport = CGSize(width: width, height: backdropViewportHeight)\n        let cropTravel = AdaptiveHeroRevealMetrics.cropTravel(imageSize: heroSourceSize, viewportSize: backdropViewport)\n        let stretch = max(0, heroRawScrollMinY)\n        let upwardScroll = max(0, -heroRawScrollMinY)\n        let consumedCropScroll = AdaptiveHeroRevealMetrics.consumedCropScroll(upwardScroll: upwardScroll, cropTravel: cropTravel, responseFactor: AdaptiveHeroRevealMetrics.detailCropResponseFactor)\n        let backdropPinOffset = AdaptiveHeroRevealMetrics.backdropPinOffset(upwardScroll: upwardScroll, cropTravel: cropTravel, responseFactor: AdaptiveHeroRevealMetrics.detailCropResponseFactor)\n        let visualHeight = baseHeight + stretch\n        let stretchedBackdropViewport = CGSize(width: width, height: backdropViewportHeight + stretch)\n        let renderedImageSize = stretch > 0 ? AdaptiveHeroRevealMetrics.stretchedImageSize(imageSize: heroSourceSize, viewportSize: stretchedBackdropViewport) : AdaptiveHeroRevealMetrics.renderedImageSize(imageSize: heroSourceSize, viewportSize: backdropViewport, consumedCropScroll: consumedCropScroll)\n""",
    "detail decoupled backdrop geometry",
)
p.write_text(s)

# Regression checker: Detail gets its own geometry/rate; Picker remains frozen on the shared 0.45 path.
p = Path("scripts/check_adaptive_hero_reveal.py")
s = p.read_text()
s = replace_once(
    s,
    'require("cropResponseFactor: CGFloat = 0.45" in metrics and "upwardScroll) * cropResponseFactor" in metrics, "crop response must stay 55 percent softer than native container travel")',
    'require("cropResponseFactor: CGFloat = 0.45" in metrics, "episode picker crop response must remain at the tested 0.45 path")\nrequire("detailCropResponseFactor: CGFloat = 0.90" in metrics, "detail clear backdrop crop response must use the competitor-calibrated 0.90 path")\nrequire("detailBackdropViewportHeight(width: CGFloat)" in metrics and "width * 0.88" in metrics, "detail clear backdrop crop viewport must be decoupled from the foreground Hero height")',
    "checker response constants",
)
s = replace_once(
    s,
    'require("cropPhaseScrollDistance" in metrics and "backdropPinOffset" in metrics and "cropTravel) / cropResponseFactor" in metrics, "clear backdrop pin duration must be derived from the real crop travel and response factor")',
    'require("cropPhaseScrollDistance" in metrics and "backdropPinOffset" in metrics and "cropTravel) / responseFactor" in metrics, "clear backdrop pin duration must be derived from the real crop travel and selected response factor")',
    "checker pin formula",
)
anchor = 'require("heroRawScrollMinY" in detail, "detail must read raw ScrollView displacement from the native ScrollView")\n'
addition = anchor + 'require("detailBackdropViewportHeight" in detail and "detailCropResponseFactor" in detail, "detail must use its decoupled backdrop viewport and response rate")\nrequire("heroViewport = CGSize(width: width, height: baseHeight)" not in detail, "detail clear backdrop geometry must not be coupled to foreground Hero baseHeight")\n'
s = replace_once(s, anchor, addition, "checker detail geometry")
anchor = 'require("private struct EmbyEpisodePickerHeroView" in picker and "@State private var rawScrollMinY" in picker, "episode picker Hero must isolate high-frequency scroll state from the ScrollViewReader root")\n'
addition = anchor + 'require("detailBackdropViewportHeight" not in picker and "detailCropResponseFactor" not in picker, "episode picker must remain frozen on its tested geometry path")\n'
s = replace_once(s, anchor, addition, "checker picker freeze")
p.write_text(s)

print("detail competitor backdrop geometry patch applied")
