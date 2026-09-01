# DEV-home-carousel-drag-smoothness

- **Status:** Active — manual sustained system-FPS-HUD transcription is no longer a required development gate. Build284's in-process crossover was CI/IPA verified but is superseded before target-device execution because the user explicitly rejected the required prolonged watch-and-record workflow as unacceptably burdensome. Current work moves to a source/architecture-driven A/B: narrow the 120 Hz `progress` invalidation boundary without changing the accepted Build241 interaction/visual contracts.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps / invalidation scope / progress publication
- **Task:** Preserve the Build241 product interaction/presentation behavior while reducing unnecessary high-frequency SwiftUI invalidation in the real Home carousel tree.
- **Base branch:** `main`
- **Current product analysis source:** current `main` plus Build241 exact tested product blobs where needed for baseline attribution.
- **Superseded diagnostic branch:** `diag/home-carousel-crossover-build284`, exact head `942e7b77a0c344dd7b797b9e7a6978c212bf9b03`.
- **Build284 Draft PR:** #288 — closed unmerged after architecture review; no target-device runtime rejection is inferred.
- **Build284 evidence:** OnePlayer `0.15.17 (284)`, run/job `33554542393 / 100012028969`, artifact `9818916696`, IPA SHA-256 `61c2f566739ff5c95b5ee2de394125ac93ffd99f5c2e8557416e29c1e485a3e0`, source ZIP SHA-256 `4c4f812e361c99705b1eeaef1e11621ff685b0a2e86f8e8cf7569d0fabc78038`, MinOS 15.0.
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment Target:** prefer iOS 15.0.

## Controlling product baseline

Build241 remains the product interaction/presentation behavior to preserve: one UIKit interaction owner, acquisition-relative movement, full-width page slots, current/previous/next clear-Hero residency, page-level foreground `compositingGroup()`, max-refresh through settle, persistent white-flash correction, ordinary progress commit `>=0.28`, direction-aware fling commit `>=500 pt/s`, commit `.easeOut(duration: 0.22)` and cancel `.easeOut(duration: 0.18)`.

Do not turn a performance refactor into a gesture, visual-style or state-ownership rewrite.

## Why manual FPS mode testing is no longer the gate

Build282 already showed that separate HUD observations are unstable across app lifetimes: the same installed TREE scope checks could sustain 120 FPS in one run and present around 90 FPS after force-quit/relaunch. Build284 removed the cross-launch variable, but still required the user to stare at the system HUD and transcribe six sustained phases. The user explicitly rejected that workflow as too burdensome.

Therefore:

- Build284 is **not** target-device rejected; it is simply no longer required to proceed.
- No future carousel iteration should require prolonged manual FPS transcription as the normal acceptance method.
- Target-device acceptance should primarily return to direct hand-feel and visible regression checks. Automated/internal diagnostics may support analysis, but the user should not need to act as the measurement recorder.

## Source-level architecture finding

This finding exists in the real Build241/main product architecture, not only in later diagnostic builds.

`V3HomeCarouselTransitionState` currently stores `fromID`, `toID`, `progress` and `direction` as `@Published` members of one `ObservableObject`. Both persistent backdrop and Hero are wrapped in `V3HomeCarouselTransitionScope`, which observes that same object. Every interactive `transitionProgress` assignment therefore emits the same object-level invalidation used for low-frequency transition-semantic changes.

The resulting fan-out is broader than the properties that actually need per-frame updates:

1. persistent backdrop scope re-enters the full-screen current/target blurred-image + gradient presentation;
2. Hero scope re-enters three resident clear-Hero artwork subtrees;
3. Hero scope also contains `ForEach(model.carouselItems)` for the full foreground set — up to six items because the model caps the carousel pool at six — each with logo/title/rating/overview content and the retained page-level `compositingGroup()`;
4. page indicators and cadence probe are in that same high-frequency scope.

SwiftUI may preserve child identity/state and optimize portions of diff/render work, so current evidence does **not** prove that every subtree is fully re-rasterized every frame. What the source does establish is that the 120 Hz continuous `progress` signal has a substantially wider observation/evaluation boundary than necessary.

This matches retained evidence better than another input-cadence experiment:

- simple device-max `CADisplayLink` and simple `@Published → SwiftUI` controls have demonstrated 120 Hz capability, so `@Published` or SwiftUI alone is not sufficient explanation;
- Build279 showed callback density alone is insufficient;
- Build281 showed device-max display-link latching of latest real input is insufficient;
- therefore the next evidence-backed boundary is the amount of real presentation tree invalidated by each progress publication.

## Next architecture A/B — one owner, two notification cadences

Keep **one** `V3HomeCarouselTransitionState` as the sole transition source of truth. Do not add a second transition/progress owner.

Refactor only notification granularity:

- low-frequency semantic state (`fromID`, `toID`, `direction`) remains on the parent transition observable and continues to rebuild structural Hero/backdrop content when a transition begins, changes direction or settles;
- the same transition state owns one nested high-frequency progress observable; `transitionProgress` continues to read/write that single stored progress value, but progress changes no longer emit the parent semantic object's `objectWillChange`;
- narrow leaf modifiers observe the progress object directly and update only properties that genuinely vary per frame: Hero artwork opacity, foreground X/opacity, target persistent-backdrop opacity and the small page-indicator/probe path;
- static image/text/mask/layout content remains mounted through the drag rather than being placed behind the broad progress-observed content closure.

This is an observation-boundary refactor, not a smoothing algorithm.

## Explicitly preserved

- single UIKit interaction owner;
- Build236 acquisition baseline behavior retained through Build241;
- current/previous/next clear-Hero residency;
- page-level foreground `compositingGroup()`;
- full-width page movement;
- backdrop blur and existing blend formula;
- max-refresh-through-settle;
- `>=500 pt/s` direction-aware fling and `>=0.28` progress commit;
- `.easeOut(duration: 0.22)` commit and `.easeOut(duration: 0.18)` cancel;
- rapid consecutive swipe semantics;
- iOS 15.0 compatibility priority;
- Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN contracts untouched.

## Do not combine into the first architecture A/B

- another `CADisplayLink` or frame latch;
- timer/watchdog/retry/fallback;
- interpolation/prediction/synthetic positions;
- second progress owner;
- blur removal;
- foreground-residency reduction;
- gesture-recognizer rewrite;
- unrelated Home/poster refactor.

Those would add variables to a change whose purpose is specifically to test invalidation scope.

## Validation state

- Build241 product interaction/presentation baseline: retained ✅
- Build284 code/CI/IPA: verified ✅
- Build284 target-device crossover: intentionally not required / not run
- Manual prolonged FPS transcription as normal gate: retired ✅
- Architecture source review against real Build241/main implementation: completed ✅
- Broad high-frequency transition observation boundary identified in source: ✅
- Narrow progress-observation refactor code written: pending ❌
- CI/IPA for architecture refactor: pending ❌
- Real-device hand-feel/regression result: pending ❌
- Stable/frozen reopened performance task: ❌

## Next exact action

Implement the narrow progress-observation refactor from current `main`, with a unique new Build/branch after collision guard. The first target-device validation should **not** require FPS logging. The user only needs to assess normal carousel use: whether rapid/slow swipes feel materially smoother and whether any visual, gesture, release-tail, white-flash or page-transition regression appears.
