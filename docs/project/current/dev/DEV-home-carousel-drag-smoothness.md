# DEV-home-carousel-drag-smoothness

- **Status:** Active — manual sustained system-FPS-HUD transcription is retired. Source review identified an unnecessarily broad high-frequency SwiftUI invalidation boundary: `V3HomeCarouselTransitionState.progress` currently publishes through the same parent `ObservableObject` observed by the full Hero and persistent-backdrop scopes. The next candidate is a narrow observation-boundary refactor that preserves all Build241 interaction/visual contracts.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps / invalidation scope / progress publication
- **Task:** Preserve the Build241 product interaction/presentation behavior while reducing unnecessary high-frequency SwiftUI invalidation in the real Home carousel tree.
- **Base branch:** `main`
- **Base source selected for Build286:** `5336240df2ad57a9a933000a524c60f0f7530c9c` — source-equivalent current main before this checkpoint-only reservation commit.
- **Planned product branch:** `perf/home-carousel-progress-scope-build286`
- **Planned CI control branch:** `ci/build286-home-progress-scope-20260904`
- **Reserved candidate:** OnePlayer `0.15.19 / Build286`
- **Collision guard:** Build285 is already occupied by Poster infrastructure (`ci/poster-final-integration-build285`); repository branch/code search found no Build286 allocation before reservation.
- **Superseded diagnostic:** Build284 / `0.15.17`, PR #288 closed unmerged before target-device execution; no runtime rejection inferred.
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment Target:** prefer iOS 15.0.

## Controlling product baseline

Build241 remains the behavior to preserve: one UIKit interaction owner, acquisition-relative movement, full-width page slots, current/previous/next clear-Hero residency, page-level foreground `compositingGroup()`, max-refresh through settle, persistent white-flash correction, ordinary progress commit `>=0.28`, direction-aware fling commit `>=500 pt/s`, commit `.easeOut(duration: 0.22)` and cancel `.easeOut(duration: 0.18)`.

Do not turn this performance refactor into a gesture, visual-style, timing, smoothing or state-ownership rewrite.

## Controlling evidence

Build279 showed callback density / standard Pan alone is insufficient. Build281 showed device-max display-link latching of latest real input is insufficient. Build282 showed simple `CADisplayLink → CALayer` and simple `@Published → SwiftUI` paths can sustain 120 in the same package/device while real TREE behavior is session-sensitive. Therefore neither generic SwiftUI capability nor input cadence alone explains the real presentation path.

Manual separate-mode/cross-launch HUD attribution is rejected. Build284's in-process crossover was CI/IPA verified but the user explicitly rejected prolonged HUD transcription as a development workflow; it is no longer a required gate.

## Source-level architecture finding

The real Build241/main architecture has one `V3HomeCarouselTransitionState` with `fromID`, `toID`, `progress` and `direction` all published on the same parent `ObservableObject`. Both the full-screen persistent backdrop and the entire Hero are wrapped in `V3HomeCarouselTransitionScope` observing that parent.

Each interactive progress publication therefore invalidates much broader SwiftUI scope than the leaf properties that actually vary per frame. The Hero scope contains three resident clear-Hero artwork subtrees plus up to six complete foreground page subtrees (logo/title/rating/overview and retained page-level `compositingGroup()`), indicators and cadence probe. The backdrop scope contains the full-screen current/target image presentation and blur path.

This does **not** prove every subtree is fully rasterized every frame; SwiftUI can preserve identity and optimize rendering. It does prove the observation/evaluation boundary for the 120 Hz continuous signal is broader than necessary.

## Build286 implementation contract

Keep the existing `V3HomeCarouselTransitionState` as the sole transition owner and keep the existing `transitionProgress` accessor as the sole product-facing progress entry point.

Change notification granularity only:

1. parent semantic fields `fromID`, `toID`, `direction` remain `@Published` on `V3HomeCarouselTransitionState`;
2. the same parent owns one nested `V3HomeCarouselProgressState`; this object contains the single stored progress value;
3. `transitionProgress` reads/writes `carouselTransitionState.progress.value`;
4. parent `V3HomeCarouselTransitionScope` therefore rebuilds on semantic transition changes but not on every progress sample;
5. narrow leaf wrappers observe the nested progress object and update only:
   - Hero artwork opacity;
   - foreground page X offset;
   - target persistent-backdrop opacity;
   - page indicators;
   - the existing tiny cadence render probe.

There is no second progress value, no duplicate transition owner and no extra DisplayLink.

## Explicitly preserved

- single UIKit interaction owner;
- Build236 acquisition baseline behavior retained through Build241;
- current/previous/next clear-Hero residency;
- page-level foreground `compositingGroup()`;
- full-width page movement;
- backdrop blur and blend formula;
- max-refresh-through-settle;
- `>=500 pt/s` direction-aware fling and `>=0.28` progress commit;
- `.easeOut(duration: 0.22)` commit and `.easeOut(duration: 0.18)` cancel;
- rapid consecutive swipe semantics;
- iOS 15.0 compatibility priority;
- Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN untouched.

## Explicitly excluded from Build286

- new DisplayLink/frame latch;
- timer/watchdog/retry/fallback;
- interpolation/prediction/synthetic positions;
- second progress owner/value;
- blur removal;
- foreground-residency reduction;
- gesture-recognizer rewrite;
- unrelated Home/poster work.

## Validation state

- Build241 product interaction/presentation baseline retained: ✅
- Manual prolonged FPS transcription retired: ✅
- Architecture source review against real Build241/main: ✅
- Broad high-frequency observation boundary identified: ✅
- Build286 candidate identity reserved: ✅ `0.15.19 / 286`
- Build286 code written: pending ❌
- Exact-scope/static guards: pending ❌
- CI passed: pending ❌
- IPA produced + identity verified: pending ❌
- Real-device hand-feel/regression result: pending ❌
- Stable/frozen reopened performance task: ❌

## Next exact action

Materialize Build286 from the recorded base, change only progress notification granularity plus package identity, run exact-scope guards and Xcode 16.4 Release/MinOS validation, produce and independently inspect the IPA. First target-device validation should require only normal use: rapid/slow swipes, release/cancel/rapid takeover, white-flash/visual regression and overall hand-feel. No prolonged FPS transcription is required.