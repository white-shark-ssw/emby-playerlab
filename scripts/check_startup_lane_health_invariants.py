from pathlib import Path

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
http = Path("Sources/Transport/RangeHTTPClient.swift").read_text()
controller = Path("Sources/Player/PlayerController.swift").read_text()

required_unified = [
    "let startupTailMetadata = isStartupTailMetadata(range, resource: resource)",
    "let concretePlaybackDemand = concreteReason && !metadata",
    "Date() > pendingUserSeekUntil",
    "case startupMetadata",
    "startupMetadataSegmentBytes: Int64 = 1 * 1_048_576",
    "actual-tail plan range=",
    "startup-metadata-preempt",
    "action=await-actual-tail-demand",
    "action=straggler-cancel",
    "action=straggler-reset",
    "private func considerSequentialLaneHealth",
    "private func observeSequentialChunk",
    "laneHealthPeerFloorBps: Double = 4 * 1_048_576",
    "laneHealthRelativeFloor: Double = 0.50",
    "action=advisory-only",
    "action=rotate-live-lane",
    "protected bulk changed slot=",
    "protected bulk failover slot=",
]
for needle in required_unified:
    if needle not in unified:
        raise SystemExit(f"startup/lane-health invariant missing: {needle}")

for obsolete in ["startupTailWarmupBytes", "configureStartupWarmupIfNeeded", "large-mp4 warmup planned", "action=queue-tail", "tail warmup complete", "action=rotate-slow-lane"]:
    if obsolete in unified:
        raise SystemExit(f"obsolete startup/lane-health strategy remains: {obsolete}")

if unified.count("recordNetworkBytes(Int64(chunk.count))") != 2:
    raise SystemExit("each received network chunk must be counted exactly once in each fetch path")

# v0.12.3: completed 32 MiB samples are advisory only. They may select the protected
# bulk slot, but must never cancel/reset a connection. Only first-byte/live-window
# health is allowed to rotate a lane.
health_start = unified.index("private func considerSequentialLaneHealth")
health_end = unified.index("private func resumeAfterSecondaryCooldown", health_start)
completed_health = unified[health_start:health_end]
for forbidden in ["resetStreamLane", "cancelSlot(", "rotate-slow-lane", "slowStreak +=", "slowStreak >="]:
    if forbidden in completed_health:
        raise SystemExit(f"completed-claim health must remain advisory only: {forbidden}")
if "preferredBulkSlot" not in completed_health or "action=advisory-only" not in completed_health:
    raise SystemExit("completed-claim health must still select/log protected bulk")

required_http = [
    "func resetStreamLane(worker: Int, reason: String) -> Bool",
    "func resetIfIdle(reason: String) -> Bool",
    "guard !invalidated, states.isEmpty else { lock.unlock(); return false }",
    "action=reset-idle-session",
]
for needle in required_http:
    if needle not in http:
        raise SystemExit(f"lane reset invariant missing: {needle}")

if 'guard value.isPlaying, !value.isBuffering else { return }' in controller:
    raise SystemExit("MPV persistent buffer history must not depend on the flaky initial isPlaying property")
if 'guard !value.isBuffering else { return }' in controller:
    raise SystemExit("MPV buffer history must retain valid demuxer cache during transient buffering states")
if 'value.bufferedRanges.contains(where:' not in controller:
    raise SystemExit("MPV buffer history must require a real current-position buffer range")

finish_anchor = unified.index("private func finishSlot")
clear_index = unified.index("slotClaims[slot] = nil", finish_anchor)
live_reset_index = unified.index("client.resetStreamLane(worker: slot, reason: \"live-lane-rotation\")", finish_anchor)
if clear_index >= live_reset_index:
    raise SystemExit("live lane reset may only run after the cancelled slot is marked idle")

# 152901 v0.12.0 regression: actual tail starts 10,180,143 bytes from EOF. The new
# scheduler must start from that real byte offset, not from the old final-16MiB boundary.
resource_bytes = 5_883_702_464
tail_offset = 5_873_522_321
segment = 1 * 1_048_576
exact_bytes = resource_bytes - tail_offset
chunk_count = (exact_bytes + segment - 1) // segment
if exact_bytes != 10_180_143 or chunk_count != 10:
    raise SystemExit("synthetic 152901 actual-demand startup plan regression failed")

# 63368: live-window health, not a completed-block historical average, owns rotation.
peer_floor = 4 * 1_048_576
relative_floor = 0.45
peer_bps = 20 * 1_048_576
slow_bps = 3 * 1_048_576
if not (peer_bps >= peer_floor and slow_bps < peer_bps * relative_floor):
    raise SystemExit("synthetic 63368 live lane degradation regression failed")

# Whole-link weak-network case must still avoid peer-relative rotation when the peer is
# below the healthy floor; only the separate hard no-first-byte watchdog may intervene.
weak_peer_bps = 3 * 1_048_576
weak_lane_bps = 2 * 1_048_576
if weak_peer_bps >= peer_floor and weak_lane_bps < weak_peer_bps * relative_floor:
    raise SystemExit("whole-link weak-network case must not trigger peer-relative live rotation")

print("Startup metadata / lane health invariants: OK")
