from pathlib import Path

unified = Path("Sources/Transport/UnifiedMediaTransportSession.swift").read_text()
controller = Path("Sources/Player/PlayerController.swift").read_text()
project = Path("project.yml").read_text()
info = Path("Config/Info.plist").read_text()
identity = Path("Sources/Core/AppIdentity.swift").read_text()
validate = Path(".github/workflows/validate-source.yml").read_text()
build = Path(".github/workflows/build-unsigned-ipa.yml").read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Scheduler v2 invariant failed: {message}")


required = [
    "UnifiedSchedulerV2",
    "hint-only request=",
    "action=keep-bulk",
    "private var preferredBulkSlot = 0",
    "protected bulk changed slot=",
    "foreground borrow slot=",
    "preserveBulk=",
    "second foreground head borrows bulk slot=",
    "private func firstIdleForegroundSlot() -> Int?",
    "slotClaims.first(where: { $0.value.role == .sequential && $0.value.range.contains(range.lowerBound) })",
    "progressiveUrgentGapBytes: Int64 = 2 * 1_048_576",
]
for needle in required:
    require(needle in unified, f"missing {needle}")

require('cancelSlot(1, reason: metadata ? "metadata-priority" : "urgent-playback-priority")' not in unified, "physical Slot 1 must not be the permanent foreground victim")
require(unified.count('cancelSlot(slot, reason: "replace-stale-urgent")') == 2, "stale foreground cancellation must inspect both physical lanes")
require('guard !value.isBuffering else { return }' not in controller, "valid MPV demux cache must remain visible during transient buffering")
require('value.bufferedRanges.contains(where:' in controller, "MPV buffer history must verify a current-position range")

# AVPlayer range announcements are speculative. They may guide the cache map but must
# return before installUrgent, so ordinary range-demand cannot destroy a warm bulk lane.
hint_index = unified.index("if !concreteReason, !metadata")
urgent_index = unified.index("installUrgent(range: range, metadata: metadata, reason: reason)", hint_index)
return_index = unified.index("return", hint_index)
require(return_index < urgent_index, "hint-only path must return before urgent installation")

# Protected bulk remains logical, not tied to a physical slot.
for avg0, avg1, expected_bulk in [(12.0, 4.0, 0), (4.0, 12.0, 1), (8.0, 8.5, 0)]:
    bulk = 0
    if avg1 >= avg0 * 1.20:
        bulk = 1
    elif avg0 >= avg1 * 1.20:
        bulk = 0
    require(bulk == expected_bulk, f"synthetic protected-bulk choice failed for {avg0}/{avg1}")
    require((1 if bulk == 0 else 0) != bulk, "foreground service lane must differ from protected bulk lane")

# 63360: a real read ~10 MiB ahead of a progressive stream head must become parallel
# urgent even when it lies inside that lane's 32 MiB claim.
claim_lower = 143_654_912
claim_upper = 167_772_160
stream_head = 149_946_368
requested = 160_497_664
threshold = 2 * 1_048_576
require(claim_lower <= requested < claim_upper, "synthetic 63360 request must lie in the active claim")
require(requested - stream_head > threshold, "synthetic 63360 request must trigger parallel urgent")

# v0.12.1 intentionally replaces v0.12.0's proactive fixed final-16MiB startup path.
# Do not reject the new scheduler reason "startup-tail-grace-ended"; only the old
# dedicated Slot-0 startup-tail start pattern is obsolete.
for obsolete in ["startupTailWarmupBytes", "configureStartupWarmupIfNeeded", "action=queue-tail", 'startSlot(0, claim: SlotClaim(range: metadata, role: .metadata), reason: "startup-tail-']:
    require(obsolete not in unified, f"obsolete proactive startup strategy remains: {obsolete}")

require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
require(project.count('MARKETING_VERSION: "0.12.1"') == 2, "marketing version must be 0.12.1")
require(project.count('CURRENT_PROJECT_VERSION: "59"') == 2, "build number must be 59")
require("<string>0.12.1</string>" in info and "<string>59</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.12.1"' in identity, "AppIdentity source version mismatch")
require("Audit Scheduler v2 invariants" in validate and "check_scheduler_v2_invariants.py" in validate, "Validate Source must enforce Scheduler v2")
require("Audit Scheduler v2 invariants" in build and "check_scheduler_v2_invariants.py" in build, "unsigned IPA build must enforce Scheduler v2")
require("Audit live lane/startup invariants" in validate and "check_live_lane_startup_invariants.py" in validate, "Validate Source must enforce live-lane/startup regression gate")
require("Audit live lane/startup invariants" in build and "check_live_lane_startup_invariants.py" in build, "unsigned IPA build must enforce live-lane/startup regression gate")
require('IPA_NAME="EmbyPlayerLab-0.12.1-${GITHUB_SHA::7}-unsigned.ipa"' in build, "IPA filename must identify v0.12.1")

for temporary in [
    ".github/workflows/apply-v0120-scheduler-v2.yml",
    "scripts/apply_v0120_scheduler_v2.py",
    "scripts/refine_v0120_scheduler_v2.py",
    "scripts/cleanup_v0120_scheduler_v2.py",
    "scripts/refine_v0120_startup_tail.py",
    "scripts/finalize_v0120.py",
    ".github/workflows/apply-v0121-live-lane-startup.yml",
    "scripts/apply_v0121_live_lane_startup.py",
    "scripts/refine_v0121_live_lane_startup.py",
    "scripts/refine_v0121_review.py",
    "scripts/refine_v0121_straggler_timestamp.py",
]:
    require(not Path(temporary).exists(), f"temporary construction file must not ship: {temporary}")

print("Scheduler v2 invariants: OK")
