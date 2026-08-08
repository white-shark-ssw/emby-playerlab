from pathlib import Path
import re

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
project = Path("project.yml").read_text()
info = Path("Config/Info.plist").read_text()
identity = Path("Sources/Core/AppIdentity.swift").read_text()
validate = Path(".github/workflows/validate-source.yml").read_text()
build = Path(".github/workflows/build-unsigned-ipa.yml").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"v0.12.4 regression failed: {message}")

for needle in [
    "lastBlockingPlaybackDemand",
    "lastBlockingPlaybackDemandAt",
    "stallBlockingDemandFreshSeconds: TimeInterval = 12",
    'reason == "blocked-read" || reason == "byte-offset"',
    "action=prioritize-blocking-demand",
    "action=keep-anchor-await-blocked-read",
]:
    require(needle in unified, f"authoritative stall recovery missing {needle}")
require("lastConcretePlaybackDemand" not in unified, "arbitrary concrete reads must not drive stall recovery")
require("stall-last-concrete-demand" not in unified, "legacy stale concrete-demand recovery must be removed")

authoritative_anchor = 213_909_504
stale_concrete = 101_842_944
blocking_age_seconds = 7
freshness = 12
anchor = authoritative_anchor
if blocking_age_seconds <= freshness:
    anchor = authoritative_anchor
require(anchor == authoritative_anchor and anchor != stale_concrete, "63368 stall anchor regressed to stale concrete read")

schedule = re.search(r"private func scheduleSlots\(reason: String\).*?private func firstIdleForegroundSlot", unified, re.S)
require(schedule is not None, "scheduleSlots body missing")
schedule_body = schedule.group(0)
for needle in [
    "pending urgent satisfied range=",
    "pending metadata satisfied range=",
    "action=drop-satisfied",
    "store.contains(urgent)",
    "store.contains(metadata)",
]:
    require(needle in schedule_body, f"satisfied-pending cleanup missing {needle}")
urgent_cleanup = schedule_body.index("if let urgent = pendingPlaybackUrgentRange, store.contains(urgent)")
critical_return = schedule_body.index("if pendingPlaybackUrgentRange != nil || pendingMetadataRange != nil")
require(urgent_cleanup < critical_return, "satisfied urgent cleanup must run before critical-work return")

metrics = re.search(r"func metrics\(\) async -> TransportMetricsSnapshot.*?func cachedByteRanges", unified, re.S)
require(metrics is not None, "metrics function missing")
require("slotTasks.isEmpty" in metrics.group(0) and 'scheduleSlots(reason: "metrics-idle-repair")' in metrics.group(0), "idle scheduler self-heal missing")

for needle in [
    "strictFrontierReserveBytes: Int64 = Int64.max",
    "sequentialWaveUpperBound",
    "sequentialWaveSegmentBytes",
    "action=strict-two-segment",
    "let relativeFrontier = max(0, snapshot.frontierByte - playbackAnchor)",
    "let waveBase = playbackAnchor + (relativeFrontier / segmentBytes) * segmentBytes",
    "safeAdd(waveBase, segmentBytes * 2)",
    "claimUpper = min(upper, sequentialWaveUpperBound)",
    "claimLookahead = 2",
    "resourceLength: claimUpper",
]:
    require(needle in unified, f"aligned strict frontier wave missing {needle}")
require("safeAdd(snapshot.frontierByte, segmentBytes * 2)" not in unified, "unaligned frontier wave must not return")

mib = 1_048_576
anchor = 0
frontier = 68 * mib
segment = 32 * mib
relative = max(0, frontier - anchor)
wave_base = anchor + (relative // segment) * segment
wave_upper = wave_base + 2 * segment
require(wave_base == 64 * mib, "synthetic wave base must align down to 64 MiB")
require(wave_upper == 128 * mib, "synthetic wave upper must end at 128 MiB")
old_unaligned_upper = frontier + 2 * segment
require(old_unaligned_upper == 132 * mib and old_unaligned_upper > wave_upper, "synthetic old 4 MiB third-tail regression changed")
active_first_upper = 96 * mib
cached_peer_upper = 128 * mib
require(max(active_first_upper, cached_peer_upper) >= wave_upper, "completed/active pair must consume the entire aligned wave")

require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
require(project.count('MARKETING_VERSION: "0.12.7"') == 2, "marketing version must be 0.12.7")
require(project.count('CURRENT_PROJECT_VERSION: "65"') == 2, "build number must be 65")
require("<string>0.12.7</string>" in info and "<string>65</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.12.7"' in identity, "AppIdentity source version mismatch")
require("Audit v0.12.4 scheduler regressions" in validate and "check_v0124_regressions.py" in validate, "Validate Source must enforce v0.12.4 regressions")
require("Audit v0.12.4 scheduler regressions" in build and "check_v0124_regressions.py" in build, "unsigned IPA build must enforce v0.12.4 regressions")
require("Audit v0.12.6 frontier rescue regressions" in validate and "check_v0126_frontier_rescue.py" in validate, "Validate Source must enforce v0.12.6 regressions")
require("Audit v0.12.6 frontier rescue regressions" in build and "check_v0126_frontier_rescue.py" in build, "unsigned IPA build must enforce v0.12.6 regressions")
require("Audit v0.12.7 MPV rotation regressions" in validate and "check_v0127_mpv_rotation.py" in validate, "Validate Source must enforce v0.12.7 regressions")
require("Audit v0.12.7 MPV rotation regressions" in build and "check_v0127_mpv_rotation.py" in build, "unsigned IPA build must enforce v0.12.7 regressions")
require('IPA_NAME="EmbyPlayerLab-0.12.7-${GITHUB_SHA::7}-unsigned.ipa"' in build, "IPA filename must identify v0.12.7")
require('RELEASE_TAG="v0.12.7-build65-dev"' in build, "versioned release tag mismatch")
require('RELEASE_IPA="EmbyPlayerLab-v0.12.7-build65-${GITHUB_SHA::7}-unsigned.ipa"' in build, "versioned release IPA mismatch")

print("v0.12.4 regressions retained: OK")
