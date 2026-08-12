from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"::error::{message}")


metrics = Path("Sources/UI/ImmersiveUIComponents.swift").read_text()
detail = Path("Sources/UI/EmbyMediaDetailView.swift").read_text()
picker = Path("Sources/UI/EmbyEpisodePickerView.swift").read_text()
nav = Path("Sources/UI/ImmersiveUIComponents.swift").read_text()
project = Path("project.yml").read_text()

require("struct AdaptiveHeroRevealMetrics" in metrics, "shared adaptive Hero reveal metrics are missing")
require("initialSize.height - fullSize.height" in metrics, "crop travel must equal the real rendered-height delta")
require("cropResponseFactor: CGFloat = 0.45" in metrics, "episode picker crop response must remain at the tested 0.45 path")
require("detailCropResponseFactor: CGFloat = 0.90" in metrics, "detail clear backdrop crop response must use the competitor-calibrated 0.90 path")
require("detailBackdropViewportHeight(width: CGFloat)" in metrics and "width * 0.88" in metrics, "detail clear backdrop crop viewport must be decoupled from the foreground Hero height")
require("let scale = viewportSize.width / imageSize.width" in metrics, "full reveal must stop at the viewport width edge to prevent side gaps")
require("initialSize.height - max(0, consumedCropScroll)" in metrics, "rendered image height must subtract the softened crop response directly")
require("cropPhaseScrollDistance" in metrics and "backdropPinOffset" in metrics and "cropTravel) / responseFactor" in metrics, "clear backdrop pin duration must be derived from the real crop travel and selected response factor")
require("width: height * aspect" in metrics, "rendered image width must follow source aspect ratio from the changing height")
require("struct AdaptiveHeroNativeScrollObserver: UIViewRepresentable" in metrics, "native ScrollView observer is missing")
require("contentOffset.y + scrollView.adjustedContentInset.top" in metrics, "native raw ScrollView displacement formula is missing")
require("AdaptiveHeroRawScrollPreferenceKey" not in metrics and "AdaptiveHeroRawScrollSentinel" not in metrics, "GeometryReader/PreferenceKey raw scroll path must stay removed")
require("eased(" not in metrics and "revealDistance(" not in metrics and "progress(upwardScroll:" not in metrics, "percentage/easing reveal timeline must stay removed")
require("UIScreen.main.bounds" not in metrics and "iPhone 15" not in metrics, "Hero geometry must not depend on a device model or physical resolution")
require("initialScale: CGFloat = 1.10" in metrics, "tested 0% Hero crop must remain unchanged")

require("heroRawScrollMinY" in detail, "detail must read raw ScrollView displacement from the native ScrollView")
require("detailBackdropViewportHeight" in detail and "detailCropResponseFactor" in detail, "detail must use its decoupled backdrop viewport and response rate")
require("heroViewport = CGSize(width: width, height: baseHeight)" not in detail, "detail clear backdrop geometry must not be coupled to foreground Hero baseHeight")
require("AdaptiveHeroNativeScrollObserver" in detail, "detail must observe native ScrollView content offset")
require(".background(\n                        GeometryReader { proxy in" not in detail, "detail must not sample raw scroll from the compensated content background")
require("renderedImageSize.width, height: renderedImageSize.height" in detail, "detail must render the image at the explicitly computed natural size")
require("baseHeight + consumedCropScroll" not in detail, "detail must not extend layout height to pin Hero during crop release")
require("stretch > 0 ? -stretch : 0" in detail, "detail content must keep native container motion while preserving elastic overscroll")
require("stretch > 0 ? 0 : backdropPinOffset" in detail, "detail clear backdrop must remain top-pinned until crop release completes")
require("AdaptiveHeroConsumedScrollPreferenceKey" not in detail, "detail must not measure scroll from the compensated Hero itself")
require("location: clearImageBottom" in detail, "detail clear image must keep continuous fade into backdrop")

require("private struct EmbyEpisodePickerHeroView" in picker and "@State private var rawScrollMinY" in picker, "episode picker Hero must isolate high-frequency scroll state from the ScrollViewReader root")
require("detailBackdropViewportHeight" not in picker and "detailCropResponseFactor" not in picker, "episode picker must remain frozen on its tested geometry path")
require("AdaptiveHeroNativeScrollObserver" in picker, "episode picker Hero must observe native ScrollView content offset")
require("forceVerticalBounce" not in picker and "forceVerticalBounce" not in metrics, "episode picker must use the same native bounce policy as detail instead of mutating UIScrollView bounce settings")
require("rawScrollProxy.frame" not in picker, "episode picker must not sample raw scroll from the compensated content background")
require("renderedImageSize.width, height: renderedImageSize.height" in picker, "episode picker must render the image at the explicitly computed natural size")
require("baseHeight + consumedCropScroll" not in picker, "episode picker must not extend layout height to pin the whole Hero during crop release")
require("stretch > 0 ? -stretch : 0" in picker, "episode picker content must preserve elastic overscroll")
require("stretch > 0 ? 0 : backdropPinOffset" in picker, "episode picker clear backdrop must remain top-pinned until crop release completes")
require("AdaptiveHeroConsumedScrollPreferenceKey" not in picker, "episode picker must not measure scroll from the compensated Hero itself")
require("location: clearImageBottom" in picker, "episode picker clear image must keep continuous fade into backdrop")

for forbidden in ["interactivePopGestureRecognizer", "UIGestureRecognizerDelegate", "transitionCoordinator", "popViewController("]:
    require(forbidden not in metrics, f"Hero visual geometry must never own native navigation: {forbidden}")
require("nativeInteractivePop() -> some View { self }" in nav, "native interactive pop compatibility modifier must remain a no-op")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")

# Detail foreground placement is independent from the already calibrated clear-backdrop geometry.
require("detailPlaybackCenterReserve: CGFloat = 72" in metrics, "detail playback center reserve missing")
require("detailForegroundBaseHeight(width: CGFloat, viewportHeight: CGFloat)" in metrics, "detail foreground height helper missing")
require("viewportHeight) * 0.5 + detailPlaybackCenterReserve" in metrics, "detail foreground no longer targets the viewport midpoint")
require("hero(width: geometry.size.width, viewportHeight: viewportHeight)" in detail, "detail Hero is not receiving viewport height")
require("let backdropBaseHeight = AdaptiveHeroRevealMetrics.detailBaseHeight(width: width)" in detail, "detail backdrop base height is no longer independent")
require("let baseHeight = AdaptiveHeroRevealMetrics.detailForegroundBaseHeight(width: width, viewportHeight: viewportHeight)" in detail, "detail foreground height is not independent")
require("viewportHeight: backdropVisualHeight" in detail, "detail clear-backdrop mask was coupled back to foreground height")
require(".offset(y: stretch > 0 ? 0 : backdropPinOffset)\n            .frame(width: width, height: visualHeight, alignment: .top)" in detail, "detail clear backdrop must occupy the taller Hero layout while staying top-aligned")
require("detailForegroundBaseHeight" not in picker, "Episode Picker must remain frozen and must not use detail foreground positioning")

print("synchronous Hero crop and container motion invariants: OK")
