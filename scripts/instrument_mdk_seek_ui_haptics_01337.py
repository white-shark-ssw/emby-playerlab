from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing patch anchor in {path}: {old[:180]!r}")
    p.write_text(text.replace(old, new, 1))


engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
haptics_path = "Sources/UI/PlaybackVolumeTickHaptics.swift"
identity_path = "Sources/Core/AppIdentity.swift"

# Build104 identity. Build103 materialization runs before this script.
replace_once(identity_path, 'sourceVersion = "0.13.36"', 'sourceVersion = "0.13.37"')

# A seek can legitimately need more than 500 ms to submit its first new frame even when
# UnifiedTransport already has the requested bytes. Keep MDK's raw buffering state, but
# suppress the user-facing buffering snapshot only while the latest seek is still waiting
# for its first visual frame, with the existing bounded watchdog safety as a hard backstop.
replace_once(
    engine_path,
    "    private let seekBufferingUIGraceSeconds: TimeInterval = 0.5\n",
    "    private let seekBufferingUIGraceSeconds: TimeInterval = 3.0\n",
)
replace_once(
    engine_path,
    "        var suppressSeekBuffering = false\n        if rawBuffering, let graceStartedAt = seekBufferingGraceStartedAt, now - graceStartedAt < seekBufferingUIGraceSeconds {\n",
    "        var suppressSeekBuffering = false\n        let seekAwaitingVisual = activeNativeSeek != nil || queuedLatestSeek != nil || pendingSeekResume != nil\n        if rawBuffering, seekAwaitingVisual, let graceStartedAt = seekBufferingGraceStartedAt, now - graceStartedAt < seekBufferingUIGraceSeconds {\n",
)
replace_once(
    engine_path,
    'reason=active-native-seek-grace graceMs=',
    'reason=seek-awaiting-first-frame graceMs=',
)

# Volume tick haptic: 15 ms -> 10 ms; intensity +60% (0.18 -> 0.288).
replace_once(
    haptics_path,
    "                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.18),\n",
    "                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.288),\n",
)
replace_once(
    haptics_path,
    "                duration: 0.015\n",
    "                duration: 0.010\n",
)

engine = Path(engine_path).read_text()
haptics = Path(haptics_path).read_text()
identity = Path(identity_path).read_text()
assert 'private let avioRequestSizeBytes = 2 * 1_048_576' in engine
assert 'player.setProperty(name: "avio.request_size", value: String(avioRequestSizeBytes))' in engine
assert 'private let seekBufferingUIGraceSeconds: TimeInterval = 3.0' in engine
assert 'let seekAwaitingVisual = activeNativeSeek != nil || queuedLatestSeek != nil || pendingSeekResume != nil' in engine
assert 'reason=seek-awaiting-first-frame graceMs=' in engine
assert 'CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.288)' in haptics
assert 'duration: 0.010' in haptics
assert 'sourceVersion = "0.13.37"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build104 MDK seek UI buffering suppression + 10ms/1.6x volume haptics materialized")
