from pathlib import Path
import re

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
versions = re.findall(r'MARKETING_VERSION: "([^"]+)"', project)
builds = re.findall(r'CURRENT_PROJECT_VERSION: "([^"]+)"', project)
require(len(versions) == 2 and len(set(versions)) == 1, "marketing version must match in both settings scopes")
require(len(builds) == 2 and len(set(builds)) == 1, "build number must match in both settings scopes")
version = versions[0]
build_number = builds[0]
require(f"<string>{version}</string>" in info and f"<string>{build_number}</string>" in info, "Info.plist version/build mismatch")
require(f'sourceVersion = "{version}"' in identity, "AppIdentity source version mismatch")
require(f'IPA_NAME="EmbyPlayerLab-{version}-${{GITHUB_SHA::7}}-unsigned.ipa"' in build, "IPA filename must identify current version")
require(f'RELEASE_TAG="v{version}-build{build_number}-dev"' in build, "release tag mismatch")
require(f'RELEASE_IPA="OS-player-v{version}-build{build_number}-${{GITHUB_SHA::7}}-unsigned.ipa"' in build, "release IPA mismatch")
require("Audit v0.12.6 frontier rescue regressions" in build and "check_v0126_frontier_rescue.py" in build, "build workflow must enforce v0.12.6 regression")
require("Audit v0.12.6 frontier rescue regressions" in validate and "check_v0126_frontier_rescue.py" in validate, "validate workflow must enforce v0.12.6 regression")
require("Audit v0.12.7 MPV rotation regressions" in build and "check_v0127_mpv_rotation.py" in build, "build workflow must enforce v0.12.7 regression")
require("Audit v0.12.7 MPV rotation regressions" in validate and "check_v0127_mpv_rotation.py" in validate, "validate workflow must enforce v0.12.7 regression")

require(0.65 < 1.0, "urgent hedge must run sub-second")
require(1.25 < 2.75 < 8.893, "midstream watchdog thresholds no longer protect the observed stall")

print("v0.12.6 frontier rescue regressions: OK")
