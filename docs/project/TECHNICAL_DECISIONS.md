# OnePlayer Technical Decisions

This file records decisions that have already consumed significant real-device testing. Do not casually re-run rejected directions.

## D001 — Media bytes never transit the NAS

Normal playback is client-direct:

```text
Emby / STRM → 302 → 115/CDN → iPhone
```

The NAS/Emby side may resolve or redirect, but it must not become the media data relay.

## D002 — Real byte demand is authoritative

Do not map playback time to file byte offset using:

```text
targetTime / duration × fileSize
```

This was rejected. Actual AVPlayer Range demand or player byte seek/demand is authoritative.

## D003 — Unified transport/cache is shared infrastructure

Network, 302, Range/206, cache and playback-demand handling belong below the playback engine. Do not rebuild separate 115/CDN networking inside each engine.

## D004 — Fast interaction beats exact seek

For double-tap / rapid ±N second Seek:

- latency is P0;
- MPV `absolute+keyframes` is the accepted runtime contract;
- `absolute+exact` was rejected for the default path because it produced materially higher latency;
- no hidden second corrective native Seek.

Long-GOP accuracy error is an accepted physical limitation of keyframe-based fast Seek.

## D005 — MDK is not the automatic daily authority

MDK showed strong performance in some media/high-rate scenarios, but extensive real-device work did not beat MPV on the project's primary metric: repeated fast ±10-second Seek consistency and long-tail stability.

Current strategy:

- MPV = normal/main engine.
- MDK = manual backup/experimental engine.

Do not silently restore broad automatic engine fallback logic.

## D006 — Renderer ownership must respect MoltenVK/MPV

Previous attempts to manually take over `CAMetalLayer.delegate` / drawable lifecycle caused real-device instability or crashes.

UIKit may own host geometry; do not casually seize MoltenVK's drawable/swapchain ownership.

## D007 — System navigation is system-owned

Immersive UI must not take ownership of or disable native navigation stack behaviour or interactive pop.

Preferred approach:

- system navigation stays intact;
- visual appearance is adapted around it;
- compatibility layers use mature UIKit/SwiftUI APIs rather than raising the minimum OS.

## D008 — PiP uses a visual bridge, MPV remains authority

Current PiP architecture uses SampleBuffer for the native PiP visual surface while MPV remains the playback/audio/time authority.

Frozen later semantics include:

- background MPV video suspension using `vid=no`;
- persistent SampleBuffer visual bridge during return;
- PiP X = `pauseAndSuspend`, not player Stop;
- completion after visual/timebase commit;
- no periodic bridge catch-up loop in Build173.

Further PiP work is paused unless a new renderer-lifecycle approach materially changes the trade-off.

## D009 — Evidence must be labelled

Always distinguish:

- implementation;
- CI;
- IPA;
- real-device result;
- frozen/stable result.

A successful GitHub Action does not equal a solved playback bug.

## D010 — Episode changes replace the source-owned playback session

A OnePlayer playback session is source-owned: `PlayerController`, `PlaybackOrchestrator`, `PlaybackTransportContext`, Emby PlaySession and the resolved 115/CDN path all correspond to the current media item.

Therefore episode selection must **not** mutate `PlayerController.source` in place. The accepted Build176 architecture uses a persistent fullscreen player host that replaces the entire child playback session for the selected episode:

- stop the old source/session through the existing lifecycle;
- keep the fullscreen host presented;
- resolve the selected episode through the existing Emby direct-play path;
- create a fresh `PlayerController` / orchestrator / transport context for that source;
- do not intentionally restore the main-interface portrait orientation between child sessions.

Episode metadata may be loaded ahead of selection, but the next episode's 115/CDN temporary media URL is not pre-resolved or retained. Resolve it only after explicit user selection or after a trusted natural end.

Automatic next episode may only advance when the existing pure `PrematureEOFGuard` classifies the current end as non-premature. A raw engine EOF, buffering/starvation, abnormal short-media recovery or premature EOF is not sufficient. No new timer, retry loop or watchdog is part of auto-next.

Build174 established the implementation direction; Build175 refined the interaction; **Build176 / OnePlayer 0.14.9 was accepted by the user on real device and merged to `main` through PR #253 at commit `d10e0d63b429f72a664193a1a5bacf728cac50b6`.** Treat the source-owned episode-session replacement and trusted-natural-end gate as the stable episode-playback contract unless new real-device evidence requires reopening it.

## D011 — Emby TV API owns canonical episode order

OnePlayer must not invent a second client-side ordering rule for a TV series when Emby already exposes its TV episode ordering authority.

Real-device evidence from the non-standard series `137597` showed 165 Episodes with `nilIndex=164`. The previous generic `/Users/{UserId}/Items` query forced `SortBy=ParentIndexNumber,IndexNumber`; `ParentIndexNumber` still grouped seasons, but the missing `IndexNumber` values left the in-season order different from Emby/EplayerX. The detail and picker UIs were only consuming that returned array and were not independently sorting it.

The accepted Build178 contract is:

- load a series episode list from `GET /Shows/{SeriesId}/Episodes`;
- preserve Emby's returned order;
- keep `SeasonId`-first logic for season membership, but do not make it a second in-season ordering owner;
- retain pagination and ID-preserving deduplication;
- do not add title, file-name, DateCreated, item-ID, or artificial episode-number fallback sorting;
- downstream detail/picker/player auto-next paths consume the same canonical array.

**Build178 / OnePlayer 0.14.11 passed dedicated standard MPV Release CI, produced an IPA, was accepted by the user on real device on 2026-08-25, and merged to `main` through PR #254 at commit `9e0d0cecb2df0a263a9a4a4c1f92c2d0e473d78f`.** Treat Emby's TV episode response order as the stable canonical-order authority unless new real-device evidence requires reopening this decision.

## D012 — Home-carousel manual drag keeps page-slide semantics and must track the finger continuously

The OP vs EX recordings establish a P0 interaction requirement for the V3 home carousel: finger motion is authoritative during manual drag. The UI must not wait for a debounce-like distance window, must not freeze while crossing the gesture origin, and must not convert small motion into a later catch-up jump.

Build179 first localized high-frequency carousel transition state into one `V3HomeCarouselTransitionState`, observed only by the Hero/persistent-backdrop scopes. That ownership model remains valid and must not be reverted: root `V3EmbyHomeView` must not regain per-finger `transitionProgress/from/to`, drag flags, or tap-suppression `@State`.

Build179 was rejected because small motion still had a dead zone and reversal could pause then jump. Build180 removed the 4pt `DragGesture` start distance, the extra `abs(horizontal) > 4` gate, the repeated center-direction gate after horizontal drag had started, and the first 8% delayed artwork blend. Real-device testing confirmed reversal continuity improved, but the initial visible movement still felt coarse.

Build183 then experimentally removed foreground horizontal travel and crossfaded the Logo/rating/year/type/overview in place. The user reported that the feel seemed somewhat finer, but also correctly identified this as an unauthorized interaction change: those foreground elements are part of each carousel page and were previously designed to move with the page. Because the interaction model changed, Build183 is **rejected as the default direction** even though it provided useful diagnostic evidence.

The established interaction contract is therefore:

- Logo, rating, year, type and overview remain attached to their carousel item and travel horizontally with that page;
- `carouselForegroundOpacity` keeps transition from/to foregrounds present during the slide;
- `carouselForegroundOffset` keeps the page-slide mapping (`from = -direction × progress × width`, `to = direction × (1-progress) × width`);
- do not pin/crossfade those foreground elements as a silent performance optimization.

Build185 targets the remaining initial-acquisition discontinuity without changing that slide semantics:

- retain one locally scoped `V3HomeCarouselTransitionState` owner;
- use `DragGesture(minimumDistance: 0)`;
- remove the old initial `abs(horizontal) > abs(vertical) * 1.08` requirement;
- keep a non-render gesture-axis state and lock horizontal/vertical once at the first meaningful 0.5pt movement using the first motion vector;
- horizontal lock continuously applies the original `translation.width` to progress, including direction reversal through zero;
- vertical lock keeps carousel updates out of that touch so the homepage ScrollView remains authoritative;
- reset the axis at gesture end; do not introduce reconciliation, debounce, throttle, interpolation, accumulated correction, timer, retry, watchdog or fallback;
- preserve existing commit/cancel thresholds, release animations, auto-advance timing and artwork/backdrop blend;
- keep Player/Transport/Cache/PiP and accepted Build176/178 contracts untouched.

The user explicitly allows the Build183-style fixed-foreground/crossfade interaction only as a **final fallback** if further real-device evidence shows that the established page-slide interaction cannot be made acceptably smooth. It must not be selected merely because it is easier to render.

The persistent two-image full-screen `.blur(radius: 30)` backdrop remains a next evidence point only if Build185 preserves fine initial motion but continuous dragging still shows frame-rate/compositing stalls. Do not preemptively rewrite the blur/image pipeline in the same patch because that would destroy attribution.

Evidence levels: Build179 = real-device rejected; Build180 = real-device partial improvement but rejected; Build183 = real-device tested, feel somewhat finer but interaction regression/rejected; **Build185 / OnePlayer 0.14.18 = Code written / CI passed / IPA produced / real-device pending / not stable**. Dedicated standard MPV Release run `32853247583` passed the Build185 axis-acquisition/page-slide contracts, home/scroll/series-order checks, Build176/178/P0 zero-diff checks, Xcode 16.4 Release build, 0.14.18 (185) identity, MinOS 15.0 validation and IPA packaging. Do not mark D012 stable/frozen until the user accepts a target-device result against EX.

## D013 — Detail high-rate scroll and warm presentation stay scoped and presentation-only

The accepted Build181/182/184 detail-page line establishes two long-term ownership boundaries.

First, native detail `UIScrollView.contentOffset` is a high-frequency render input and must not be written into root detail-view state that invalidates the full page. Build181 isolates that raw offset in `EmbyDetailHeroScrollState`, observed only by the Hero scope; the native ScrollView and existing Hero stretch/crop/pin geometry remain authoritative. The user accepted the resulting scrolling behavior on iPhone 15 Pro Max / iOS 17.0.

Second, detail warm state is **presentation-only**. Build182 may persist safe display metadata (`episodes`, `seasons`, `imageInfos`, `similarItems`) under `Library/Caches/OnePlayer/DetailPresentation` so a known detail page can restore Logo/episode presentation across process restarts, but normal Emby loading still refreshes current server data. PlaybackInfo, MediaSource, PlaySession, ResolvedPlaybackSource and temporary 115/CDN URLs must not enter this cache. Resume/played/favorite authority remains the live server/session path.

Build184 adds only the accepted detail visual hierarchy (`视频信息` below `更多类似`, above the bottom glass media-source summary, and 19 pt bold main section headers) and does not reopen those ownership boundaries. **Build184 / OnePlayer 0.14.17 was accepted by the user on real device on 2026-08-25 and merged to `main` through PR #255 at commit `5bf00bb0f48d0b640bcbea740d4c17c9f8e7be8f`.** Treat the detail scroll owner and presentation-cache boundary as stable/frozen unless new real-device regression evidence requires reopening them.
