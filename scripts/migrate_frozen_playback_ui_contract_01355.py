from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing frozen-ui anchor in {path}: {old!r}")
    p.write_text(text.replace(old, new, 1))


engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
screen_path = "Sources/UI/PlayerScreen.swift"
slider_path = "Sources/UI/BufferedTimelineSlider.swift"
haptics_path = "Sources/UI/PlaybackVolumeTickHaptics.swift"

# Restore the previously frozen MDK Seek UI grace. Multi-second suppression hides real network stalls.
replace_once(
    engine_path,
    "    private let seekBufferingUIGraceSeconds: TimeInterval = 3.0\n",
    "    private let seekBufferingUIGraceSeconds: TimeInterval = 0.5\n",
)

# The normal timeline's gray layer is current UnifiedTransport cache only.
replace_once(
    screen_path,
    "                    bufferState: controller.bufferState,\n                    onEditingChanged: { editing in\n",
    "                    bufferState: controller.bufferState,\n                    cacheByteRanges: controller.transportCacheRanges,\n                    onEditingChanged: { editing in\n",
)

engine = Path(engine_path).read_text()
screen = Path(screen_path).read_text()
slider = Path(slider_path).read_text()
haptics = Path(haptics_path).read_text()

assert "seekBufferingUIGraceSeconds: TimeInterval = 0.5" in engine
assert "seekBufferingUIGraceSeconds: TimeInterval = 3.0" not in engine
assert "cacheByteRanges: controller.transportCacheRanges" in screen
assert "normalizedCacheRanges" in slider
assert "normalizedLivePlayableRanges" not in slider
assert "bufferState.livePlayableRanges" not in slider
assert ".hapticIntensity, value: 0.38" in haptics
assert "duration: 0.005" in haptics
assert "MDKSeekPreempt" not in engine
assert engine.count("quarantineCurrentGeneration(") == 2
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in Path("project.mdklab.yml").read_text()
print("frozen playback UI contract migrated")
