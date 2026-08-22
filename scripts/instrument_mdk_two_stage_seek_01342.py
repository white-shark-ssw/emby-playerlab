from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"missing patch anchor in {path}: {old[:260]!r}")
    p.write_text(text.replace(old, new, 1))


engine_path = "MDKLab/App/MDKKSAVIOPlayerEngine.swift"
identity_path = "Sources/Core/AppIdentity.swift"

# Build109 identity. Build108 materialization runs before this script.
replace_once(identity_path, 'sourceVersion = "0.13.41"', 'sourceVersion = "0.13.42"')

# A rapid seek burst uses keyframe preview for responsiveness, then performs one accurate
# correction after the user stops. Isolated seeks remain accurate immediately.
replace_once(
    engine_path,
    '''        var retryCount = 0
        var nativeStartedAt: TimeInterval?
        var nativeStartFrameSerial: UInt64?
''',
    '''        var retryCount = 0
        var nativeStartedAt: TimeInterval?
        var nativeStartFrameSerial: UInt64?
        var fastPreview = false
''',
)

replace_once(
    engine_path,
    '''    private let ignoredSeekSettleCheckSeconds: TimeInterval = 0.18
    private let ignoredSeekSettleHardLimitSeconds: TimeInterval = 0.72
''',
    '''    private let ignoredSeekSettleCheckSeconds: TimeInterval = 0.18
    private let ignoredSeekSettleHardLimitSeconds: TimeInterval = 0.72
    private let continuousSeekBurstThresholdSeconds: TimeInterval = 0.45
    private let continuousSeekPreciseSettleSeconds: TimeInterval = 0.28
    private var lastUserSeekRequestedAt: TimeInterval?
''',
)

replace_once(
    engine_path,
    '''        pendingSeekResume = nil
        activeNativeSeek = nil
        queuedLatestSeek = nil
        renderedFrameSerial = 0
''',
    '''        pendingSeekResume = nil
        activeNativeSeek = nil
        queuedLatestSeek = nil
        lastUserSeekRequestedAt = nil
        renderedFrameSerial = 0
''',
)

replace_once(
    engine_path,
    '''        let requestedAt = Date().timeIntervalSince1970
        let currentPlayerGeneration = generation
        seekGeneration &+= 1
        let seekID = seekGeneration
        let intent = NativeSeekIntent(id: seekID, target: target, duration: duration, requestedAt: requestedAt, direction: direction, playerGeneration: currentPlayerGeneration)
        pendingSeekResume = PendingSeekResume(id: seekID, target: target, requestedAt: requestedAt, callbackAt: nil, callbackPosition: nil, callbackFrameSerial: nil)
''',
    '''        let requestedAt = Date().timeIntervalSince1970
        let currentPlayerGeneration = generation
        let previousUserSeekAt = lastUserSeekRequestedAt
        let fastPreview = previousUserSeekAt.map { requestedAt - $0 <= continuousSeekBurstThresholdSeconds } ?? false
        lastUserSeekRequestedAt = requestedAt
        seekGeneration &+= 1
        let seekID = seekGeneration
        var intent = NativeSeekIntent(id: seekID, target: target, duration: duration, requestedAt: requestedAt, direction: direction, playerGeneration: currentPlayerGeneration)
        intent.fastPreview = fastPreview
        pendingSeekResume = PendingSeekResume(id: seekID, target: target, requestedAt: requestedAt, callbackAt: nil, callbackPosition: nil, callbackFrameSerial: nil)
        DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) mode=\\(fastPreview ? \"fast-keyframe-preview\" : \"accurate\") previousGapMs=\\(previousUserSeekAt.map { Int((requestedAt - $0) * 1_000) } ?? -1) burstThresholdMs=\\(Int(continuousSeekBurstThresholdSeconds * 1_000))")
        if fastPreview { scheduleContinuousSeekPreciseSettle(intent: intent, player: player) }
''',
)

replace_once(
    engine_path,
    '''            let immediateResult = player.seek(self.milliseconds(dispatchedIntent.target), flags: .FromStart) { [weak self, weak player] actualMs in
''',
    '''            let seekFlag: SeekFlag = dispatchedIntent.fastPreview ? .Default : .FromStart
            DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) nativeMode=\\(dispatchedIntent.fastPreview ? \"keyframe-preview\" : \"accurate\") retry=\\(dispatchedIntent.retryCount)")
            let immediateResult = player.seek(self.milliseconds(dispatchedIntent.target), flags: seekFlag) { [weak self, weak player] actualMs in
''',
)

# An ignored preview is intentionally not retried. The idle precise settle is the only correction.
replace_once(
    engine_path,
    '''                    } else if actualMs == -2, isCurrent, dispatchedIntent.retryCount < 1 {
                        if var pending = self.pendingSeekResume, pending.id == dispatchedIntent.id {
''',
    '''                    } else if actualMs == -2, isCurrent, dispatchedIntent.fastPreview {
                        if self.shouldPlay { self.requestPlayerState(playing: true, expectedPlayer: player, generation: dispatchedIntent.playerGeneration) }
                        DiagnosticsLogger.shared.playback("MDKSeek", "id=\\(dispatchedIntent.id) target=\\(String(format: \"%.3f\", dispatchedIntent.target)) callbackMs=\\(String(format: \"%.1f\", requestLatency)) nativeMs=\\(String(format: \"%.1f\", nativeLatency)) result=-2 current=true action=preview-ignored-no-retry")
                    } else if actualMs == -2, isCurrent, dispatchedIntent.retryCount < 1 {
                        if var pending = self.pendingSeekResume, pending.id == dispatchedIntent.id {
''',
)

replace_once(
    engine_path,
    '''    private func scheduleIgnoredSeekSettleRetry(intent: NativeSeekIntent, player: swift_mdk.Player, startedAt: TimeInterval) {
''',
    '''    private func scheduleContinuousSeekPreciseSettle(intent: NativeSeekIntent, player: swift_mdk.Player) {
        DispatchQueue.main.asyncAfter(deadline: .now() + continuousSeekPreciseSettleSeconds) { [weak self, weak player] in
            guard let self, let player, self.isCurrentPlayer(player, generation: intent.playerGeneration), self.pendingSeekResume?.id == intent.id, self.seekGeneration == intent.id else { return }
            let now = Date().timeIntervalSince1970
            guard let lastUserSeekRequestedAt = self.lastUserSeekRequestedAt, abs(lastUserSeekRequestedAt - intent.requestedAt) < 0.001 else { return }
            self.seekGeneration &+= 1
            let preciseID = self.seekGeneration
            var precise = NativeSeekIntent(id: preciseID, target: intent.target, duration: intent.duration, requestedAt: now, direction: intent.direction, playerGeneration: intent.playerGeneration)
            precise.fastPreview = false
            self.pendingSeekResume = PendingSeekResume(id: preciseID, target: intent.target, requestedAt: now, callbackAt: nil, callbackPosition: nil, callbackFrameSerial: nil)
            let superseded = self.activeNativeSeek?.id
            self.queuedLatestSeek = nil
            DiagnosticsLogger.shared.playback("MDKSeekPrecisionSettle", "previewID=\\(intent.id) preciseID=\\(preciseID) target=\\(String(format: \"%.3f\", intent.target)) idleMs=\\(Int((now - intent.requestedAt) * 1_000)) superseded=\\(superseded.map { String($0) } ?? \"none\") action=accurate-final-settle")
            self.dispatchNativeSeek(precise, player: player)
        }
    }

    private func scheduleIgnoredSeekSettleRetry(intent: NativeSeekIntent, player: swift_mdk.Player, startedAt: TimeInterval) {
''',
)

engine = Path(engine_path).read_text()
identity = Path(identity_path).read_text()
assert 'private let avioRequestSizeBytes = 2 * 1_048_576' in engine
assert 'private let seekBufferMinMs: Int64 = 200' in engine
assert 'action=native-latest-wins' in engine
assert 'action=defer-ignored-settle-check' in engine
assert 'fastPreview = false' in engine
assert 'fast-keyframe-preview' in engine
assert 'nativeMode=\\(dispatchedIntent.fastPreview ? "keyframe-preview" : "accurate")' in engine
assert 'MDKSeekPrecisionSettle' in engine
assert 'action=preview-ignored-no-retry' in engine
assert 'flags: seekFlag' in engine
assert 'sourceVersion = "0.13.42"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build109 MPV-style two-stage continuous seek materialized")
