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


Build236 target-device evidence is now accepted as the **frozen-for-current-phase interaction/presentation foundation**, not a mandate to chase perfect metrics. The user explicitly accepts the remaining 4/53 double-no-predecessor first-step cases and does not want further perfection-driven sampling changes unless a new regression appears. Retain Build236 post-acquisition real-baseline handling, Build231 page-level foreground `compositingGroup()`, Build226 Hero residency and Build228 max-refresh-through-settle/release-tail behavior. This freezes those subcontracts only; the carousel remains Active for newly reported release/presentation details.

Build237 is a narrow two-variable A/B backed by current source and explicit user request. Release sensitivity changes only the predicted-distance fling gate from `0.48×width` to `0.24×width`; the ordinary actual-progress threshold remains `0.28`, so slow-drag commit behavior is not intentionally made 50% easier. Separately, persistent backdrop crossfade no longer applies complementary opacity to two separate opaque source-over layers. At blend 0.5 that old composition covers only 75% (`0.5 + 0.5×0.5`) and can expose the light `systemBackground`, matching the newly reported white flash. Build237 therefore keeps outgoing persistent fully opaque and fades incoming over it using the unchanged backdrop blend progress. Do not remove the established system-background gradient or image-contrast scrims merely to hide the symptom. CI/IPA are verified; real-device acceptance is pending.


Build237 target-device evidence accepts the persistent source-over white-flash correction but rejects **predicted total displacement as the sole fling-intent model**. Halving the gate from 0.48×width to 0.24×width did not reproduce EX-style almost-in-place flick commits; it only moved the distance boundary. Preserve the 0.28 actual-progress slow-drag rule and do not continue lowering width fractions.

Build238 target-device diagnostics supply the missing evidence: intended quick flicks are about 1139.8–2239.8 pt/s in `abs(last_move_delivered_velocity_x)`, while short slow drags are 0–160 pt/s, with a wide empty interval between them. `end_velocity_x` overlaps the two intent families and `predicted_extra_x` is often absent or tiny for clear quick flicks, so neither becomes the sole authority. This validates latest delivered move velocity as the next release-intent signal.

Build239 is the narrow behavioral A/B: keep `actualProgress >= 0.28`; remove the rejected 0.24×width predicted-total-distance commit gate; additionally commit when latest delivered move velocity is direction-compatible and at least 600 pt/s in directional magnitude. `600` is an evidence-bounded OnePlayer tuning value inside the measured gap, not an asserted EX constant. CI/IPA are verified but target-device acceptance is pending, so the velocity threshold is not frozen yet. Retain the frozen-for-current-phase Build236 start-step, Build231 foreground compositing, Build226 Hero residency, Build228 max-refresh-through-settle/release-tail behavior and accepted Build237 persistent source-over correction.

Build239 target-device testing accepts the velocity-intent release contract for the current phase: keep `actualProgress >= 0.28` for ordinary drag and allow commit when direction-aware latest delivered move velocity is `>=600 pt/s`; keep the rejected predicted-total-distance width gate removed. The user reports no issue with Build239. Freeze this release-intent behavior unless new false-commit/false-cancel evidence appears.

A subsequent EX-only 30fps reference clip visibly decelerates into settle over roughly the final 0.15–0.25s, without obvious rebound. OnePlayer Build239 already uses `.easeOut(duration: 0.22)` for commit and `.easeOut(duration: 0.18)` for cancel. Therefore this reference does not by itself authorize another release-tail tuning build; compare a matched OnePlayer capture first if tail matching is reopened.

Matched OnePlayer-vs-EX 30fps tail evidence closes the remaining carousel release-tail comparison for the current phase. Build239's existing `.easeOut(duration: 0.22)` commit tail produces materially similar normalized late-frame settle decay to EX, while cancel remains `.easeOut(duration: 0.18)`. Do not change release duration/curve, 600 pt/s fling threshold, 0.28 slow-drag threshold, Build236 start-step handling, Build231 foreground compositing, Build226 Hero residency or Build237 persistent white-flash correction without a new target-device regression. Home carousel is frozen-for-current-phase at Build239 / 0.14.72; this does not change the merged overall product baseline from Build216.

New target-device tactile evidence after the matched tail comparison narrows the residual EX gap to **release-handoff momentum continuity**, not the late ease-out shape. Build239's latest-delivered velocity >=600 pt/s remains the accepted binary fling-intent gate; exact source then discards that velocity and always executes the same 0.22s `.easeOut` to progress 1. Therefore the first post-release velocity can be discontinuous from the user's finger velocity even though late-frame decay matches EX. Reopen only this handoff question. Before changing behavior, measure release velocity / remaining progress against the first 2–3 post-release progress/display deltas. Do not infer EX implementation details or introduce guessed spring/easing/duration mapping.

Build240 / 0.14.73 implements exactly that measurement-only handoff probe. It records the already accepted release velocity/current progress and the first post-release animated-progress/CADisplayLink samples, while leaving the 600 pt/s gate, 0.28 slow-drag threshold, fixed 0.22s/0.18s ease-out tail and all retained Build237/236/231/226/228 contracts unchanged. Exact tested source `0f894953a70e11712a82d28b4e8292979826575c` passed CI and produced a verified MinOS15 IPA. This is diagnostic evidence only; no momentum-preserving behavior is authorized until target-device logs show a material release derivative discontinuity.


**Build241 direction supersedes Build240 for the current phase by explicit user choice, not by disproving the handoff hypothesis.** The user prefers the real-device-tested Build239 behavior as the baseline and wants only an easier fling trigger. Build241 therefore lowers the accepted direction-aware latest-delivered binary gate from 600 to 500 pt/s and changes nothing else in carousel motion/settle ownership. Build238 logs provide the evidence margin: intended quick flicks were ~1139.8–2239.8 pt/s while short slow drags were ~0–160 pt/s. Treat 500 pt/s as a target-device A/B until accepted; retain the 0.28 slow-drag threshold, Build239 0.22s/0.18s tail, Build237 white-flash correction and Build236/231/226/228 contracts. Do not infer that Build240's momentum-continuity hypothesis was false, and do not reintroduce it without new user/device evidence.

Build242 is the whole-stack Home-performance attribution A/B and does **not** redefine normal carousel behavior. Exact Build241 source remains the behavioral baseline; Build242 preserves immersive Home mode, carousel data presence, Hero footprint and Home vertical layout while disabling carousel persistent blur, Hero rendering/interaction, preload, auto-advance and carousel-owned Hero scroll updates. Only a clear repeatable Build241-vs-Build242 target-device vertical-scroll improvement may justify decomposing carousel performance costs further. If no material improvement appears, do not keep optimizing carousel internals for the separate Home vertical-performance problem.

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

## D019 — Home carousel is frozen on Build241; Build242 is diagnostic-only

Build241 / OnePlayer 0.14.74 is the final Home-carousel behavior selected by the user after target-device testing. The frozen interaction/presentation contract is the exact Build241 tested runtime at source `997a93a5f2c3c6544908ad112df5e714d2538e65`: one UIKit interaction owner; acquisition-relative handling; full-width page slots; three-slot Hero residency; page-level foreground `compositingGroup()`; device-max refresh retained through settle; persistent white-flash correction; ordinary progress commit `>=0.28`; direction-aware latest-delivered fling commit `>=500 pt/s`; commit/cancel settle durations 0.22/0.18 s. Do not replace it with another smoothing owner, timer/watchdog/retry/debounce/interpolation layer without new real-device regression evidence.

PR #262 integrated only the five exact Build241 runtime blobs onto current `main` and merged at `75d9f53d0984ee7f32e7e3fa02cd9bf8794b56e3`. Independent integration compile run/job `33248884259 / 99090990039` passed and preserved MinOS 15.0. The integration compile is CI evidence only; the real-device acceptance authority remains Build241 itself.

Build242 / OnePlayer 0.14.75 is permanently classified as a diagnostic-only A/B, not a product baseline. It intentionally disabled the carousel presentation/runtime stack and the user explicitly states those diagnostic changes made it unsuitable/broken as normal carousel behavior. Never inherit carousel runtime from Build242. Its retained diagnostic result is only that Home vertical scrolling felt little/no different from Build241, weakening the hypothesis that the whole carousel stack is a major Home-wide performance bottleneck. When the user disables carousel in normal settings, `carouselItems` returns `[]`, so expensive persistent/Hero/preload/interaction presentation is absent.


## Search recommendation startup warm and Dock ownership — Build247 candidate

- The visible server Dock belongs to `EmbyServerRootViewV3`. Search may host keyboard-responsive navigation/content, but it must not own a second visible Dock inside that nested tree. This is the direct replacement for the Build244–246 safe-area-only attempts that still lifted Dock on device.
- Search landing recommendations use a client-visible whitelist: actual returned `LibraryItem.type` must be `Movie` or `Series`. `IncludeItemTypes=Movie,Series` is a server-query optimization, not the final UI authority.
- Because landing recommendations are independent of a typed keyword, saved-session recommendation metadata and exact poster URLs may be warmed once after app startup restore. The Search page consumes that shared in-flight/completed process-lifetime work. Typed keyword results are not precomputed.
- Recommendation presentation uses a bounded fixed set for the current candidate; do not mutate the recommendation grid through incremental Suggestions requests while the user is scrolling. This isolates Search from the Build246 load-more twitch without changing the shared poster-grid owner.
- Existing `EmbyImageDiskCache` remains the persistent poster-byte authority and `EmbyDecodedImageRenderPool` remains the decoded-memory authority. Do not add a Search-specific second disk image cache.
- This decision is candidate-level until Build247 target-device testing; it does not mark Search stable/frozen.


## Search Build248 refinement — safe-area-compensated root Dock and visible-set preload

- Build247 target-device evidence validates root ownership as the right place to separate Dock from keyboard-responsive Search navigation, but also proves that root ownership alone is insufficient when the root deliberately extends its frame by the bottom safe-area inset. A root-owned Search Dock aligned to that expanded bottom must compensate `geometry.safeAreaInsets.bottom` to occupy the same physical band as the other tabs.
- Search landing recommendations are an up-to-3×3 presentation. Startup warm work should therefore be bounded by the visible recommendation contract rather than an arbitrary larger 60-item set. Per-library Suggestions requests should ask only for remaining visible slots.
- This refinement preserves the prior decisions: actual returned `LibraryItem.type` is the final Movie/Series whitelist authority; startup warm is one-shot per process; existing `EmbyImageDiskCache` and `EmbyDecodedImageRenderPool` remain cache owners; Search recommendation load-more stays removed.
- Build248 remains candidate-level until target-device validation.


## Search recommendation view eligibility — Build249 candidate

- `UserViews` must not be treated as if every view is a Movie/Series recommendation source. Search recommendation traversal uses the real decoded `LibraryItem.collectionType` before issuing Suggestions. Eligible collection types are `movies`, `tvshows`, and `mixed`; request types map to Movie, Series, and Movie+Series respectively.
- The returned item `Type` remains the final client-visible whitelist authority. CollectionType filtering is request selection, not a replacement for the Movie/Series output whitelist.
- Build248 target-device evidence accepts the root-owned, bottom-safe-area-compensated Search Dock behavior; Build249 must preserve it.
- No retry/timer/watchdog/fallback or second image cache is introduced. Build249 remains candidate-level pending target-device validation.


## Search Suggestions type authority when Emby omits `Type` — Build250 candidate

- Search recommendation source eligibility remains based on real `UserViews.CollectionType`: `movies`, `tvshows`, `mixed`. Request types remain strictly Movie/Series.
- When a Suggestions item returns a usable `Type`, that actual value remains the final whitelist authority and must be Movie or Series.
- When the Suggestions response omits `Type`, the exact `IncludeItemTypes` request that generated that response may serve as the whitelist authority only when every requested type is itself in the Movie/Series whitelist. This is not heuristic media-type inference or a generic fallback; it trusts the server API filter that constrained the response.
- The Search view must not reapply an incompatible `Type != nil` filter after the preloader has validated the response under this rule.
- Build248-accepted Dock ownership/safe-area behavior remains unchanged. Build250 remains candidate-level pending target-device first-paint validation.


## Search landing recommendations use normal Items + Random, not Suggestions — 2026-08-30

**Decision:** OnePlayer Search landing recommendations use the normal user Items endpoint with `SortBy=Random`, `Recursive=true`, and an explicit `IncludeItemTypes=Movie,Series` whitelist. `/Users/{userId}/Suggestions` is not the Search landing authority.

**Evidence:** Build252 target-device surfaced a `Tag` object from `/Suggestions` despite the Movie/Series query constraint, while official Emby Web Search on the same server shows actual media. Independent inspection of `bpking1/embyExternalUrl` shows Emby Web `/Users/(.*)/Items` traffic with `SortBy=Random` is classified as `searchSuggest`.

**Scope:** This decision only changes Search recommendation metadata retrieval. It does not change Player, MPV, STRM/302/115, UnifiedTransport, playback Session Cache, Emby progress/Resume, credentials, PiP or Deployment Target.

## Search state lifetime is Dock-scoped — Build256 final

- Search recommendation metadata is not app-start/global state. A fresh Search lifetime begins when the Search Dock page is entered.
- Detail push/pop stays inside that Search lifetime and must preserve already-loaded recommendations.
- Manually switching Dock away from Search ends the lifetime and destroys the recommendation dataset; re-entering Search starts fresh with a new initial 9.
- Shared image disk/decoded caches may persist independently; recommendation metadata/tasks do not.
- Build256 target-device accepted; PR #264 merged at `647c1f66e5836fcd20a23a57600211488eeafb3d`.

## D013 — Home carousel inertia gate is containment fallback, not preferred final architecture

Build241 remains the frozen authority for manual Home-carousel drag/release/presentation. Target-device evidence establishes that starting an automatic carousel transition during active Home vertical drag/deceleration can produce a repeatable very large hitch. Build257 reuses the existing real vertical `UIScrollView` and prevents a new auto transition from beginning while `isDragging || isDecelerating`; target-device testing confirms that containment behavior works.

The user explicitly does not accept this gate as the preferred fundamental smoothness solution. PR #265 is closed without merge and Build257 is retained only as a fallback if the actual shared scrolling/transition cost cannot be reduced enough. Do not treat the gate as a frozen mandatory product rule. Build241 manual carousel semantics remain frozen and must not be retuned from this evidence.

## D020 — Shared 3×3 cadence is a first-class smoothness variable; Search semantics remain protected

Build258 target-device diagnostics show Library, Search full-results and detail-filter grids with fixed item counts all delivering passive display cadence p50/p95 near `16.67 ms` while the target device reports `maximum_fps=120`. This cross-route evidence means mild baseline roughness is not demonstrated to be Library-only, pagination-only, Search-append-only or large cell-churn-only. Search `推荐观看` does show a separate long-tail cost during accepted +6 appends, but that is an additional layer rather than a universal explanation.

Build256 Search is stable/merged through PR #264. Its Random Items recommendation authority, initial 9, +6 `ExcludeItemIds` incremental loading, detail-return lifetime and Dock-away reset are protected functional contracts. Poster smoothness work may optimize the shared presentation/cadence layer without altering those semantics.

Build259 is a candidate-level A/B only: reuse the single existing Build258 cadence `CADisplayLink`, request `CAFrameRateRange(minimum: 80, maximum: deviceMaximum, preferred: deviceMaximum)` while any observed real shared-3×3 owner is dragging/decelerating, and return to `.default` when motion ends. No second display link/timer/smoothing owner is allowed. This is not a stable high-refresh architecture decision until target-device hand-feel and cadence evidence accepts it.

## Home carousel presented-FPS control and blur A/B — 2026-08-31

Target-device system FPS HUD **without screen recording** is the controlling presentation-cadence condition for the current carousel performance work. The user reports Build265 peaks only around ~90 FPS without recording, while enabling screen recording can make the same HUD climb to 120. At the same time `HomeCarouselCadence` can report ~8.4–9 ms `CADisplayLink` callback intervals before the HUD reaches 120. Therefore `CADisplayLink` callback cadence is main-run-loop callback evidence, not direct proof of final compositor/screen presented FPS, and screen-recording 120 must not be used as acceptance evidence.

Build269 directly removed only the persistent full-screen real-time `.blur(radius: 30)` while preserving Build265 interaction/presentation structure. On iPhone 15 Pro Max / iOS 17.0, the no-recording system FPS HUD still topped out around ~90 FPS. This rejects real-time blur30 as the **primary** limiter; it does not prove blur has zero cost. Do not continue blur-specific surgery or inherit Build269 blur-off behavior.

Exact Build265 source shows clear Hero artwork already uses current/previous/next residency while foreground title/logo/metadata mounts all up-to-6 carousel pages, each with the retained Build231 `.compositingGroup()`. Every interactive target is the immediate neighbor of the settled current page, including rapid settle takeover. Build270 therefore tests the narrower compositor hypothesis by mounting foreground only in the same current/previous/next window while retaining the proven per-page compositing group, blur30 and all interaction contracts. If Build270 does not materially raise the no-recording FPS ceiling, reject foreground residency as the primary limiter rather than stacking speculative optimizations.

## D021 — Presented-FPS diagnosis locates the pipeline boundary before synthetic stress

For the reopened Home-carousel cadence task, the target-device **system FPS HUD with screen recording off** is the controlling evidence for final presented cadence. Screen recording can itself change the HUD from the no-recording ~90 FPS ceiling toward 120, and the existing `CADisplayLink`-based monitors can report near-120 callbacks while the final HUD remains around ~90. Therefore `CADisplayLink` callback frequency must not be presented as final screen FPS.

Build269 removed only persistent full-screen blur30 and remained around ~90 FPS without recording. Build270 reduced foreground title/logo/metadata residency from all up-to-6 pages to current/previous/next while retaining Build231 page-level `compositingGroup()` and also remained around ~90. Those target-device A/Bs reject persistent blur30 and foreground-residency/offscreen-compositing count as demonstrated primary causes. Do not continue those directions or inherit their diagnostic presentation changes without new evidence.

Build271 / 0.15.4 changes the diagnostic method rather than stacking another optimization. Exact product source `643ff1cbbd24ea06a315c632b08ac1ad162ee43f` branches directly from Build265 and provides one-package `CAROUSEL → CA → DISPLAYLINK → SWIFTUI` modes. The three simplified probe modes unmount the normal Home/carousel presentation so the first layer that fails to match the preceding simpler layer identifies the next instrumentation boundary: Core Animation/system presentation, main-thread display-link/commit scheduling, SwiftUI publication/render invalidation, or the actual carousel render tree. Dedicated run/job `33329047915 / 99304195063` passed; artifact `9737161622`; IPA SHA `e2c6540e5705f9837dd75db6a41ef7a1ce02d24c3afb3f7abc2160faaa8a963f`; MinOS 15.0 independently verified.

Do **not** add synthetic busy-loop CPU/GPU load, timer-driven stress, or another carousel runtime optimization before the Build271 four-mode target-device boundary result exists. Synthetic stress becomes useful only after the failing layer is known, so it measures headroom instead of contaminating the diagnosis. Build271 is diagnostic-only; CI/IPA verification is not real-device acceptance.



## D021 — Poster 3×3 stops SwiftUI container variants after Build272

Build269 replaced the shared `LazyVGrid` with row-based `LazyVStack`/`HStack` and did not remove the target-device whole-content up/down twitch. Build272 then made the normal Library standard poster row height explicit from the already-deterministic `V3PosterCard(width:nil)` geometry and still did not remove the symptom. Therefore further `LazyVGrid`/`LazyVStack`/row-height variants are rejected as the next direction without new contradictory real-device evidence.

Build272 target-device log `OnePlayer-App-1788117273.log` contains a fixed `775→775` 5.36 s session at display 118.50 Hz / offset 110.85 Hz with a maximum measured native reverse of 33.00 pt while item count and load-ahead are unchanged and content height plus adjusted top/bottom insets change by 0.00 pt. This rejects dynamic standard-row-height/contentSize/inset change as the sufficient explanation. The reverse counter alone does not prove a mid-scroll correction because distance to legal bounds was not captured and normal edge bounce can reverse direction.

The next permitted architecture A/B is Library-only native `UICollectionView` 3×3, preserving the current Library data/pagination authority, poster presentation/navigation semantics and shared image cache/loading contracts. Its scroll diagnostics should record reverse position and distance to legal top/bottom bounds so edge bounce and true mid-scroll reversal can be separated. Do not reopen Search Build256 data/lifetime semantics, guessed `decelerationRate`, Home carousel behavior, Player/MPV/PiP, UnifiedTransport, playback Cache/Session or STRM/302/115/CDN contracts as part of this A/B.


## D022 — Native 120 Hz capability is proven; isolate the full carousel tree before interaction lifecycle

Build271 target-device evidence supersedes the earlier pending interpretation in D021. With screen recording off, user-supplied system-HUD screenshots show `PIPE CA = 60 FPS`, `PIPE DISPLAYLINK = 120 FPS`, and `PIPE SWIFTUI = 120 FPS`. Exact Build271 source reveals that only the CA `CABasicAnimation` omitted `CAAnimation.preferredFrameRateRange`; both 120 FPS probes explicitly requested device-max refresh. Therefore the CA=60 result is not evidence of a generic system compositor/window ceiling. The target device demonstrably supports real 120 FPS through main-thread `CADisplayLink→CALayer` and through `CADisplayLink→@Published→SwiftUI`.

Do not resume generic ProMotion flags, SwiftUI-vs-UIKit rewrites, blur removal, foreground-residency reduction, or synthetic CPU/GPU stress from this result. The next evidence boundary is whether the **unchanged full carousel render tree** can sustain a device-max progress stream when touch/settle/resident rotation/new-target loading are removed.

Build274 / 0.15.7 implements exactly that A/B. One `CADisplayLink` drives the existing `transitionProgress` 0→1→0 between a fixed current/neighbor pair while the normal persistent backdrop, preload, clear Hero residency, foreground pages/compositing, indicators, Home scroll content/header/dock remain mounted. It does not create a second product state owner: the diagnostic writes the same transition owner already consumed by the real presentation. It deliberately avoids settle and resident rotation during measurement. If `TREE120` remains ~90, next work may split real per-frame tree layers. If `TREE120` reaches 120 while manual `CAROUSEL` remains ~90, next work must move to touch delivery / release-settle / resident rotation / image-callback lifecycle instead.

Build274 exact source `6d18ca0cdb02bbce3f8fee13f8b5dc082a43ab63`; run/job `33333236724 / 99315483085`; artifact `9738285110`; IPA SHA `2fc79d5d09aa8e0c2f6384b4a50e933cf79f885c4b8d9fd05932fc1a3cc6295a`; MinOS 15.0 verified. This is CI/IPA evidence only until the target-device TREE120 HUD result exists.

Build-number attribution rule reinforced: carousel Build273 is invalid/retired because poster-grid had already allocated Build273. Never reuse a build identity across parallel tasks; carousel TREE120 begins at Build274.

## D023 — Full-tree ceiling reproduced; split the two real transition observer scopes

Build274 target-device testing with screen recording off reports `CAROUSEL ≈90 / TREE FULL ≈90`. The TREE probe already removes touch delivery, release/settle, resident-window rotation and new-target image selection while driving the exact existing `transitionProgress` owner between a fixed pair. Therefore those interaction-lifecycle events are not necessary to reproduce the presented-FPS ceiling; steady-state full real carousel-tree invalidation/composition is sufficient.

Exact source inspection establishes the next boundary without guessing. `V3HomeCarouselTransitionState.progress` is `@Published`, while the high-frequency progress stream is observed through exactly two real `V3HomeCarouselTransitionScope` presentation owners: the persistent full-screen backdrop and the Hero subtree. Do not resume generic ProMotion flags, touch smoothing, easing, timer/watchdog, blur-only removal, foreground-residency tuning or Player/Transport changes before these two observers are separated.

Build275 / 0.15.8 performs that separation while keeping both static trees mounted. `TREE FULL` observes both, `TREE HERO` observes only Hero with backdrop frozen, and `TREE BACKDROP` observes only backdrop with Hero frozen. The real `EmbyHomeHeroV3.swift`, `EmbyHomeCarouselInteractionV3.swift`, and `EmbyHomeCarouselStateV3.swift` blobs remain unchanged. Exact source `8c6a882c03e60e9d2f49e9bc95b09f9e3712577b`; run/job `33334208681 / 99318066653`; artifact `9738555839`; IPA SHA `26229afe7b1cec29ab2bf2cca18c0348fd3337a2d6f996bd2a6b6b07c5bebe64`; MinOS 15.0. Target-device scope results are still required before any product optimization.


## D023 — Poster native collection rejects container/offset-reverse as sufficient root

Build273 moves Library `.items` only to native `UICollectionViewFlowLayout` but target-device testing still shows several visible twitch events. Therefore replacing the SwiftUI grid owner with UICollectionView is not a sufficient fix.

`OnePlayer-App-1788122398.log` also shows every emitted reverse >=1 pt occurs outside the legal top bound during normal bounce, max 3.00 pt; fixed-item sessions can run ~118–120 Hz with zero reverse. This run does not support an interior native contentOffset correction as the visible twitch cause. Do not tune `decelerationRate`, add smoothing, or try another container rewrite from this evidence.

Exact Build273 source has two existing synchronous presentation events that now deserve timing: append `performBatchUpdates/insertItems`, and unchanged-ID visible hosting-root replacement with intrinsic-size invalidation. They are candidates only, not proven causes. Next work may instrument per-frame gaps and these two events; behavior changes require same-frame evidence. Search Build256, Home carousel and all P0 playback/transport contracts remain protected.


## D024 — Build275 full-control 120 invalidates premature Hero/backdrop attribution

Build275 target-device screenshots with recording off show `TREE FULL`, `TREE HERO`, `TREE BACKDROP`, corrected `CA`, `DISPLAYLINK` and `SWIFTUI` all at 120 FPS. This supersedes the assumption that Build274's `TREE FULL≈90` was a stable invariant. Because the FULL control itself changed, the Build275 Hero/backdrop split cannot yet prove combined-budget pressure or identify either scope as the limiter.

Exact Build274→275 source comparison shows `EmbyHomeHeroV3.swift`, `EmbyHomeCarouselInteractionV3.swift` and `EmbyHomeCarouselStateV3.swift` are unchanged. The runtime-relevant difference is the HomeCore conditional structure around the two `V3HomeCarouselTransitionScope` mount points plus additional diagnostic-mode routing. In `TREE FULL`, both transition observers and the same device-max progress driver remain active. Therefore the next evidence must be the **normal `PIPE CAROUSEL` value in the same Build275 package/session**. Do not add another performance patch before that control. If Build275 CAROUSEL is also ~120, isolate the Build274→275 structural delta; if it remains ~90 while TREE FULL is 120, return to interaction-lifecycle versus fixed-progress diagnosis and treat Build274 TREE≈90 as non-reproduced/session-dependent evidence.


## D024 — Build275 isolates carousel cadence to real input→progress publication

With screen recording off on the target iPhone 15 Pro Max / iOS 17.0, the same Build275 package presents normal finger-driven `PIPE CAROUSEL≈90 FPS` while `TREE FULL`, `TREE HERO`, `TREE BACKDROP`, corrected `CA`, `DISPLAYLINK`, and `SWIFTUI` all reach a real 120 FPS system HUD. Therefore a generic ProMotion/SwiftUI/CALayer ceiling and the unchanged steady-state carousel presentation tree are not demonstrated causes of the normal ~90 ceiling. Build274 `TREE FULL≈90` did not reproduce and must not remain a stable causal premise.

Exact normal source publishes `transitionProgress` only when the custom UIKit recognizer receives a delivered `touchesMoved` callback; its max-refresh `CADisplayLink` is diagnostic-only. The next permitted A/B is therefore input-pipeline attribution before any product owner change or display-link interpolation. Build277 compares custom touchesMoved→native CALayer, UIPanGestureRecognizer→native CALayer, and native horizontal UIScrollView under the same device-max refresh request, while leaving HomeCore/Hero/Interaction/State product blobs unchanged.

Do not re-open blur30, foreground residency, Hero/backdrop scope removal, generic UIKit-vs-SwiftUI rewrites, guessed easing, timer/watchdog/retry/fallback or predictive smoothing from this evidence. Product gesture ownership may change only if Build277 real-device input results directly support that architecture.

## D025 — Carousel Build277 validates denser standard input delivery; test real-tree Pan before owner change

Build277 target-device HUD reports normal `CAROUSEL≈90`, `PAN≈110` and native `SCROLLVIEW≈110` with recording off. The reported `TOUCH≈110` is **not valid raw-touch evidence**: source/log correlation shows the first-entry `setMode` guard failed to install `V3HomeRawTouchRecognizer`, and every logged `mode=rawTouch` session ends through ScrollView drag/deceleration callbacks. Do not use that mislabeled value in architecture decisions.

The valid log evidence is narrower and sufficient for one next A/B. A long standard-Pan drag delivered 1,257 callbacks at 8.79 ms average spacing; ScrollView delivery is similarly near device-max cadence, while normal carousel delivered-touch median is ~13.54 ms and progress/render publication is ~21 ms. This establishes that the custom product delivered-move path is materially sparser than standard UIKit Pan/Scroll delivery under the same device, but it does not prove recognizer replacement will raise the full carousel presentation.

Build279 therefore keeps the normal product owner unchanged as `CAROUSEL` control and adds diagnostic `CAROUSEL PAN`: standard `UIPanGestureRecognizer` drives the existing `shouldBeginNativeCarouselDrag`, `handleNativeCarouselDrag`, `finishNativeCarouselDrag` and the same real transition state/presentation tree. It also corrects the raw-touch probe initializer. No DisplayLink interpolation/latch, coalesced continuous render authority, timer/watchdog/retry/fallback, duplicate state owner or playback/transport change is authorized. Replace the product owner only if Build279 target-device `CAROUSEL PAN` materially and repeatably outperforms normal `CAROUSEL`. Exact source `94f7a4ba5aa5bfdd3beb724e216015141dfc50b7`; run/job `33377860245 / 99443301805`; artifact `9752649942`; IPA SHA `36f17a02a0deddbae593f137d455cba3d22849bf28f00c0fafeb755b620abf9b`; MinOS 15.0.



## D025 — Build279 rejects recognizer-only attribution; Build281 tests frame-aligned real input

Build279 target-device evidence is `CAROUSEL≈90 / CAROUSEL PAN≈90 / corrected TOUCH≈80` with recording off. Its App log proves standard Pan and corrected raw-touch callbacks can already arrive at high cadence while final presentation stays below 120. Therefore changing only the recognizer class, or maximizing callback count, is rejected as a sufficient explanation/fix. Do not promote `UIPanGestureRecognizer` to product owner from Build279.

Build279 also exposed one fairness gap: the real-carousel Pan probe lacked the normal gesture-local device-max `CADisplayLink` request. Build281 corrects that gap and isolates publication timing on the same real tree. Direct Pan and frame-latched Pan both request device max; the latched mode stores only the newest real translation and publishes at most once per display-link tick, flushing the final real translation before unchanged release handling. This is a diagnostic of frame alignment, not authorization for interpolation, predicted/coalesced rendering authority, synthetic positions, timer/watchdog/fallback, or a second transition state. Product behavior may change only if target-device Build281 evidence supports it.
