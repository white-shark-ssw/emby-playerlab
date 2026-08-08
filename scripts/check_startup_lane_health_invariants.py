from pathlib import Path

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
http = Path("Sources/Transport/RangeHTTPClient.swift").read_text()
controller = Path("Sources/Player/PlayerController.swift").read_text()

required_unified = [
    "let startupTailMetadata = isStartupTailMetadata(range, resource: resource)",
    "let concretePlaybackDemand = concreteReason && !metadata",
    "Date() > pendingUserSeekUntil",
    "critical-tail-metadata range=",
    'cancelSlot(0, reason: "startup-metadata-priority")',
    "critical metadata queued on primary",
    "preserveSecondary=",
    "private func considerSequentialLaneHealth",
    "laneHealthPeerFloorBps: Double = 4 * 1_048_576",
    "laneHealthRelativeFloor: Double = 0.50",
    "current.slowStreak >= 2",
    "laneHealthResetCooldownSeconds: TimeInterval = 25",
    "action=rotate-slow-lane",
]
for needle in required_unified:
    if needle not in unified:
        raise SystemExit(f"startup/lane-health invariant missing: {needle}")

if unified.count("recordNetworkBytes(Int64(chunk.count))") != 2:
    raise SystemExit("each received network chunk must be counted exactly once in each of the two fetch paths")
if "recordNetworkBytes(Int64(chunk.count))\n                            recordNetworkBytes(Int64(chunk.count))" in unified:
    raise SystemExit("duplicate adjacent network-byte accounting returned")

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
if controller.count("guard !value.isBuffering else { return }") != 1:
    raise SystemExit("MPV persistent buffer history must require non-buffering progression exactly once")

finish_anchor = unified.index("private func finishSlot")
clear_index = unified.index("slotClaims[slot] = nil", finish_anchor)
health_index = unified.index("considerSequentialLaneHealth(slot:", finish_anchor)
if clear_index >= health_index:
    raise SystemExit("lane health reset may only run after the completed slot is marked idle")
if "if claim.role == .sequential, error == nil" not in unified[finish_anchor:health_index + 256]:
    raise SystemExit("lane rotation must only be evaluated from successful sequential completion")

# 152901 v0.11.2 regression: libmpv's startup seek lands 10,180,143 bytes from EOF
# in a 5.88 GB MP4. That is container-tail metadata, not a 5.87 GB playback seek.
resource_bytes = 5_883_702_464
tail_offset = 5_873_522_321
near_tail_window = 64 * 1_048_576
if resource_bytes < 4 * 1_073_741_824:
    raise SystemExit("synthetic 152901 large-MP4 condition failed")
if tail_offset < resource_bytes - near_tail_window:
    raise SystemExit("synthetic 152901 tail metadata condition failed")

# Health policy: rotate a clearly degraded lane only when a recently healthy peer proves
# that the whole network is not simply slow. Two bad completed blocks are required.
peer_floor = 4 * 1_048_576
relative_floor = 0.50
peer_bps = 16 * 1_048_576
slow_samples = [3 * 1_048_576, 2.5 * 1_048_576]
streak = 0
for sample in slow_samples:
    if peer_bps >= peer_floor and sample < peer_bps * relative_floor:
        streak += 1
if streak < 2:
    raise SystemExit("synthetic degraded-lane rotation regression failed")

weak_peer_bps = 3 * 1_048_576
weak_lane_bps = 2 * 1_048_576
if weak_peer_bps >= peer_floor and weak_lane_bps < weak_peer_bps * relative_floor:
    raise SystemExit("whole-link weak-network case must not trigger peer-relative lane rotation")

print("Startup metadata / lane health invariants: OK")
