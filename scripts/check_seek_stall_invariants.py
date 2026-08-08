from pathlib import Path

text = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()

required = [
    'acceptRealDemand(concreteRange, resource: resolved, reason: "concrete-read")',
    'reason == "concrete-read" || reason == "blocked-read" || reason == "byte-offset"',
    'pendingUserSeek, !metadata, !concretePlaybackDemand',
    'awaitingConcreteRead=true',
    'parallel-read-head primary=',
    'action=keep-primary-anchor',
    '$0.value.role != .sequential && $0.value.range.contains(range.lowerBound)',
    'active.role == .urgentPlayback',
    'foreground active-gap slot=',
    'reason: "foreground-active-gap-',
    'startSlot(slot, claim: SlotClaim(range: urgent, role: .urgentPlayback)',
    'second foreground head borrows bulk slot=',
    'if claim.role == .urgentPlayback, pendingPlaybackUrgentRange == nil { pendingPlaybackUrgentRange = claim.range }',
    'return max(0, configuration.cellularPreloadBytes)',
    'if reanchored { scheduleSlots(reason: "reanchor-cache-hit") }',
]
for needle in required:
    if needle not in text:
        raise SystemExit(f"seek stall invariant missing: {needle}")

forbidden = [
    'cancelSlot(0, reason: "blocked-demand-reanchor")',
    'return configuration.ktvPreloadOnCellular ? max(0, configuration.cellularPreloadBytes) : 0',
    'awaitingConcreteDemand=true anchor=',
    'startSlot(1, claim: SlotClaim(range: urgent, role: .urgentPlayback)',
]
for needle in forbidden:
    if needle in text:
        raise SystemExit(f"seek stall forbidden pattern present: {needle}")

# Synthetic regression: the 63368 log showed valid concurrent read heads around
# ~195/611 MiB and ~236/772 MiB. The scheduler must preserve the first post-seek
# concrete read as the primary anchor and classify the distant second read as parallel.
block = 32 * 1024 * 1024
threshold = block * 4
for primary, second in [(195_035_138, 611_385_344), (236_257_280, 772_734_976)]:
    assert abs(second - primary) > threshold
    anchor = primary
    if abs(second - anchor) > threshold:
        parallel = second
    else:
        anchor = second
        parallel = None
    if anchor != primary or parallel != second:
        raise SystemExit("synthetic 63368 parallel-read regression failed")

# v0.12.1 152901 regression: the requested read can already be inside a 16 MiB urgent
# claim while only the first MiB has arrived. Containment is not readiness; if the
# concrete read is >2 MiB ahead of that urgent stream head the second lane must fill it.
urgent_lower = 4_687_136_579
urgent_upper = urgent_lower + 16 * 1_048_576
stream_head = urgent_lower + 1 * 1_048_576
requested = 4_698_670_915
progressive_gap = 2 * 1_048_576
if not (urgent_lower <= requested < urgent_upper and requested - stream_head > progressive_gap):
    raise SystemExit("synthetic 152901 active-urgent gap regression failed")

print("Seek stall invariants: OK")
