# DEV-home-carousel-drag-smoothness

- **Status:** Active — the previous manual separate-mode / cross-launch system-FPS-HUD A/B is rejected as a component-attribution method. On Build282 the user observed TREE scope modes sustaining 120 FPS in one run, then roughly 90 FPS after force-quit/relaunch under the same package. Build284 replaces that protocol with one in-process REF↔TREE crossover that holds process/session, Home tree, image pair and one device-max `CADisplayLink` constant.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps / crossover
- **Task:** Preserve the Build241 product interaction/presentation behavior while determining whether final-present FPS changes reproducibly with real carousel-tree invalidation load.
- **Base branch:** `main`
- **Current working branch:** `diag/home-carousel-crossover-build284`
- **Current exact product source / branch head:** `942e7b77a0c344dd7b797b9e7a6978c212bf9b03`
- **Current Draft PR:** #288 — diagnostic-only, unmerged
- **Current candidate:** OnePlayer `0.15.17 (284)`
- **Exact-source CI run / job:** `33554542393 / 100012028969` — success
- **Artifact:** `OnePlayer-0.15.17-build284-home-crossover-probe`, ID `9818916696`, digest `sha256:5db87a31508a4b61615403fc8d7dc4aa48ae4d4f9d90b6b4ef6e2ec0c9e55358`
- **IPA SHA-256:** `61c2f566739ff5c95b5ee2de394125ac93ffd99f5c2e8557416e29c1e485a3e0`
- **Source ZIP SHA-256:** `4c4f812e361c99705b1eeaef1e11621ff685b0a2e86f8e8cf7569d0fabc78038`
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment Target / built MinOS:** iOS 15.0

## Controlling product baseline

Build241 remains the product interaction/presentation behavior to preserve: one UIKit interaction owner, acquisition-relative movement, full-width page slots, current/previous/next clear-Hero residency, page-level foreground `compositingGroup()`, max-refresh through settle, persistent white-flash correction, ordinary progress commit `>=0.28`, direction-aware fling commit `>=500 pt/s`, commit `.easeOut(duration: 0.22)` and cancel `.easeOut(duration: 0.18)`.

Build284 is diagnostic only. It does not change HomeCore, Hero implementation, gesture ownership, transition-state ownership, Player/MPV/PiP/Transport/Cache/Emby Session or STRM→302→115/CDN.

## Why the Build282 manual protocol is rejected

Latest target-device evidence is internally inconsistent across app lifetimes. In the same installed Build282 package, TREE scope checks could both sustain 120 FPS in one run, while after force-quit/relaunch the same checks were around 90 FPS. Therefore a result such as `TREE HERO=120` versus `TREE BACKDROP=90` from separate manual runs cannot be treated as causal evidence for a component.

Earlier Build282 evidence remains valid only for narrower claims: `TREE FULL` and `TREE PANLOAD` can both decay, so Pan load alone is not causal; `DISPLAYLINK` and `SWIFTUI` can sustain 120 in a run, so generic device-max display-link/SwiftUI capability exists. It no longer supports cross-launch component attribution.

## Build284 / 0.15.17 — in-process REF↔TREE crossover

Exact Build282→Build284 product diff is two files only:

1. `Sources/Core/AppIdentity.swift` — diagnostic identity.
2. `Sources/UI/EmbyHomeFramePipelineProbeV3.swift` — crossover probe.

The existing `TREE FULL` probe slot is relabeled `CROSSOVER`. One device-max `CADisplayLink` stays alive continuously. The same Home presentation and fixed current/neighbor pair remain mounted. A native CALayer marker moves on every display tick in both phases. The probe alternates automatically every 15 seconds:

- `CROSSOVER REF 1/3`: real carousel progress is frozen at 0.5; reference CALayer continues moving.
- `CROSSOVER TREE 1/3`: the same display link additionally drives real `transitionProgress`.
- then REF/TREE rounds 2 and 3; the six-phase sequence loops.

Phase boundaries log `HomeCarouselCrossover` with round, callback cadence, Low Power Mode and thermal state. Internal display-link cadence remains diagnostic only; the target-device system FPS HUD with screen recording off is the final-present observation.

## Acceptance / falsification rule

Run one uninterrupted crossover cycle without force-quitting, mode switching or finger interaction. Record the sustained HUD value for each label:

`REF1 / TREE1 / REF2 / TREE2 / REF3 / TREE3`

Only a repeatable within-process relationship is actionable. Example: all three TREE phases fall while all three REF phases recover materially. If HUD does not track REF↔TREE repeatedly — for example all phases remain ~90, all remain 120, or changes occur independently of phase — then this HUD/probe method is not reliable enough for component attribution. The next step must change measurement strategy rather than add another carousel visual/gesture patch.

## Rejected / do not repeat without new evidence

- manual separate-mode / cross-launch HUD comparison for component causality;
- blur30 removal as the primary limiter;
- foreground-residency/compositing-count reduction as the primary limiter;
- generic UIKit↔SwiftUI rewrite;
- speculative ProMotion opt-in;
- recognizer replacement or callback-density maximization by itself;
- latest-real-input frame latch as a sufficient fix;
- Pan-load-only attribution;
- interpolation, prediction or synthetic intermediate positions;
- timer/watchdog/retry/fallback smoothing;
- a second transition/progress owner.

## Validation state

- Build284 code written: ✅
- Exact Build282→Build284 two-file scope verified: ✅
- Exact-source CI passed: ✅
- IPA produced + independently verified: ✅
- Bundle/version/build/MinOS verified: ✅ `com.embyplayerlab.app / 0.15.17 (284) / iOS 15.0`
- Target-device crossover: pending ❌
- Stable/frozen reopened performance task: ❌

## Next exact action

Install Build284, keep screen recording off, enter Home, switch `PIPE` until `PIPE CROSSOVER`, then leave the screen untouched for one complete six-phase cycle (~90 seconds). Report the six HUD observations and attach the App log. Do not force-quit/relaunch during the first cycle.
