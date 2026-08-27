# OnePlayer Technical Decisions

This file records decisions that have already consumed significant implementation or real-device testing. Do not casually re-run rejected directions.

## D001 — Media bytes never transit the NAS

Normal playback is client-direct:

`Emby / STRM → HTTP 302 → 115/CDN → iPhone`

The NAS/Emby side may resolve or redirect, but must never become the media-byte relay.

## D002 — Real byte demand is authoritative

Never use `targetTime / duration × fileSize` as a Seek/Transport anchor. Actual player byte demand / HTTP Range demand is authoritative.

## D003 — Unified transport/cache is shared infrastructure

HTTP 302, Range/206, cache and playback-demand handling live below playback engines. Do not create per-engine 115/CDN networking or UI-owned transport state.

## D004 — Fast interaction beats exact Seek

For double-tap/rapid ±N-second Seek, latency is P0. MPV `absolute+keyframes` is the accepted runtime contract; `absolute+exact` is rejected as the normal path and there is no hidden second corrective Seek.

## D005 — MDK is not automatic daily authority

MDK remains manual/experimental backup. MPV is the normal engine because repeated real-device work did not show MDK beating MPV on repeated fast Seek consistency and long-tail stability. Do not silently restore broad automatic fallback.

## D006 — Renderer ownership must respect MoltenVK/MPV

UIKit may own host geometry; product code must not casually seize `CAMetalLayer.delegate`, drawable or swapchain ownership from MoltenVK/MPV.

## D007 — System navigation is system-owned

Native iOS push/pop and interactive-pop remain system-owned. Immersive appearance may adapt around navigation but must not replace that ownership.

## D008 — PiP uses a visual bridge; MPV remains authority

PiP is frozen at Build173 unless new real-device evidence or a materially better renderer-lifecycle approach appears. SampleBuffer is the native visual bridge; MPV remains playback/audio/time authority; background video suspension uses `vid=no`; PiP X = `pauseAndSuspend`; no periodic bridge catch-up loop is part of the frozen design.

## D009 — Evidence levels remain explicit

Always distinguish:

1. Code written
2. CI passed
3. IPA produced
4. Real-device tested
5. Stable / frozen

CI/IPA alone never proves a runtime problem solved.

## D010 — Episode changes replace the source-owned playback session

Selecting another episode replaces the complete source-owned playback session while fullscreen presentation remains. Each selected episode gets a fresh controller/orchestrator/transport context/Emby session. Temporary 115/CDN URLs are resolved only after explicit selection or trusted natural auto-next. Auto-next requires the existing `PrematureEOFGuard` trusted natural-end classification; raw EOF/starvation/premature EOF is insufficient. Build176 was real-device accepted and merged through PR #253.

## D011 — Emby TV API owns canonical episode order

Canonical series order comes from `GET /Shows/{SeriesId}/Episodes`; OnePlayer preserves Emby's returned order. `SeasonId` is season-membership authority, not a second in-season sort owner. Do not add title/file/date/item-ID/artificial-number fallback sorting. Build178 was accepted and merged through PR #254.

## D012 — Home-carousel keeps one UIKit owner; full-width page slots use acquisition-relative render motion

Retain Build198 lifecycle ownership and Build208 full-width `pageStep = width`. Horizontal acquisition remains UIKit-owned; vertical acquisition yields to the Home `UIScrollView`; predicted touch stays release-only; one `V3HomeCarouselTransitionState` remains the high-frequency owner; first↔last modulo ownership and settle/cancel semantics remain unchanged. Do not add a second SwiftUI owner, timer, watchdog, retry, interpolation, debounce or throttle.

Build208 vs EX real-device video rejected whole-range easing as the remaining fix: OnePlayer published touch-down translation already accumulated before horizontal acquisition, creating a hold-then-jump start, then visually lagged; EX behaved like a short take-up followed by nearly 1:1 motion. EX also kept foreground near opaque while OnePlayer tied foreground fade to the compensating visual progress.

Build215 therefore establishes the current evidence-backed contract: acquisition records `horizontalAcquisitionTranslation` and publishes no acquisition movement; subsequent render is exactly `currentTranslation - acquisitionTranslation`; original touch-down distance still owns 0.28 commit and 0.48×width predicted release, including one-sample fast release; transition foreground pages remain opaque and backdrop crossfade is independent. Whole-range easing/travel-percentage tuning is rejected as the primary solution for first-sample coarseness.

Carousel Build214 / 0.14.47 passed CI/IPA but was retired before distribution due identity collision with parallel poster work. Current carousel candidate is **Build215 / 0.14.48**, tested source `d22634ece2f29eba2e60de01182bf15d4ba554a7`, cleanup head `01a13615fc056fd3b13296d98abfaa7a6aa2b46d`; run/job `33058337107 / 98470624555`; artifact `9640692378`; IPA SHA `6551a5e9e8a28a66bd4f105118387e8fc9378b72bd47778897f013b411c06c97`; MinOS 15.0 verified. Build215 target-device testing positively confirms two parts of this contract: the acquisition-relative start is now about as fine as EX, and keeping interactive foreground pages opaque removes the previous blurred/ghosted feel. The overall tactile smoothness still trails EX, described by the user as smooth glass vs rough paper. The residual cause is not yet established; a backdrop-blend timing difference seen in 30fps analysis is only a hypothesis. Evidence is **Code written / CI passed / IPA produced+verified / real-device tested / partial success / not stable**.

Retain acquisition-relative X, opaque foreground, page slots and the original release semantics. Do not add another easing/smoothing layer or change the backdrop curve without stronger evidence; investigate the touch→state→SwiftUI render/compositing cadence first.

## D013 — Detail high-rate scroll and warm presentation stay scoped and presentation-only

High-frequency native detail scroll offset stays in the Hero-scoped owner, not root detail state. Persistent warm detail cache is presentation-only: safe display metadata may be cached, but PlaybackInfo, MediaSource, PlaySession, ResolvedPlaybackSource and temporary 115/CDN URLs remain live/session-owned. Build182 was real-device accepted/frozen; Build184 visual hierarchy was accepted and merged through PR #255.

## D014 — Emby server entry selection is Session-owned and media transport remains separate

`SessionStore` owns saved sessions/server configuration. Alternate routes must resolve to the same Emby Server ID. Route latency is editor/diagnostic state only. Same-server route selection changes only the Emby API/server entry; media remains `Emby / STRM → 302 → 115/CDN → iPhone`. Player/Transport/Cache/Seek/Resume/PiP remain outside this feature.

Credential split accepted at Build199: AccessToken and retained password are separate Keychain records; password is absent from UserDefaults/plain server config/diagnostics/synchronized JSON. When iCloud sync is enabled, password is additionally stored in a separate synchronizable Keychain item. Build199 was real-device accepted and merged through PR #256.

## D014A — Auto-start is cached-first; retained password is Keychain-owned

After local session/token restore, auto-start constructs the authenticated Emby root immediately so existing Home snapshots/image cache can render while route selection/live refresh proceeds. If route selection fails and an initial client exists, stale cached Home remains. Edit Server preloads the retained local Keychain password; unchanged password does not force reauthentication; changed password must preserve same Server ID/User ID before AccessToken replacement. Manual first-level server entry retains its pre-Home route-selection behavior.

## D015 — Detail episode browsing separates selection from playback

Detail horizontal episode cards select only. `selectedEpisodeID` is the visible selection owner. Default selection is explicit initial episode → resumable episode → canonical first episode. Quick range buttons select the range's first canonical episode. Main Play/Resume targets selected episode through the source-owned playback path. Full picker stays mounted through playback. Build191 was accepted and merged through PR #257.

## D016 — Player episode grouping follows real SeasonId; very large rows are lazy

Player picker consumes the same canonical episode/season semantics as detail. Episode `SeasonId` resolves against real Season item/index first; `ParentIndexNumber` is fallback only. Build178 server order remains authoritative. The horizontal player episode row uses `LazyHStack`; do not solve large seasons through truncation/artificial pagination/second sorting. Build195 was accepted and merged through PR #258.

## D017 — Non-playback page persistence is a warm presentation snapshot, not a second data authority

Build213 / OnePlayer 0.14.46 establishes the accepted first milestone for Favorites + Library page persistence:

- Favorites and the Library 7 top tabs may restore the last accepted presentation data from disk before live network completion so relaunch does not regress to an empty wait state;
- live Emby refresh on page/tab entry remains authoritative and is never suppressed merely because a snapshot exists;
- only fresh state already accepted by the existing page owner may replace the disk snapshot; refresh failure must not erase a valid old snapshot;
- necessary paging frontier/content IDs may be restored with the warm content so subsequent pagination continues from the recovered owner state;
- loading/error/isFetching/generation/sheet/button state is transient and must not be persisted;
- Library `sortBy` is a Preference concern and is not owned by the page snapshot; `selectedTab`, scroll position and Favorites root lifetime are separate browse-session/lifecycle concerns and were intentionally not added to this milestone;
- disk snapshots never become authority for Favorite/Played/PlaybackPosition, playback Session, MediaSource, CDN URL, Transport Range or any other live business/playback state;
- current cache identity remains safely route-scoped by `baseURL + userId + scope (+ library.id)`. Build199 same-server multi-route selection can therefore cause a cache miss when a different URL wins on a later launch, but the accepted implementation prefers this benign miss over weakening isolation with `serverName` or broadening stable SessionStore ownership without evidence;
- storage remains `Library/Caches/OnePlayer/PagePresentation`, JSON schema 1 with atomic writes and no TTL/timer/watchdog/retry/fallback layer.

Build213 dedicated MPV run/job `33052588518` / `98451457434` succeeded, artifact `9638292306` was produced with MinOS 15.0, and the user reported target-device acceptance on iPhone 15 Pro Max / iOS 17.0 on 2026-08-27. Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115/CDN and shared Home/poster owners were not changed by this feature.

## D018 — Detail range taps cancel native row deceleration before selection

The detail horizontal episode row remains SwiftUI-owned for layout/selection, but quick range-pill taps must not compete with an in-flight native `UIScrollView` deceleration. When the existing episode row is actively decelerating, the range action first synchronously freezes that same native scroll view at its current `contentOffset`, then runs the accepted Build191 range-first selection and existing 0.32 s `ScrollViewReader.scrollTo` target animation. Non-decelerating taps are unchanged.

This is an interaction-ownership fix, not a second episode-selection owner: no timer, watchdog, retry, debounce, throttle, fallback or duplicate range state is allowed. Build182 detail Hero/cache, Build178 canonical order, Build191 detail selection/navigation, Build195 player grouping/lazy row and all Player/MPV/PiP/Transport/Cache/Session contracts remain separate and unchanged. Build216 / OnePlayer 0.14.49 passed dedicated Xcode 16.4 Release CI (`33064051545 / 98489652724`), produced artifact `9643031850` with IPA SHA-256 `e3054a53398e1df48134fecd8c30671e10ecaa8a93df5483936adcf10e055075` and MinOS 15.0, was accepted on iPhone 15 Pro Max / iOS 17.0 on 2026-08-27, and merged through PR #261 at `f5ad126b7b47e9713b1949780a6507fb3f0ca50f`.

## D019 — Aether is manual-only and shares exact-byte UnifiedTransport

AetherEngine 6.50.0 is integrated as a manually selectable experimental engine for comparison; MPV remains the default/automatic playback authority. Aether does not receive an automatic fallback role. Its custom `IOReader` consumes the existing `PlaybackTransportContext` / UnifiedTransport session and reprioritizes only exact byte offsets supplied by the demuxer/current reader cursor; it must never use time→byte proportional guessing or a separate 115/CDN networking stack.

The selected Aether release requires iOS 16 and newer SDK/toolchain APIs. Direct iOS15 static import was proven incompatible, while a runtime loader shim/local compatibility fork was rejected as non-minimal; therefore the Aether comparison candidate raises only this product line to MinOS 16.0 and uses Xcode 26.3. Build219 / OnePlayer 0.14.52 exact source `b1a06cb2b3dc9cf715fc5d49a7b324780aa23981` passed Release CI (`33096553966 / 98602865604`) and produced verified artifact `9656814369`, IPA SHA-256 `8df11d2db597fd6841a3708976824b21879ee0d47257c1766d1704cc4196d06d`. This is **CI/IPA evidence only**: Aether remains experimental until target-device behavior is reported, and frozen MPV fast Seek/PiP/STRM→302→115/CDN contracts remain unchanged.
