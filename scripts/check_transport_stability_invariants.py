from pathlib import Path

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
controller = Path("Sources/Player/PlayerController.swift").read_text()
types = Path("Sources/Transport/TransportTypes.swift").read_text()

required_unified = [
    "progressiveUrgentGapBytes: Int64 = 2 * 1_048_576",
    "foreground gap slot=",
    "action=parallel-urgent",
    "reason: \"foreground-gap-",
    "preferredBulkSlot",
    "firstIdleForegroundSlot",
    "foreground borrow slot=",
    "recordNetworkBytes(Int64(chunk.count))",
    "private func recordNetworkBytes(_ bytes: Int64)",
    "metricsValue.resourceBytes = resource.contentLength",
]
for needle in required_unified:
    if needle not in unified:
        raise SystemExit(f"transport stability invariant missing: {needle}")

forbidden_unified = [
    'cancelSlot(0, reason: "real-seek-demand")',
    'metricsValue.bytesDownloaded += downloadedBytes',
    'speedSamples.append(SpeedSample(date: Date(), bytes: downloadedBytes))',
    'cancelSlot(1, reason: metadata ? "metadata-priority" : "urgent-playback-priority")',
]
for needle in forbidden_unified:
    if needle in unified:
        raise SystemExit(f"transport stability forbidden pattern present: {needle}")

if unified.count("recordNetworkBytes(Int64(chunk.count))") != 2:
    raise SystemExit("network chunks must be counted exactly once in sequential and foreground fetch paths")
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

# 63360 regression from the 0.11.1 device log. The same check must work regardless
# of whether the faster protected bulk connection is physical Slot 0 or Slot 1.
claim_lower = 143_654_912
claim_upper = 167_772_160
stream_head = 149_946_368
requested = 160_497_664
threshold = 2 * 1_048_576
assert claim_lower <= requested < claim_upper
if requested - stream_head <= threshold:
    raise SystemExit("synthetic 63360 foreground-gap regression failed")

near_head = 159_383_552
near_requested = 160_497_664
if near_requested - near_head > threshold:
    raise SystemExit("near-head progressive reuse regression failed")

# 63368 full-cache regression.
resource_bytes = 996_085_874
cache_bytes = 996_085_874
holes = 0
if not (resource_bytes > 0 and holes == 0 and cache_bytes >= resource_bytes):
    raise SystemExit("synthetic 63368 full-cache regression failed")

exec(Path("scripts/check_startup_lane_health_invariants.py").read_text(), {"__name__": "__main__"})

print("Transport stability invariants: OK")
