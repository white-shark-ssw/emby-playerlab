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

## D012 — Home-carousel manual drag must be continuous through first movement and direction reversal

The OP vs EX recordings established a P0 interaction requirement for the V3 home carousel: finger motion itself is the authority during manual drag. The UI must not wait for a debounce-like distance window, must not freeze while crossing the gesture origin, and must not convert a small reverse movement into a later large catch-up jump.

Build179 first localized high-frequency carousel transition state into one `V3HomeCarouselTransitionState`, observed only by the Hero/persistent-backdrop scopes. That architecture remains valid and should not be reverted: root `V3EmbyHomeView` must not regain per-finger `transitionProgress/from/to`, drag flags, or tap-suppression `@State`.

However, Build179 / OnePlayer 0.14.12 was **rejected on real device**. The user reported that a small drag still did not move immediately and that dragging slightly to one side then reversing toward the other side could visibly pause before jumping a large distance. Source inspection showed three remaining policy dead zones that directly matched that feedback:

- `DragGesture(minimumDistance: 4)` plus `abs(horizontal) > 4` withheld progress until an accumulated translation threshold was crossed;
- the horizontal-dominance guard was re-applied on every `onChanged`, so an already-established horizontal drag could stop updating while reversing through the center where horizontal translation approaches zero;
- `carouselBackdropBlendProgress` discarded the first 8% of raw progress and then applied smoothstep, so the main artwork intentionally showed no response for small movement even after the drag existed.

Build180 therefore adopts the following current direction:

- retain one locally scoped `V3HomeCarouselTransitionState` owner; no second progress owner or reconciliation loop;
- use `DragGesture(minimumDistance: 0)` so SwiftUI delivers the first movement instead of enforcing an application-level start distance;
- use horizontal dominance only to acquire the initial carousel drag; once `isCarouselDragging` is true, keep tracking horizontal translation continuously through zero and direction reversal rather than re-entering the axis gate;
- remove the extra absolute `abs(horizontal) > 4` gate;
- map manual artwork blend directly from clamped raw transition progress instead of discarding the first 8% or applying a low-response smoothstep;
- do not throttle/debounce finger updates;
- keep the existing commit/cancel thresholds, release animations and auto-advance timing unless separate real-device evidence requires changing them;
- keep Player/Transport/Cache/PiP and accepted Build176/178 contracts untouched.

The persistent two-image full-screen `.blur(radius: 30)` backdrop remains a **next evidence point, not a proven root cause**. If Build180 still shows reversal stalls after the gesture/progress dead zones are removed, then inspect target replacement and full-screen blur/compositing cost with the new real-device evidence. Do not preemptively rewrite the image pipeline in the same patch because that would destroy attribution.

Evidence levels: Build179 = Code written / CI passed / IPA produced / **real-device tested and rejected**. Build180 = **Code written / CI passed / IPA produced / real-device not yet tested / not stable**. Build180 dedicated standard MPV Release run `32845376285` passed the zero-point drag/initial-axis-lock/no-old-gate contracts, Build179 local-owner contract, home/scroll/series-order checks, Build176/178/P0 zero-diff checks, Xcode 16.4 Release build, 0.14.13 (180) identity, MinOS 15.0 validation and IPA packaging. Do not mark D012 stable/frozen until the user accepts a target-device result against EX.
