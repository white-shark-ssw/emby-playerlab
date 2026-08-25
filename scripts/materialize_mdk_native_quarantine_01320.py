from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
PROJECT = ROOT / "project.mdklab.yml"
IDENTITY = ROOT / "Sources/Core/AppIdentity.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)


def regex_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{label}: expected one regex match, got {count}")
    return updated

project = PROJECT.read_text()
if 'MARKETING_VERSION: "0.13.20"' in project and 'CURRENT_PROJECT_VERSION: "87"' in project:
    print("Build87 already materialized")
    raise SystemExit(0)
if 'MARKETING_VERSION: "0.13.19"' not in project or 'CURRENT_PROJECT_VERSION: "86"' not in project:
    raise SystemExit("Build87 requires validated Build86 baseline")

text = ENGINE.read_text()

text = replace_once(
    text,
    '''    private var lastNativeBuffering = false\n    private var lastNativePosition: Double = 0\n    private var lastNativeDuration: Double = 0\n''',
    '''    private var lastNativeBuffering = false\n    private var lastNativePosition: Double = 0\n    private var lastNativeDuration: Double = 0\n    private var lastNativeStatus: Int32 = 0\n    private var lastNativeBufferMs: Int64 = 0\n    private var lastNativeIsPlaying = false\n    private var lastNativeEnded = false\n''',
    "cached native snapshot fields")

text = replace_once(
    text,
    '''        lastNativeBuffering = false\n        lastNativePosition = max(0, startPosition)\n        lastNativeDuration = source.mediaSource.durationSeconds ?? 0\n''',
    '''        lastNativeBuffering = false\n        lastNativePosition = max(0, startPosition)\n        lastNativeDuration = source.mediaSource.durationSeconds ?? 0\n        lastNativeStatus = 0\n        lastNativeBufferMs = 0\n        lastNativeIsPlaying = false\n        lastNativeEnded = false\n''',
    "cached native snapshot reset")

text = regex_once(
    text,
    r'''    func setPlaybackRate\(_ rate: Double\) \{.*?\n    \}\n\n    func seek''',
    r'''    func setPlaybackRate(_ rate: Double) {
        let clamped = min(8, max(0.15, rate))
        playbackRate = clamped
        rateGeneration &+= 1
        let currentRateGeneration = rateGeneration
        guard let player = currentPlayerReference() else {
            DiagnosticsLogger.shared.playback("MDKRate", "requested=\(String(format: "%.2f", clamped)) state=pending-player")
            return
        }
        let currentPlayerGeneration = generation
        let startPosition = lastNativePosition
        let startedAt = CACurrentMediaTime()
        let queue = nativeControlQueue
        queue.async { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: currentPlayerGeneration), self.rateGeneration == currentRateGeneration else { return }
            player.playbackRate = Float(clamped)
            let applied = Double(player.playbackRate)
            DiagnosticsLogger.shared.playback("MDKRate", "requested=\(String(format: "%.2f", clamped)) applied=\(String(format: "%.2f", applied)) sourceFPS=\(self.sourceFrameRateText) decoder=VT mainNativeCall=false")
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self, let player, self.isCurrentPlayer(player, generation: currentPlayerGeneration), self.rateGeneration == currentRateGeneration else { return }
                self.scheduleRateHealth(player: player, generation: currentRateGeneration, requested: clamped, startedAt: startedAt, startPosition: startPosition, delay: 1.5)
                self.scheduleRateHealth(player: player, generation: currentRateGeneration, requested: clamped, startedAt: startedAt, startPosition: startPosition, delay: 4.0)
            }
        }
    }

    func seek''',
    "setPlaybackRate isolation")

text = replace_once(
    text,
    '''    func seek(to targetSeconds: Double, direction: SeekDirection) {\n        guard let player else { return }\n        let target = max(0, targetSeconds)\n        let duration = max(source.mediaSource.durationSeconds ?? 0, seconds(player.mediaInfo.duration))\n''',
    '''    func seek(to targetSeconds: Double, direction: SeekDirection) {\n        guard let player = currentPlayerReference() else { return }\n        let target = max(0, targetSeconds)\n        let duration = max(source.mediaSource.durationSeconds ?? 0, lastNativeDuration)\n''',
    "seek cached duration")

text = regex_once(
    text,
    r'''    private func performNativeSeek\(_ intent: NativeSeekIntent, player: swift_mdk\.Player\) \{.*?\n    \}\n\n    private func dispatchQueuedSeekIfNeeded''',
    r'''    private func performNativeSeek(_ intent: NativeSeekIntent, player: swift_mdk.Player) {
        guard intent.playerGeneration == generation, self.player === player, activeNativeSeek?.id == intent.id else { return }
        var dispatchedIntent = intent
        let nativeStartedAt = Date().timeIntervalSince1970
        dispatchedIntent.nativeStartedAt = nativeStartedAt
        dispatchedIntent.nativeStartFrameSerial = renderedFrameSerial
        activeNativeSeek = dispatchedIntent
        seekBufferingGraceStartedAt = nativeStartedAt
        seekBufferingGraceID = dispatchedIntent.id
        seekBufferingGraceTarget = dispatchedIntent.target
        didLogSeekBufferingGraceID = nil

        let queue = nativeControlQueue
        queue.async { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: dispatchedIntent.playerGeneration) else { return }
            let immediateResult = player.seek(self.milliseconds(dispatchedIntent.target), flags: .Default) { [weak self, weak player] actualMs in
                let callbackAt = Date().timeIntervalSince1970
                DispatchQueue.main.async { [weak self, weak player] in
                    guard let self else { return }
                    let requestLatency = (callbackAt - dispatchedIntent.requestedAt) * 1_000
                    let nativeLatency = (callbackAt - nativeStartedAt) * 1_000
                    guard let player, self.isCurrentPlayer(player, generation: dispatchedIntent.playerGeneration) else {
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=\(actualMs) current=false action=discard-stale-player-generation requestGeneration=\(dispatchedIntent.playerGeneration) activeGeneration=\(self.generation)")
                        return
                    }
                    guard self.activeNativeSeek?.id == dispatchedIntent.id else {
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=\(actualMs) action=discard-nonactive-native")
                        return
                    }

                    self.activeNativeSeek = nil
                    let isCurrent = self.pendingSeekResume?.id == dispatchedIntent.id
                    if actualMs >= 0 {
                        let actual = self.seconds(actualMs)
                        if var pending = self.pendingSeekResume, pending.id == dispatchedIntent.id {
                            pending.callbackAt = callbackAt
                            pending.callbackPosition = actual
                            pending.callbackFrameSerial = self.renderedFrameSerial
                            self.pendingSeekResume = pending
                            self.scheduleSeekFrameWatchdog(player: player, seekID: dispatchedIntent.id, playerGeneration: dispatchedIntent.playerGeneration, hard: false)
                        }
                        if isCurrent, self.shouldPlay { self.requestPlayerState(playing: true, expectedPlayer: player, generation: dispatchedIntent.playerGeneration) }
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) actual=\(String(format: "%.3f", actual)) current=\(isCurrent) action=\(isCurrent ? "callback-current-await-frame" : "diagnostic-only") nativeOutstanding=\(self.nativeSeekOutstandingCount) unifiedTransport=\(self.sharedTransportSession != nil) direction=\(String(describing: dispatchedIntent.direction)) nativeQueue=isolated")
                    } else if actualMs == -2, isCurrent, self.queuedLatestSeek == nil, dispatchedIntent.retryCount < 1 {
                        var retry = dispatchedIntent
                        retry.retryCount += 1
                        retry.nativeStartedAt = nil
                        self.queuedLatestSeek = retry
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=-2 current=true action=retry-ignored-once")
                    } else if actualMs == -2, self.queuedLatestSeek != nil {
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=-2 current=false action=ignored-dispatch-latest")
                    } else {
                        let recoveryTarget = self.latestDesiredTarget(fallback: dispatchedIntent.target)
                        if self.lastNativeEnded {
                            self.pendingSeekResume = nil
                            self.queuedLatestSeek = nil
                            DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=\(actualMs) current=\(isCurrent) action=eof-negative-callback-in-place-reprepare latestTarget=\(String(format: "%.3f", recoveryTarget)) source=cached-native-snapshot")
                            self.recoverStall(position: recoveryTarget, duration: dispatchedIntent.duration)
                            return
                        }
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) callbackMs=\(String(format: "%.1f", requestLatency)) nativeMs=\(String(format: "%.1f", nativeLatency)) result=\(actualMs) current=\(isCurrent) action=negative-callback-recover latestTarget=\(String(format: "%.3f", recoveryTarget))")
                        self.recoverWedgedSeek(reason: "negative-callback-\(actualMs)", fallbackTarget: recoveryTarget, playerGeneration: dispatchedIntent.playerGeneration)
                        return
                    }
                    self.dispatchQueuedSeekIfNeeded(player: player)
                }
            }
            DiagnosticsLogger.shared.playback("MDKSeek", "id=\(dispatchedIntent.id) target=\(String(format: "%.3f", dispatchedIntent.target)) phase=native-dispatch immediateResult=\(immediateResult) semantics=advisory retry=\(dispatchedIntent.retryCount) nativeOutstanding=isolated mainNativeCall=false")
            DispatchQueue.main.async { [weak self, weak player] in
                guard let self, let player, self.isCurrentPlayer(player, generation: dispatchedIntent.playerGeneration), self.activeNativeSeek?.id == dispatchedIntent.id else { return }
                self.scheduleActiveNativeSeekFastWatchdog(player: player, intent: dispatchedIntent)
                self.scheduleActiveNativeSeekWatchdog(player: player, intent: dispatchedIntent, hard: false)
            }
        }
    }

    private func dispatchQueuedSeekIfNeeded''',
    "native seek isolation")

text = regex_once(
    text,
    r'''    func recoverStall\(position: Double, duration: Double\) \{.*?\n    \}\n\n    func transportMetrics''',
    r'''    func recoverStall(position: Double, duration: Double) {
        guard let player = currentPlayerReference() else { return }
        if let sharedTransportSession { Task { await sharedTransportSession.recoverStall(position: position, duration: duration) } }
        let status = lastNativeStatus
        let prematureEnd = lastNativeEnded && duration > 0 && position + max(3, duration * 0.005) < duration
        if prematureEnd, shouldPlay {
            guard !prematureEOFRecoveryActive else {
                DiagnosticsLogger.shared.playback("MDKRecovery", "position=\(String(format: "%.3f", position)) action=wait-existing-eof-recovery")
                return
            }
            prematureEOFRecoveryActive = true
            transportHTTPServer?.resetClientStreams(reason: "mdk-premature-eof-reprepare")
            let recoveryGeneration = generation
            DiagnosticsLogger.shared.playback("MDKRecovery", "position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) playing=\(lastNativeIsPlaying) status=0x\(String(status, radix: 16)) unifiedTransport=\(sharedTransportSession != nil) action=reprepare-same-player nativeQueue=isolated")
            let queue = nativeControlQueue
            queue.async { [weak self, weak player] in
                guard let self, let player, self.isCurrentPlayer(player, generation: recoveryGeneration) else { return }
                player.prepare(from: self.milliseconds(position), complete: { [weak self, weak player] preparedAtMs, boost in
                    guard let self, let player, self.isCurrentPlayer(player, generation: recoveryGeneration) else { return false }
                    boost = true
                    DispatchQueue.main.async { [weak self, weak player] in
                        guard let self, let player, self.isCurrentPlayer(player, generation: recoveryGeneration) else { return }
                        if preparedAtMs < 0 {
                            self.prematureEOFRecoveryActive = false
                            DiagnosticsLogger.shared.playback("MDKRecovery", "position=\(String(format: "%.3f", position)) preparedAtMs=\(preparedAtMs) action=reprepare-failed-no-rebuild")
                            return
                        }
                        if self.shouldPlay { self.requestPlayerState(playing: true, expectedPlayer: player, generation: recoveryGeneration) }
                        DiagnosticsLogger.shared.playback("MDKRecovery", "position=\(String(format: "%.3f", position)) preparedAtMs=\(preparedAtMs) action=reprepare-ready-await-frame")
                    }
                    return true
                })
            }
            return
        }
        DiagnosticsLogger.shared.playback("MDKRecovery", "position=\(String(format: "%.3f", position)) duration=\(String(format: "%.3f", duration)) playing=\(lastNativeIsPlaying) status=0x\(String(status, radix: 16)) unifiedTransport=\(sharedTransportSession != nil) action=prioritize-and-play source=cached-native-snapshot")
        if shouldPlay { requestPlayerState(playing: true, expectedPlayer: player, generation: generation) }
    }

    func transportMetrics''',
    "recoverStall isolation")

text = replace_once(
    text,
    '''        lastNativePosition = position\n        lastNativeDuration = duration\n        lastNativeBuffering = rawBuffering\n''',
    '''        lastNativePosition = position\n        lastNativeDuration = duration\n        lastNativeBuffering = rawBuffering\n        lastNativeStatus = status\n        lastNativeBufferMs = bufferMs\n        lastNativeIsPlaying = isPlaying\n        lastNativeEnded = ended\n''',
    "consume cached native snapshot")

text = regex_once(
    text,
    r'''    private func scheduleActiveNativeSeekFastWatchdog\(player: swift_mdk\.Player, intent: NativeSeekIntent\) \{.*?\n    \}\n\n    private func scheduleActiveNativeSeekWatchdog''',
    r'''    private func scheduleActiveNativeSeekFastWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent) {
        guard let nativeStartedAt = intent.nativeStartedAt, let startFrameSerial = intent.nativeStartFrameSerial else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + activeNativeSeekFastWatchdogSeconds) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.activeNativeSeek?.id == intent.id else { return }
            guard self.renderedFrameSerial <= startFrameSerial else {
                DiagnosticsLogger.shared.playback("MDKSeekFastWatchdog", "id=\(intent.id) elapsedNativeMs=\(String(format: "%.1f", (Date().timeIntervalSince1970 - nativeStartedAt) * 1_000)) action=defer-render-progress")
                return
            }
            guard let session = self.sharedTransportSession else {
                DiagnosticsLogger.shared.playback("MDKSeekFastWatchdog", "id=\(intent.id) elapsedNativeMs=\(String(format: "%.1f", (Date().timeIntervalSince1970 - nativeStartedAt) * 1_000)) action=defer-no-unified-transport")
                return
            }
            Task { [weak self, weak player] in
                let metrics = await session.metrics()
                await MainActor.run {
                    guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.activeNativeSeek?.id == intent.id else { return }
                    let rawBuffering = self.lastNativeBuffering
                    let bufferMs = self.lastNativeBufferMs
                    let noRenderedProgress = self.renderedFrameSerial <= startFrameSerial
                    let transportHealthy = metrics.rangeFailureCount == 0 && metrics.resourceBytes > 0 && (metrics.cacheBytes > 0 || metrics.currentDownloadBytesPerSecond >= 1_048_576 || metrics.activeRequestCount == 0)
                    let engineDataHealthy = bufferMs >= 500 && !rawBuffering
                    let shouldRecover = noRenderedProgress && transportHealthy && engineDataHealthy
                    let recoveryTarget = self.latestDesiredTarget(fallback: intent.target)
                    DiagnosticsLogger.shared.playback("MDKSeekFastWatchdog", "id=\(intent.id) target=\(String(format: "%.3f", intent.target)) elapsedNativeMs=\(String(format: "%.1f", (Date().timeIntervalSince1970 - nativeStartedAt) * 1_000)) frameSerial=\(self.renderedFrameSerial)/\(startFrameSerial) bufferMs=\(bufferMs) rawBuffering=\(rawBuffering) transportHealthy=\(transportHealthy) cacheBytes=\(metrics.cacheBytes) active=\(metrics.activeRequestCount) networkBps=\(Int(metrics.currentDownloadBytesPerSecond)) latestTarget=\(String(format: "%.3f", recoveryTarget)) action=\(shouldRecover ? "recover-latest-target" : "defer-standard-watchdog") source=cached-native-snapshot")
                    if shouldRecover { self.recoverWedgedSeek(reason: "active-native-fast-timeout", fallbackTarget: recoveryTarget, playerGeneration: intent.playerGeneration) }
                }
            }
        }
    }

    private func scheduleActiveNativeSeekWatchdog''',
    "fast watchdog cached snapshot")

text = regex_once(
    text,
    r'''    private func scheduleActiveNativeSeekWatchdog\(player: swift_mdk\.Player, intent: NativeSeekIntent, hard: Bool\) \{.*?\n    \}\n\n    private func scheduleSeekFrameWatchdog''',
    r'''    private func scheduleActiveNativeSeekWatchdog(player: swift_mdk.Player, intent: NativeSeekIntent, hard: Bool) {
        guard let nativeStartedAt = intent.nativeStartedAt else { return }
        let delay = hard ? activeNativeSeekHardWatchdogSeconds - activeNativeSeekWatchdogSeconds : activeNativeSeekWatchdogSeconds
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.1, delay)) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.activeNativeSeek?.id == intent.id else { return }
            let now = Date().timeIntervalSince1970
            let rawBuffering = self.lastNativeBuffering
            let bufferMs = self.lastNativeBufferMs
            let recoveryTarget = self.latestDesiredTarget(fallback: intent.target)
            let shouldRecover = hard || bufferMs >= 500 || !rawBuffering
            DiagnosticsLogger.shared.playback("MDKSeekWatchdog", "id=\(intent.id) target=\(String(format: "%.3f", intent.target)) elapsedNativeMs=\(String(format: "%.1f", (now - nativeStartedAt) * 1_000)) position=\(String(format: "%.3f", self.lastNativePosition)) playing=\(self.lastNativeIsPlaying) status=0x\(String(self.lastNativeStatus, radix: 16)) bufferMs=\(bufferMs) rawBuffering=\(rawBuffering) nativeOutstanding=\(self.nativeSeekOutstandingCount) latestTarget=\(String(format: "%.3f", recoveryTarget)) action=\(shouldRecover ? "recover-latest-target" : "wait-media-data") unifiedTransport=\(self.sharedTransportSession != nil) source=cached-native-snapshot")
            if let session = self.sharedTransportSession {
                Task {
                    let metrics = await session.metrics()
                    DiagnosticsLogger.shared.playback("MDKSeekWatchdog", "id=\(intent.id) transport anchor=\(metrics.schedulerAnchorByte) frontier=\(metrics.schedulerFrontierByte) cacheBytes=\(metrics.cacheBytes) active=\(metrics.activeRequestCount) networkBps=\(Int(metrics.currentDownloadBytesPerSecond))")
                }
            }
            if shouldRecover {
                self.recoverWedgedSeek(reason: hard ? "active-native-hard-timeout" : "active-native-timeout", fallbackTarget: recoveryTarget, playerGeneration: intent.playerGeneration)
            } else {
                self.scheduleActiveNativeSeekWatchdog(player: player, intent: intent, hard: true)
            }
        }
    }

    private func scheduleSeekFrameWatchdog''',
    "seek watchdog cached snapshot")

text = regex_once(
    text,
    r'''    private func scheduleSeekFrameWatchdog\(player: swift_mdk\.Player, seekID: Int, playerGeneration: Int, hard: Bool\) \{.*?\n    \}\n\n    private func latestDesiredTarget''',
    r'''    private func scheduleSeekFrameWatchdog(player: swift_mdk.Player, seekID: Int, playerGeneration: Int, hard: Bool) {
        let delay = hard ? seekFrameHardWatchdogSeconds - seekFrameWatchdogSeconds : seekFrameWatchdogSeconds
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.1, delay)) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: playerGeneration), let pending = self.pendingSeekResume, pending.id == seekID, pending.callbackAt != nil else { return }
            let rawBuffering = self.lastNativeBuffering
            let bufferMs = self.lastNativeBufferMs
            let recoveryTarget = self.latestDesiredTarget(fallback: pending.target)
            let shouldRecover = self.shouldPlay && (hard || bufferMs >= 500 || !rawBuffering)
            DiagnosticsLogger.shared.playback("MDKSeekFrameWatchdog", "id=\(seekID) target=\(String(format: "%.3f", pending.target)) renderedSerial=\(self.renderedFrameSerial) callbackSerial=\(pending.callbackFrameSerial.map { String($0) } ?? "pending") position=\(String(format: "%.3f", self.lastNativePosition)) bufferMs=\(bufferMs) rawBuffering=\(rawBuffering) playingWanted=\(self.shouldPlay) action=\(shouldRecover ? "recover-latest-target" : (self.shouldPlay ? "wait-media-data" : "paused-wait-frame")) latestTarget=\(String(format: "%.3f", recoveryTarget)) source=cached-native-snapshot")
            if shouldRecover {
                self.recoverWedgedSeek(reason: hard ? "callback-without-new-frame-hard" : "callback-without-new-frame", fallbackTarget: recoveryTarget, playerGeneration: playerGeneration)
            } else if self.shouldPlay, !hard {
                self.scheduleSeekFrameWatchdog(player: player, seekID: seekID, playerGeneration: playerGeneration, hard: true)
            }
        }
    }

    private func latestDesiredTarget''',
    "frame watchdog cached snapshot")

text = regex_once(
    text,
    r'''    private func scheduleRateHealth\(player: swift_mdk\.Player, generation: Int, requested: Double, startedAt: TimeInterval, startPosition: Double, delay: TimeInterval\) \{.*?\n    \}\n\n    private func recordRenderedFrame''',
    r'''    private func scheduleRateHealth(player: swift_mdk.Player, generation: Int, requested: Double, startedAt: TimeInterval, startPosition: Double, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak player] in
            guard let self, let player, self.rateGeneration == generation, self.currentPlayerReference() === player else { return }
            let elapsed = max(0.001, CACurrentMediaTime() - startedAt)
            let currentPosition = self.lastNativePosition
            let actualRate = max(0, (currentPosition - startPosition) / elapsed)
            DiagnosticsLogger.shared.playback("MDKRateHealth", "requested=\(String(format: "%.2f", requested)) actual=\(String(format: "%.2f", actualRate)) sample=\(String(format: "%.1f", elapsed))s position=\(String(format: "%.3f", currentPosition)) status=0x\(String(self.lastNativeStatus, radix: 16)) playing=\(self.lastNativeIsPlaying) sourceFPS=\(self.sourceFrameRateText) decoder=VT source=cached-native-snapshot mainNativeCall=false")
        }
    }

    private func recordRenderedFrame''',
    "rate health cached snapshot")

# Build87 version/source identity.
identity = IDENTITY.read_text()
identity = identity.replace('sourceVersion = "0.13.19"', 'sourceVersion = "0.13.20"')
identity = identity.replace('?? "0.13.19"', '?? "0.13.20"')
IDENTITY.write_text(identity)
project = project.replace('MARKETING_VERSION: "0.13.19"', 'MARKETING_VERSION: "0.13.20"').replace('CURRENT_PROJECT_VERSION: "86"', 'CURRENT_PROJECT_VERSION: "87"')
PROJECT.write_text(project)
ENGINE.write_text(text)

print("Build87 MDK native quarantine materialized")
