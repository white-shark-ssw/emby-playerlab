from pathlib import Path

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
controller = Path("Sources/Player/PlayerController.swift").read_text()
slider = Path("Sources/UI/BufferedTimelineSlider.swift").read_text()
screen = Path("Sources/UI/PlayerScreen.swift").read_text()
surface = Path("Sources/UI/MPVPlayerSurface.swift").read_text()
project = Path("project.yml").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.12.2 regression failed: {message}")

# Live throughput must use real elapsed windows, never adjacent callback timing.
for needle in [
    "liveLaneSampleWindowSeconds: TimeInterval = 1.0",
    "sampleWindowStartedAt",
    "sampleWindowStartedBytes",
    "lastSampleAt",
    "let windowBps = Double(sampleBytes) / max(sampleSeconds, 0.001)",
    "windowMs=",
]:
    require(needle in unified, f"windowed lane health missing {needle}")
require("let chunkBps = Double(bytes) / interval" not in unified, "callback-interarrival speed estimator must not return")
require("now.timeIntervalSince(live.lastChunkAt)" not in unified, "rolling health must not divide by last callback interval")

# Synthetic callback burst: 1 MiB callbacks 5ms apart must not imply 200 MiB/s.
bytes_in_window = 2 * 1_048_576
real_window_seconds = 1.05
window_bps = bytes_in_window / real_window_seconds
callback_bps = 1_048_576 / 0.005
require(window_bps < 3 * 1_048_576, "synthetic real-window sample invalid")
require(callback_bps > 100 * 1_048_576, "synthetic callback-burst regression invalid")

# A demand deep inside an active urgent claim must be able to borrow the other lane.
for needle in [
    "foreground active-gap slot=",
    'reason: "foreground-active-gap-',
    "active.role == .urgentPlayback",
    "gap > progressiveUrgentGapBytes",
]:
    require(needle in unified, f"active urgent gap recovery missing {needle}")

# Cache bar represents UnifiedTransport byte coverage independently from AVPlayer/mpv buffer ranges.
require("@Published private(set) var transportCacheFraction: Double = 0" in controller, "transport cache fraction missing")
require("Double(metrics.cacheBytes) / Double(metrics.resourceBytes)" in controller, "cache fraction must use actual byte cache/resource size")
require("downloadCacheFraction: Double" in slider, "timeline download-cache layer missing")
require("downloadCacheFraction: controller.transportCacheFraction" in screen, "PlayerScreen must pass transport cache fraction")
require("下载缓存" in screen, "diagnostics must label download cache separately from playable buffer")

# MPVKit's iOS demo uses UIViewControllerRepresentable. Keep our CAMetalLayer hosted in a
# controller so rotation gets UIKit size-transition callbacks instead of leaving a portrait UIView
# around a landscape MoltenVK drawable.
require("struct MPVPlayerSurface: UIViewControllerRepresentable" in surface, "MPV surface must use controller representable")
require("viewWillTransition(to size:" in surface, "MPV surface rotation callback missing")
require("transition target=" in surface, "rotation geometry diagnostics missing")
require("displayLayer.drawableSize =" not in surface, "UI must not force MoltenVK drawableSize")

require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
require(project.count('MARKETING_VERSION: "0.12.2"') == 2, "marketing version must be 0.12.2")
require(project.count('CURRENT_PROJECT_VERSION: "60"') == 2, "build number must be 60")

print("v0.12.2 regressions: OK")
