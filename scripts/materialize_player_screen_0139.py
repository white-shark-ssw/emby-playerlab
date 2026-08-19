from pathlib import Path

path = Path("Sources/UI/PlayerScreen.swift")
text = path.read_text()
old = """                    bufferState: controller.bufferState,\n                    onEditingChanged: { editing in\n"""
new = """                    bufferState: controller.bufferState,\n                    cacheByteRanges: controller.transportCacheRanges,\n                    onEditingChanged: { editing in\n"""
if new in text:
    print("PlayerScreen cache byte ranges already materialized")
elif old in text:
    path.write_text(text.replace(old, new, 1))
    print("PlayerScreen cache byte ranges materialized")
else:
    raise SystemExit("PlayerScreen timeline initializer anchor not found")
