from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing patch anchor in {path}: {old[:220]!r}")
    p.write_text(text.replace(old, new, 1))


engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
identity_path = "Sources/Core/AppIdentity.swift"

# Build106 identity. Build105 materialization runs before this script.
replace_once(identity_path, 'sourceVersion = "0.13.38"', 'sourceVersion = "0.13.39"')

# Keep the existing 2s first-frame watchdog as a checkpoint, but a non-zero Resume can
# legitimately still be waiting on concrete UnifiedTransport reads. Recheck once per second
# while transport is healthy and MDK is still waiting for media, with a hard 12s cap.
replace_once(
    engine_path,
    "    private let firstFrameWatchdogSeconds: TimeInterval = 2.0\n",
    "    private let firstFrameWatchdogSeconds: TimeInterval = 2.0\n    private let coldResumeFirstFrameRecheckSeconds: TimeInterval = 1.0\n    private let coldResumeFirstFrameHardLimitSeconds: TimeInterval = 12.0\n",
)

replace_once(
    engine_path,
    '''    private func scheduleFirstFrameWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double) {
        let startSerial = nativeRenderHealth().serial
        watchdogQueue.asyncAfter(deadline: .now() + firstFrameWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player, self.preparedGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration), self.shouldPlay else { return }
            let health = self.nativeRenderHealth()
            guard health.generation == currentGeneration, health.serial <= startSerial else { return }
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(currentGeneration) phase=first-frame-timeout elapsedMs=\\(Int(self.firstFrameWatchdogSeconds * 1_000)) position=\\(String(format: \"%.3f\", self.lastNativePosition)) watchdogQueue=independent renderBridge=offscreen-texture")
            self.quarantineCurrentGeneration(reason: "first-frame-timeout", position: max(startPosition, self.lastNativePosition), failedGeneration: currentGeneration, message: "MDK native isolation first frame timeout")
        }
    }
''',
    '''    private func scheduleFirstFrameWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double) {
        let startSerial = nativeRenderHealth().serial
        let startedAt = CACurrentMediaTime()
        watchdogQueue.asyncAfter(deadline: .now() + firstFrameWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player else { return }
            self.evaluateFirstFrameWatchdog(player: player, generation: currentGeneration, startPosition: startPosition, startSerial: startSerial, startedAt: startedAt)
        }
    }

    private func evaluateFirstFrameWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double, startSerial: UInt64, startedAt: TimeInterval) {
        guard preparedGeneration == currentGeneration, isCurrentPlayer(player, generation: currentGeneration), shouldPlay else { return }
        let health = nativeRenderHealth()
        guard health.generation == currentGeneration, health.serial <= startSerial else { return }
        let elapsed = CACurrentMediaTime() - startedAt
        let elapsedMs = elapsed * 1_000
        guard startPosition > 0.5, let session = sharedTransportSession, elapsed < coldResumeFirstFrameHardLimitSeconds else {
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(currentGeneration) phase=first-frame-timeout elapsedMs=\\(Int(elapsedMs)) position=\\(String(format: \"%.3f\", lastNativePosition)) start=\\(String(format: \"%.3f\", startPosition)) reason=\\(startPosition > 0.5 ? \"hard-limit-or-no-unified-transport\" : \"normal-start\") watchdogQueue=independent renderBridge=offscreen-texture")
            quarantineCurrentGeneration(reason: "first-frame-timeout", position: max(startPosition, lastNativePosition), failedGeneration: currentGeneration, message: "MDK native isolation first frame timeout")
            return
        }

        Task { [weak self, weak player] in
            let metrics = await session.metrics()
            guard let self, let player else { return }
            self.watchdogQueue.async { [weak self, weak player] in
                guard let self, let player, self.preparedGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration), self.shouldPlay else { return }
                let currentHealth = self.nativeRenderHealth()
                guard currentHealth.generation == currentGeneration, currentHealth.serial <= startSerial else { return }
                let nowElapsed = CACurrentMediaTime() - startedAt
                let transportProgressing = metrics.rangeFailureCount == 0 && (metrics.activeRequestCount > 0 || metrics.currentDownloadBytesPerSecond >= 65_536)
                let waitingForMedia = self.lastNativeBuffering || self.lastNativeBufferMs < self.normalBufferMinMs
                if transportProgressing, waitingForMedia, nowElapsed < self.coldResumeFirstFrameHardLimitSeconds {
                    DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(currentGeneration) phase=first-frame-grace elapsedMs=\\(Int(nowElapsed * 1_000)) start=\\(String(format: \"%.3f\", startPosition)) position=\\(String(format: \"%.3f\", self.lastNativePosition)) active=\\(metrics.activeRequestCount) networkBps=\\(Int(metrics.currentDownloadBytesPerSecond)) bufferMs=\\(self.lastNativeBufferMs) rawBuffering=\\(self.lastNativeBuffering) rangeFailures=\\(metrics.rangeFailureCount) hardLimitMs=\\(Int(self.coldResumeFirstFrameHardLimitSeconds * 1_000)) action=defer-cold-resume-first-frame")
                    self.watchdogQueue.asyncAfter(deadline: .now() + self.coldResumeFirstFrameRecheckSeconds) { [weak self, weak player] in
                        guard let self, let player else { return }
                        self.evaluateFirstFrameWatchdog(player: player, generation: currentGeneration, startPosition: startPosition, startSerial: startSerial, startedAt: startedAt)
                    }
                    return
                }
                DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(currentGeneration) phase=first-frame-timeout elapsedMs=\\(Int(nowElapsed * 1_000)) start=\\(String(format: \"%.3f\", startPosition)) position=\\(String(format: \"%.3f\", self.lastNativePosition)) reason=\\(transportProgressing ? (waitingForMedia ? \"hard-limit\" : \"engine-not-waiting-for-media\") : \"transport-not-progressing\") active=\\(metrics.activeRequestCount) networkBps=\\(Int(metrics.currentDownloadBytesPerSecond)) bufferMs=\\(self.lastNativeBufferMs) rawBuffering=\\(self.lastNativeBuffering) rangeFailures=\\(metrics.rangeFailureCount) action=quarantine")
                self.quarantineCurrentGeneration(reason: "first-frame-timeout", position: max(startPosition, self.lastNativePosition), failedGeneration: currentGeneration, message: "MDK native isolation first frame timeout")
            }
        }
    }
''',
)

engine = Path(engine_path).read_text()
identity = Path(identity_path).read_text()
assert 'private let avioRequestSizeBytes = 2 * 1_048_576' in engine
assert 'private let seekBufferMinMs: Int64 = 200' in engine
assert 'private let coldResumeFirstFrameHardLimitSeconds: TimeInterval = 12.0' in engine
assert 'phase=first-frame-grace' in engine
assert 'action=defer-cold-resume-first-frame' in engine
assert 'MDK native isolation first frame timeout' in engine
assert 'sourceVersion = "0.13.39"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build106 bounded cold-resume first-frame grace materialized")
