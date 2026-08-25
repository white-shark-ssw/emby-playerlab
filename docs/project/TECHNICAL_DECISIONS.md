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

## D012 — High-frequency home-carousel drag state is locally scoped

The OP vs EX real-device recordings on 2026-08-25 showed that the OnePlayer home carousel could visually pause and then catch up during continuous manual drag. Source inspection showed the drag callback updated `transitionProgress` and tap-suppression state as root `V3EmbyHomeView` `@State`, even though only the clear Hero and persistent backdrop needed the per-finger-movement transition values.

The current Build179 implementation direction is therefore:

- keep one carousel transition owner, `V3HomeCarouselTransitionState`;
- Hero and persistent backdrop observe that owner through local `V3HomeCarouselTransitionScope` instances;
- do not put high-frequency `transitionProgress/from/to` back into the full home root `@State`;
- keep drag-only `isDragging` and tap suppression as non-render event state rather than root invalidation triggers;
- do not improve perceived smoothness by throttling/debouncing finger updates—the interaction must remain directly responsive;
- use the existing horizontal-dominance guard with a 4 pt `DragGesture` start distance rather than the former 12 pt dead zone;
- keep the existing commit/cancel thresholds, settle animations, auto-advance timing and visual design unless separate evidence requires changing them.

The persistent two-image full-screen `.blur(radius: 30)` backdrop composition remains unchanged. It is a possible next GPU evidence point if the scoped-state change still fails real-device smoothness testing, but it is **not** currently proven to be the remaining bottleneck and should not be speculatively rewritten.

**Evidence level for D012 is currently Code written / CI passed / IPA produced only.** Build179 / OnePlayer 0.14.12 run `32841344067` passed Xcode 16.4 Release CI and produced artifact `9560700233`; target-device validation against EX is still pending. Do not mark this carousel architecture stable/frozen until the user reports the Build179 real-device result.
