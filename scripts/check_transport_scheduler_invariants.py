from pathlib import Path

path = Path("Sources/Transport/UnifiedMediaTransportSession.swift")
text = path.read_text()

required = [
    "private var pendingPlaybackUrgentRange: Range<Int64>?",
    "private var pendingMetadataRange: Range<Int64>?",
    "private let secondaryMetadataMaxBytes: Int64 = 2 * 1_048_576",
    'cancelSlot(1, reason: metadata ? "metadata-priority" : "urgent-playback-priority")',
    "pendingPlaybackUrgentRange == nil, pendingMetadataRange == nil, slotClaims[0]?.role == .sequential",
    "Int64(metadata.count) <= secondaryMetadataMaxBytes",
    "Date() >= secondaryCooldownUntil",
]

for needle in required:
    if needle not in text:
        raise SystemExit(f"transport scheduler invariant missing: {needle}")

forbidden = [
    "secondary enabled alongside urgent playback",
    "private var pendingUrgentRange: Range<Int64>?",
    "private var pendingUrgentIsMetadata",
    "may overlap safely in the sparse store",
]

for needle in forbidden:
    if needle in text:
        raise SystemExit(f"transport scheduler forbidden pattern present: {needle}")

print("Transport scheduler invariants: OK")
