from pathlib import Path


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
