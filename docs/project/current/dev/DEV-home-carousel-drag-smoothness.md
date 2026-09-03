# DEV-home-carousel-drag-smoothness

- **Status:** Active — Build286 architecture A/B is code-written, exact-scope guarded, Xcode 16.4 CI-passed and IPA-produced/independently verified. Manual sustained system-FPS-HUD transcription remains retired. The next gate is qualitative target-device hand-feel/regression testing; no FPS transcription is required.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps / invalidation scope / progress publication
- **Task:** Preserve Build241 product interaction/presentation while reducing unnecessary high-frequency SwiftUI invalidation in the real Home carousel tree.
- **Base branch / source:** `main` checkpoint `8dac5e687506d52fab9b3634389fa029cb7f0bde` (runtime source-equivalent to preceding `5336240...`; the extra commit only reserved/documented Build286).
- **Product branch:** `perf/home-carousel-progress-scope-build286`
- **Exact product source:** `7e7b2ec944f5c0e74bc291e37683f1529e3d46b4`
- **Draft PR:** #289 — open, unmerged
- **CI control branch:** `ci/build286-home-progress-scope-20260904`
- **Candidate:** OnePlayer `0.15.19 / Build286`
- **Xcode 16.4 CI run / job:** `33786964921 / 100753960778` — success
- **Artifact:** `OnePlayer-0.15.19-build286-home-progress-scope`, ID `9905942602`, digest `sha256:983c3cb1aa650f727266019b9a1ea834fad9c29266a043a775f9109c40f0c9f4`
- **IPA SHA-256:** `5c26b36eb70117abbd27885f5b637827020f7fffcc949d79a45e5b9a19bc28b0`
- **Source ZIP SHA-256:** `ff975b72afcfc660542c112a2eb55e4c0f8669e11933bc4d368df7b3c7c8f68e`
- **Bundle / version / MinOS:** `com.embyplayerlab.app / 0.15.19 (286) / iOS 15.0`
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Collision guard:** Build285 is occupied by Poster infrastructure; Build286 had no prior allocation and is now reserved by this Home line.
- **Superseded diagnostic:** Build284 / `0.15.17`, PR #288 closed unmerged before target-device execution; no runtime rejection inferred.

## Controlling product baseline

Build241 remains the behavior to preserve: one UIKit interaction owner, acquisition-relative movement, full-width page slots, current/previous/next clear-Hero residency, page-level foreground `compositingGroup()`, max-refresh through settle, persistent white-flash correction, ordinary progress commit `>=0.28`, direction-aware fling commit `>=500 pt/s`, commit `.easeOut(duration: 0.22)` and cancel `.easeOut(duration: 0.18)`.

Build286 is an observation-boundary performance A/B, not a gesture, timing, visual-style or smoothing redesign.

## Why this architecture A/B is justified

Build279 showed callback density / standard Pan alone is insufficient. Build281 showed device-max DisplayLink latching of latest real input is insufficient. Build282 showed simple `CADisplayLink → CALayer` and simple `@Published → SwiftUI` paths can sustain 120 on the same package/device while the real TREE path remains session-sensitive. Therefore neither generic SwiftUI capability nor input cadence alone explains the real presentation path.

The real Build241/main architecture published `fromID`, `toID`, `progress` and `direction` through one parent `V3HomeCarouselTransitionState`. Both the full persistent backdrop and full Hero scopes observed that parent. Each progress sample therefore emitted the same broad object-level invalidation used for low-frequency transition semantics.

The source does **not** prove every descendant is fully rasterized on each sample; SwiftUI can preserve identity and optimize rendering. It does prove that the high-frequency observation/evaluation boundary was wider than necessary.

## Build286 exact implementation

Build286 keeps one `V3HomeCarouselTransitionState` as the sole transition owner and keeps `transitionProgress` as the sole product-facing progress entry point.

Notification granularity only is changed:

1. parent semantic fields `fromID`, `toID`, `direction` remain `@Published`;
2. the parent owns one nested `V3HomeCarouselProgressState` containing the single stored progress value;
3. `transitionProgress` reads/writes `carouselTransitionState.progress.value`;
4. parent `V3HomeCarouselTransitionScope` still rebuilds for semantic transition changes but no longer receives each progress object's `objectWillChange`;
5. narrow progress-observing wrappers update only Hero artwork opacity, foreground page X offset, target persistent-backdrop opacity, page indicators and the existing tiny cadence probe.

There is no second progress value/owner and no added DisplayLink.

## Exact product scope / guards

Build286 base→product diff contains exactly five paths:

- `Sources/Core/AppIdentity.swift`
- `Sources/UI/EmbyHomeCarouselInteractionV3.swift`
- `Sources/UI/EmbyHomeCarouselProgressPresentationV3.swift` (new)
- `Sources/UI/EmbyHomeCarouselStateV3.swift`
- `Sources/UI/EmbyHomeHeroV3.swift`

`Sources/UI/EmbyHomeCoreV3.swift` remains exact blob `c7900bae5e608ae46c0cd476c1f08999be9baf0b`.

Independent source-ZIP git-blob verification matched product commit blobs:

- AppIdentity `e435b73ad030474af14e9199914af9429114fac2`
- Interaction `bd5666d2c7e4d29bec6987fdb4a96f636d519e3f`
- progress presentation `81da601c9860a29d38a6a26676cf27adb7727dd9`
- carousel state `c7694568ee9bc3b6c9bbc0d529100d5327a48e7a`
- Hero `99cf58a8ac908e064855cee42fcc4ffb636fcb55`
- unchanged HomeCore `c7900bae5e608ae46c0cd476c1f08999be9baf0b`

Static guards also preserve `.compositingGroup()`, `blur(radius: 30)`, three-slot Hero residency, `>=500 pt/s`, `>=0.28`, 0.22/0.18 animations, `CADisableMinimumFrameDurationOnPhone`, and iOS 15.0 target; Player/Transport/Session/Cache/MPV/PiP paths are excluded.

## Packaging verification

Run `33786964921`, job `100753960778` passed materialization, exact-scope guards, Xcode 16.4 Release compile, identity/MinOS validation, IPA packaging and artifact upload.

Independent artifact re-download verified:

- outer artifact ZIP SHA-256 equals GitHub digest `983c3cb1aa650f727266019b9a1ea834fad9c29266a043a775f9109c40f0c9f4`;
- IPA SHA-256 equals recorded `5c26b36eb70117abbd27885f5b637827020f7fffcc949d79a45e5b9a19bc28b0`;
- source ZIP SHA-256 equals recorded `ff975b72afcfc660542c112a2eb55e4c0f8669e11933bc4d368df7b3c7c8f68e`;
- both archives pass integrity tests;
- built Info.plist: `com.embyplayerlab.app`, `OnePlayer`, `0.15.19`, build `286`, `MinimumOSVersion=15.0`, `CADisableMinimumFrameDurationOnPhone=true`;
- runtime Mach-O MinOS audit reports 15.0 and passes the required <=17.0 ceiling.

## Explicitly preserved / excluded

Preserved: single UIKit interaction owner; Build236 acquisition behavior; current/previous/next clear-Hero residency; page-level foreground `compositingGroup()`; full-width page movement; backdrop blur/blend; white-flash correction; max-refresh-through-settle; rapid takeover; `>=500 pt/s`; `>=0.28`; 0.22/0.18 settle; iOS 15.0 priority; Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN.

Excluded: new DisplayLink/frame latch; timer/watchdog/retry/fallback; interpolation/prediction/synthetic positions; second progress owner/value; blur removal; residency reduction; gesture rewrite; unrelated Home/poster refactor.

## Validation state

- Build241 product interaction/presentation baseline retained: ✅
- Manual prolonged FPS transcription retired: ✅
- Architecture source review: ✅
- Build286 code written: ✅
- Exact-scope/static guards: ✅
- Xcode 16.4 CI passed: ✅
- IPA produced + independently verified: ✅
- Real-device hand-feel/regression result: pending ❌
- Stable/frozen reopened performance task: ❌

## Next exact action

Install Build286 on iPhone 15 Pro Max / iOS 17.0 and use the carousel normally. No prolonged FPS transcription is required. Check only:

- slow drag tracking;
- rapid consecutive swipes / takeover;
- commit and cancel release tails;
- page-transition continuity and white-flash regression;
- overall hand-feel versus the prior product baseline.

A compact result such as `明显更顺 / 差不多 / 更差 + 是否有视觉或手势回归` is sufficient. CI/IPA success is not a claim that the real-device smoothness issue is fixed.