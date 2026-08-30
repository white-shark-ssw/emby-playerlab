# DEV-home-carousel-drag-smoothness

- **Status:** Active — Build265 is the current normal-behavior evidence baseline; Build269 / 0.15.2 has now been target-device tested and rejects full-screen persistent `blur(radius: 30)` as the cause of the observed no-recording ~90 FPS ceiling. Next direction is foreground presentation residency/compositing isolation from exact Build265 source.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps
- **Task:** Preserve the accepted Build241 carousel appearance/gesture feel while fixing rapid consecutive swipe ownership and improving actual no-screen-recording presentation cadence toward EX on iPhone 15 Pro Max / iOS 17.0.
- **Base branch:** `main`
- **Build265 branch:** `perf/home-carousel-image-analysis-dedupe-build265`
- **Build265 PR:** #274 — closed without merge after target-device evidence corrected the FPS interpretation.
- **Build265 exact product source:** `af92164890e7dc1c869bd586577b39177335df5f`
- **Build269 diagnostic branch:** `diag/home-carousel-persistent-blur-build269`
- **Build269 exact product source:** `28d09e1cf7b3932e9033c370df12026889033197`
- **Build269 candidate:** OnePlayer `0.15.2 (269)` — diagnostic only; do not inherit blur-off behavior.
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment Target:** iOS 15.0.

## Controlling interaction baseline

Build241 remains the merged visual/gesture foundation to preserve: one UIKit interaction owner, acquisition-relative handling, full-width page slots, Build226 clear-Hero three-slot residency, Build231 page-level foreground `compositingGroup()`, Build228 device-max refresh through settle, persistent white-flash correction, ordinary progress commit `>=0.28`, direction-aware fling commit `>=500 pt/s`, commit `.easeOut(duration: 0.22)` and cancel `.easeOut(duration: 0.18)`.

New 2026-08-30/31 target-device evidence reopened the performance claim and rapid-swipe ownership only. Do not treat previous screen-recording 120 FPS or CADisplayLink callback cadence as proof of actual final presented 120 FPS.

## Build262 → Build264 rapid-swipe result

Build262 added spatial axis hysteresis and rapid settle takeover, but its experimental persistent current/previous/next backdrop residency caused a severe visual presentation freeze while authoritative interaction/current-item state continued advancing. That persistent residency experiment was rejected.

Build264 rolled only the persistent backdrop back to Build241 current + transition-target structure while retaining the Build262 recognizer/rapid-settle improvements. Target-device testing removed the hard visual freeze and preserved the improved rapid-swipe interaction behavior. This established the retained interaction base for Build265.

## Build265 / 0.14.98 — image-analysis dedupe

Exact source: `af92164890e7dc1c869bd586577b39177335df5f`.

Build265 keeps Build264 behavior and only dedupes repeated `EmbyImageContrastAnalyzer` work for the same decoded carousel `UIImage` identity. CI run/job `33318027714 / 99274932594` passed; artifact `9734083764`; IPA SHA-256 `cf381c823e863562b1f21d40d61926e693b76fac3ba4d5023e7ce2c154ffa100`; source ZIP SHA-256 `b1cf0debf996ea30ba0e7171b035749e5f31192a7e4e70db7e146d76064d2b53`; MinOS 15.0.

### Build265 target-device correction

The user reports the actual system FPS HUD, **without screen recording**, peaks only around **~90 FPS**. When screen recording is enabled, the HUD can climb to 120 FPS. The supplied recording also showed the HUD ramping roughly `76 → 104 → 120` while the carousel diagnostic `CADisplayLink` callback interval was already around `8.4–9 ms`.

Therefore:

- screen-recording 120 FPS is not an acceptance/control baseline for this task;
- `HomeCarouselCadence display_*` measures CADisplayLink/main-run-loop callback cadence, not final compositor/screen presentation FPS;
- previous conversion of those callback intervals into effective presented Hz is withdrawn;
- Build265 is not a proven 120 FPS product candidate and PR #274 stays closed/unmerged;
- Build265 remains useful as the normal-behavior exact-source baseline because rapid-swipe interaction is functional and the image-analysis dedupe itself does not introduce a reported regression.

The Build265 App log contained 93 release decisions / cadence sessions and 79 `HomeCarouselRapidSwipe` settle-takeover events, confirming the rapid-swipe path is exercised heavily on device rather than merely compiling.

## Build269 / 0.15.2 — persistent full-screen blur A/B

Purpose: test whether the persistent full-screen `carouselPersistentImage(...).blur(radius: 30)` is the major GPU/compositor limiter behind the no-recording ~90 FPS ceiling.

Build269 branches from exact Build265 behavior and changes only candidate identity plus removal of that persistent real-time blur. It deliberately changes backdrop appearance and is diagnostic-only.

- Branch: `diag/home-carousel-persistent-blur-build269`
- Exact product source: `28d09e1cf7b3932e9033c370df12026889033197`
- Corrected CI run/job: `33324520023 / 99292189686` — success.
- Artifact: `OnePlayer-0.15.2-build269-carousel-persistent-blur-off`, ID `9735866507`.
- Artifact digest / independently recomputed ZIP SHA-256: `0ef920811a06f762d7544e001c4d05628ce9f58e09ae9df81b6fa578f2e22d18`.
- IPA SHA-256: `89ff7b1be43f7cefccfe9a4e5d32bab64ed45a4d9543c54ba8905200de3c1b8f`.
- Source ZIP SHA-256: `e512553e196c4d51cc4fda4249de3135bc54944c7393d5f70f51b9a492669c12`.
- Independently reopened IPA: bundle `com.embyplayerlab.app`, display/name `OnePlayer`, version `0.15.2`, build `269`, `MinimumOSVersion=15.0`; IPA `unzip -t` clean.

### Build269 target-device result — 2026-08-31

User result: **same as Build265 — without screen recording, maximum observed FPS remains around ~90 FPS.**

This is a direct negative A/B for the tested hypothesis. Removing the full-screen real-time blur does not materially raise the no-recording ceiling, so `blur(radius: 30)` is **not demonstrated to be the primary limiter**. Do not continue blur-specific tuning, do not keep the blur-off product behavior, and do not infer that blur has zero cost; only the major-cause hypothesis is rejected.

## Source review for next direction

Exact Build265 source confirms:

- `V3EmbyHomeViewModel.liveCarouselItems()` caps the carousel at **6 items**.
- Clear Hero artwork already uses `carouselHeroResidentItems`, exactly current + previous + next.
- Every interactive transition target is the immediate neighbor of `currentCarouselItemID`; rapid commit-settle interruption first calls `settleCarousel(on:)`, then the three-slot resident window recomputes around the new current item.
- Foreground title/logo/metadata currently still uses `ForEach(model.carouselItems)` across all up-to-6 carousel items, and each foreground page applies the retained Build231 `.compositingGroup()` even though `carouselForegroundOpacity` exposes only current/from/to.
- Logo metadata is separately resolved for all carousel items by `resolveCarouselLogosIfNeeded()`, so reducing foreground view residency does not require changing the logo-resolution owner.

This makes foreground residency the next evidence-backed presentation A/B: keep the beneficial per-page `compositingGroup()` contract, but mount only the same current/previous/next resident window already proven sufficient for every reachable transition target. This is narrower and safer than removing `compositingGroup()` itself, which had positive target-device title-stability evidence in Build231.

## Parallel-task / identity guard

- Build268 is occupied by the parallel poster task (`perf/poster-grid-lean-cadence-build268`).
- Build269 belongs only to this carousel diagnostic.
- Repository branch search currently finds no Build270 branch; Build270 is available for this task once allocated.
- `DEV-aether-multi-engine-comparison`, poster-grid and Search remain separate state owners.
- No Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN code is in scope.

## Acceptance criteria

1. Repeated fast horizontal swipes start immediately after the previous finger-up; Home vertical scrolling does not steal a horizontal sequence after horizontal intent is acquired.
2. No hard visual freeze occurs while rapid swiping.
3. Preserve Build241 visual direction, 500 pt/s fling gate, 0.28 progress gate, full-width motion, Build231 foreground compositing behavior, clear-Hero three-slot residency and 0.22/0.18 settle.
4. Performance comparison uses the target-device **system FPS HUD without screen recording** as the controlling visual cadence condition; screen-recording 120 is not acceptance evidence.
5. CADisplayLink logs remain diagnostic callback evidence only and must not be translated directly into final presented FPS.
6. Final candidate must compile/package at MinOS 15.0 with exact-source identity verification before handoff.
7. Final acceptance requires target-device A/B; CI/IPA alone is not success.

## Validation state

- Build265 Code written / CI passed / IPA produced: ✅.
- Build265 real-device tested: ✅ — rapid-swipe path functional, but no-recording presentation peaks around ~90 FPS; not stable.
- Build269 Code written / corrected CI passed / IPA produced + independently verified: ✅.
- Build269 real-device tested: ✅ — no-recording max remains ~90 FPS; blur-primary hypothesis rejected.
- Build269 stable/product candidate: ❌ diagnostic-only.
- Stable/frozen whole-carousel task: ❌.

## Next exact action

Allocate Build270 from exact Build265 source `af92164890e7dc1c869bd586577b39177335df5f`, not from Build269. Change only candidate identity plus `immersiveCarouselHero` foreground enumeration from all `model.carouselItems` to the already-existing `carouselHeroResidentItems`, retaining each page's Build231 `.compositingGroup()` and all interaction/persistent-backdrop/image-cache behavior. Run exact-source CI/IPA validation and hand off for a no-screen-recording FPS A/B. If the ~90 ceiling does not materially move, reject the foreground-residency hypothesis and switch direction again rather than stacking speculative optimizations.