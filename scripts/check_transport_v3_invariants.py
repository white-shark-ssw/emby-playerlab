from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Transport v3 invariant failed: {message}")


http = read("Sources/Transport/RangeHTTPClient.swift")
unified = read("Sources/Transport/UnifiedMediaTransportSession.swift")
orchestrator = read("Sources/Player/PlaybackOrchestrator.swift")
engine = read("Sources/Player/PlayerEngine.swift")
controller = read("Sources/Player/PlayerController.swift")
mpv = read("Sources/Player/MPVPlayerEngine.swift")
project = read("project.yml")
info = read("Config/Info.plist")
identity = read("Sources/Core/AppIdentity.swift")
stability_gate = read("scripts/check_transport_stability_invariants.py")
validate_workflow = read(".github/workflows/validate-source.yml")
build_workflow = read(".github/workflows/build-unsigned-ipa.yml")

require("PersistentRangeStreamLane" in http, "persistent Range stream lane missing")
require("private lazy var session: URLSession" in http, "each stream lane must own one long-lived URLSession")
require("session=persistent" in http, "persistent-session diagnostics missing")
require("taskOnly=true sessionKept=true" in http, "task cancellation must explicitly preserve the lane session")
require("func invalidate()" in http and "persistent range pool invalidated" in http, "RangeHTTPClient explicit lifecycle teardown missing")
require("TransportV3Metric" in http and "isReusedConnection" in http, "connection reuse diagnostics missing")
require("RangeStreamLoader" not in http, "legacy per-Range URLSession loader must not return")
require("115Browser/" not in http, "Transport v3 must reuse the resolved UA rather than hard-code a 115 browser UA")
require("lower.hasPrefix(\"x-emby-\")" in http and "lower.hasPrefix(\"x-mediabrowser-\")" in http, "remote auth-header prefix filtering missing")

lane_start = http.index("private final class PersistentRangeStreamLane")
lane_body = http[lane_start:]
require("finishTasksAndInvalidate" not in lane_body, "stream completion must not invalidate a persistent lane session")
require(lane_body.count("invalidateAndCancel()") == 2, "lane session invalidation must exist only for explicit idle rotation and final teardown")
require("guard !invalidated, states.isEmpty else { lock.unlock(); return false }" in lane_body, "health rotation may only replace an idle lane")

require("reuse active sequential stream" in unified, "near-head playback demand must still reuse an active sequential stream")
require("promote slot0 sequential->urgent" not in unified, "legacy in-range cancel/reopen promotion must not return")
require("cancelSlot(0, reason: \"real-seek-demand\")" not in unified, "ordinary user seeks must preserve warmed sequential work")
require("foreground gap slot=" in unified and "action=parallel-urgent" in unified, "far in-claim foreground reads must be able to borrow the other lane")
require(unified.count("recordNetworkBytes(Int64(chunk.count))") == 2, "network throughput must count each chunk exactly once per fetch path")
require("client.invalidate()" in unified, "transport stop must explicitly tear down the persistent connection pool")
require("action=rotate-live-lane" in unified, "Transport v3 must be able to rotate a degraded sequential connection before a full 32 MiB claim completes")
require("liveLaneResetPending" in unified, "live lane reset lifecycle guard missing")

require("automaticProfile=AVPlayerResourceLoader+UnifiedTransportV3" in orchestrator, "native automatic route must use ResourceLoader + Unified v3")
require("automaticProfile=MPV+UnifiedTransportV3" in orchestrator, "compatibility automatic route must use MPV + Unified v3")
require("self.currentKind = .resourceLoaderAVPlayer" in orchestrator, "native automatic engine must be ResourceLoader AVPlayer")
require("return .resourceLoaderAVPlayer" in engine, "automatic preference must resolve native media to ResourceLoader AVPlayer")
require("return MPVPlayerEngine(sharedTransportSession: transportContext?.session)" in controller, "MPV must consume the shared Unified transport session")
require("ktvCacheHandoff" not in controller, "KTV cache handoff must not leak into Transport v3 engine switching")
require("transport=KTVProxyTransportV2" not in mpv, "MPV core must not identify automatic playback as KTV transport")
require(mpv.count("if sharedTransportSession == nil") == 2, "MPV should have one direct fallback in prepare and one compatibility fallback")

require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
require(project.count('MARKETING_VERSION: "0.12.2"') == 2, "project marketing version must be 0.12.2 in both settings scopes")
require(project.count('CURRENT_PROJECT_VERSION: "60"') == 2, "project build number must be 59 in both settings scopes")
require("<string>0.12.2</string>" in info and "<string>59</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.12.2"' in identity, "AppIdentity source version mismatch")

for temporary_path in [
    ".github/workflows/apply-transport-v3-core.yml",
    "scripts/apply_transport_v3_core.py",
    "scripts/refine_transport_v3.py",
    ".github/workflows/apply-v0112-transport-stability.yml",
    "scripts/apply_v0112_transport_stability.py",
    "scripts/finalize_v0112.py",
    ".github/workflows/apply-v0113-startup-lane-health.yml",
    "scripts/apply_v0113_startup_lane_health.py",
    ".github/workflows/apply-v0120-scheduler-v2.yml",
    "scripts/apply_v0120_scheduler_v2.py",
    "scripts/refine_v0120_scheduler_v2.py",
    "scripts/cleanup_v0120_scheduler_v2.py",
    "scripts/finalize_v0120.py",
    ".github/workflows/apply-v0121-live-lane-startup.yml",
    "scripts/apply_v0121_live_lane_startup.py",
    "scripts/refine_v0121_live_lane_startup.py",
    "scripts/refine_v0121_review.py",
    "scripts/refine_v0121_straggler_timestamp.py",
]:
    require(not Path(temporary_path).exists(), f"temporary construction file must not ship: {temporary_path}")

require("check_startup_lane_health_invariants.py" in stability_gate, "transport stability gate must retain startup/lane-health regressions")
require("Audit Transport v3 invariants" in validate_workflow and "check_transport_v3_invariants.py" in validate_workflow, "Validate Source must enforce Transport v3 invariants")
require("Audit Transport v3 invariants" in build_workflow and "check_transport_v3_invariants.py" in build_workflow, "unsigned IPA build must enforce Transport v3 invariants")
require("Audit seek stall invariants" in validate_workflow and "check_seek_stall_invariants.py" in validate_workflow, "Validate Source must enforce seek stall invariants")
require("Audit seek stall invariants" in build_workflow and "check_seek_stall_invariants.py" in build_workflow, "unsigned IPA build must enforce seek stall invariants")
require("Audit transport stability invariants" in validate_workflow and "check_transport_stability_invariants.py" in validate_workflow, "Validate Source must enforce transport stability invariants")
require("Audit transport stability invariants" in build_workflow and "check_transport_stability_invariants.py" in build_workflow, "unsigned IPA build must enforce transport stability invariants")
require("Audit Scheduler v2 invariants" in validate_workflow and "check_scheduler_v2_invariants.py" in validate_workflow, "Validate Source must enforce Scheduler v2 invariants")
require("Audit Scheduler v2 invariants" in build_workflow and "check_scheduler_v2_invariants.py" in build_workflow, "unsigned IPA build must enforce Scheduler v2 invariants")
require("Audit live lane/startup invariants" in validate_workflow and "check_live_lane_startup_invariants.py" in validate_workflow, "Validate Source must enforce live lane/startup invariants")
require("Audit live lane/startup invariants" in build_workflow and "check_live_lane_startup_invariants.py" in build_workflow, "unsigned IPA build must enforce live lane/startup invariants")
require('IPA_NAME="EmbyPlayerLab-0.12.2-${GITHUB_SHA::7}-unsigned.ipa"' in build_workflow, "unsigned IPA filename must identify v0.12.2")
require('scripts/check_min_os.sh "${{ steps.app.outputs.path }}" "15.0"' in build_workflow, "Release build must still validate iOS 15.0 minimum OS")

print("Transport v3 invariants passed")
