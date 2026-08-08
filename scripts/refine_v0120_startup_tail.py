from pathlib import Path

path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = path.read_text()
old = '''        if let metadata = pendingMetadataRange, !store.contains(metadata), let slot = firstIdleForegroundSlot() {
            pendingMetadataRange = nil
            startSlot(slot, claim: SlotClaim(range: metadata, role: .metadata), reason: "metadata-\\(reason)")
        }
'''
new = '''        if let metadata = pendingMetadataRange, !isStartupTailMetadata(metadata, resource: resource), !store.contains(metadata), let slot = firstIdleForegroundSlot() {
            pendingMetadataRange = nil
            startSlot(slot, claim: SlotClaim(range: metadata, role: .metadata), reason: "metadata-\\(reason)")
        }
'''
if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit("generic metadata scheduler target missing")
path.write_text(text)
print("startup tail ordering refinement applied")
