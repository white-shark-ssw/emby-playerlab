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
controller_path = "Sources/Player/PlayerController.swift"

# Cold Resume should not race engine activation against the startup transport resolve.
replace_once(
    controller_path,
    '''            let duration = self.source.mediaSource.durationSeconds ?? 0
            if !self.mdkDirectHTTPABActive, let session = self.transportContext?.session {
                await session.releaseStartupPrewarm(initialPosition: startPosition, duration: duration)
                guard !Task.isCancelled, self.started else { return }
            }
''',
    '''            let duration = self.source.mediaSource.durationSeconds ?? 0
            if startPosition > 0.5, let prewarmTask = self.startupTransportPrewarmTask {
                await prewarmTask.value
                guard !Task.isCancelled, self.started else { return }
                DiagnosticsLogger.shared.playback("StartupFastPath", "cold resume transport resolve awaited item=\\(self.source.itemId) position=\\(String(format: \"%.3f\", startPosition))")
            }
            if !self.mdkDirectHTTPABActive, let session = self.transportContext?.session {
                await session.releaseStartupPrewarm(initialPosition: startPosition, duration: duration)
                guard !Task.isCancelled, self.started else { return }
            }
''',
)

# Keep the original 3s watchdog as a safety checkpoint. Only non-zero UnifiedTransport
# resumes with healthy active byte movement can earn bounded grace, capped at 20s total.
replace_once(
    engine_path,
    '''    private let prepareWatchdogSeconds: TimeInterval = 3.0
    private let firstFrameWatchdogSeconds: TimeInterval = 2.0
''',
    '''    private let prepareWatchdogSeconds: TimeInterval = 3.0
    private let coldResumePrepareRecheckSeconds: TimeInterval = 2.0
    private let coldResumePrepareHardLimitSeconds: TimeInterval = 20.0
    private let firstFrameWatchdogSeconds: TimeInterval = 2.0
''',
)

replace_once(
    engine_path,
    '''    private func schedulePrepareWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double, startedAt: TimeInterval) {
        watchdogQueue.asyncAfter(deadline: .now() + prepareWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player, self.preparingGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
            let elapsedMs = (CACurrentMediaTime() - startedAt) * 1_000
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(currentGeneration) phase=prepare-timeout elapsedMs=\\(String(format: \"%.1f\", elapsedMs)) start=\\(String(format: \"%.3f\", startPosition)) watchdogQueue=independent")
            self.quarantineCurrentGeneration(reason: "prepare-timeout", position: startPosition, failedGeneration: currentGeneration, message: "MDK native prepare timeout")
        }
    }
''',
    '''    private func schedulePrepareWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double, startedAt: TimeInterval) {
        watchdogQueue.asyncAfter(deadline: .now() + prepareWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player else { return }
            self.evaluatePrepareWatchdog(player: player, generation: currentGeneration, startPosition: startPosition, startedAt: startedAt)
        }
    }

    private func evaluatePrepareWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double, startedAt: TimeInterval) {
        guard preparingGeneration == currentGeneration, isCurrentPlayer(player, generation: currentGeneration) else { return }
        let elapsed = CACurrentMediaTime() - startedAt
        let elapsedMs = elapsed * 1_000
        guard startPosition > 0.5, let session = sharedTransportSession, elapsed < coldResumePrepareHardLimitSeconds else {
            DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(currentGeneration) phase=prepare-timeout elapsedMs=\\(String(format: \"%.1f\", elapsedMs)) start=\\(String(format: \"%.3f\", startPosition)) reason=\\(startPosition > 0.5 ? \"hard-limit-or-no-unified-transport\" : \"normal-start\") watchdogQueue=independent")
            quarantineCurrentGeneration(reason: "prepare-timeout", position: startPosition, failedGeneration: currentGeneration, message: "MDK native prepare timeout")
            return
        }

        Task { [weak self, weak player] in
            let metrics = await session.metrics()
            guard let self, let player else { return }
            self.watchdogQueue.async { [weak self, weak player] in
                guard let self, let player, self.preparingGeneration == currentGeneration, self.isCurrentPlayer(player, generation: currentGeneration) else { return }
                let nowElapsed = CACurrentMediaTime() - startedAt
                let progressing = metrics.rangeFailureCount == 0 && (metrics.activeRequestCount > 0 || metrics.currentDownloadBytesPerSecond >= 65_536)
                if progressing, nowElapsed < self.coldResumePrepareHardLimitSeconds {
                    DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(currentGeneration) phase=prepare-grace elapsedMs=\\(Int(nowElapsed * 1_000)) start=\\(String(format: \"%.3f\", startPosition)) active=\\(metrics.activeRequestCount) networkBps=\\(Int(metrics.currentDownloadBytesPerSecond)) cacheBytes=\\(metrics.cacheBytes) rangeFailures=\\(metrics.rangeFailureCount) hardLimitMs=\\(Int(self.coldResumePrepareHardLimitSeconds * 1_000)) action=defer-cold-resume")
                    self.watchdogQueue.asyncAfter(deadline: .now() + self.coldResumePrepareRecheckSeconds) { [weak self, weak player] in
                        guard let self, let player else { return }
                        self.evaluatePrepareWatchdog(player: player, generation: currentGeneration, startPosition: startPosition, startedAt: startedAt)
                    }
                    return
                }
                DiagnosticsLogger.shared.playback("MDKPrepareGuard", "generation=\\(currentGeneration) phase=prepare-timeout elapsedMs=\\(Int(nowElapsed * 1_000)) start=\\(String(format: \"%.3f\", startPosition)) reason=\\(progressing ? \"hard-limit\" : \"transport-not-progressing\") active=\\(metrics.activeRequestCount) networkBps=\\(Int(metrics.currentDownloadBytesPerSecond)) cacheBytes=\\(metrics.cacheBytes) rangeFailures=\\(metrics.rangeFailureCount) action=quarantine")
                self.quarantineCurrentGeneration(reason: "prepare-timeout", position: startPosition, failedGeneration: currentGeneration, message: "MDK native prepare timeout")
            }
        }
    }
''',
)

controller = Path(controller_path).read_text()
engine = Path(engine_path).read_text()
assert 'cold resume transport resolve awaited' in controller
assert 'coldResumePrepareHardLimitSeconds: TimeInterval = 20.0' in engine
assert 'phase=prepare-grace' in engine
assert 'rangeFailures=' in engine
assert 'avioRequestSizeBytes = 2 * 1_048_576' in engine
assert 'action=preserve-existing-stream-before-native-seek' in engine
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build103 bounded cold-resume prepare grace materialized")
