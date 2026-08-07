from pathlib import Path

p = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = p.read_text()
old = "if let metadata = pendingMetadataRange, Int64(metadata.count) <= secondaryMetadataMaxBytes, !store.contains(metadata), slotClaims[0]?.role == .urgentPlayback, slotTasks[1] == nil {"
new = "if let metadata = pendingMetadataRange, Int64(metadata.count) <= secondaryMetadataMaxBytes, !store.contains(metadata), Date() >= secondaryCooldownUntil, slotClaims[0]?.role == .urgentPlayback, slotTasks[1] == nil {"
if old in text:
    p.write_text(text.replace(old, new, 1))
elif new not in text:
    raise SystemExit("tiny metadata Slot 1 gate not found")
