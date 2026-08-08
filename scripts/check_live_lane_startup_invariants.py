from pathlib import Path

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
http = Path("Sources/Transport/RangeHTTPClient.swift").read_text()
project = Path("project.yml").read_text()
info = Path("Config/Info.plist").read_text()
identity = Path("Sources/Core/AppIdentity.swift").read_text()
validate = Path(".github/workflows/validate-source.yml").read_text()
build = Path(".github/workflows/build-unsigned-ipa.yml").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Live lane/startup invariant failed: {message}")


required = [
    "case startupMetadata",
    "startupMetadataSegmentBytes: Int64 = 1 * 1_048_576",
    "actual-tail plan range=",
    "startupMetadataQueue",
    "startup-metadata-preempt",
    "startupTailDemandGraceSeconds: TimeInterval = 0.25",
    "action=await-actual-tail-demand",
    "startupMetadataStartedAt",
    "startupMetadataLastProgressAt",
    "peerProgressAt > startedAt",
    "action=straggler-cancel",
    "action=straggler-reset",
    "private func observeSequentialChunk",
    "liveLaneFirstBytePeerTimeoutSeconds: TimeInterval = 1.5",
    "liveLaneFirstByteHardTimeoutSeconds: TimeInterval = 3.0",
    "liveLaneRelativeFloor: Double = 0.45",
    "liveLaneAbsoluteFloorBps: Double = 1.25 * 1_048_576",
    "action=rotate-live-lane",
    "liveLaneResetPending",
    "action=reset-retry",
    "!liveLaneResetPending.contains(0)",
]
for needle in required:
    require(needle in unified, f"missing {needle}")

for forbidden in [
    "startupTailWarmupBytes",
    "startupTailWarmupRange",
    "configureStartupWarmupIfNeeded",
    "large-mp4 warmup planned",
    "action=queue-tail",
    'startSlot(0, claim: SlotClaim(range: metadata, role: .metadata), reason: "startup-tail-',
    "tail warmup complete",
]:
    require(forbidden not in unified, f"obsolete proactive-tail strategy remains: {forbidden}")

require("RangeHTTPClient(maximumConnections: 2)" in unified, "normal transport must remain exactly two upstream lanes")
require("guard !invalidated, states.isEmpty else { lock.unlock(); return false }" in http, "stream lane reset must only occur after the lane is idle")
require("for slot in [0, 1] where slotTasks[slot] == nil && !liveLaneResetPending.contains(slot)" in unified, "startup metadata must fan out over both available lanes")
require("if slot == 1, Date() < secondaryCooldownUntil { continue }" in unified, "startup and sequential scheduling must respect Slot 1 failure cooldown")
require("startupMetadataQueue.insert(claim.range, at: 0)" in unified, "failed/straggling startup chunks must return to the front of the queue")

resource_bytes = 5_883_702_464
actual_tail = 5_873_522_321
old_warmup_start = resource_bytes - 16 * 1_048_576
wasted_before_actual = actual_tail - old_warmup_start
require(wasted_before_actual == 6_597_073, "synthetic 152901 old-warmup waste changed unexpectedly")
exact_tail_bytes = resource_bytes - actual_tail
segment = 1 * 1_048_576
chunks = (exact_tail_bytes + segment - 1) // segment
require(exact_tail_bytes == 10_180_143, "synthetic 152901 actual tail length mismatch")
require(chunks == 10, "152901 actual tail should require ten 1 MiB-or-smaller chunks")
require(actual_tail > old_warmup_start, "actual-demand plan must start after the obsolete proactive warmup start")

peer_bps = 20 * 1_048_576
slow_bps = 3 * 1_048_576
require(peer_bps >= 4 * 1_048_576, "synthetic peer must be healthy")
require(slow_bps < peer_bps * 0.45, "synthetic 63368 slow lane must trigger relative live rotation")
peer_first_byte_bps = 9 * 1_048_576
require(peer_first_byte_bps >= 2 * 1_048_576, "synthetic peer-fast first-byte case must qualify")

require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
require(project.count('MARKETING_VERSION: "0.12.4"') == 2, "marketing version must be 0.12.4")
require(project.count('CURRENT_PROJECT_VERSION: "62"') == 2, "build number must be 62")
require("<string>0.12.4</string>" in info and "<string>62</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.12.4"' in identity, "AppIdentity source version mismatch")
require("Audit live lane/startup invariants" in validate and "check_live_lane_startup_invariants.py" in validate, "Validate Source must enforce live-lane/startup invariants")
require("Audit live lane/startup invariants" in build and "check_live_lane_startup_invariants.py" in build, "unsigned IPA workflow must enforce live-lane/startup invariants")
require("Audit v0.12.4 scheduler regressions" in validate and "check_v0124_regressions.py" in validate, "Validate Source must enforce v0.12.4")
require("Audit v0.12.4 scheduler regressions" in build and "check_v0124_regressions.py" in build, "unsigned IPA build must enforce v0.12.4")
require('IPA_NAME="EmbyPlayerLab-0.12.4-${GITHUB_SHA::7}-unsigned.ipa"' in build, "IPA filename must identify v0.12.4")

for temporary in [
    ".github/workflows/apply-v0121-live-lane-startup.yml",
    "scripts/apply_v0121_live_lane_startup.py",
    "scripts/refine_v0121_live_lane_startup.py",
    "scripts/refine_v0121_review.py",
    "scripts/refine_v0121_straggler_timestamp.py",
]:
    require(not Path(temporary).exists(), f"temporary construction file must not ship: {temporary}")

print("Live lane/startup invariants: OK")
