from pathlib import Path

app = Path('Sources/Core/AppIdentity.swift')
text = app.read_text()
if '"0.13.68"' not in text:
    if text.count('"0.13.67"') != 2:
        raise SystemExit('AppIdentity version anchor mismatch')
    app.write_text(text.replace('"0.13.67"', '"0.13.68"'))

engine = Path('Sources/Player/MPVPlayerEngine.swift')
text = engine.read_text()

marker = '    private var seekGeneration: UInt64 = 0\n'
addition = '''    private var seekGeneration: UInt64 = 0
    private var residualRefineSeekID: UInt64?
    private var residualPrimaryLanding: Double?
    private var residualPrimaryCompletionMs: Double?
    private var residualRefineStartedAt: TimeInterval?
    private var latestNativeSeekDispatchID: UInt64?
    private static let residualRefineMinSeconds = 0.050
    private static let residualRefineMaxSeconds = 1.250
'''
if 'private static let residualRefineMaxSeconds = 1.250' not in text:
    if text.count(marker) != 1:
        raise SystemExit('seekGeneration anchor mismatch')
    text = text.replace(marker, addition, 1)

old_reset = '''        let requestedAt = CACurrentMediaTime()
        pendingSeek = PendingSeek(id: seekID, requestedAt: requestedAt, target: target, bufferHit: bufferHit, intent: intent, mode: mode)
'''
new_reset = '''        let requestedAt = CACurrentMediaTime()
        residualRefineSeekID = nil
        residualPrimaryLanding = nil
        residualPrimaryCompletionMs = nil
        residualRefineStartedAt = nil
        latestNativeSeekDispatchID = nil
        pendingSeek = PendingSeek(id: seekID, requestedAt: requestedAt, target: target, bufferHit: bufferHit, intent: intent, mode: mode)
'''
if 'residualRefineSeekID = nil\n        residualPrimaryLanding = nil' not in text:
    if text.count(old_reset) != 1:
        raise SystemExit('interactive seek reset anchor mismatch')
    text = text.replace(old_reset, new_reset, 1)

old_dispatch = '''                let dispatchAt = CACurrentMediaTime()
                DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: "%.3f", target)) phase=native-dispatch prioritizeMs=\\(String(format: "%.1f", (prioritizedAt - requestedAt) * 1000)) dispatchMs=\\(String(format: "%.1f", (dispatchAt - requestedAt) * 1000)) intent=\\(intent) mode=\\(mode) bufferHit=\\(bufferHit) enginePosition=\\(String(format: "%.3f", self.snapshot.position))")
'''
new_dispatch = '''                let dispatchAt = CACurrentMediaTime()
                self.latestNativeSeekDispatchID = seekID
                DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: "%.3f", target)) phase=native-dispatch prioritizeMs=\\(String(format: "%.1f", (prioritizedAt - requestedAt) * 1000)) dispatchMs=\\(String(format: "%.1f", (dispatchAt - requestedAt) * 1000)) intent=\\(intent) mode=\\(mode) bufferHit=\\(bufferHit) enginePosition=\\(String(format: "%.3f", self.snapshot.position))")
'''
if 'self.latestNativeSeekDispatchID = seekID' not in text:
    if text.count(old_dispatch) != 1:
        raise SystemExit('native dispatch anchor mismatch')
    text = text.replace(old_dispatch, new_dispatch, 1)

old_landing = '''            if let pending = pendingSeek {
                pendingSeek = nil
                let latency = (CACurrentMediaTime() - pending.requestedAt) * 1000
                let delta = actualPosition - pending.target
                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\\(pending.id) target=\\(String(format: "%.3f", pending.target)) actual=\\(String(format: "%.3f", actualPosition)) delta=\\(String(format: "%.3f", delta)) completionMs=\\(String(format: "%.1f", latency)) bufferHit=\\(pending.bufferHit) intent=\\(pending.intent) mode=\\(pending.mode) event=playback-restart")
                DispatchQueue.main.async { [weak self] in
                    self?.onSeekCompleted?(SeekResult(
                        requestedAt: pending.requestedAt,
                        target: pending.target,
                        actualPosition: actualPosition,
                        bufferHit: pending.bufferHit,
                        completionLatencyMs: latency,
                        measurement: "MPV playback-restart after latest seek"
                    ))
                }
            } else {
                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=none actual=\\(String(format: "%.3f", actualPosition)) event=playback-restart-without-pending")
            }
'''
new_landing = '''            if let pending = pendingSeek {
                let now = CACurrentMediaTime()
                if pending.id > 0, residualRefineSeekID != pending.id, latestNativeSeekDispatchID != pending.id {
                    DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\\(pending.id) actual=\\(String(format: "%.3f", actualPosition)) event=playback-restart-before-latest-native-dispatch ignored=true")
                    emitOnMain()
                    return
                }

                if residualRefineSeekID == pending.id {
                    pendingSeek = nil
                    let totalLatency = (now - pending.requestedAt) * 1000
                    let refineLatency = residualRefineStartedAt.map { (now - $0) * 1000 } ?? 0
                    let finalDelta = actualPosition - pending.target
                    DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\\(pending.id) target=\\(String(format: "%.3f", pending.target)) actual=\\(String(format: "%.3f", actualPosition)) delta=\\(String(format: "%.3f", finalDelta)) completionMs=\\(String(format: "%.1f", totalLatency)) bufferHit=\\(pending.bufferHit) intent=\\(pending.intent) mode=absolute+exact stage=refined event=playback-restart")
                    DiagnosticsLogger.shared.log("MPVSeekRefine", "id=\\(pending.id) phase=complete primaryLanding=\\(residualPrimaryLanding.map { String(format: "%.3f", $0) } ?? "none") primaryMs=\\(residualPrimaryCompletionMs.map { String(format: "%.1f", $0) } ?? "none") final=\\(String(format: "%.3f", actualPosition)) finalDelta=\\(String(format: "%.3f", finalDelta)) refineMs=\\(String(format: "%.1f", refineLatency)) totalMs=\\(String(format: "%.1f", totalLatency))")
                    residualRefineSeekID = nil
                    residualPrimaryLanding = nil
                    residualPrimaryCompletionMs = nil
                    residualRefineStartedAt = nil
                    latestNativeSeekDispatchID = nil
                    DispatchQueue.main.async { [weak self] in
                        self?.onSeekCompleted?(SeekResult(requestedAt: pending.requestedAt, target: pending.target, actualPosition: actualPosition, bufferHit: pending.bufferHit, completionLatencyMs: totalLatency, measurement: "MPV keyframe landing + bounded absolute exact residual refinement"))
                    }
                } else if pending.id == 0 {
                    pendingSeek = nil
                    let latency = (now - pending.requestedAt) * 1000
                    let delta = actualPosition - pending.target
                    DiagnosticsLogger.shared.log("MPVSeekLanding", "id=0 target=\\(String(format: "%.3f", pending.target)) actual=\\(String(format: "%.3f", actualPosition)) delta=\\(String(format: "%.3f", delta)) completionMs=\\(String(format: "%.1f", latency)) intent=\\(pending.intent) mode=\\(pending.mode) stage=startup event=playback-restart")
                    DispatchQueue.main.async { [weak self] in
                        self?.onSeekCompleted?(SeekResult(requestedAt: pending.requestedAt, target: pending.target, actualPosition: actualPosition, bufferHit: pending.bufferHit, completionLatencyMs: latency, measurement: "MPV startup playback-restart"))
                    }
                } else {
                    let primaryLatency = (now - pending.requestedAt) * 1000
                    let residual = pending.target - actualPosition
                    let delta = actualPosition - pending.target
                    let eligible = residual > Self.residualRefineMinSeconds && residual <= Self.residualRefineMaxSeconds
                    DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\\(pending.id) target=\\(String(format: "%.3f", pending.target)) actual=\\(String(format: "%.3f", actualPosition)) delta=\\(String(format: "%.3f", delta)) completionMs=\\(String(format: "%.1f", primaryLatency)) bufferHit=\\(pending.bufferHit) intent=\\(pending.intent) mode=\\(pending.mode) stage=primary event=playback-restart")
                    DiagnosticsLogger.shared.log("MPVSeekRefine", "id=\\(pending.id) phase=consider target=\\(String(format: "%.3f", pending.target)) keyframeLanding=\\(String(format: "%.3f", actualPosition)) residual=\\(String(format: "%.3f", residual)) eligible=\\(eligible) primaryMs=\\(String(format: "%.1f", primaryLatency))")
                    if eligible {
                        residualRefineSeekID = pending.id
                        residualPrimaryLanding = actualPosition
                        residualPrimaryCompletionMs = primaryLatency
                        residualRefineStartedAt = now
                        DiagnosticsLogger.shared.log("MPVSeekRefine", "id=\\(pending.id) phase=native-dispatch residual=\\(String(format: "%.3f", residual)) mode=absolute+exact target=\\(String(format: "%.3f", pending.target))")
                        emitOnMain()
                        command(handle, ["seek", String(format: "%.3f", pending.target), "absolute+exact"])
                        return
                    }
                    pendingSeek = nil
                    latestNativeSeekDispatchID = nil
                    let skipReason = residual <= Self.residualRefineMinSeconds ? "already-frame-close-or-past" : "residual-over-cap"
                    DiagnosticsLogger.shared.log("MPVSeekRefine", "id=\\(pending.id) phase=skip reason=\\(skipReason) residual=\\(String(format: "%.3f", residual)) finalDelta=\\(String(format: "%.3f", delta)) totalMs=\\(String(format: "%.1f", primaryLatency))")
                    DispatchQueue.main.async { [weak self] in
                        self?.onSeekCompleted?(SeekResult(requestedAt: pending.requestedAt, target: pending.target, actualPosition: actualPosition, bufferHit: pending.bufferHit, completionLatencyMs: primaryLatency, measurement: "MPV keyframe landing; residual refine skipped"))
                    }
                }
            } else {
                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=none actual=\\(String(format: "%.3f", actualPosition)) event=playback-restart-without-pending")
            }
'''
if 'phase=complete primaryLanding=' not in text:
    if text.count(old_landing) != 1:
        raise SystemExit(f'playback restart anchor mismatch: {text.count(old_landing)}')
    text = text.replace(old_landing, new_landing, 1)

engine.write_text(text)
