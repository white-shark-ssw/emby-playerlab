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
    "startupTailWarmupBytes: Int64 = 16 * 1_048_576",
    "large-mp4 warmup planned",
    "action=queue-tail",
    "reason: \"startup-tail-",
    "tail warmup complete",
    "!isStartupTailMetadata(metadata, resource: resource)",
]
for needle in required:
    require(needle in unified, f"missing {needle}")

require(unified.count("private func configureStartupWarmupIfNeeded") == 1, "startup warmup helper must be unique")
require('cancelSlot(1, reason: metadata ? "metadata-priority" : "urgent-playback-priority")' not in unified, "physical Slot 1 must not be the permanent foreground victim")
require('cancelSlot(0, reason: "startup-metadata-priority")' not in unified, "large-MP4 tail warmup must not cancel the warm head")
require(unified.count('cancelSlot(slot, reason: "replace-stale-urgent")') == 2, "stale foreground cancellation must inspect both physical lanes")
require('guard !value.isBuffering else { return }' not in controller, "valid MPV demux cache must remain visible during transient buffering")
require('value.bufferedRanges.contains(where:' in controller, "MPV buffer history must verify a current-position range")

# Speculative AVPlayer range announcements must not preempt bulk work. The hint-only
# branch must return before the concrete reanchor / installUrgent paths below it.
hint_index = unified.index("if !concreteReason, !metadata")
urgent_index = unified.index("installUrgent(range: range, metadata: metadata, reason: reason)", hint_index)
return_index = unified.index("return", hint_index)
require(return_index < urgent_index, "hint-only path must return before urgent installation")

# Planned large-MP4 startup metadata may only use the dedicated Slot 0 branch. The
# generic metadata path must explicitly exclude it, otherwise a cold Slot 1 can steal it.
dedicated_tail = unified.index('reason: "startup-tail-')
generic_metadata = unified.index("if let metadata = pendingMetadataRange, !isStartupTailMetadata(metadata, resource: resource)")
require(dedicated_tail < generic_metadata, "dedicated startup-tail path must precede generic metadata scheduling")

# Synthetic lane selection: whichever lane is materially faster becomes protected,
# and the opposite lane becomes the first foreground service lane.
for avg0, avg1, expected_bulk in [(12.0, 4.0, 0), (4.0, 12.0, 1), (8.0, 8.5, 0)]:
    bulk = 0
    if avg1 >= avg0 * 1.20:
        bulk = 1
    elif avg0 >= avg1 * 1.20:
        bulk = 0
    require(bulk == expected_bulk, f"synthetic protected-bulk choice failed for {avg0}/{avg1}")
    service = 1 if bulk == 0 else 0
    require(service != bulk, "foreground service lane must differ from protected bulk lane")

# 152901: actual startup tail seek is 10,180,143 bytes from EOF and must be fully
# inside the proactive final-16MiB warmup window.
resource_bytes = 5_883_702_464
actual_tail = 5_873_522_321
warmup_start = resource_bytes - 16 * 1_048_576
require(warmup_start <= actual_tail < resource_bytes, "152901 tail is not covered by proactive warmup")

require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
require(project.count('MARKETING_VERSION: "0.12.0"') == 2, "marketing version must be 0.12.0")
require(project.count('CURRENT_PROJECT_VERSION: "58"') == 2, "build number must be 58")
require("<string>0.12.0</string>" in info and "<string>58</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.12.0"' in identity, "AppIdentity source version mismatch")
require("Audit Scheduler v2 invariants" in validate and "check_scheduler_v2_invariants.py" in validate, "Validate Source must enforce Scheduler v2")
require("Audit Scheduler v2 invariants" in build and "check_scheduler_v2_invariants.py" in build, "unsigned IPA build must enforce Scheduler v2")
require('IPA_NAME="EmbyPlayerLab-0.12.0-${GITHUB_SHA::7}-unsigned.ipa"' in build, "IPA filename must identify v0.12.0")

for temporary in [
    ".github/workflows/apply-v0120-scheduler-v2.yml",
    "scripts/apply_v0120_scheduler_v2.py",
    "scripts/refine_v0120_scheduler_v2.py",
    "scripts/cleanup_v0120_scheduler_v2.py",
    "scripts/refine_v0120_startup_tail.py",
    "scripts/finalize_v0120.py",
]:
    require(not Path(temporary).exists(), f"temporary construction file must not ship: {temporary}")

print("Scheduler v2 invariants: OK")
