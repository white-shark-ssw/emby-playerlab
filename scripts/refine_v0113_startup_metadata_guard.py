from pathlib import Path

path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = path.read_text()
old = '''        guard !range.isEmpty, Date().timeIntervalSince(createdAt) < 35, playbackAnchor == 0 else { return false }
        guard source.mediaSource.normalizedContainer == "mp4", resource.contentLength >= 4 * 1_073_741_824 else { return false }
'''
new = '''        guard !range.isEmpty, Date().timeIntervalSince(createdAt) < 35, playbackAnchor == 0, Date() > pendingUserSeekUntil else { return false }
        guard source.mediaSource.normalizedContainer == "mp4", resource.contentLength >= 4 * 1_073_741_824 else { return false }
'''
if new not in text:
    if old not in text:
        raise SystemExit("startup metadata guard target missing")
    path.write_text(text.replace(old, new, 1))
print("v0.11.3 startup metadata user-seek guard applied")
