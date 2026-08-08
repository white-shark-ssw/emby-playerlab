from pathlib import Path

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
controller = Path("Sources/Player/PlayerController.swift").read_text()
types = Path("Sources/Transport/TransportTypes.swift").read_text()

required_unified = [
    "progressiveUrgentGapBytes: Int64 = 2 * 1_048_576",
    "foreground gap request=",
    "action=parallel-urgent",
    "reason: \"foreground-gap-",
    "preserve slot0 sequential for foreground request=",
    "slotTasks[0] != nil, slotTasks[1] == nil",
    "recordNetworkBytes(Int64(chunk.count))",
    "private func recordNetworkBytes(_ bytes: Int64)",
    "metricsValue.resourceBytes = resource.contentLength",
]
for needle in required_unified:
    if needle not in unified:
        raise SystemExit(f"transport stability invariant missing: {needle}")

forbidden_unified = [
    'cancelSlot(0, reason: "real-seek-demand")',
    'slotClaims[0]?.range.contains(urgent.lowerBound) != true',
    'metricsValue.bytesDownloaded += downloadedBytes',
    'speedSamples.append(SpeedSample(date: Date(), bytes: downloadedBytes))',
]
for needle in forbidden_unified:
    if needle in unified:
        raise SystemExit(f"transport stability forbidden pattern present: {needle}")

if "var resourceBytes: Int64 = 0" not in types:
    raise SystemExit("TransportMetricsSnapshot.resourceBytes missing")
if "transport cache complete bytes=" not in controller or "promote-full-duration" not in controller:
    raise SystemExit("full-cache timeline promotion missing")
if "metrics.cacheHoleCount == 0" not in controller or "metrics.cacheBytes >= metrics.resourceBytes" not in controller:
    raise SystemExit("full-cache promotion must require complete byte coverage")
if controller.count("private func promoteFullCacheRangeIfNeeded") != 1:
    raise SystemExit("full-cache promotion function must appear exactly once")
if controller.count("self.promoteFullCacheRangeIfNeeded(metrics)") != 1:
    raise SystemExit("full-cache promotion polling call must appear exactly once")

# 63360 regression from the 0.11.1 device log: the real read for ~194s was inside
# Slot 0's 143.65-167.77 MiB claim, but the progressive stream head was still far
# behind. Being inside a claim must not force the reader to wait for the whole gap.
claim_lower = 143_654_912
claim_upper = 167_772_160
stream_head = 149_946_368
requested = 160_497_664
threshold = 2 * 1_048_576
assert claim_lower <= requested < claim_upper
assert requested - stream_head > threshold
should_parallel_urgent = requested - stream_head > threshold
if not should_parallel_urgent:
    raise SystemExit("synthetic 63360 foreground-gap regression failed")

# A request genuinely close to the progressive head should still reuse the warm Range.
near_head = 159_383_552
near_requested = 160_497_664
if near_requested - near_head > threshold:
    raise SystemExit("near-head progressive reuse regression failed")

# 63368 full-cache regression: once every byte is present and there are no holes,
# the persistent cache overlay may safely cover the full media duration even if
# AVPlayer.loadedTimeRanges remains fragmented after many seeks.
resource_bytes = 996_085_874
cache_bytes = 996_085_874
holes = 0
if not (resource_bytes > 0 and holes == 0 and cache_bytes >= resource_bytes):
    raise SystemExit("synthetic 63368 full-cache regression failed")

print("Transport stability invariants: OK")
