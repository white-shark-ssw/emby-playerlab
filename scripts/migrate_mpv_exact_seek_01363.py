from pathlib import Path

path = Path("Sources/Player/MPVPlayerEngine.swift")
text = path.read_text()

hr_anchor = 'check(mpv_set_option_string(handle, "hr-seek", "no"), operation: "disable precise seek")'
if text.count(hr_anchor) != 1:
    raise SystemExit(f"expected one hr-seek anchor, found {text.count(hr_anchor)}")
text = text.replace(hr_anchor, hr_anchor + '\n        check(mpv_set_option_string(handle, "hr-seek-framedrop", "yes"), operation: "enable precise seek frame drop")', 1)

mode_anchor = 'let mode = "absolute+keyframes"'
if text.count(mode_anchor) != 1:
    raise SystemExit(f"expected one MPV keyframe seek mode, found {text.count(mode_anchor)}")
text = text.replace(mode_anchor, 'let mode = "absolute+exact"', 1)

log_anchor = 'mode=\\(mode) bufferHit='
if text.count(log_anchor) != 1:
    raise SystemExit(f"expected one MPV dispatch log marker, found {text.count(log_anchor)}")
text = text.replace(log_anchor, 'mode=\\(mode) hrSeekDefault=no exactCommandOverride=true hrSeekFrameDrop=yes bufferHit=', 1)

path.write_text(text)
final = path.read_text()
assert 'let mode = "absolute+exact"' in final
assert 'hr-seek-framedrop", "yes"' in final
assert 'exactCommandOverride=true' in final
assert 'let mode = "absolute+keyframes"' not in final
print("Applied OnePlayer Build130 MPV absolute+exact seek experiment")
