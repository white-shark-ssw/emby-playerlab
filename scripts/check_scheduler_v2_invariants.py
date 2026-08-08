from pathlib import Path
import re

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

hint_index = unified.index("if !concreteReason, !metadata")
urgent_index = unified.index("installUrgent(range: range, metadata: metadata, reason: reason)", hint_index)
return_index = unified.index("return", hint_index)
require(return_index < urgent_index, "hint-only path must return before urgent installation")

for avg0, avg1, expected_bulk in [(12.0, 4.0, 0), (4.0, 12.0, 1), (8.0, 8.5, 0)]:
    bulk = 0
    if avg1 >= avg0 * 1.20:
        bulk = 1
    elif avg0 >= avg1 * 1.20:
        bulk = 0
    require(bulk == expected_bulk, f"synthetic protected-bulk choice failed for {avg0}/{avg1}")
    require((1 if bulk == 0 else 0) != bulk, "foreground service lane must differ from protected bulk lane")

claim_lower = 143_654_912
claim_upper = 167_772_160
stream_head = 149_946_368
requested = 160_497_664
threshold = 2 * 1_048_576
require(claim_lower <= requested < claim_upper, "synthetic 63360 request must lie in the active claim")
require(requested - stream_head > threshold, "synthetic 63360 request must trigger parallel urgent")

for obsolete in ["startupTailWarmupBytes", "configureStartupWarmupIfNeeded", "action=queue-tail", 'startSlot(0, claim: SlotClaim(range: metadata, role: .metadata), reason: "startup-tail-']:
    require(obsolete not in unified, f"obsolete proactive startup strategy remains: {obsolete}")

require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
versions = re.findall(r'MARKETING_VERSION: "([^"]+)"', project)
builds = re.findall(r'CURRENT_PROJECT_VERSION: "([^"]+)"', project)
require(len(versions) == 2 and len(set(versions)) == 1, "marketing version must match in both settings scopes")
require(len(builds) == 2 and len(set(builds)) == 1, "build number must match in both settings scopes")
version = versions[0]
build_number = builds[0]
require(f"<string>{version}</string>" in info and f"<string>{build_number}</string>" in info, "Info.plist version/build mismatch")
require(f'sourceVersion = "{version}"' in identity, "AppIdentity source version mismatch")
require("Audit Scheduler v2 invariants" in validate and "check_scheduler_v2_invariants.py" in validate, "Validate Source must enforce Scheduler v2")
require("Audit Scheduler v2 invariants" in build and "check_scheduler_v2_invariants.py" in build, "unsigned IPA build must enforce Scheduler v2")
require("Audit live lane/startup invariants" in validate and "check_live_lane_startup_invariants.py" in validate, "Validate Source must enforce live-lane/startup regression gate")
require("Audit live lane/startup invariants" in build and "check_live_lane_startup_invariants.py" in build, "unsigned IPA build must enforce live-lane/startup regression gate")
require("Audit v0.12.4 scheduler regressions" in validate and "check_v0124_regressions.py" in validate, "Validate Source must enforce v0.12.4")
require("Audit v0.12.4 scheduler regressions" in build and "check_v0124_regressions.py" in build, "unsigned IPA build must enforce v0.12.4")
require("Audit v0.12.6 frontier rescue regressions" in validate and "check_v0126_frontier_rescue.py" in validate, "Validate Source must enforce v0.12.6")
require("Audit v0.12.6 frontier rescue regressions" in build and "check_v0126_frontier_rescue.py" in build, "unsigned IPA build must enforce v0.12.6")
require("Audit v0.12.7 MPV rotation regressions" in validate and "check_v0127_mpv_rotation.py" in validate, "Validate Source must enforce v0.12.7")
require("Audit v0.12.7 MPV rotation regressions" in build and "check_v0127_mpv_rotation.py" in build, "unsigned IPA build must enforce v0.12.7")
require(f'IPA_NAME="EmbyPlayerLab-{version}-${{GITHUB_SHA::7}}-unsigned.ipa"' in build, "IPA filename must identify current version")

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
