from pathlib import Path

path = Path("Sources/Player/MPVPlayerEngine.swift")
text = path.read_text()
old = 'pendingSeek?.id.map(String.init) ?? "none"'
new = 'pendingSeek.map { String($0.id) } ?? "none"'
count = text.count(old)
if count not in (0, 2):
    raise SystemExit(f"Build137 optional seek id anchors: expected 0 or 2, got {count}")
if count == 2:
    text = text.replace(old, new)
path.write_text(text)
