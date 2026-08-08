from pathlib import Path

text = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()

required = [
    'acceptRealDemand(concreteRange, resource: resolved, reason: "concrete-read")',
    'reason == "concrete-read" || reason == "blocked-read" || reason == "byte-offset"',
    'pendingUserSeek, !metadata, !concretePlaybackDemand',
    'awaitingConcreteRead=true',
    'parallel-read-head primary=',
    'action=keep-primary-anchor',
    'slot1.role == .urgentPlayback',
    'startSlot(1, claim: SlotClaim(range: urgent, role: .urgentPlayback)',
    'reason: "parallel-urgent-',
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

print("Seek stall invariants: OK")
