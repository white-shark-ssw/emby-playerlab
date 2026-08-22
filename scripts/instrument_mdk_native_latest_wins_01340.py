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

# Build107 identity. Build106 materialization runs before this script.
replace_once(identity_path, 'sourceVersion = "0.13.39"', 'sourceVersion = "0.13.40"')

# MDK 0.38.0 already supports frequent seeking and guarantees the latest request is processed.
# Do not serialize user double-taps behind the previous native seek callback. Every new target
# immediately supersedes the previous active intent; stale callbacks are already rejected by seekID.
replace_once(
    engine_path,
    '''        if let activeNativeSeek {
            let replaced = queuedLatestSeek?.id
            queuedLatestSeek = intent
            DiagnosticsLogger.shared.playback("MDKSeekCoalesce", "latest=\\(seekID) target=\\(String(format: \"%.3f\", target)) active=\\(activeNativeSeek.id) replacedQueued=\\(replaced.map { String($0) } ?? \"none\") action=latest-wins")
        } else {
            dispatchNativeSeek(intent, player: player)
        }
''',
    '''        let supersededNativeSeekID = activeNativeSeek?.id
        queuedLatestSeek = nil
        if let supersededNativeSeekID = supersededNativeSeekID {
            DiagnosticsLogger.shared.playback("MDKSeekPreempt", "latest=\\(seekID) target=\\(String(format: \"%.3f\", target)) superseded=\\(supersededNativeSeekID) action=native-latest-wins")
        }
        dispatchNativeSeek(intent, player: player)
''',
)

# With overlapping native seeks, a late frame from a superseded request must never satisfy the
# newest seek completion. Only accept a rendered frame that is actually near the newest target.
replace_once(
    engine_path,
    '''        guard let pending = pendingSeekResume, let callbackAt = pending.callbackAt, let callbackFrameSerial = pending.callbackFrameSerial, renderedFrameSerial > callbackFrameSerial else { return }
        let now = Date().timeIntervalSince1970
''',
    '''        guard let pending = pendingSeekResume, let callbackAt = pending.callbackAt, let callbackFrameSerial = pending.callbackFrameSerial, renderedFrameSerial > callbackFrameSerial else { return }
        guard abs(renderResult - pending.target) <= 1.0 else {
            DiagnosticsLogger.shared.playback("MDKSeekFrame", "id=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) renderTimestamp=\\(String(format: \"%.6f\", renderResult)) action=discard-superseded-frame")
            return
        }
        let now = Date().timeIntervalSince1970
''',
)

engine = Path(engine_path).read_text()
identity = Path(identity_path).read_text()
assert 'private let avioRequestSizeBytes = 2 * 1_048_576' in engine
assert 'private let seekBufferMinMs: Int64 = 200' in engine
assert 'reason=seek-settle-window graceMs=' in engine
assert 'phase=first-frame-grace' in engine
assert 'flags: .FromStart' in engine
assert 'action=native-latest-wins' in engine
assert 'MDKSeekPreempt' in engine
assert 'action=discard-superseded-frame' in engine
assert 'queuedLatestSeek = intent' not in engine
assert 'sourceVersion = "0.13.40"' in identity
assert 'iOS: "15.0"' in Path("project.mdklab.yml").read_text()
print("Build107 MDK native latest-wins frequent seek materialized")
