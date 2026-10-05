# DEV-home-carousel-drag-smoothness

- **Status:** Active — Build289 real-device rejected for bottom-Dock displacement; Build290 / 0.15.23 minimal Home-root layout correction is code-complete, CI/IPA verified, and awaiting target-device validation.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps / invalidation scope / progress publication
- **Task:** Refactor the bounded Home carousel presentation: full-page residency, one transition authority, immediate visible-state takeover, fixed-position artwork blending/full-width foreground sliding, and a single lower-Home color surface.
- **Executable development plan:** [HOME_CAROUSEL_DEVELOPMENT_PLAN.md](../../HOME_CAROUSEL_DEVELOPMENT_PLAN.md)
- **Requirement/source/reference evidence:** [HOME_CAROUSEL_REFACTOR_PLAN.md](../../HOME_CAROUSEL_REFACTOR_PLAN.md)
- **Scope of this checkpoint:** Build289 native presentation implementation, the 2026-10-05 target-device rejection, Build290 minimal Dock-layout correction, CI/package evidence, and the next exact real-device gate are recorded here.

## Controlling baseline / identity

- **Behavior foundation:** merged Build241 interaction contracts remain protected; Build289 introduced the bounded Home-private native presentation runtime.
- **Current product branch:** `perf/home-carousel-progress-scope-build286`
- **Draft PR:** #289 — open, unmerged.
- **Build289 rejected source:** `0f5a1893988e20e0dcfe21d0395abe194c2340e6`, OnePlayer `0.15.22 / 289`; 2026-10-05 target-device recording shows the bottom Dock displaced below the visible screen.
- **Current Build290 source:** `9e0bb371fe65c29524b92ac1892bab84b6684444`, OnePlayer `0.15.23 / 290`. Build289→Build290 delta is exactly AppIdentity plus one Home-root `.frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)` line.
- **Build290 CI run / job:** `37325862505 / 111816942719` — success.
- **Build290 artifact:** `OnePlayer-0.15.23-build290-home-carousel-dock-fix`, ID `11352810860`, digest `sha256:70806c4d5fed5ef48b3e71dea887f5f0867c55b4a962bde0cb4ff9c4d357904f`.
- **Build290 IPA SHA-256:** `734e2f40fd3d6c694c79feb060d675128927cd0ff2c9c541791be1b1a5a1cf2e`; source ZIP SHA-256: `1a3d3b50abaf3707193da427ed3512d223fb0005e7fe33ef891486916ddf7de4`.
- **Bundle / version / MinOS:** `com.embyplayerlab.app / 0.15.23 (290) / iOS15.0`.
- **Target device:** iPhone 15 Pro Max / iOS 17.0.
- **Evidence boundary:** Build289 is device-rejected; Build290 has Code written + CI passed + IPA produced/independently verified, but no Build290 real-device acceptance yet.
- **Recording interpretation:** uploaded capture is 30 FPS; use it for qualitative layout/visual evidence, not numerical 120 Hz measurement.

Build288 exact source `ce565996e37dcb750117c9de4607b23b673edce3` matches286 HomeCore/Hero/HeroScrollState and all carousel runtime/diagnostic blobs. User reports persistent drops, inability to sustain desired120FPS and a large competitor experience gap. This is qualitative target-device evidence, not a numerical frame trace or proof of zero improvement. Detail-navigation Build288 acceptance remains separate/frozen; PR#290 is closed unmerged with no distinct detail behavior to inherit.

## Confirmed current requirements

1. Requirements-first bounded refactor; design avoidable long-frame work out of drag, settle and auto×vertical-inertia paths.
2. All currently accepted carousel items (HomeModel cap6) prebuilt/resident; only current/target nodes consume motion. Do not create pages during each switch or copy full-screen textures/snapshots per page.
3. Artwork remains near fixed position and blends; title/logo/metadata/overview slide full width. One progress/transition owner controls both.
4. New horizontal input during settle immediately takes over the current visible state. Existing source rejects start when toID is present and dragging=false; old checkpoint wording “rapid takeover” was not proof that this requirement already worked.
5. One opaque lower-Home base color and Hero seam gradient replace mandatory full-screen dynamic blur behind lower content. Per-item prepared color is the adopted reversible default; no per-frame image analysis.
6. Preserve normal thresholds/tails, auto6s/0.62s, vertical stretch/crop/refresh, click suppression/system navigation and max-refresh lifecycle.
7. Stable UIKit/CALayer presentation is the selected implementation direction to verify, not a proven performance cure. SwiftUI Home shell/content/navigation remain.
8. Prepared bindings/resources are separate from motion. Existing async decode/cache/log persistence are not replaced without actual need. Cold resources use existing async placeholder behavior, never block gestures.

**Superseded constraints:** Build286's three clear-Hero residents, unchanged blur30 and scope-only diff were that experiment's guards. They do not constrain this approved refactor. Keep their history below; preserve visual compositing/white-flash effects rather than requiring old SwiftUI API text in a native renderer.

## Completed

- Build289 bounded native presentation runtime implemented and packaged.
- User target-device recording reviewed; Build289 rejected because the bottom Dock is pushed below the visible viewport.
- Exact layout ownership traced without changing the Dock owner: the oversized native Home surface was allowed to determine the root `ZStack` layout extent.
- Build290 minimal correction committed at exact source `9e0bb371fe65c29524b92ac1892bab84b6684444`; no speculative animation/network/cache/P0 changes added.
- Build290 exact-source CI run/job `37325862505 / 111816942719` passed and artifact `11352810860` was independently downloaded and verified.

## Validation state

| Evidence | Build289 | Build290 |
|---|---|---|
| Code written | yes | yes |
| CI passed | yes | yes |
| IPA produced + independently verified | yes | yes |
| Real-device tested | **rejected — Dock offscreen** | pending |
| Stable / frozen | no | no |

## Pending

- Install Build290 on iPhone 15 Pro Max / iOS 17.0 and verify the bottom Dock is restored to the accepted position.
- Recheck carousel slow/rapid/reversal/release/cancel/immediate-settle-takeover behavior, visual continuity, tap-to-detail and Home vertical scrolling.
- Treat the 30 FPS recording qualitatively; do not claim a numerical 120 Hz result from it.
- If further carousel defects remain, inspect exact Build290 source/state ownership and new device evidence before any additional code change.

## Next exact action

Install and exercise Build290 (`0.15.23 / 290`, exact source `9e0bb371fe65c29524b92ac1892bab84b6684444`) on the target iPhone. First confirm Dock visibility/position, then run the existing Home carousel qualitative matrix. Build290 must not be described as resolved/stable until that target-device result exists. If the Dock is fixed but other carousel problems remain, use the new recording/log evidence to isolate the next issue; do not add speculative fixes from the current 30 FPS capture alone.

## Rejected / do not repeat

Separate experiments showed blur-only removal, foreground reduction, standardPan/input cadence, frame latching and286 notification scope isolation insufficient. Simple native/SwiftUI probes can reach120; no generic framework ceiling or guaranteed native cure follows. TREE mode was session-sensitive; do not compare cross-launch readings as root-cause proof. Build284 was retired before device use; do not treat it as a pending gate. Do not add prediction/interpolation of finger positions, timers/watchdogs/retries, duplicate progress/current-page authority or unrelated refactors.

## Historical Build286 implementation and packaging — not current refactor constraints

The following records describe only the existing286 candidate and its old guards. Current requirements and the executable development plan above take precedence for new implementation.

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

