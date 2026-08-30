# DEV-home-carousel-drag-smoothness

- **Status:** Active — Build269 blur-off and Build270 foreground-residency target-device A/Bs both leave the no-recording system FPS HUD ceiling around ~90 FPS, so both major-cause hypotheses are rejected. Build271 / 0.15.4 is the current diagnostic: an in-app frame-pipeline benchmark that compares normal carousel, pure Core Animation, native CADisplayLink→CALayer, and CADisplayLink→@Published→SwiftUI paths in one package.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps / pipeline probe
- **Task:** Preserve the accepted Build241 carousel appearance/gesture feel while locating the real cause of the no-screen-recording ~90 FPS presentation ceiling on iPhone 15 Pro Max / iOS 17.0.
- **Base branch:** `main`
- **Controlling normal-behavior diagnostic base:** Build265 exact product source `af92164890e7dc1c869bd586577b39177335df5f`.
- **Build269 diagnostic:** `diag/home-carousel-persistent-blur-build269`, exact product source `28d09e1cf7b3932e9033c370df12026889033197`.
- **Build270 diagnostic:** `perf/home-carousel-foreground-residency-build270`, exact product source `cee2031aa7dc2abb59fb371196e22fbce56e32ee`.
- **Current working branch:** `diag/home-carousel-frame-pipeline-build271`.
- **Current exact product source:** `643ff1cbbd24ea06a315c632b08ac1ad162ee43f`.
- **Current candidate:** OnePlayer `0.15.4 (271)` — pipeline diagnostic; Code written / exact-source CI passed / IPA produced and independently verified; target-device four-mode HUD test pending.
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

## Scope guard

No Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN code is in scope. No Build241 gesture thresholds, rapid-swipe ownership, Hero rendering implementation, image cache or transport contract is modified by Build271.

## Acceptance / test procedure

1. Use iPhone 15 Pro Max / iOS 17.0.
2. Keep screen recording **off** for every comparison.
3. Open Home and observe the system FPS HUD in `PIPE CAROUSEL` while rapidly swiping as before.
4. Tap `PIPE CAROUSEL` once for `PIPE CA`; do not swipe, just watch the moving marker and HUD for several seconds.
5. Tap again for `PIPE DISPLAYLINK`; watch marker/HUD.
6. Tap again for `PIPE SWIFTUI`; watch marker/HUD.
7. Report the approximate stable/maximum FPS for all four modes in one result, e.g. `CAROUSEL 90 / CA 120 / DISPLAYLINK 120 / SWIFTUI 90`.
8. CI/IPA evidence is not a performance conclusion; target-device A/B remains required.

## Validation state

- Build265 Code / CI / IPA: ✅. Real-device: ✅ ~90 no-recording ceiling; not stable.
- Build269 Code / CI / IPA: ✅. Real-device: ✅ ~90; blur-primary hypothesis rejected; diagnostic-only.
- Build270 Code / CI / IPA: ✅. Real-device: ✅ ~90; foreground-residency hypothesis rejected; diagnostic-only.
- Build271 Code written: ✅ exact product source `643ff1cbbd24ea06a315c632b08ac1ad162ee43f`.
- Build271 exact-source CI passed: ✅ run/job `33329047915 / 99304195063`.
- Build271 IPA produced + independently verified: ✅ artifact `9737161622`; IPA SHA `e2c6540e5705f9837dd75db6a41ef7a1ce02d24c3afb3f7abc2160faaa8a963f`; source SHA `df4b09881cab1ff955b830c6dc821eaf8d6bc4ef377898978af1ee24f194ef22`; MinOS 15.0.
- Build271 real-device tested: ❌ pending four-mode no-recording HUD A/B.
- Stable/frozen reopened performance task: ❌.

## Next exact action

Install Build271 and perform the four-mode no-screen-recording system-HUD test: `CAROUSEL → CA → DISPLAYLINK → SWIFTUI`. Do not change runtime again before this result. The first mode that fails to reach the cadence shown by the preceding simpler mode determines the next instrumentation layer; only after that boundary is known should controlled synthetic CPU/GPU stress be added.
