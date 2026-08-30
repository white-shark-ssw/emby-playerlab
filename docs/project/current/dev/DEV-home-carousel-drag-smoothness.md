# DEV-home-carousel-drag-smoothness

- **Status:** Active — Build274 target-device result is now `CAROUSEL ≈90 / TREE FULL ≈90` with screen recording off, so steady-state full real carousel-tree invalidation/composition is sufficient to reproduce the presented-FPS ceiling without touch, settle, resident rotation, or new-target loading. Build275 / 0.15.8 is the current exact-source CI/IPA-verified scope-isolation diagnostic: `TREE FULL / TREE HERO / TREE BACKDROP`.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps / pipeline probe
- **Task:** Preserve the accepted Build241 carousel appearance/gesture feel while locating the real cause of the no-screen-recording ~90 FPS presentation ceiling on iPhone 15 Pro Max / iOS 17.0.
- **Base branch:** `main`
- **Controlling normal-behavior diagnostic base:** Build265 exact product source `af92164890e7dc1c869bd586577b39177335df5f`.
- **Build269 diagnostic:** `diag/home-carousel-persistent-blur-build269`, exact product source `28d09e1cf7b3932e9033c370df12026889033197`.
- **Build270 diagnostic:** `perf/home-carousel-foreground-residency-build270`, exact product source `cee2031aa7dc2abb59fb371196e22fbce56e32ee`.
- **Current working branch:** `diag/home-carousel-tree-scope-build275`.
- **Current exact product source:** `8c6a882c03e60e9d2f49e9bc95b09f9e3712577b`.
- **Current candidate:** OnePlayer `0.15.8 (275)` — full/Hero/backdrop transition-scope 120 Hz A/B; Code written / exact-source CI passed / IPA produced and independently verified; target-device scope HUD results pending.
- **Target device:** iPhone 15 Pro Max / iOS 17.0.
- **Deployment Target:** iOS 15.0.

## Controlling product/interaction baseline

Build241 remains the final/frozen product carousel behavior to preserve: one UIKit interaction owner, acquisition-relative handling, full-width page slots, clear-Hero current/previous/next residency, page-level foreground `compositingGroup()`, max-refresh-through-settle behavior, persistent white-flash correction, ordinary progress commit `>=0.28`, direction-aware fling commit `>=500 pt/s`, commit `.easeOut(duration: 0.22)` and cancel `.easeOut(duration: 0.18)`.

The reopened task is diagnostic/performance work only. Build241 remains the product behavior authority. Build242 remains diagnostic-only and must not be used as a product/inheritance baseline.

## Measurement authority

The controlling performance measurement is the target-device **system FPS HUD with screen recording off**.

- Screen-recording 120 FPS is not acceptance evidence because target-device testing shows recording itself can change the final presentation cadence.
- `CADisplayLink` callback timing is diagnostic main-run-loop/display-link evidence only; it is not final compositor/screen-presentation FPS.
- Current source already contains `CADisableMinimumFrameDurationOnPhone = true` in `Config/Info.plist`; do not add another speculative ProMotion opt-in.
- Existing `DisplayRefreshRateMonitor` also uses `CADisplayLink`; it can report near-120 callbacks while the system HUD remains around ~90, so it cannot by itself locate the final-present bottleneck.

## Build265 / 0.14.98 — normal-behavior diagnostic base

Exact product source: `af92164890e7dc1c869bd586577b39177335df5f`.

Build265 retains the accepted rapid-swipe path and only dedupes repeated `EmbyImageContrastAnalyzer` work for the same decoded carousel `UIImage` identity. CI run/job `33318027714 / 99274932594` passed; artifact `9734083764`; IPA SHA-256 `cf381c823e863562b1f21d40d61926e693b76fac3ba4d5023e7ce2c154ffa100`; MinOS 15.0.

Target-device controlling result: without screen recording, the system FPS HUD peaks only around ~90 FPS. With recording enabled it can climb toward 120. Therefore Build265 is useful as the normal-behavior exact-source diagnostic base, not a proven 120 FPS product candidate; PR #274 remains closed/unmerged.

## Build269 / 0.15.2 — persistent blur A/B rejected

Build269 branches directly from Build265 and removes only the persistent full-screen `carouselPersistentImage(...).blur(radius: 30)` plus candidate identity. It is diagnostic-only and intentionally changes appearance.

- Exact product source: `28d09e1cf7b3932e9033c370df12026889033197`.
- CI run/job: `33324520023 / 99292189686` success.
- Artifact ID: `9735866507`.
- IPA SHA-256: `89ff7b1be43f7cefccfe9a4e5d32bab64ed45a4d9543c54ba8905200de3c1b8f`.
- MinOS 15.0.
- Target-device result: no recording, maximum observed FPS still around ~90.

Conclusion: disabling blur30 does not materially move the ceiling. The hypothesis that this single blur is the primary limiter is rejected. Do not inherit blur-off behavior and do not continue blur-specific tuning without new evidence.

## Build270 / 0.15.3 — foreground residency A/B rejected

Build270 also branches directly from Build265, restoring normal blur30. It changes only candidate identity plus foreground enumeration from all up-to-6 `model.carouselItems` to the already-existing current/previous/next `carouselHeroResidentItems`. The retained Build231 `.compositingGroup()` stays on each resident foreground page. Hero artwork, gestures, transition state, cache, persistent backdrop, preload, logo resolution and playback/P0 modules are untouched.

- Exact product source: `cee2031aa7dc2abb59fb371196e22fbce56e32ee`.
- CI run/job: `33327653253 / 99300535892` success.
- Artifact ID: `9736735731`.
- Artifact digest: `sha256:3a8ab81ccce3b4e6fc10928b829bad053a5060c3130c5ceced9398f85af4ad2b`.
- IPA SHA-256: `169fb53bd3012c7b864912638f9f627e68282b3f6fb2dd18be58e48edca56b8d`.
- Source ZIP SHA-256: `f586270e852d09623cf5af38d6cd3b8bbaea85d4b8475bc4512e6a816f4ef98a`.
- Info.plist: `0.15.3 (270)`, MinOS 15.0.
- Target-device result — 2026-08-31: **same as Build265/269; without screen recording, highest observed system HUD remains around ~90 FPS.**

Conclusion: reducing invisible foreground page residency/offscreen compositing groups from up to six pages to current/previous/next does not materially move the ceiling. The foreground-residency/compositing-count major-cause hypothesis is rejected. Build270 remains diagnostic-only and must not become product behavior.

## Build271 / 0.15.4 — frame-pipeline benchmark

The repeated negative A/Bs now justify changing from component-removal guesses to a code-driven pipeline benchmark.

Build271 is created directly from exact Build265 source, **not** from Build269 or Build270. Relative to Build265 it changes only:

1. `Sources/Core/AppIdentity.swift` — diagnostic identity `0.15.4`.
2. `Sources/UI/EmbyHomeCoreV3.swift` — adds a diagnostic mode state/control and replaces the entire Home presentation with a probe only when a non-carousel diagnostic mode is selected.
3. `Sources/UI/EmbyHomeFramePipelineProbeV3.swift` — new diagnostic-only benchmark implementation.

`Sources/UI/EmbyHomeHeroV3.swift` is intentionally unchanged from Build265; CI guards its exact blob SHA `ab2ab5d80a59e174622dca0006c0f3aad4111a54`.

### Probe modes

Tap the top-right `PIPE ...` control to cycle:

1. `CAROUSEL` — normal Build265 Home/carousel presentation. This is the in-package control.
2. `CA` — full-screen simple Core Animation render-server motion. Normal Home/carousel presentation is not mounted in this mode.
3. `DISPLAYLINK` — `CADisplayLink` requests `UIScreen.main.maximumFramesPerSecond` and directly updates a native `CALayer` on the main thread. Normal Home/carousel presentation is not mounted.
4. `SWIFTUI` — the same display-link cadence publishes a single scalar through `@Published`, and SwiftUI moves one simple marker. Normal Home/carousel presentation is not mounted.

This single package is intended to locate the layer where the system HUD ceiling first appears:

- if `CA` itself remains ~90, investigate final Core Animation/ProMotion/window/system presentation scheduling rather than carousel view cost;
- if `CA` reaches ~120 but `DISPLAYLINK` remains ~90, main-thread display-link/commit scheduling becomes the next target;
- if `CA` and `DISPLAYLINK` reach ~120 but `SWIFTUI` remains ~90, SwiftUI state publication/render invalidation becomes the next target;
- if all three probes reach ~120 while `CAROUSEL` stays ~90, the bottleneck is inside the actual Home/carousel render tree and further instrumentation should target its per-frame invalidation/commit work rather than static visual components already rejected.

No synthetic busy-loop load is added in Build271. First locate the failing pipeline boundary without heating the device or contaminating subsequent modes; controlled CPU-load headroom testing can be justified only after the boundary is known.

### Build / package evidence

- Exact product source: `643ff1cbbd24ea06a315c632b08ac1ad162ee43f`.
- Dedicated exact-source CI run/job: `33329047915 / 99304195063` — success. The preceding run `33328917736` failed only in a macOS Bash source-guard script before build; product source did not change because of that CI-script issue.
- Artifact: `OnePlayer-0.15.4-build271-frame-pipeline-probe`, ID `9737161622`.
- Artifact digest: `sha256:56ae2d35b3fc8598c1db02f5cc8cc23cc7153d8a6079d27b54e0e2fde00fab47`.
- IPA SHA-256: `e2c6540e5705f9837dd75db6a41ef7a1ce02d24c3afb3f7abc2160faaa8a963f`.
- Source ZIP SHA-256: `df4b09881cab1ff955b830c6dc821eaf8d6bc4ef377898978af1ee24f194ef22`.
- Independent artifact re-download/unpack in ChatGPT runtime reproduced both hashes; IPA `unzip -t` passed.
- Independent IPA Info.plist: bundle `com.embyplayerlab.app`, display `OnePlayer`, version `0.15.4`, build `271`, `MinimumOSVersion=15.0`.
- Independent MinOS report ends `Minimum OS compatibility audit: OK`.
- Diagnostic prerelease tag: `build271-frame-pipeline-test`; publish run `33330204282` success. Release publishing republishes the already-verified fixed artifact; it does not rebuild product code.

## Build271 target-device pipeline result — 2026-08-31

The user supplied direct target-device screenshots and explicitly confirmed that the system FPS HUD shown in them is real. With screen recording off, Build271 shows:

- `PIPE CA`: **60 FPS**.
- `PIPE DISPLAYLINK`: **120 FPS**.
- `PIPE SWIFTUI`: **120 FPS**.

The accompanying `OnePlayer-App-1788120204.log` contains 40 normal-carousel cadence sessions. Their internal display-link intervals remain broadly high-refresh (median `display_avg_gap_ms=8.795`), while delivered touch / publish / render state changes are less frequent (median `15.455 / 21.445 / 21.665 ms`). This reinforces the already-established rule that callback cadence is not identical to final presented cadence or to user-driven state publication cadence.

Exact Build271 source explains the 60 FPS CA screenshot: the `CABasicAnimation` probe did **not** set `CAAnimation.preferredFrameRateRange`, while both DISPLAYLINK and SWIFTUI probes explicitly requested `UIScreen.main.maximumFramesPerSecond`. Because the more complex `CADisplayLink→CALayer` and `CADisplayLink→@Published→SwiftUI` paths both reach a real 120 FPS on the same device, Build271 rejects a generic 60/90 FPS ceiling in UIKit/SwiftUI/Combine/CALayer/display-link capability. The next diagnostic must exercise the actual Home carousel render tree.

Build271 evidence is now: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device pipeline tested ✅ / generic pipeline ceiling rejected ✅ / actual carousel bottleneck unresolved / stable ❌**.

## Build274 / 0.15.7 — full carousel-tree 120 Hz probe

Build274 is created from exact Build271 product source `643ff1cbbd24ea06a315c632b08ac1ad162ee43f` and changes exactly three product files: AppIdentity, Home diagnostic-mode mounting, and the frame-pipeline probe. `EmbyHomeHeroV3.swift`, `EmbyHomeCarouselInteractionV3.swift`, and `EmbyHomeCarouselStateV3.swift` remain exact protected blobs `ab2ab5d80a59e174622dca0006c0f3aad4111a54`, `f8df5af61101c0272c5ec378caae617000b8fcea`, and `96f38514cfb09668f11c21a61105ac87a2f26f3d`.

New `TREE120` mode keeps the full real Build265/271 Home presentation mounted — persistent blur backdrop, preload layer, three-slot clear Hero artwork, all foreground pages with retained page-level `compositingGroup()`, indicators, Home rows/header/dock — but replaces finger input with one main-thread `CADisplayLink` requesting device-max refresh. That display link drives the **same existing `transitionProgress` owner** continuously 0→1→0 between one fixed current/neighbor pair. It deliberately does not settle, rotate `currentCarouselItemID`, rotate resident windows, or request a new target image during the measurement.

Interpretation is binary:

- `TREE120` also stays around ~90: steady-state real carousel-tree invalidation/composition/commit cost is sufficient to cap presentation, so the next probe should split the real tree's per-frame layers.
- `TREE120` reaches 120 while manual `CAROUSEL` remains around ~90: the real tree has 120 Hz headroom in steady state; the next target becomes touch delivery / release-settle / resident rotation / image-callback lifecycle rather than static tree cost.

The CA marker probe in Build274 also adds the missing `CAAnimation.preferredFrameRateRange` high-refresh request, correcting the Build271 probe configuration; this is diagnostic hygiene, not a carousel product change.

Build274 exact product source: `6d18ca0cdb02bbce3f8fee13f8b5dc082a43ab63`. Xcode 16.4 run/job `33333236724 / 99315483085` passed. Artifact `9738285110`, digest `sha256:0fb0e5f9a07c6eb16eab00cdf516283991b0d5e6d61597ea368497ccb4f320f7`. IPA SHA-256 `2fc79d5d09aa8e0c2f6384b4a50e933cf79f885c4b8d9fd05932fc1a3cc6295a`; source ZIP SHA-256 `ed85b8c7a1d28de8af26ba7124386dfa987b3e83d8c4d38b61e8b5b61c4d5598`. Independent re-download verifies both hashes, IPA archive integrity, `com.embyplayerlab.app / OnePlayer / 0.15.7 (274)`, `MinimumOSVersion=15.0`, and `Minimum OS compatibility audit: OK`.

A provisional carousel `Build273 / 0.15.6` identity was retired **before valid carousel compile/package attribution** after discovering the independent poster-grid task already owned Build273 (`perf/poster-grid-native-collection-build273`). Never use carousel Build273 for attribution. Build274 is the first valid identity for this TREE120 diagnostic.

## Build274 target-device TREE result — 2026-08-31

The user tested Build274 on iPhone 15 Pro Max / iOS 17.0 with screen recording off and reported **`CAROUSEL ≈90 FPS / TREE FULL ≈90 FPS`**. The supplied TREE screenshot captures 101 FPS at one instant, but the sustained observation remains around 90 and does not approach a stable 120. The sustained target-device result controls.

This closes the Build274 binary split: touch delivery, release/settle, resident-window rotation and new-target image loading are **not necessary** to reproduce the ceiling. A fixed-pair device-max `CADisplayLink` driving the unchanged real `transitionProgress` through the full real Home carousel tree is sufficient. The uploaded `OnePlayer-App-1788121754.log` also continues to show many internal display-link intervals near 8.34 ms during manual carousel sessions while the real HUD is lower, reinforcing that internal callback cadence is not final presented FPS.

Exact source ownership gives a narrow next boundary. `V3HomeCarouselTransitionState.progress` is `@Published`, but the whole Home root is not observing it. The high-frequency progress publication is consumed through exactly two `V3HomeCarouselTransitionScope` observers in the Build274 presentation: (1) the full-screen persistent backdrop; and (2) the Hero subtree containing clear artwork/mask/foreground pages/indicators. Therefore the next A/B splits those two scopes rather than resuming generic SwiftUI/UIKit, blur-only, gesture, timing or ProMotion guesses.

Build274 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device TREE tested ✅ / full steady-state tree sufficient to reproduce ~90 ceiling ✅ / stable ❌**.

## Build275 / 0.15.8 — transition-scope split

Build275 extends exact Build274 source and changes only `Sources/Core/AppIdentity.swift`, `Sources/UI/EmbyHomeCoreV3.swift`, and `Sources/UI/EmbyHomeFramePipelineProbeV3.swift`. The real product files `EmbyHomeHeroV3.swift`, `EmbyHomeCarouselInteractionV3.swift`, and `EmbyHomeCarouselStateV3.swift` remain exact protected blobs `ab2ab5d80a59e174622dca0006c0f3aad4111a54`, `f8df5af61101c0272c5ec378caae617000b8fcea`, and `96f38514cfb09668f11c21a61105ac87a2f26f3d`.

The package keeps the same fixed-pair device-max progress driver and adds three Home-tree modes:

- `TREE FULL`: Build274 control; both persistent-backdrop and Hero transition scopes observe progress.
- `TREE HERO`: only the Hero transition scope observes progress; the persistent backdrop remains mounted but is frozen during the high-frequency stream.
- `TREE BACKDROP`: only the persistent-backdrop transition scope observes progress; the Hero remains mounted but frozen during the high-frequency stream.

This preserves static tree complexity while isolating which `ObservableObject` invalidation scope consumes the per-frame budget. There is still no settle, resident rotation, new target selection, timer/watchdog/retry, second product state owner, gesture change, image-cache change, or Player/Transport/P0 change.

Build275 exact product source `8c6a882c03e60e9d2f49e9bc95b09f9e3712577b`. Xcode 16.4 run/job `33334208681 / 99318066653` passed. Artifact `9738555839`, digest `sha256:16e42660ac53bffcc9d7d222fcf81bcadf692a7ff87cbd4562d791dbd6973c0b`. IPA SHA-256 `26229afe7b1cec29ab2bf2cca18c0348fd3337a2d6f996bd2a6b6b07c5bebe64`; source ZIP SHA-256 `4bf558ce4731fb3813e276f19f43e73450f360c79667c48c0a2122fa4848c0f4`. Independent unpack verifies IPA integrity, `com.embyplayerlab.app / OnePlayer / 0.15.8 (275)`, `MinimumOSVersion=15.0`, and the MinOS audit.

## Scope guard

No Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN code is in scope. No Build241 gesture thresholds, rapid-swipe ownership, Hero rendering implementation, image cache or transport contract is modified by Build271.

## Acceptance / test procedure

1. Use iPhone 15 Pro Max / iOS 17.0 with screen recording **off**.
2. `PIPE CAROUSEL`: rapidly swipe as the normal control and note the real system HUD.
3. Tap once to `PIPE TREE FULL`; stop touching the screen and let the fixed pair oscillate for 5–10 seconds; note HUD.
4. Tap once to `PIPE TREE HERO`; do not touch; note HUD.
5. Tap once to `PIPE TREE BACKDROP`; do not touch; note HUD.
6. Report all four approximate sustained values, e.g. `CAROUSEL 90 / FULL 90 / HERO 120 / BACKDROP 120`.
7. Interpretation: HERO-only ~90 localizes a sufficient Hero-scope cost; BACKDROP-only ~90 localizes a sufficient backdrop-scope cost; both isolated modes ~120 while FULL ~90 indicates combined budget pressure; both isolated modes ~90 means each scope can independently exceed the 120-Hz budget and requires deeper split.
8. CI/IPA evidence is not a performance conclusion; target-device HUD remains authoritative.
## Validation state

- Build265 Code / CI / IPA: ✅. Real-device: ✅ ~90 no-recording ceiling; not stable.
- Build269 Code / CI / IPA: ✅. Real-device: ✅ ~90; blur-primary hypothesis rejected; diagnostic-only.
- Build270 Code / CI / IPA: ✅. Real-device: ✅ ~90; foreground-residency hypothesis rejected; diagnostic-only.
- Build271 Code / CI / IPA: ✅. Real-device pipeline: ✅ `CA 60 / DISPLAYLINK 120 / SWIFTUI 120`; generic display-link/CALayer/SwiftUI 120 capability proven; not stable.
- Carousel Build273: ❌ retired identity collision; poster-grid owns Build273; no valid carousel package attribution.
- Build274 Code / CI / IPA: ✅. Real-device: ✅ `CAROUSEL ≈90 / TREE FULL ≈90`; full steady-state real carousel tree is sufficient to reproduce the ceiling; diagnostic-only.
- Build275 Code written: ✅ exact product source `8c6a882c03e60e9d2f49e9bc95b09f9e3712577b`.
- Build275 exact-source CI passed: ✅ run/job `33334208681 / 99318066653`.
- Build275 IPA produced + independently verified: ✅ artifact `9738555839`; IPA SHA `26229afe7b1cec29ab2bf2cca18c0348fd3337a2d6f996bd2a6b6b07c5bebe64`; source SHA `4bf558ce4731fb3813e276f19f43e73450f360c79667c48c0a2122fa4848c0f4`; MinOS 15.0.
- Build275 target-device scope split: ❌ pending.
- Stable/frozen reopened performance task: ❌.
## Next exact action

Install Build275 and keep screen recording off. Measure `CAROUSEL → TREE FULL → TREE HERO → TREE BACKDROP`, with no screen touch during the three automatic tree modes. The relative real system-HUD values determine whether the next change targets the Hero observer scope, persistent-backdrop observer scope, or their combined per-frame budget. Do not alter product gesture/release timing, image transport/cache, Player/MPV/PiP, or add smoothing/fallback logic before this scope result.