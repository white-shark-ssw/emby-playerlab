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
engine = Path(engine_path).read_text()

# Build103 identity is enforced again by xcodebuild in CI. Keep source identity readable too.
identity_path = Path("Sources/Core/AppIdentity.swift")
identity = identity_path.read_text().replace('0.13.35', '0.13.36')
identity_path.write_text(identity)

# User seeks must target the requested timestamp instead of the next keyframe.
replace_once(
    engine_path,
    "            let immediateResult = player.seek(self.milliseconds(dispatchedIntent.target), flags: .Default) { [weak self, weak player] actualMs in\n",
    "            let immediateResult = player.seek(self.milliseconds(dispatchedIntent.target), flags: .FromStart) { [weak self, weak player] actualMs in\n",
)

# Preserve Build102's bounded HTTP AVIO fix and add a narrowly-scoped startup audio recovery.
replace_once(
    engine_path,
    "    private let avioShortSeekSizeBytes = 2 * 1_048_576\n    private let avioRequestSizeBytes = 2 * 1_048_576\n    private var preparingGeneration: Int?\n",
    "    private let avioShortSeekSizeBytes = 2 * 1_048_576\n    private let avioRequestSizeBytes = 2 * 1_048_576\n    private let trueHDStartupFallbackSeconds: TimeInterval = 2.0\n    private var trueHDStartupFallbackArmedAt: TimeInterval?\n    private var trueHDStartupFallbackAttempted = false\n    private var preparingGeneration: Int?\n",
)

replace_once(
    engine_path,
    "        endCandidatePosition = max(0, startPosition)\n        endCandidateFrameSerial = 0\n        installMDKLoggingIfNeeded()\n",
    "        endCandidatePosition = max(0, startPosition)\n        endCandidateFrameSerial = 0\n        trueHDStartupFallbackArmedAt = nil\n        trueHDStartupFallbackAttempted = false\n        installMDKLoggingIfNeeded()\n",
)

replace_once(
    engine_path,
    "        preparingGeneration = nil\n        preparedGeneration = currentGeneration\n        endCandidateSince = nil\n        let elapsedMs = (CACurrentMediaTime() - prepareStartedAt) * 1_000\n",
    "        preparingGeneration = nil\n        preparedGeneration = currentGeneration\n        endCandidateSince = nil\n        trueHDStartupFallbackArmedAt = CACurrentMediaTime()\n        let elapsedMs = (CACurrentMediaTime() - prepareStartedAt) * 1_000\n",
)

replace_once(
    engine_path,
    "        let isPlaying = player.state == .Playing\n        let bufferMs = player.buffered()\n        DispatchQueue.main.async { [weak self, weak player] in\n",
    "        let isPlaying = player.state == .Playing\n        let bufferMs = player.buffered()\n        recoverTrueHDStartupIfNeeded(player: player, info: info, position: position, rawBuffering: rawBuffering, bufferMs: bufferMs, generation: generation)\n        DispatchQueue.main.async { [weak self, weak player] in\n",
)

replace_once(
    engine_path,
    "    private func consumeStateSample(position: Double, duration: Double, status: Int32, rawBuffering: Bool, ended: Bool, isPlaying: Bool, bufferMs: Int64) {\n",
    '''    private func recoverTrueHDStartupIfNeeded(player: swift_mdk.Player, info: MediaInfo, position: Double, rawBuffering: Bool, bufferMs: Int64, generation: Int) {
        guard !trueHDStartupFallbackAttempted, let armedAt = trueHDStartupFallbackArmedAt else { return }
        if position > 0.25 {
            trueHDStartupFallbackArmedAt = nil
            return
        }
        guard CACurrentMediaTime() - armedAt >= trueHDStartupFallbackSeconds, shouldPlay, rawBuffering, bufferMs < 250 else { return }
        let health = nativeRenderHealth()
        guard health.generation == generation, health.serial > 0 else { return }
        guard let firstAudio = info.audio.first, (firstAudio.codec.codec ?? "").lowercased() == "truehd" else {
            trueHDStartupFallbackArmedAt = nil
            return
        }
        guard let fallbackIndex = info.audio.firstIndex(where: { ["ac3", "eac3"].contains(($0.codec.codec ?? "").lowercased()) }) else {
            trueHDStartupFallbackArmedAt = nil
            DiagnosticsLogger.shared.playback("MDKAudioStartupFallback", "generation=\\(generation) source=truehd action=none reason=no-ac3-compatible-track")
            return
        }
        trueHDStartupFallbackAttempted = true
        trueHDStartupFallbackArmedAt = nil
        let fallback = info.audio[fallbackIndex]
        DiagnosticsLogger.shared.playback("MDKAudioStartupFallback", "generation=\\(generation) elapsedMs=\\(Int((CACurrentMediaTime() - armedAt) * 1_000)) position=\\(String(format: \"%.3f\", position)) bufferMs=\\(bufferMs) renderedSerial=\\(health.serial) source=truehd fallbackIndex=\\(fallbackIndex) fallbackStream=\\(fallback.index) fallbackCodec=\\((fallback.codec.codec ?? \"unknown\").lowercased()) action=switch-audio-track")
        player.activeAudioTracks = [fallbackIndex]
        if shouldPlay { player.state = .Playing }
    }

    private func consumeStateSample(position: Double, duration: Double, status: Int32, rawBuffering: Bool, ended: Bool, isPlaying: Bool, bufferMs: Int64) {
''',
)

# Static audit: Build102 is frozen, only precise seek + bounded TrueHD startup fallback are new.
engine = Path(engine_path).read_text()
assert 'avioRequestSizeBytes = 2 * 1_048_576' in engine
assert 'player.setProperty(name: "avio.request_size", value: String(avioRequestSizeBytes))' in engine
assert 'flags: .FromStart' in engine
assert 'flags: .Default' not in engine[engine.index('private func performNativeSeek'):engine.index('private func dispatchQueuedSeekIfNeeded')]
assert 'MDKAudioStartupFallback' in engine
assert 'trueHDStartupFallbackSeconds: TimeInterval = 2.0' in engine
assert 'action=preserve-existing-stream-before-native-seek' in engine
assert 'UnifiedReadTrace' not in Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build103 precise MDK seek + bounded TrueHD startup fallback materialized")
