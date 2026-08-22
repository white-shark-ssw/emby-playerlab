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

# Build114 identity. Build113 materialization runs before this script.
replace_once(identity_path, 'sourceVersion = "0.13.46"', 'sourceVersion = "0.13.47"')

# User-visible seek is always fast-first. Do not classify human double-tap cadence using
# a 450 ms threshold. Every user seek dispatches a keyframe preview immediately; the
# existing 550 ms idle-settle mechanism performs one accurate correction only after no
# newer user seek has arrived. New input still supersedes prior work immediately.
replace_once(
    engine_path,
    '''    private let continuousSeekBurstThresholdSeconds: TimeInterval = 0.45\n    private let continuousSeekPreciseSettleSeconds: TimeInterval = 0.55\n''',
    '''    private let continuousSeekPreciseSettleSeconds: TimeInterval = 0.55\n''',
)

replace_once(
    engine_path,
    '''        let previousUserSeekAt = lastUserSeekRequestedAt\n        let fastPreview = previousUserSeekAt.map { requestedAt - $0 <= continuousSeekBurstThresholdSeconds } ?? false\n        lastUserSeekRequestedAt = requestedAt\n        seekGeneration &+= 1\n        let seekID = seekGeneration\n        var intent = NativeSeekIntent(id: seekID, target: target, duration: duration, requestedAt: requestedAt, direction: direction, playerGeneration: currentPlayerGeneration)\n        intent.fastPreview = fastPreview\n        pendingSeekResume = PendingSeekResume(id: seekID, target: target, requestedAt: requestedAt, callbackAt: nil, callbackPosition: nil, callbackFrameSerial: nil)\n        DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) mode=\\(fastPreview ? \"fast-keyframe-preview\" : \"accurate\") previousGapMs=\\(previousUserSeekAt.map { Int((requestedAt - $0) * 1_000) } ?? -1) burstThresholdMs=\\(Int(continuousSeekBurstThresholdSeconds * 1_000))")\n        if fastPreview { scheduleContinuousSeekPreciseSettle(intent: intent, player: player) }\n''',
    '''        let previousUserSeekAt = lastUserSeekRequestedAt\n        let fastPreview = true\n        lastUserSeekRequestedAt = requestedAt\n        seekGeneration &+= 1\n        let seekID = seekGeneration\n        var intent = NativeSeekIntent(id: seekID, target: target, duration: duration, requestedAt: requestedAt, direction: direction, playerGeneration: currentPlayerGeneration)\n        intent.fastPreview = fastPreview\n        pendingSeekResume = PendingSeekResume(id: seekID, target: target, requestedAt: requestedAt, callbackAt: nil, callbackPosition: nil, callbackFrameSerial: nil)\n        DiagnosticsLogger.shared.playback("MDKSeekMode", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) mode=fast-first-keyframe previousGapMs=\\(previousUserSeekAt.map { Int((requestedAt - $0) * 1_000) } ?? -1) settleIdleMs=\\(Int(continuousSeekPreciseSettleSeconds * 1_000))")\n        scheduleContinuousSeekPreciseSettle(intent: intent, player: player)\n''',
)

engine = Path(engine_path).read_text()
identity = Path(identity_path).read_text()
assert 'private let continuousSeekPreciseSettleSeconds: TimeInterval = 0.55' in engine
assert 'continuousSeekBurstThresholdSeconds' not in engine
assert 'let fastPreview = true' in engine
assert 'mode=fast-first-keyframe' in engine
assert 'scheduleContinuousSeekPreciseSettle(intent: intent, player: player)' in engine
assert 'let seekFlag: SeekFlag = dispatchedIntent.fastPreview ? .Default : .FromStart' in engine
assert 'MDKSeekPrecisionSettle' in engine
assert 'action=native-latest-wins' in engine
assert 'private var avioRequestSize2MiBEnabled: Bool' in engine
assert 'sourceVersion = "0.13.47"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build114 MDK user seek fast-first experiment materialized")
