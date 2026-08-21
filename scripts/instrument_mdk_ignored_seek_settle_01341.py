from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing patch anchor in {path}: {old[:240]!r}")
    p.write_text(text.replace(old, new, 1))


engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
identity_path = "Sources/Core/AppIdentity.swift"

# Build108 identity. Build107 materialization runs before this script.
replace_once(identity_path, 'sourceVersion = "0.13.40"', 'sourceVersion = "0.13.41"')

replace_once(
    engine_path,
    "    private let seekFrameHardWatchdogSeconds: TimeInterval = 4.0\n",
    "    private let seekFrameHardWatchdogSeconds: TimeInterval = 4.0\n    private let ignoredSeekSettleCheckSeconds: TimeInterval = 0.18\n    private let ignoredSeekSettleHardLimitSeconds: TimeInterval = 0.72\n",
)

replace_once(
    engine_path,
    '''                    } else if actualMs == -2, isCurrent, self.queuedLatestSeek == nil, dispatchedIntent.retryCount < 1 {
                        var retry = dispatchedIntent
                        retry.retryCount += 1
                        retry.nativeStartedAt = nil
                        self.queuedLatestSeek = retry
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) callbackMs=\\(String(format: \"%.1f\", requestLatency)) nativeMs=\\(String(format: \"%.1f\", nativeLatency)) result=-2 current=true action=retry-ignored-once")
                    } else if actualMs == -2, self.queuedLatestSeek != nil {
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) callbackMs=\\(String(format: \"%.1f\", requestLatency)) nativeMs=\\(String(format: \"%.1f\", nativeLatency)) result=-2 current=false action=ignored-dispatch-latest")
''',
    '''                    } else if actualMs == -2, isCurrent, dispatchedIntent.retryCount < 1 {
                        if var pending = self.pendingSeekResume, pending.id == dispatchedIntent.id {
                            pending.callbackAt = callbackAt
                            pending.callbackPosition = dispatchedIntent.target
                            pending.callbackFrameSerial = self.renderedFrameSerial
                            self.pendingSeekResume = pending
                            self.scheduleSeekFrameWatchdog(player: player, seekID: dispatchedIntent.id, playerGeneration: dispatchedIntent.playerGeneration, hard: false)
                        }
                        if self.shouldPlay { self.requestPlayerState(playing: true, expectedPlayer: player, generation: dispatchedIntent.playerGeneration) }
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) callbackMs=\\(String(format: \"%.1f\", requestLatency)) nativeMs=\\(String(format: \"%.1f\", nativeLatency)) result=-2 current=true action=defer-ignored-settle-check")
                        self.scheduleIgnoredSeekSettleRetry(intent: dispatchedIntent, player: player, startedAt: callbackAt)
                    } else if actualMs == -2 {
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) callbackMs=\\(String(format: \"%.1f\", requestLatency)) nativeMs=\\(String(format: \"%.1f\", nativeLatency)) result=-2 current=false action=ignored-superseded-no-retry")
''',
)

replace_once(
    engine_path,
    '''    private func dispatchQueuedSeekIfNeeded(player: swift_mdk.Player) {
        guard activeNativeSeek == nil, let next = queuedLatestSeek else { return }
        queuedLatestSeek = nil
        dispatchNativeSeek(next, player: player)
    }

    func reload(at seconds: Double) {
''',
    '''    private func dispatchQueuedSeekIfNeeded(player: swift_mdk.Player) {
        guard activeNativeSeek == nil, let next = queuedLatestSeek else { return }
        queuedLatestSeek = nil
        dispatchNativeSeek(next, player: player)
    }

    private func scheduleIgnoredSeekSettleRetry(intent: NativeSeekIntent, player: swift_mdk.Player, startedAt: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + ignoredSeekSettleCheckSeconds) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.pendingSeekResume?.id == intent.id else {
                return
            }
            let elapsed = Date().timeIntervalSince1970 - startedAt
            if let rendered = self.lastRenderedTimestamp, abs(rendered - intent.target) <= 1.0 {
                DiagnosticsLogger.shared.playback("MDKSeekSettle", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) elapsedMs=\\(Int(elapsed * 1_000)) rendered=\\(String(format: \"%.3f\", rendered)) action=settled-without-retry")
                return
            }
            let nativeSeeking = self.hasStatus(self.lastNativeStatus, bit: 7)
            if nativeSeeking, elapsed < self.ignoredSeekSettleHardLimitSeconds {
                DiagnosticsLogger.shared.playback("MDKSeekSettle", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) elapsedMs=\\(Int(elapsed * 1_000)) raw=0x\\(String(self.lastNativeStatus, radix: 16)) action=wait-native-seeking")
                self.scheduleIgnoredSeekSettleRetry(intent: intent, player: player, startedAt: startedAt)
                return
            }
            guard self.activeNativeSeek == nil else {
                DiagnosticsLogger.shared.playback("MDKSeekSettle", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) elapsedMs=\\(Int(elapsed * 1_000)) active=\\(self.activeNativeSeek?.id ?? -1) action=cancel-active-newer")
                return
            }
            var retry = intent
            retry.retryCount += 1
            retry.nativeStartedAt = nil
            retry.nativeStartFrameSerial = nil
            DiagnosticsLogger.shared.playback("MDKSeekSettle", "id=\\(intent.id) target=\\(String(format: \"%.3f\", intent.target)) elapsedMs=\\(Int(elapsed * 1_000)) raw=0x\\(String(self.lastNativeStatus, radix: 16)) action=retry-final-ignored")
            self.dispatchNativeSeek(retry, player: player)
        }
    }

    func reload(at seconds: Double) {
''',
)

engine = Path(engine_path).read_text()
identity = Path(identity_path).read_text()
assert 'private let avioRequestSizeBytes = 2 * 1_048_576' in engine
assert 'private let seekBufferMinMs: Int64 = 200' in engine
assert 'action=native-latest-wins' in engine
assert 'action=discard-superseded-frame' in engine
assert 'action=defer-ignored-settle-check' in engine
assert 'action=retry-final-ignored' in engine
assert 'action=settled-without-retry' in engine
assert 'retry-ignored-once' not in engine
assert 'sourceVersion = "0.13.41"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build108 ignored seek settle handling materialized")
