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
require("initialSize.height - max(0, consumedCropScroll)" in metrics, "rendered image height must subtract raw consumed scroll directly")
require("width: height * aspect" in metrics, "rendered image width must follow source aspect ratio from the changing height")
require("struct AdaptiveHeroNativeScrollObserver: UIViewRepresentable" in metrics, "native ScrollView observer is missing")
require("contentOffset.y + scrollView.adjustedContentInset.top" in metrics, "native raw ScrollView displacement formula is missing")
require("AdaptiveHeroRawScrollPreferenceKey" not in metrics and "AdaptiveHeroRawScrollSentinel" not in metrics, "GeometryReader/PreferenceKey raw scroll path must stay removed")
require("eased(" not in metrics and "revealDistance(" not in metrics and "progress(upwardScroll:" not in metrics, "percentage/easing reveal timeline must stay removed")
require("UIScreen.main.bounds" not in metrics and "iPhone 15" not in metrics, "Hero geometry must not depend on a device model or physical resolution")
require("initialScale: CGFloat = 1.10" in metrics, "tested 0% Hero crop must remain unchanged")

require("heroRawScrollMinY" in detail, "detail must read raw ScrollView displacement outside the compensated Hero")
require("AdaptiveHeroNativeScrollObserver" in detail, "detail must observe native ScrollView content offset")
require(".background(\n                        GeometryReader { proxy in" not in detail, "detail must not sample raw scroll from the compensated content background")
require("renderedImageSize.width, height: renderedImageSize.height" in detail, "detail must render the image at the explicitly computed natural size")
require("baseHeight + consumedCropScroll" in detail, "detail content must stay below the pinned Hero until crop reaches zero")
require("stretch > 0 ? -stretch : consumedCropScroll" in detail, "detail Hero must pin during crop release and preserve elastic overscroll")
require("AdaptiveHeroConsumedScrollPreferenceKey" not in detail, "detail must not measure scroll from the compensated Hero itself")
require("location: clearImageBottom" in detail, "detail clear image must keep continuous fade into backdrop")

require("pickerHeroRawScrollMinY" in picker, "episode picker must read raw ScrollView displacement outside the compensated Hero")
require("AdaptiveHeroNativeScrollObserver" in picker, "episode picker must observe native ScrollView content offset")
require("rawScrollProxy.frame" not in picker, "episode picker must not sample raw scroll from the compensated content background")
require("renderedImageSize.width, height: renderedImageSize.height" in picker, "episode picker must render the image at the explicitly computed natural size")
require("baseHeight + consumedCropScroll" in picker, "episode list must stay below pinned Hero until crop reaches zero")
require("stretch > 0 ? -stretch : consumedCropScroll" in picker, "episode picker must share pin-then-exit and elastic behavior")
require("AdaptiveHeroConsumedScrollPreferenceKey" not in picker, "episode picker must not measure scroll from the compensated Hero itself")
require("location: clearImageBottom" in picker, "episode picker clear image must keep continuous fade into backdrop")

for forbidden in ["interactivePopGestureRecognizer", "UIGestureRecognizerDelegate", "transitionCoordinator", "popViewController("]:
    require(forbidden not in metrics, f"Hero visual geometry must never own native navigation: {forbidden}")
require("nativeInteractivePop() -> some View { self }" in nav, "native interactive pop compatibility modifier must remain a no-op")
require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
print("raw one-to-one Hero scroll invariants: OK")
