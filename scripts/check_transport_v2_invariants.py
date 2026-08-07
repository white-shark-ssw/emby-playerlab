from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Transport v2 invariant failed: {message}")


bridge = read("Sources/Cache/EPLKTVCacheBridge.m")
session = read("Sources/Cache/KTVCachePlaybackSession.swift")
ktv_av = read("Sources/Player/KTVAVPlayerEngine.swift")
mpv = read("Sources/Player/MPVPlayerEngine.swift")
controller = read("Sources/Player/PlayerController.swift")
orchestrator = read("Sources/Player/PlaybackOrchestrator.swift")
engine = read("Sources/Player/PlayerEngine.swift")
project = read("project.yml")
wrapper = read("Sources/Player/KTVMPVPlayerEngine.swift")

ua_decl = "static NSString * const EPLKTV115UserAgent"
require(bridge.count(ua_decl) == 1, "115 User-Agent must have exactly one declaration")
require("115Browser/36.0.0" in bridge, "stable 115Browser UA profile missing")
require("downloadSetAdditionalHeaders" in bridge, "KTV additional outbound headers missing")
require('requestHeaders[@"User-Agent"] = EPLKTV115UserAgent;' in bridge, "preload requests must pin the same UA")
require("EPLKTVIsSensitiveRemoteHeader" in bridge, "central sensitive remote-header filter missing")
require('[lower hasPrefix:@"x-emby-"]' in bridge, "all X-Emby-* headers must be blocked")
require('[lower hasPrefix:@"x-mediabrowser-"]' in bridge, "all X-MediaBrowser-* headers must be blocked")
for token in ["authorization", "cookie", "set-cookie"]:
    require(token in bridge, f"sensitive header filter missing {token}")
require("EPLKTVIsSensitiveRemoteHeader(key)" in bridge, "preload requests must use the central sensitive-header filter")
require('EPLKTVIsSensitiveRemoteHeader(key) || [lower isEqualToString:@"user-agent"]' in bridge, "KTV whitelist must reject auth prefixes and source User-Agent")

require("private let segmentBytes: Int64 = 512 * 1_048_576" in session, "background claims must be long-lived 512 MiB ranges")
require("probe skipped transport-v2" in session, "legacy wrong-UA redirect probe must stay disabled")
require("enableSecondaryAfterWarmup" in session and "session-warmup-dual" in session, "lane B must start from session warmup rather than UI metrics polling")
require("dual warmup deferred by playback priority" in session, "warmup collision with seek must reschedule rather than permanently lose lane B")
require("playbackPriorityUntil.timeIntervalSince(now) + 0.05" in session, "warmup retry must follow the latest foreground priority deadline")
require("self?.enableSecondaryAfterWarmup()" in session, "deferred warmup must retry the same session-owned enable path")
require("playback-priority-yield-secondary" in session, "starvation must yield only secondary lane")
require("user-seek-yield-secondary" in session, "user seek must immediately yield secondary lane")
require("keep-primary-yield-secondary" in session, "seek must preserve warmed primary lane")
require("playbackPriorityUntil = max(playbackPriorityUntil" in session, "seek priority window must suppress immediate lane-B restart")
require("user-seek-priority-ended" in session, "secondary lane must have delayed post-seek resume")

pause_start = session.index("private func pauseBackgroundForPlaybackDemand")
pause_end = session.index("private func stopSecondaryLane", pause_start)
pause_body = session[pause_start:pause_end]
require("stopSecondaryLane" in pause_body, "playback starvation must stop lane B")
require("primaryLane.loader" not in pause_body and "primary?.close" not in pause_body, "playback starvation must never tear down primary lane")

require("headers: [:]" in ktv_av, "AVPlayer must talk to localhost without forwarding source headers")
require("takeCacheSessionForHandoff" in ktv_av, "AVPlayer must support KTV cache handoff")
require("automaticProfile=AVPlayer+KTVProxyTransportV2" in orchestrator, "native automatic route must use KTV proxy")
require("automaticProfile=MPV+KTVProxyTransportV2" in orchestrator, "compatibility automatic route must use KTV proxy")
require("self.currentKind = .ktvAVPlayer" in orchestrator, "native automatic engine must be KTV AVPlayer")
require("return .ktvAVPlayer" in engine, "automatic native preference must resolve to KTV AVPlayer")

require("KTVMPVPlayerEngine" in controller and "return KTVMPVPlayerEngine" in controller, "automatic MPV must use KTV proxy wrapper")
require("ktvCacheHandoff" in controller and "ktvCacheSession: ktvCacheHandoff" in controller, "AVPlayer/MPV switch must preserve session cache")
require("takeCacheSessionForHandoff" in wrapper and "cacheSession: KTVCachePlaybackSession? = nil" in wrapper, "MPV wrapper must support KTV cache handoff")
require("KTVCachePlaybackSession" in wrapper and "headers: [:]" in wrapper, "KTV MPV wrapper must use localhost proxy without source headers")
require("load direct HTTP transport=KTVProxyTransportV2" in mpv, "MPV must support localhost HTTP Transport v2")
require("url.absoluteString" in mpv, "MPV localhost URL must load as normal HTTP URL")

require('iOS: "15.0"' in project and 'deploymentTarget: "15.0"' in project, "Deployment Target must remain iOS 15.0")
require('MARKETING_VERSION: "0.10.0"' in project and 'CURRENT_PROJECT_VERSION: "53"' in project, "Transport v2 version/build mismatch")

print("Transport v2 invariants passed")
