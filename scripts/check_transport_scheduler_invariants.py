from pathlib import Path

text = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()

required = [
    "private var pendingPlaybackUrgentRange: Range<Int64>?",
    "private var pendingMetadataRange: Range<Int64>?",
    "private var preferredBulkSlot = 0",
    "private func firstIdleForegroundSlot() -> Int?",
    "foreground borrow slot=",
    "preserveBulk=",
    "second foreground head borrows bulk slot=",
    "slotClaims.first(where: { $0.value.role == .sequential && $0.value.range.contains(range.lowerBound) })",
    "if slot == 1, Date() < secondaryCooldownUntil { continue }",
]

for needle in required:
    if needle not in text:
        raise SystemExit(f"transport scheduler invariant missing: {needle}")

forbidden = [
    "secondary enabled alongside urgent playback",
    "private var pendingUrgentRange: Range<Int64>?",
    "private var pendingUrgentIsMetadata",
    'cancelSlot(1, reason: metadata ? "metadata-priority" : "urgent-playback-priority")',
    "pendingPlaybackUrgentRange == nil, pendingMetadataRange == nil, slotClaims[0]?.role == .sequential",
]

for needle in forbidden:
    if needle in text:
        raise SystemExit(f"transport scheduler forbidden pattern present: {needle}")

print("Transport scheduler invariants: OK")
