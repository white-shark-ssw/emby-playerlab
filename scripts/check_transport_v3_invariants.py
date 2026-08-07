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
require(lane_body.count("invalidateAndCancel()") == 1, "persistent lane session may only be invalidated during lane teardown")

require("reuse active sequential stream" in unified, "in-range playback demand must reuse the active sequential stream")
require("promote slot0 sequential->urgent" not in unified, "legacy in-range cancel/reopen promotion must not return")
require("cancelSlot(0, reason: \"real-seek-demand\")" in unified, "true far seek must still be able to retarget slot 0")
require("client.invalidate()" in unified, "transport stop must explicitly tear down the persistent connection pool")

require("automaticProfile=AVPlayerResourceLoader+UnifiedTransportV3" in orchestrator, "native automatic route must use ResourceLoader + Unified v3")
require("automaticProfile=MPV+UnifiedTransportV3" in orchestrator, "compatibility automatic route must use MPV + Unified v3")
require("self.currentKind = .resourceLoaderAVPlayer" in orchestrator, "native automatic engine must be ResourceLoader AVPlayer")
require("return .resourceLoaderAVPlayer" in engine, "automatic preference must resolve native media to ResourceLoader AVPlayer")
require("return MPVPlayerEngine(sharedTransportSession: transportContext?.session)" in controller, "MPV must consume the shared Unified transport session")
require("ktvCacheHandoff" not in controller, "KTV cache handoff must not leak into Transport v3 engine switching")
require("transport=KTVProxyTransportV2" not in mpv, "MPV core must not identify automatic playback as KTV transport")
require(mpv.count("if sharedTransportSession == nil") == 2, "MPV should have one direct fallback in prepare and one compatibility fallback")

require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
require(project.count('MARKETING_VERSION: "0.11.0"') == 2, "project marketing version must be 0.11.0 in both settings scopes")
require(project.count('CURRENT_PROJECT_VERSION: "54"') == 2, "project build number must be 54 in both settings scopes")
require("<string>0.11.0</string>" in info and "<string>54</string>" in info, "Info.plist version/build mismatch")
require('sourceVersion = "0.11.0"' in identity, "AppIdentity source version mismatch")

for temporary_path in [
    ".github/workflows/apply-transport-v3-core.yml",
    "scripts/apply_transport_v3_core.py",
    "scripts/refine_transport_v3.py",
]:
    require(not Path(temporary_path).exists(), f"temporary construction file must not ship: {temporary_path}")

require("Audit Transport v3 invariants" in validate_workflow and "check_transport_v3_invariants.py" in validate_workflow, "Validate Source must enforce Transport v3 invariants")
require("Audit Transport v3 invariants" in build_workflow and "check_transport_v3_invariants.py" in build_workflow, "unsigned IPA build must enforce Transport v3 invariants")
require('IPA_NAME="EmbyPlayerLab-0.11.0-${GITHUB_SHA::7}-unsigned.ipa"' in build_workflow, "unsigned IPA filename must identify v0.11.0")
require('scripts/check_min_os.sh "${{ steps.app.outputs.path }}" "15.0"' in build_workflow, "Release build must still validate iOS 15.0 minimum OS")

print("Transport v3 invariants passed")
