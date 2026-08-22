from pathlib import Path

path = Path("Sources/Player/MPVPlayerEngine.swift")
text = path.read_text()

old_hr = '        check(mpv_set_option_string(handle, "hr-seek", "no"), operation: "disable precise seek")\n'
new_hr = old_hr + '        check(mpv_set_option_string(handle, "hr-seek-framedrop", "yes"), operation: "enable precise seek frame drop")\n'
if text.count(old_hr) != 1:
    raise SystemExit(f"expected one hr-seek anchor, found {text.count(old_hr)}")
text = text.replace(old_hr, new_hr, 1)

old_mode = '                let mode = "absolute+keyframes"\n'
new_mode = '                let mode = "absolute+exact"\n'
if text.count(old_mode) != 1:
    raise SystemExit(f"expected one MPV keyframe seek mode, found {text.count(old_mode)}")
text = text.replace(old_mode, new_mode, 1)

old_dispatch_log = '                DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=native-dispatch prioritizeMs=\\(String(format: \"%.1f\", (prioritizedAt - requestedAt) * 1000)) dispatchMs=\\(String(format: \"%.1f\", (dispatchAt - requestedAt) * 1000)) mode=\\(mode) bufferHit=\\(bufferHit) enginePosition=\\(String(format: \"%.3f\", self.snapshot.position))")\n'
new_dispatch_log = '                DiagnosticsLogger.shared.log("MPVSeek", "id=\\(seekID) target=\\(String(format: \"%.3f\", target)) phase=native-dispatch prioritizeMs=\\(String(format: \"%.1f\", (prioritizedAt - requestedAt) * 1000)) dispatchMs=\\(String(format: \"%.1f\", (dispatchAt - requestedAt) * 1000)) mode=\\(mode) hrSeekDefault=no exactCommandOverride=true hrSeekFrameDrop=yes bufferHit=\\(bufferHit) enginePosition=\\(String(format: \"%.3f\", self.snapshot.position))")\n'
if text.count(old_dispatch_log) != 1:
    raise SystemExit(f"expected one MPV dispatch log anchor, found {text.count(old_dispatch_log)}")
text = text.replace(old_dispatch_log, new_dispatch_log, 1)

old_landing = '                let delta = actualPosition - pending.target\n                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) actual=\\(String(format: \"%.3f\", actualPosition)) delta=\\(String(format: \"%.3f\", delta)) completionMs=\\(String(format: \"%.1f\", latency)) bufferHit=\\(pending.bufferHit) event=playback-restart")\n'
new_landing = '                let delta = actualPosition - pending.target\n                let avsync = self.getStringProperty(handle: handle, name: "avsync") ?? "nil"\n                let decoderDrops = self.integerProperty(handle: handle, name: "decoder-frame-drop-count")\n                let voDrops = self.integerProperty(handle: handle, name: "frame-drop-count")\n                DiagnosticsLogger.shared.log("MPVSeekLanding", "id=\\(pending.id) target=\\(String(format: \"%.3f\", pending.target)) actual=\\(String(format: \"%.3f\", actualPosition)) delta=\\(String(format: \"%.3f\", delta)) completionMs=\\(String(format: \"%.1f\", latency)) bufferHit=\\(pending.bufferHit) event=playback-restart avsync=\\(avsync) decoderDrops=\\(decoderDrops) voDrops=\\(voDrops) mode=absolute+exact")\n'
if text.count(old_landing) != 1:
    raise SystemExit(f"expected one MPV landing log anchor, found {text.count(old_landing)}")
text = text.replace(old_landing, new_landing, 1)

path.write_text(text)
final = path.read_text()
assert 'let mode = "absolute+exact"' in final
assert 'hr-seek-framedrop", "yes"' in final
assert 'exactCommandOverride=true' in final
assert 'mode=absolute+exact' in final
assert 'let mode = "absolute+keyframes"' not in final
print("Applied OnePlayer Build130 MPV absolute+exact seek experiment")
