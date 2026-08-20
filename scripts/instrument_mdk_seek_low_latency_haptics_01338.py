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

# Build105 identity. Build104 materialization runs before this script.
replace_once(identity_path, 'sourceVersion = "0.13.37"', 'sourceVersion = "0.13.38"')

# Build104 stopped suppressing raw buffering as soon as the first post-seek frame arrived.
# Device logs show MDK can then spend another ~0.6-0.9s rebuilding decoded buffer and briefly
# report Buffering again. Keep the existing 3s hard bound, but cover the full seek settle window.
replace_once(
    engine_path,
    "        let seekAwaitingVisual = activeNativeSeek != nil || queuedLatestSeek != nil || pendingSeekResume != nil\n        if rawBuffering, seekAwaitingVisual, let graceStartedAt = seekBufferingGraceStartedAt, now - graceStartedAt < seekBufferingUIGraceSeconds {\n",
    "        if rawBuffering, let graceStartedAt = seekBufferingGraceStartedAt, now - graceStartedAt < seekBufferingUIGraceSeconds {\n",
)
replace_once(
    engine_path,
    'reason=seek-awaiting-first-frame graceMs=',
    'reason=seek-settle-window graceMs=',
)

# The normal MDK minimum decoded buffer remains 1000ms. During an explicit user seek only,
# temporarily lower the minimum to 200ms so the new target can resume quickly; once decoded
# buffer reaches >=1000ms with no seek in flight, restore the normal 1000ms policy.
replace_once(
    engine_path,
    "    private let seekBufferingUIGraceSeconds: TimeInterval = 3.0\n",
    "    private let seekBufferingUIGraceSeconds: TimeInterval = 3.0\n    private let normalBufferMinMs: Int64 = 1_000\n    private let seekBufferMinMs: Int64 = 200\n    private var seekLowLatencyBufferActive = false\n",
)
replace_once(
    engine_path,
    "        didLogSeekBufferingGraceID = nil\n        prematureEOFRecoveryActive = false\n",
    "        didLogSeekBufferingGraceID = nil\n        seekLowLatencyBufferActive = false\n        prematureEOFRecoveryActive = false\n",
)
replace_once(
    engine_path,
    "            player.setBufferRange(msMin: 1_000, msMax: Int64(max(3_000, min(30_000, preferredForwardBuffer * 1_000))), drop: false)\n",
    "            player.setBufferRange(msMin: self.normalBufferMinMs, msMax: Int64(max(3_000, min(30_000, preferredForwardBuffer * 1_000))), drop: false)\n",
)
replace_once(
    engine_path,
    "        didLogSeekBufferingGraceID = nil\n\n        let queue = nativeControlQueue\n",
    "        didLogSeekBufferingGraceID = nil\n        seekLowLatencyBufferActive = true\n\n        let queue = nativeControlQueue\n",
)
replace_once(
    engine_path,
    "            guard let self, let player, self.isCurrentPlayer(player, generation: dispatchedIntent.playerGeneration) else { return }\n            let immediateResult = player.seek",
    "            guard let self, let player, self.isCurrentPlayer(player, generation: dispatchedIntent.playerGeneration) else { return }\n            player.setBufferRange(msMin: self.seekBufferMinMs, msMax: Int64(max(3_000, min(30_000, self.preferredForwardBuffer * 1_000))), drop: false)\n            DiagnosticsLogger.shared.playback(\"MDKSeekBuffer\", \"id=\\(dispatchedIntent.id) phase=low-latency minMs=\\(self.seekBufferMinMs) normalMinMs=\\(self.normalBufferMinMs)\")\n            let immediateResult = player.seek",
)
replace_once(
    engine_path,
    "        lastNativeBufferMs = bufferMs\n\n        let farFromEnd",
    "        lastNativeBufferMs = bufferMs\n\n        if seekLowLatencyBufferActive, activeNativeSeek == nil, queuedLatestSeek == nil, pendingSeekResume == nil, bufferMs >= normalBufferMinMs, let player = currentPlayerReference() {\n            seekLowLatencyBufferActive = false\n            let currentGeneration = generation\n            let queue = nativeControlQueue\n            queue.async { [weak self, weak player] in\n                guard let self, let player, self.isCurrentPlayer(player, generation: currentGeneration) else { return }\n                player.setBufferRange(msMin: self.normalBufferMinMs, msMax: Int64(max(3_000, min(30_000, self.preferredForwardBuffer * 1_000))), drop: false)\n                DiagnosticsLogger.shared.playback(\"MDKSeekBuffer\", \"phase=restore-normal minMs=\\(self.normalBufferMinMs) bufferedMs=\\(bufferMs)\")\n            }\n        }\n\n        let farFromEnd",
)
replace_once(
    engine_path,
    "        didLogSeekBufferingGraceID = nil\n        hasRenderedValidFrame = false\n",
    "        didLogSeekBufferingGraceID = nil\n        seekLowLatencyBufferActive = false\n        hasRenderedValidFrame = false\n",
)
replace_once(
    engine_path,
    "        didLogSeekBufferingGraceID = nil\n        let oldRenderer = renderer\n",
    "        didLogSeekBufferingGraceID = nil\n        seekLowLatencyBufferActive = false\n        let oldRenderer = renderer\n",
)

# Build104 used 0.288 (+60% over original 0.18). Build105 adds another 30%: 0.3744.
replace_once(
    haptics_path,
    "                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.288),\n",
    "                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3744),\n",
)

engine = Path(engine_path).read_text()
haptics = Path(haptics_path).read_text()
identity = Path(identity_path).read_text()
assert 'private let avioRequestSizeBytes = 2 * 1_048_576' in engine
assert 'private let seekBufferingUIGraceSeconds: TimeInterval = 3.0' in engine
assert 'private let normalBufferMinMs: Int64 = 1_000' in engine
assert 'private let seekBufferMinMs: Int64 = 200' in engine
assert 'reason=seek-settle-window graceMs=' in engine
assert 'MDKSeekBuffer' in engine
assert 'phase=restore-normal' in engine
assert 'CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3744)' in haptics
assert 'duration: 0.010' in haptics
assert 'sourceVersion = "0.13.38"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build105 seek settle UI + 200ms temporary seek buffer + 10ms/1.3x Build104 haptics materialized")