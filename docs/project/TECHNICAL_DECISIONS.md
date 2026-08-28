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

Retain acquisition-relative X, opaque foreground, page slots and the original release semantics. Build217/219 establish that refresh cadence is a first-class part of this interaction contract: Build217's passive diagnostic path ran around 50–60 Hz despite a 120 Hz-capable target device, while Build219's drag-local device-max `preferredFrameRateRange` request raised delivered touch / publication / SwiftUI render / display cadence to roughly 98–110 Hz without changing motion math. Therefore do not revert the evidence-backed high-refresh direction or replace it with another easing/smoothing layer. Coalesced/predicted touches are still not interactive render authority.

Build219's strongest remaining repeatable pattern is a 50 ms display gap about 19.6–25.3 ms after persistent 1400px callbacks, while other residual gaps also cluster near Hero callbacks. Build221 directly isolated persistent presentation during active horizontal drag by keeping current persistent opaque and not mounting target persistent. Target-device testing found acceptable initial take-up but overall feel still behind EX, and the supplied recording shows a pale/white washed intermediate state because Hero continues crossfading over a frozen outgoing persistent backing. Therefore the whole-drag frozen-persistent strategy is **rejected as the final visual/performance contract**; this does not prove persistent has zero cost, only that freezing it is insufficient and visually wrong.

Build225 is the next narrow horizontal diagnostic from the exact Build219 tested 120Hz line: restore normal persistent current/target crossfade, keep the already-visible current Hero opaque during active drag, and defer only target Hero clear 1400px mounting until drag ends. Target-device horizontal testing reports the version feels **noticeably finer**. Because input ownership, acquisition-relative motion, foreground travel, release semantics, preload, persistent behavior and exact device-max refresh were retained, fresh target-Hero first presentation during active finger tracking is now established as a **material causal contributor** to the residual rough-paper feel. Build225 itself is not the final visual contract because it withholds incoming clear Hero during drag.

The resulting presentation contract is: do not reintroduce a freshly mounted target clear-Hero surface into the active finger-tracking path unless new real-device evidence overturns this result. Build226 implements this visually by deriving a current+previous+next Hero residency set from the existing settled current ID. Both adjacent targets remain resident through drag/release; normal Hero opacity blending is restored; after settle the resident window may rotate one new neighbor outside direct finger tracking. Target-device testing is materially positive: the user reports the overall carousel is now fairly close to EX and much better than the original OnePlayer carousel. Therefore three-slot Hero residency is retained as the current evidence-backed presentation direction, while the carousel remains Active because the final hand-feel gap is not closed.

The Build226 slow-drag recording also establishes a separate visual symptom: large fallback movie-title text visibly shimmers while the foreground page moves. Frame-by-frame inspection shows title, rating/year/type and overview translate together with stable relative geometry, so there is no evidence for a title-specific state/layout owner bug. Build227 is a narrow diagnostic of subpixel foreground presentation: it rounds only final page X presentation to `UIScreen.main.scale` physical pixels. This is not yet an accepted motion contract; reject it if target-device testing produces staircase feel or fails to reduce text shimmer. Do not stack drawing-group/offscreen compositing, interpolation or another smoothing owner before this A/B is resolved.

Build227 target-device testing rejects physical-pixel foreground X quantization as a sufficient movie-title shimmer fix: the shimmer remains visible, so do not carry pixel-grid rounding forward without new evidence.

**Build228 target-device release-tail acceptance:** exact Build227 source showed the device-max refresh request ended inside `touchesEnded` before the existing commit/cancel animation. Carousel Build228 returns to the Build226 presentation baseline and retains that same proven max-refresh request through interactive settle/cancel. The user now reports the release tail is “差不多了，尾巴这里先这样吧”. Therefore retain max-refresh-through-settle and stop further release-tail easing/duration/velocity tuning unless new regression evidence appears. This freezes only the release-tail sub-contract for the current phase; the Home carousel remains Active because slow-drag title shimmer and residual overall refinement versus EX are still unresolved.

Because an independent poster task also used `Build228 / 0.14.61`, future evidence must attribute the carousel package by branch `perf/home-carousel-release-refresh-build228`, tested source `bdf63c7562fcd1edc1d224872230e988ac462281`, run/job `33156739621 / 98801196041` and artifact `9679963420`, not by build number alone.

Build230 is the next diagnostic implementation of the same presentation-lifecycle principle, not yet a frozen contract. The existing derived current+previous+next residency window is reused for the persistent blurred backdrop so the adjacent target persistent surface is mounted before active drag while normal opacity crossfade remains. This is specifically different from rejected Build221: no outgoing-background freeze or visual mismatch is introduced. Accept this only if target-device testing improves active-drag cadence/title stability without moving the hitch to post-settle resident-window rotation or adding unacceptable compositor/memory pressure.

Build230 target-device slow-drag testing reports that the movie-title shimmer still remains. Therefore persistent-neighbor residency is rejected as a sufficient title-shimmer fix and must not be promoted to the foreground-stability contract on that basis; no broader Build230 hand-feel/post-settle conclusion is inferred from the limited report. Build231 is the next single-variable diagnostic: return to cleaned Build228 and place one `compositingGroup()` boundary around each existing foreground page before unchanged opacity/X translation. This tests foreground child-layer composition without adding drawingGroup/Metal rasterization, a second state owner, interpolation or timing changes. Build231 is not an accepted contract until target-device evidence exists.

Build231 target-device evidence is now positive and supersedes that pending status for the foreground-compositing subproblem: the user reports the slow-drag movie-title text is clearly steadier and not blurred. Retain the single page-level `compositingGroup()` as the current foreground title-stability contract unless new device regression evidence overturns it. This does not freeze the whole carousel.

The same session newly exposes a dwell-sensitive first-visible-step symptom, but the user is unsure whether it existed before Build231. Exact UIKit recognizer source acquires horizontal ownership on the first delivered move at or beyond 0.5pt, stores that event's translation as `horizontalAcquisitionTranslation`, returns without visual publication, then publishes `currentTranslation - acquisitionTranslation` on the next delivered move. That structure is a plausible explanation for different first-step sizes when immediate motion changes delivered-sample spacing, but plausibility is not enough to alter the retained acquisition contract. Build232 therefore measures touch-down→acquisition and acquisition→first-render timing/X only. Do not promote coalesced/predicted touch to a second visual owner or add smoothing/easing before this measurement.

Build232 target-device measurement now provides the missing evidence. The user repeatedly confirms immediate touch-and-drag is very likely to show the coarse first step while hold-before-drag is almost always fine. The log has 34 drags split cleanly into 20 first steps of 0.33–2.33pt and 14 of 8.00–13.67pt, with zero middle samples and a median acquisition→first-render interval of 8.34ms. This validates changing the acquisition-frame sample usage, but does **not** justify a timer, synthetic interpolation or artificial step cap. Build233 is therefore allowed as one narrow exception to the earlier “coalesced is diagnostic only” rule: on the acquisition UIEvent only, the immediately preceding real coalesced touch may define the render baseline if its delta continues in the already-selected horizontal direction; the current delivered touch is then published immediately. After that event, delivered touch remains the sole interactive render authority and predicted touch remains release-only. Treat this as an A/B until target-device evidence confirms it.

Build231 foreground `compositingGroup()` remains retained because the first target-device A/B made title text clearly steadier without blur, but Build232 reproduced title jitter with the same rendering path. Therefore compositing is a material improvement, not a frozen claim of complete title stability. Residual cadence/frame-delivery investigation remains open after the acquisition-start issue is resolved.


Build233 target-device evidence refines but does not replace the acquisition-relative contract. A real acquisition-local coalesced predecessor is useful when present: 42/67 same-event starts materially reduce first-step size versus 25 fallback starts. However the user still perceives frequent coarse starts and the overall >=5pt rate remains 41.8%, so the Build233 one-event predecessor implementation is **not yet accepted as a final contract**. Do not hide the residual with a numeric step cap, easing, timer or interpolation. Build234 first measures whether residual starts are caused by missing predecessor availability, zero/direction guard rejection, or a legitimately large predecessor delta/age. Only one of those evidence-backed causes should drive the next behavioral A/B. Build231 foreground compositing remains retained as beneficial; Build226 Hero residency and Build228 max-refresh-through-settle remain unchanged.


Build234 resolves the remaining Build233 acquisition-fallback ambiguity. In 31 target-device drags, every fallback is `acq_predecessor_status=none` with `acq_coalesced_count=1`; there are zero `direction` and zero `zero` rejections. When a same-event predecessor exists, the path remains materially finer; when the acquisition event has only the current sample, the recognizer has no real earlier same-event touch and the old next-delivered fallback recreates the coarse start. Therefore do not remove the same-direction guard and do not introduce synthetic interpolation or a hard first-step cap. A future A/B may extend the one-time real-coalesced-baseline rule to the first post-acquisition event only for these one-sample acquisition cases, provided it still uses a real direction-compatible predecessor and returns immediately to delivered-touch ownership; if no such real predecessor exists, preserve the existing fallback.

Build236 implements the Build234-authorized one-event extension without changing the retained owner model. Only when acquisition itself is `none/count=1`, the recognizer may inspect the first post-acquisition UIEvent for a real coalesced predecessor after the acquisition timestamp; if that predecessor continues in the already-selected horizontal direction, it defines the render baseline once while the current delivered touch is still the visual publication. The pending path is then cleared immediately. Acquisition events with an accepted predecessor are unchanged; if the first post-acquisition event has no valid real predecessor, the old fallback remains. This does not authorize continuous coalesced rendering, interpolation, a numeric step cap, timer/easing smoothing, predicted-touch render authority or a second state owner. Build236 is CI/IPA verified but target-device pending, so this one-event extension remains an A/B rather than a frozen acquisition contract. Build235 is reserved by the independent Aether task; carousel uses Build236 / 0.14.69.


Build236 target-device evidence accepts the **first post-acquisition real-predecessor extension as materially positive**, but not yet as a frozen final contract. In 53 drags, overall >=5pt first steps fall to 10/53 (18.9%) and >=8pt to 3/53 (5.7%). Of 20 acquisition-event `none` starts, 16 obtain one real direction-compatible predecessor on the first post-acquisition UIEvent and then have median first step 2.0pt with zero >=5pt starts; the remaining 4 expose no predecessor on that event and remain coarse. Therefore retain the Build236 one-event extension. Do not hide residual real motion with a numeric first-step cap: six acquisition-accepted >=5pt starts are real 4.17ms predecessor deltas of roughly 5.33–11pt. If the residual 4/53 family is pursued, measure the second post-acquisition UIEvent first; current evidence does not prove a usable predecessor exists there. Build231 foreground compositing remains materially beneficial and title jitter is now very slight, but rare cadence tails remain and the whole carousel is not frozen.

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

## 2026-08-28 — Carousel acceptance is horizontal interaction, not general Home vertical scrolling

- **Decision:** `DEV-home-carousel-drag-smoothness` is accepted/rejected by target-device horizontal carousel swipe/drag behavior. General Home vertical inertial scrolling is supporting diagnostic evidence only.
- **Reason:** after Build224 still showed visible vertical jitter, the user explicitly clarified that the active goal is optimizing the carousel itself. The previous Build222–224 vertical A/B sequence was useful only as a stress/isolation detour and had begun to replace the actual product acceptance question.
- **Consequence:** do not return to vertical-only carousel candidates. Build221 is rejected as the final frozen-persistent strategy. Build225 positively identifies active-drag target-Hero first presentation as a material contributor; Build226 now validates three-slot Hero residency with materially positive horizontal real-device evidence; Build227 isolates the remaining slow-drag foreground-title shimmer. Horizontal evaluation still covers first movement, sustained tracking, reversal, clear-Hero/backdrop continuity and release/settle.
- **Evidence:** latest user target-device feedback outranks the prior diagnostic plan. Build225 and Build226 now both have direct positive horizontal real-device evidence; Build227 has Code/CI/IPA evidence and awaits target-device A/B.

## 2026-08-28 — Library presentation snapshot write must not serialize/write on MainActor during pagination

Build228 target-device diagnostics captured a 55.1 ms real grid dragging frame beside a 39.7 ms synchronous Library persistent-snapshot operation, while image publish/Combine→UIKit adoption measured 0.0 ms and page result apply 0.3 ms. For the Library presentation cache, Build229 therefore retains MainActor-owned immutable state capture and existing Build213 cache identity/schema/content/atomic-write semantics, but moves object→JSON conversion, JSON serialization and disk write onto one serial `.utility` queue and awaits completion to preserve ordering. This decision applies only to the evidenced Library path; Favorites remains unchanged. Build212 predates Build213, so this is not declared the universal poster-hitch root cause. Exact Build229 source `f5e3e3eb144578c863b172e3bd3a1aa13e5c2177` is CI/IPA verified and still requires target-device acceptance.
