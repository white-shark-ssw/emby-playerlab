from pathlib import Path
import re

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
controller = Path("Sources/Player/PlayerController.swift").read_text()
slider = Path("Sources/UI/BufferedTimelineSlider.swift").read_text()
screen = Path("Sources/UI/PlayerScreen.swift").read_text()
surface = Path("Sources/UI/MPVPlayerSurface.swift").read_text()
project = Path("project.yml").read_text()
info = Path("Config/Info.plist").read_text()
identity = Path("Sources/Core/AppIdentity.swift").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.12.3 regression failed: {message}")

for needle in [
    'let authoritativeSeekDemand = reason == "blocked-read" || reason == "byte-offset"',
    "seek concrete-read deferred request=",
    "awaitingBlockedRead=true",
    "authority=cache-miss",
    'cancelSlot(slot, reason: "seek-reanchor-sequential")',
]:
    require(needle in unified, f"seek-anchor fix missing {needle}")
require("pendingUserSeek, !metadata, concretePlaybackDemand, authoritativeSeekDemand" in unified, "pending seek must require authoritative demand")

old_anchor = 233_046_016
stale_cached_read = 237_305_856
actual_miss = 781_254_656
anchor = old_anchor
assert anchor == old_anchor
anchor = actual_miss
require(anchor == actual_miss and anchor != stale_cached_read, "synthetic 478s seek must anchor at actual miss")

health = re.search(r"private func considerSequentialLaneHealth.*?private func resumeAfterSecondaryCooldown", unified, re.S)
require(health is not None, "completed lane-health function missing")
health_body = health.group(0)
require("action=advisory-only" in health_body, "completed lane health must be advisory")
require("resetStreamLane" not in health_body, "completed lane health must not reset a warm connection")
require("rotate-slow-lane" not in unified, "legacy completed-claim rotation must be removed")
require("action=rotate-live-lane" in unified, "live-window lane rotation must remain")

for needle in [
    "func cachedByteRanges() -> [Range<Int64>]",
    "@Published private(set) var transportCacheRanges: [ClosedRange<Double>] = []",
    "downloadCacheRanges: [ClosedRange<Double>]",
    "downloadCacheRanges: controller.transportCacheRanges",
]:
    require(needle in unified + controller + slider + screen, f"sparse cache UI missing {needle}")
require("verifiedBufferedRanges:" not in slider and "bufferedRanges:" not in slider, "engine buffer overlays must not be rendered")
require("downloadCacheFraction:" not in slider, "aggregate cache fraction must not masquerade as positional coverage")

require("struct MPVPlayerSurface: UIViewRepresentable" in surface, "MPV surface must use stable UIViewRepresentable host")
require("UIViewControllerRepresentable" not in surface and "MPVSurfaceViewController" not in surface, "custom MPV wrapper controller must not return")
require("GeometryReader" in screen and "geometry.size.width" in screen and "geometry.size.height" in screen, "MPV host must follow SwiftUI orientation geometry")
require("displayLayer.drawableSize =" not in surface, "UI must not force MoltenVK drawableSize")
require("displayLayer.delegate" not in surface, "do not reintroduce CAMetalLayer delegate coupling")

require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
require(project.count('MARKETING_VERSION: "0.12.6"') == 2, "marketing version must be 0.12.6")
require(project.count('CURRENT_PROJECT_VERSION: "64"') == 2, "build number must be 64")
require("<string>0.12.6</string>" in info and "<string>64</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.12.6"' in identity, "source version mismatch")

print("v0.12.3 regressions retained: OK")
