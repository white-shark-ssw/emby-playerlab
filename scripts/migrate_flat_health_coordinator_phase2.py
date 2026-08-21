from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing phase2 anchor in {path}: {old[:260]!r}")
    p.write_text(text.replace(old, new, 1))


def replace_between(path: str, start: str, end: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    i = text.find(start)
    if i < 0:
        raise SystemExit(f"missing phase2 start in {path}: {start!r}")
    j = text.find(end, i)
    if j < 0:
        raise SystemExit(f"missing phase2 end in {path}: {end!r}")
    p.write_text(text[:i] + new + text[j:])


engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
health_path = "MDKLab/App/MDKPlaybackHealthCoordinator.swift"

# One policy owner per MDK engine generation.
replace_once(
    engine_path,
    '    private let watchdogQueue = DispatchQueue(label: "OnePlayer.MDK.Watchdog", qos: .userInitiated)\n',
    '    private let watchdogQueue = DispatchQueue(label: "OnePlayer.MDK.Watchdog", qos: .userInitiated)\n    private let healthCoordinator = MDKPlaybackHealthCoordinator()\n',
)

# Health generation starts before transport/prepare work begins.
replace_once(
    engine_path,
    '''        generation &+= 1
        let currentGeneration = generation
        inputTraceSession = String(UUID().uuidString.prefix(8)).lowercased()
''',
    '''        generation &+= 1
        let currentGeneration = generation
        healthCoordinator.reset(generation: currentGeneration)
        healthCoordinator.beginPrepare(generation: currentGeneration)
        inputTraceSession = String(UUID().uuidString.prefix(8)).lowercased()
''',
)

# Normal stop invalidates every outstanding health candidate with the new generation.
replace_once(
    engine_path,
    '''        generation &+= 1
        rateGeneration &+= 1
        prematureEOFRecoveryActive = false
''',
    '''        generation &+= 1
        rateGeneration &+= 1
        healthCoordinator.reset(generation: generation)
        prematureEOFRecoveryActive = false
''',
)

# Prepared callback enters first-frame phase. Renderer progress, not player.position, will close it.
replace_once(
    engine_path,
    '''        preparingGeneration = nil
        preparedGeneration = currentGeneration
        endCandidateSince = nil
''',
    '''        preparingGeneration = nil
        preparedGeneration = currentGeneration
        healthCoordinator.beginFirstFrame(generation: currentGeneration, renderSerial: nativeRenderHealth().serial)
        endCandidateSince = nil
''',
)

# Native Seek phase begins only when player.seek() is actually about to be invoked.
replace_once(
    engine_path,
    '''        activeNativeSeek = dispatchedIntent
        DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=\(inputTraceSource) event=seek-native-start seekID=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) position=\(String(format: "%.3f", lastNativePosition)) retry=\(dispatchedIntent.retryCount) frameSerial=\(renderedFrameSerial) raw=0x\(String(lastNativeStatus, radix: 16))")
''',
    '''        activeNativeSeek = dispatchedIntent
        healthCoordinator.beginNativeSeek(generation: dispatchedIntent.playerGeneration, seekID: dispatchedIntent.id, target: dispatchedIntent.target, renderSerial: renderedFrameSerial)
        DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=\(inputTraceSource) event=seek-native-start seekID=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) position=\(String(format: "%.3f", lastNativePosition)) retry=\(dispatchedIntent.retryCount) frameSerial=\(renderedFrameSerial) raw=0x\(String(lastNativeStatus, radix: 16))")
''',
)

# The actual callback releases native ownership. If it is the current logical seek, transition to
# callback->render phase; otherwise retire the old phase before dispatching the latest queued intent.
replace_once(
    engine_path,
    '''                    self.activeNativeSeek = nil
                    let isCurrent = self.pendingSeekResume?.id == dispatchedIntent.id
''',
    '''                    self.activeNativeSeek = nil
                    self.healthCoordinator.finishNativeSeek(generation: dispatchedIntent.playerGeneration, seekID: dispatchedIntent.id)
                    let isCurrent = self.pendingSeekResume?.id == dispatchedIntent.id
''',
)
replace_once(
    engine_path,
    '''                            pending.callbackFrameSerial = self.renderedFrameSerial
                            self.pendingSeekResume = pending
                            self.scheduleSeekFrameWatchdog(player: player, seekID: dispatchedIntent.id, playerGeneration: dispatchedIntent.playerGeneration, hard: false)
''',
    '''                            pending.callbackFrameSerial = self.renderedFrameSerial
                            self.pendingSeekResume = pending
                            self.healthCoordinator.beginSeekFrame(generation: dispatchedIntent.playerGeneration, seekID: dispatchedIntent.id, target: dispatchedIntent.target, callbackLanding: actual, renderSerial: self.renderedFrameSerial)
                            self.scheduleSeekFrameWatchdog(player: player, seekID: dispatchedIntent.id, playerGeneration: dispatchedIntent.playerGeneration, hard: false)
''',
)

# Negative native result is deterministic fatal evidence but still goes through the sole policy owner.
replace_once(
    engine_path,
    '''                        let recoveryTarget = self.latestDesiredTarget(fallback: dispatchedIntent.target)
                        let message = "MDK session unsafe seek failure"
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=\(actualMs) current=\(isCurrent) action=quarantine-session-switch-mpv latestTarget=\(String(format: "%.3f", recoveryTarget)) sameProcessMDKRebuild=false")
                        self.quarantineCurrentGeneration(reason: "seek-negative-\(actualMs)", position: recoveryTarget, failedGeneration: dispatchedIntent.playerGeneration, message: message)
                        return
''',
    '''                        let recoveryTarget = self.latestDesiredTarget(fallback: dispatchedIntent.target)
                        let message = "MDK session unsafe seek failure"
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=\(actualMs) current=\(isCurrent) action=submit-fatal-health latestTarget=\(String(format: "%.3f", recoveryTarget))")
                        self.submitHealthCandidate(.fatal(generation: dispatchedIntent.playerGeneration, reason: "seek-negative-\(actualMs)"), fallbackPosition: recoveryTarget, message: message)
                        return
''',
)

# Feed native clock/buffer progress to the coordinator. It is evidence, not a presentation position.
replace_once(
    engine_path,
    '''        lastNativeStatus = status
        lastNativeBufferMs = bufferMs
        let traceSecond = Int(max(0, position).rounded(.down))
''',
    '''        lastNativeStatus = status
        lastNativeBufferMs = bufferMs
        healthCoordinator.noteNativeSample(generation: generation, position: position, bufferMs: bufferMs)
        let traceSecond = Int(max(0, position).rounded(.down))
''',
)

# Premature EOF while a Seek transaction exists is fatal evidence, but the central health commit owns fallback.
replace_once(
    engine_path,
    '''            DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=premature-eof-during-seek position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) latestTarget=\(String(format: "%.3f", recoveryTarget)) action=quarantine-generation")
            quarantineCurrentGeneration(reason: "premature-eof-during-seek", position: recoveryTarget, failedGeneration: generation, message: "MDK premature EOF during seek")
            return
''',
    '''            DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=premature-eof-during-seek position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) latestTarget=\(String(format: "%.3f", recoveryTarget)) action=submit-fatal-health")
            submitHealthCandidate(.fatal(generation: generation, reason: "premature-eof-during-seek"), fallbackPosition: recoveryTarget, message: "MDK premature EOF during seek")
            return
''',
)

# Every real rendered frame is progress evidence. Completing the current Seek also closes seekFrame phase.
replace_once(
    engine_path,
    '''        lastRenderedTimestamp = renderResult
        renderedFrameSerial &+= 1
        if renderedFrameSerial == 1 || renderedFrameSerial % 30 == 0 { DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=\(inputTraceSource) event=render frameSerial=\(renderedFrameSerial) position=\(String(format: "%.3f", lastNativePosition)) renderValue=\(String(format: "%.6f", renderResult))") }
''',
    '''        lastRenderedTimestamp = renderResult
        renderedFrameSerial &+= 1
        healthCoordinator.noteRenderedFrame(generation: generation, serial: renderedFrameSerial, position: renderResult)
        if renderedFrameSerial == 1 || renderedFrameSerial % 30 == 0 { DiagnosticsLogger.shared.playback("MDKInputTrace", "session=\(inputTraceSession) source=\(inputTraceSource) event=render frameSerial=\(renderedFrameSerial) position=\(String(format: "%.3f", lastNativePosition)) renderValue=\(String(format: "%.6f", renderResult))") }
''',
)
replace_once(
    engine_path,
    '''        pendingSeekResume = nil
        seekBufferingGraceStartedAt = nil
''',
    '''        healthCoordinator.completeSeek(generation: generation, seekID: pending.id)
        pendingSeekResume = nil
        seekBufferingGraceStartedAt = nil
''',
)

# Render watchdog submits evidence only; no timer directly owns engine switching.
replace_between(
    engine_path,
    "    private func evaluateRenderLiveness() {\n",
    "\n    func prepare(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double) {\n",
    '''    private func evaluateRenderLiveness() {
        let currentGeneration = generation
        guard shouldPlay, preparedGeneration == currentGeneration, !lastNativeBuffering else { return }
        guard activeNativeSeek == nil, pendingSeekResume == nil else { return }
        let health = nativeRenderHealth()
        guard health.generation == currentGeneration, health.serial > 0 else { return }
        let age = CACurrentMediaTime() - health.lastAt
        guard age >= renderWatchdogTimeoutSeconds else { return }
        submitHealthCandidate(.renderTimeout(generation: currentGeneration), fallbackPosition: lastRenderedTimestamp ?? lastNativePosition, message: "MDK renderer made no progress")
    }
''',
)

# All prepare checks use the same policy for start=0 and resume positions. Transport progress is evidence,
# never a special-case permission owned by this timer.
replace_between(
    engine_path,
    "    private func schedulePrepareWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double, startedAt: TimeInterval) {\n",
    "\n    private func scheduleFirstFrameWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double) {\n",
    '''    private func schedulePrepareWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double, startedAt: TimeInterval) {
        watchdogQueue.asyncAfter(deadline: .now() + prepareWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player else { return }
            self.evaluatePrepareWatchdog(player: player, generation: currentGeneration, startPosition: startPosition, startedAt: startedAt)
        }
    }

    private func evaluatePrepareWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double, startedAt: TimeInterval) {
        guard preparingGeneration == currentGeneration, isCurrentPlayer(player, generation: currentGeneration) else { return }
        submitHealthCandidate(
            .prepareTimeout(generation: currentGeneration),
            fallbackPosition: startPosition,
            message: "MDK prepare made no progress",
            recheck: { [weak self, weak player] in
                guard let self, let player else { return }
                self.watchdogQueue.asyncAfter(deadline: .now() + 1.0) { [weak self, weak player] in
                    guard let self, let player else { return }
                    self.evaluatePrepareWatchdog(player: player, generation: currentGeneration, startPosition: startPosition, startedAt: startedAt)
                }
            }
        )
    }
''',
)

# First-frame timer is also only a candidate producer.
replace_between(
    engine_path,
    "    private func scheduleFirstFrameWatchdog(player: swift_mdk.Player, generation currentGeneration: Int, startPosition: Double) {\n",
    "\n    private func startMDKPlayer(url: URL, headers: [String: String], preferredForwardBuffer: Double, startPosition: Double, generation currentGeneration: Int, transportMode: String) {\n",
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
        let renderHealth = nativeRenderHealth()
        guard renderHealth.generation == currentGeneration, renderHealth.serial <= startSerial else { return }
        submitHealthCandidate(
            .firstFrameTimeout(generation: currentGeneration),
            fallbackPosition: max(startPosition, lastRenderedTimestamp ?? lastNativePosition),
            message: "MDK first frame made no progress",
            recheck: { [weak self, weak player] in
                guard let self, let player else { return }
                self.watchdogQueue.asyncAfter(deadline: .now() + 1.0) { [weak self, weak player] in
                    guard let self, let player else { return }
                    self.evaluateFirstFrameWatchdog(player: player, generation: currentGeneration, startPosition: startPosition, startSerial: startSerial, startedAt: startedAt)
                }
            }
        )
    }
''',
)

# The 1s Fast watchdog is diagnostic/evidence only.
replace_between(
    engine_path,
    "    private func scheduleActiveNativeSeekFastWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent) {\n",
    "\n    private func scheduleActiveNativeSeekWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent, hard: Bool) {\n",
    '''    private func scheduleActiveNativeSeekFastWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent) {
        guard intent.nativeStartedAt != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + activeNativeSeekFastWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.activeNativeSeek?.id == intent.id else { return }
            self.submitHealthCandidate(.nativeSeekTimeout(generation: intent.playerGeneration, seekID: intent.id, hard: false), fallbackPosition: self.latestDesiredTarget(fallback: intent.target), message: "MDK native seek soft probe")
        }
    }
''',
)

# 2s probe is diagnostic only; the existing hard check becomes a coordinator decision. If recent progress
# exists, recheck later without clearing native ownership.
replace_between(
    engine_path,
    "    private func scheduleActiveNativeSeekWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent, hard: Bool) {\n",
    "\n    private func scheduleSeekFrameWatchdog(player: swift_mdk.Player, seekID: Int, playerGeneration: Int, hard: Bool) {\n",
    '''    private func scheduleActiveNativeSeekWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent, hard: Bool) {
        guard intent.nativeStartedAt != nil else { return }
        let delay = hard ? activeNativeSeekHardWatchdogSeconds - activeNativeSeekWatchdogSeconds : activeNativeSeekWatchdogSeconds
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.1, delay)) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.activeNativeSeek?.id == intent.id else { return }
            self.submitHealthCandidate(
                .nativeSeekTimeout(generation: intent.playerGeneration, seekID: intent.id, hard: hard),
                fallbackPosition: self.latestDesiredTarget(fallback: intent.target),
                message: "MDK native seek made no progress",
                recheck: { [weak self, weak player] in
                    guard let self, let player else { return }
                    if hard {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self, weak player] in
                            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.activeNativeSeek?.id == intent.id else { return }
                            self.submitHealthCandidate(.nativeSeekTimeout(generation: intent.playerGeneration, seekID: intent.id, hard: true), fallbackPosition: self.latestDesiredTarget(fallback: intent.target), message: "MDK native seek made no progress", recheck: nil)
                        }
                    } else {
                        self.scheduleActiveNativeSeekWatchdog(player: player, intent: intent, hard: true)
                    }
                }
            )
        }
    }
''',
)

# Callback->frame timer follows the same model.
replace_between(
    engine_path,
    "    private func scheduleSeekFrameWatchdog(player: swift_mdk.Player, seekID: Int, playerGeneration: Int, hard: Bool) {\n",
    "\n    private func latestDesiredTarget(fallback: Double) -> Double {\n",
    '''    private func scheduleSeekFrameWatchdog(player: swift_mdk.Player, seekID: Int, playerGeneration: Int, hard: Bool) {
        let delay = hard ? seekFrameHardWatchdogSeconds - seekFrameWatchdogSeconds : seekFrameWatchdogSeconds
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.1, delay)) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: playerGeneration), let pending = self.pendingSeekResume, pending.id == seekID, pending.callbackAt != nil else { return }
            self.submitHealthCandidate(
                .seekFrameTimeout(generation: playerGeneration, seekID: seekID, hard: hard),
                fallbackPosition: self.latestDesiredTarget(fallback: pending.target),
                message: "MDK seek callback had no matching rendered frame",
                recheck: { [weak self, weak player] in
                    guard let self, let player else { return }
                    if hard {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self, weak player] in
                            guard let self, let player, self.isCurrentPlayer(player, generation: playerGeneration), let pending = self.pendingSeekResume, pending.id == seekID else { return }
                            self.submitHealthCandidate(.seekFrameTimeout(generation: playerGeneration, seekID: seekID, hard: true), fallbackPosition: self.latestDesiredTarget(fallback: pending.target), message: "MDK seek callback had no matching rendered frame", recheck: nil)
                        }
                    } else {
                        self.scheduleSeekFrameWatchdog(player: player, seekID: seekID, playerGeneration: playerGeneration, hard: true)
                    }
                }
            )
        }
    }
''',
)

# recoverWedgedSeek is now only a fatal-candidate adapter. It cannot switch engines itself.
replace_between(
    engine_path,
    "    private func recoverWedgedSeek(reason: String, fallbackTarget: Double, playerGeneration: Int) {\n",
    "\n    private func scheduleRateHealth(player: swift_mdk.Player, generation: Int, requested: Double, startedAt: TimeInterval, startPosition: Double, delay: TimeInterval) {\n",
    '''    private func recoverWedgedSeek(reason: String, fallbackTarget: Double, playerGeneration: Int) {
        guard playerGeneration == generation, player != nil else { return }
        let recoveryTarget = latestDesiredTarget(fallback: fallbackTarget)
        DiagnosticsLogger.shared.playback("MDKSeekWedge", "reason=\(reason) generation=\(playerGeneration) active=\(activeNativeSeek?.id ?? -1) queued=\(queuedLatestSeek?.id ?? -1) latestTarget=\(String(format: "%.3f", recoveryTarget)) action=submit-fatal-health")
        submitHealthCandidate(.fatal(generation: playerGeneration, reason: "seek-wedge-\(reason)"), fallbackPosition: recoveryTarget, message: "MDK session unsafe seek recovery")
    }
''',
)

# External stall recovery can prioritize/replay, but a confirmed premature EOF must use the same central fatal path.
replace_once(
    engine_path,
    '''            let message = "MDK session unsafe premature EOF"
            DiagnosticsLogger.shared.playback("MDKCompat", "position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) status=0x\(String(status, radix: 16)) action=quarantine-session-switch-mpv sameProcessMDKRebuild=false unifiedTransport=\(sharedTransportSession != nil)")
            quarantineCurrentGeneration(reason: "confirmed-premature-eof", position: position, failedGeneration: generation, message: message)
            return
''',
    '''            let message = "MDK session unsafe premature EOF"
            DiagnosticsLogger.shared.playback("MDKCompat", "position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) status=0x\(String(status, radix: 16)) action=submit-fatal-health unifiedTransport=\(sharedTransportSession != nil)")
            submitHealthCandidate(.fatal(generation: generation, reason: "confirmed-premature-eof"), fallbackPosition: position, message: message)
            return
''',
)

# Insert the one and only failure commit point immediately before the quarantine teardown implementation.
replace_once(
    engine_path,
    '''    private func quarantineCurrentGeneration(reason: String, position: Double, failedGeneration: Int, message: String) {
''',
    '''    private func submitHealthCandidate(_ candidate: MDKPlaybackHealthCoordinator.Candidate, fallbackPosition: Double, message: String, recheck: (() -> Void)? = nil) {
        let evaluate: (TransportMetricsSnapshot?) -> Void = { [weak self] metrics in
            guard let self, candidate.generation == self.generation else { return }
            if let metrics {
                self.healthCoordinator.noteTransport(generation: candidate.generation, cacheBytes: metrics.cacheBytes, frontierByte: metrics.schedulerFrontierByte, activeRequests: metrics.activeRequestCount, networkBps: metrics.currentDownloadBytesPerSecond, rangeFailures: metrics.rangeFailureCount)
            }
            let verdict = self.healthCoordinator.evaluate(candidate, shouldPlay: self.shouldPlay, buffering: self.lastNativeBuffering)
            switch verdict {
            case let .ignore(reason):
                DiagnosticsLogger.shared.playback("MDKHealth", "candidate=\(String(describing: candidate)) verdict=ignore reason=\(reason) \(self.healthCoordinator.debugState())")
            case let .defer(reason):
                DiagnosticsLogger.shared.playback("MDKHealth", "candidate=\(String(describing: candidate)) verdict=defer reason=\(reason) \(self.healthCoordinator.debugState())")
                recheck?()
            case let .fail(reason):
                DiagnosticsLogger.shared.playback("MDKHealth", "candidate=\(String(describing: candidate)) verdict=fail reason=\(reason) fallback=\(String(format: "%.3f", fallbackPosition)) \(self.healthCoordinator.debugState())")
                self.commitHealthFailure(reason: reason, position: fallbackPosition, failedGeneration: candidate.generation, message: message)
            }
        }

        if case .fatal = candidate {
            DispatchQueue.main.async { evaluate(nil) }
            return
        }
        guard let session = sharedTransportSession else {
            DispatchQueue.main.async { evaluate(nil) }
            return
        }
        Task { [weak self] in
            let metrics = await session.metrics()
            guard self != nil else { return }
            await MainActor.run { evaluate(metrics) }
        }
    }

    private func commitHealthFailure(reason: String, position: Double, failedGeneration: Int, message: String) {
        guard failedGeneration == generation, currentPlayerReference() != nil else { return }
        nativeQuarantineActive = true
        DiagnosticsLogger.shared.playback("MDKHealth", "generation=\(failedGeneration) commit=fallback reason=\(reason) position=\(String(format: "%.3f", position)) authority=health-coordinator")
        quarantineCurrentGeneration(reason: "health-\(reason)", position: position, failedGeneration: failedGeneration, message: message)
    }

    private func quarantineCurrentGeneration(reason: String, position: Double, failedGeneration: Int, message: String) {
''',
)

# Teardown invalidates the failed generation's coordinator state immediately after generation changes.
replace_once(
    engine_path,
    '''        generation &+= 1
        rateGeneration &+= 1
        nativeQuarantineActive = false
''',
    '''        generation &+= 1
        rateGeneration &+= 1
        healthCoordinator.reset(generation: generation)
        nativeQuarantineActive = false
''',
)

engine = Path(engine_path).read_text()
health = Path(health_path).read_text()

assert "private let healthCoordinator = MDKPlaybackHealthCoordinator()" in engine
assert "healthCoordinator.beginPrepare" in engine
assert "healthCoordinator.beginFirstFrame" in engine
assert "healthCoordinator.beginNativeSeek" in engine
assert "healthCoordinator.beginSeekFrame" in engine
assert "healthCoordinator.noteNativeSample" in engine
assert "healthCoordinator.noteRenderedFrame" in engine
assert "healthCoordinator.completeSeek" in engine
assert "private func submitHealthCandidate" in engine
assert "private func commitHealthFailure" in engine
assert "authority=health-coordinator" in engine
assert "action=queue-latest-single-native" in engine
assert "MDKSeekPreempt" not in engine
assert "liveTrackHeight" not in Path("Sources/UI/BufferedTimelineSlider.swift").read_text()
# Definition + sole central commit call. No watchdog/fatal path may bypass the coordinator.
assert engine.count("quarantineCurrentGeneration(") == 2, engine.count("quarantineCurrentGeneration(")
assert "import QuartzCore" in health
assert 'IPHONEOS_DEPLOYMENT_TARGET: "15.0"' in Path("project.mdklab.yml").read_text()
print("flat health coordinator phase2 migration applied")
