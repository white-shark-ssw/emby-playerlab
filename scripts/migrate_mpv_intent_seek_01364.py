from pathlib import Path

path = Path("Sources/Player/MPVPlayerEngine.swift")
text = path.read_text()

if 'intent=doubleTapFastSeek' in text and 'scrubReleasePreciseSeek' in text:
    print("Build131 MPV intent seek policy already applied")
    raise SystemExit(0)

old_pending = '''    private struct PendingSeek {
        let id: UInt64
        let requestedAt: TimeInterval
        let target: Double
        let bufferHit: Bool
    }
'''
new_pending = '''    private struct PendingSeek {
        let id: UInt64
        let requestedAt: TimeInterval
        let target: Double
        let bufferHit: Bool
        let intent: String
        let mode: String
    }
'''
if text.count(old_pending) != 1:
    raise SystemExit(f"expected one PendingSeek block, found {text.count(old_pending)}")
text = text.replace(old_pending, new_pending, 1)

old_seek_head = '''        let bufferHit = snapshot.bufferedRanges.contains(where: { $0.contains(target) })
        seekGeneration &+= 1
        let seekID = seekGeneration
        let requestedAt = CACurrentMediaTime()
        pendingSeek = PendingSeek(id: seekID, requestedAt: requestedAt, target: target, bufferHit: bufferHit)
        DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=request bufferHit=\\(bufferHit) enginePosition=\\(String(format: \"%.3f\", snapshot.position)) direction=\\(String(describing: direction))")
'''
new_seek_head = '''        let bufferHit = snapshot.bufferedRanges.contains(where: { $0.contains(target) })
        let intent: String
        let mode: String
        switch direction {
        case .forward, .backward:
            intent = "doubleTapFastSeek"
            mode = "absolute+keyframes"
        case .absolute:
            intent = "scrubReleasePreciseSeek"
            mode = "absolute+exact"
        }
        seekGeneration &+= 1
        let seekID = seekGeneration
        let requestedAt = CACurrentMediaTime()
        pendingSeek = PendingSeek(id: seekID, requestedAt: requestedAt, target: target, bufferHit: bufferHit, intent: intent, mode: mode)
        DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=request intent=\\(intent) mode=\\(mode) bufferHit=\\(bufferHit) enginePosition=\\(String(format: \"%.3f\", snapshot.position)) direction=\\(String(describing: direction))")
'''
if text.count(old_seek_head) != 1:
    raise SystemExit(f"expected one MPV seek head, found {text.count(old_seek_head)}")
text = text.replace(old_seek_head, new_seek_head, 1)

old_dispatch = '''                let mode = "absolute+keyframes"
                let dispatchAt = CACurrentMediaTime()
                DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=native-dispatch prioritizeMs=\\(String(format: \"%.1f\", (prioritizedAt - requestedAt) * 1000)) dispatchMs=\\(String(format: \"%.1f\", (dispatchAt - requestedAt) * 1000)) mode=\\(mode) bufferHit=\\(bufferHit) enginePosition=\\(String(format: \"%.3f\", self.snapshot.position))")
                self.command(handle, ["seek", String(format: "%.3f", target), mode])
'''
new_dispatch = '''                let dispatchAt = CACurrentMediaTime()
                DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=native-dispatch prioritizeMs=\\(String(format: \"%.1f\", (prioritizedAt - requestedAt) * 1000)) dispatchMs=\\(String(format: \"%.1f\", (dispatchAt - requestedAt) * 1000)) intent=\\(intent) mode=\\(mode) bufferHit=\\(bufferHit) enginePosition=\\(String(format: \"%.3f\", self.snapshot.position))")
                self.command(handle, ["seek", String(format: "%.3f", target), mode])
'''
if text.count(old_dispatch) != 1:
    raise SystemExit(f"expected one MPV dispatch block, found {text.count(old_dispatch)}")
text = text.replace(old_dispatch, new_dispatch, 1)

old_landing = '''                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) actual=\\(String(format: \"%.3f\", actualPosition)) delta=\\(String(format: \"%.3f\", delta)) completionMs=\\(String(format: \"%.1f\", latency)) bufferHit=\\(pending.bufferHit) event=playback-restart")
'''
new_landing = '''                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) actual=\\(String(format: \"%.3f\", actualPosition)) delta=\\(String(format: \"%.3f\", delta)) completionMs=\\(String(format: \"%.1f\", latency)) bufferHit=\\(pending.bufferHit) intent=\\(pending.intent) mode=\\(pending.mode) event=playback-restart")
'''
if text.count(old_landing) != 1:
    raise SystemExit(f"expected one MPV landing log, found {text.count(old_landing)}")
text = text.replace(old_landing, new_landing, 1)

hr_anchor = '        check(mpv_set_option_string(handle, "hr-seek", "no"), operation: "disable precise seek")\n'
hr_drop = '        check(mpv_set_option_string(handle, "hr-seek-framedrop", "yes"), operation: "enable precise seek frame drop")\n'
if text.count(hr_anchor) != 1:
    raise SystemExit(f"expected one hr-seek anchor, found {text.count(hr_anchor)}")
if hr_drop not in text:
    text = text.replace(hr_anchor, hr_anchor + hr_drop, 1)

path.write_text(text)
final = path.read_text()
assert 'intent = "doubleTapFastSeek"' in final
assert 'mode = "absolute+keyframes"' in final
assert 'intent = "scrubReleasePreciseSeek"' in final
assert 'mode = "absolute+exact"' in final
assert 'intent=\\(pending.intent) mode=\\(pending.mode)' in final
assert 'hr-seek-framedrop", "yes"' in final
print("Applied OnePlayer Build131 MPV intent-aware Seek policy")
