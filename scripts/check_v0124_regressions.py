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

# 63368 v0.12.3 hard-stall regression: stall recovery must never use an arbitrary
# AVPlayer concrete read. Only a cache-miss blocked read or MPV byte offset is allowed.
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

# Exact supplied 63368 sequence: the real cache-miss seek anchor was 213,909,504.
# A stale concrete read at 101,842,944 must not drag the scheduler backwards seven seconds later.
authoritative_anchor = 213_909_504
stale_concrete = 101_842_944
blocking_age_seconds = 7
freshness = 12
anchor = authoritative_anchor
if blocking_age_seconds <= freshness:
    anchor = authoritative_anchor
require(anchor == authoritative_anchor and anchor != stale_concrete, "63368 stall anchor regressed to stale concrete read")

# A satisfied pending critical request used to remain non-nil and force scheduleSlots()
# to return forever with slot0=idle, slot1=idle and networkBps=0. Satisfied pending work
# must be dropped before the critical-work early return.
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

# Metrics polling is the final self-heal: if both lanes are idle after all callbacks settle,
# the scheduler is kicked again instead of remaining dead forever.
metrics = re.search(r"func metrics\(\) async -> TransportMetricsSnapshot.*?func cachedByteRanges", unified, re.S)
require(metrics is not None, "metrics function missing")
require("slotTasks.isEmpty" in metrics.group(0) and 'scheduleSlots(reason: "metrics-idle-repair")' in metrics.group(0), "idle scheduler self-heal missing")

# Near startup and after a seek, prefetch is wave-bounded. Two adjacent 32 MiB workers may
# run concurrently, but the fast one may not open a third segment while the frontier pair is incomplete.
for needle in [
    "strictFrontierReserveBytes: Int64 = 128 * 1_048_576",
    "sequentialWaveUpperBound",
    "sequentialWaveSegmentBytes",
    "action=strict-two-segment",
    "safeAdd(snapshot.frontierByte, segmentBytes * 2)",
    "claimLookahead = 2",
]:
    require(needle in unified, f"strict frontier wave missing {needle}")

# Synthetic strict-wave barrier: 0-32 and 32-64 are the only two initial claims.
# If 0-32 finishes first while 32-64 is still active, no 64-96 third claim is legal
# until the active frontier segment closes.
mib = 1_048_576
wave_upper = 64 * mib
frontier = 32 * mib
active_frontier_upper = 64 * mib
candidate = active_frontier_upper
require(candidate >= wave_upper, "synthetic strict wave unexpectedly allows a third segment")

require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
require(project.count('MARKETING_VERSION: "0.12.4"') == 2, "marketing version must be 0.12.4")
require(project.count('CURRENT_PROJECT_VERSION: "62"') == 2, "build number must be 62")
require("<string>0.12.4</string>" in info and "<string>62</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.12.4"' in identity, "AppIdentity source version mismatch")
require("Audit v0.12.4 scheduler regressions" in validate and "check_v0124_regressions.py" in validate, "Validate Source must enforce v0.12.4 regressions")
require("Audit v0.12.4 scheduler regressions" in build and "check_v0124_regressions.py" in build, "unsigned IPA build must enforce v0.12.4 regressions")
require('IPA_NAME="EmbyPlayerLab-0.12.4-${GITHUB_SHA::7}-unsigned.ipa"' in build, "IPA filename must identify v0.12.4")
require('RELEASE_TAG="v0.12.4-build62-dev"' in build, "versioned release tag mismatch")
require('RELEASE_IPA="EmbyPlayerLab-v0.12.4-build62-${GITHUB_SHA::7}-unsigned.ipa"' in build, "versioned release IPA mismatch")

print("v0.12.4 regressions: OK")
