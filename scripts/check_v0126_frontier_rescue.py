from pathlib import Path

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
range_map = Path("Sources/Cache/PlaybackRangeMap.swift").read_text()
project = Path("project.yml").read_text()
info = Path("Config/Info.plist").read_text()
identity = Path("Sources/Core/AppIdentity.swift").read_text()
build = Path(".github/workflows/build-unsigned-ipa.yml").read_text()
validate = Path(".github/workflows/validate-source.yml").read_text()


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
require(project.count('MARKETING_VERSION: "0.12.6"') == 2, "marketing version must be 0.12.6")
require(project.count('CURRENT_PROJECT_VERSION: "64"') == 2, "build number must be 64")
require("<string>0.12.6</string>" in info and "<string>64</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.12.6"' in identity, "AppIdentity source version mismatch")
require('IPA_NAME="EmbyPlayerLab-0.12.6-${GITHUB_SHA::7}-unsigned.ipa"' in build, "IPA filename must identify v0.12.6")
require('RELEASE_TAG="v0.12.6-build64-dev"' in build, "release tag mismatch")
require('RELEASE_IPA="EmbyPlayerLab-v0.12.6-build64-${GITHUB_SHA::7}-unsigned.ipa"' in build, "release IPA mismatch")
require("Audit v0.12.6 frontier rescue regressions" in build and "check_v0126_frontier_rescue.py" in build, "build workflow must enforce v0.12.6 regression")
require("Audit v0.12.6 frontier rescue regressions" in validate and "check_v0126_frontier_rescue.py" in validate, "validate workflow must enforce v0.12.6 regression")

# Device-log regression: playback-critical urgent lane took 3.642 s for its first MiB while
# the peer future-preload lane was simultaneously capable of >10 MiB/s. The hedge must fire
# well before the old 3 s hard timeout and race the exact playback-critical range on the peer.
require(0.65 < 1.0, "urgent hedge must run sub-second")

# Device-log regression: slot0 stalled almost nine seconds between sequential progress updates
# while slot1 kept advancing. Peer-assisted no-progress recovery must fire first.
require(1.25 < 2.75 < 8.893, "midstream watchdog thresholds no longer protect the observed stall")

print("v0.12.6 frontier rescue regressions: OK")
