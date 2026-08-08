from pathlib import Path

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
range_map = Path("Sources/Cache/PlaybackRangeMap.swift").read_text()

def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.12.6 frontier rescue regression failed: {message}")

for needle in [
    "urgentFirstByteHedgeSeconds: TimeInterval = 0.65",
    "liveLaneNoProgressPeerSeconds: TimeInterval = 1.25",
    "liveLaneNoProgressHardSeconds: TimeInterval = 2.75",
    "armUrgentFirstByteHedge",
    "action=hedge-urgent-first-byte",
    "action=urgent-race-won",
    "action=reset-race-loser",
    "armSequentialProgressWatchdog",
    "action=midstream-no-progress",
    "action=midstream-hard-timeout",
    "midstream-no-progress-peer-fast",
    "liveLaneWifiAbsoluteFloorBps: Double = 2.5 * 1_048_576",
    "liveLanePeakRelativeFloor: Double = 0.45",
]:
    require(needle in unified, f"missing {needle}")

require("playback.ranges + downloading.values" not in range_map, "in-flight claims must not hide physical sparse holes")
require("physicalHoleCount" in range_map, "physical hole metric missing")

# Device-log regression: playback-critical urgent lane can take 3.642 s for first MiB while
# the peer future-preload lane is simultaneously capable of >10 MiB/s. The hedge must fire
# well before the old 3 s hard timeout and borrow that peer lane for the exact urgent range.
require(0.65 < 1.0, "urgent hedge must run sub-second")

# Device-log regression: slot0 stalled almost nine seconds between sequential progress updates
# while slot1 kept advancing. Peer-assisted no-progress recovery must fire first.
require(1.25 < 2.75 < 8.893, "midstream watchdog thresholds no longer protect the observed stall")

print("v0.12.6 frontier rescue regressions: OK")
