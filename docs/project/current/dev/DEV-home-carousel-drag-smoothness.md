# DEV-home-carousel-drag-smoothness

- **Status:** Active — Build282 sustained-control gate is now target-device resolved. With screen recording off, `DISPLAYLINK` and `SWIFTUI` both remain stable at 120 FPS for the same sustained duration that makes `TREE FULL` / `TREE PANLOAD` decay. Generic sustained ProMotion/main-thread display-link/SwiftUI publication capability is therefore not the primary cause. The next exact action uses the already-installed Build282 `TREE HERO` and `TREE BACKDROP` modes for equal-duration sustained A/B before any new runtime patch.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps / pipeline probe
- **Task:** Preserve the accepted Build241 carousel appearance/gesture feel while locating the real cause of the no-screen-recording ~90 FPS presentation ceiling / sustained TREE decay on iPhone 15 Pro Max / iOS 17.0.
- **Base branch:** `main`
- **Current working branch:** `diag/home-carousel-tree-panload-build282`
- **Current exact product source / branch head:** `58801ef0acc6084c3168e8d7635a1258925cc382`
- **Current Draft PR:** #285 — diagnostic-only, unmerged
- **Current candidate:** OnePlayer `0.15.15 (282)`
- **Run / job:** `33425378615 / 99597549081`
- **Artifact:** `OnePlayer-0.15.15-build282-carousel-tree-panload-probe`, ID `9770646338`, digest `sha256:a8bb976eb2b8889f713357168797c1b144c35511d2b37ea8f22800f7b2876a8e`
- **IPA SHA-256:** `3ce933d6d380472fc0dec5aeadeda45d68008a3a37bc86ff48a335437f7d70cd`
- **Source ZIP SHA-256:** `fab24ca52fd5a280d2051455537490b8cf12d223f973f0f7542a94e72a652ed6`
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment Target / built MinOS:** iOS 15.0

## Controlling product baseline

Build241 remains the product interaction/presentation behavior to preserve while this reopened performance diagnosis runs: one UIKit interaction owner, acquisition-relative movement, full-width page slots, current/previous/next clear-Hero residency, page-level foreground `compositingGroup()`, max-refresh through settle, persistent white-flash correction, ordinary progress commit `>=0.28`, direction-aware fling commit `>=500 pt/s`, commit `.easeOut(duration: 0.22)` and cancel `.easeOut(duration: 0.18)`.

This task is diagnostic/performance work. Do not silently convert a diagnostic probe into product behavior.

## Measurement authority

- Controlling metric: target-device **system FPS HUD with screen recording off**.
- Screen recording can change final presentation cadence and is not acceptance evidence.
- `CADisplayLink` callback timing is diagnostic evidence only; it is not final presented FPS.
- `Config/Info.plist` already contains `CADisableMinimumFrameDurationOnPhone = true`; do not add another speculative ProMotion opt-in.

## Current source ownership relevant to the next A/B

Exact Build282 source keeps one `V3HomeCarouselTransitionState` owner. `transitionProgress` writes `state.progress`, which is `@Published`.

The real Home presentation consumes that high-frequency owner through two existing `V3HomeCarouselTransitionScope` observers in `EmbyHomeCoreV3.swift`:

1. persistent full-screen carousel backdrop scope;
2. Hero scope containing clear artwork/masks, foreground pages and indicators.

Build282 already includes fixed-pair device-max tree modes that preserve the static Home tree while changing which scope observes the progress stream:

- `TREE FULL`: Hero + backdrop observe progress.
- `TREE HERO`: only Hero observes progress; backdrop remains mounted but frozen.
- `TREE BACKDROP`: only backdrop observes progress; Hero remains mounted but frozen.
- `TREE PANLOAD`: same full-tree synthetic progress authority plus an active Pan recognizer that records load only; Pan does not mutate carousel progress.

Therefore a new instrumentation build is not yet justified: equal-duration `TREE HERO` / `TREE BACKDROP` on the same Build282 can answer a narrower question first.

## Evidence chain retained

### Build275 control

Same-package target-device control established normal finger-driven `CAROUSEL≈90` while fixed device-max `TREE FULL`, `TREE HERO`, `TREE BACKDROP`, corrected `CA`, `DISPLAYLINK`, and `SWIFTUI` could reach 120. This rejected a generic UIKit/SwiftUI/CALayer capability ceiling and made input/publication the next boundary.

### Build279

Target-device `CAROUSEL≈90 / CAROUSEL PAN≈90 / corrected TOUCH≈80`. Standard Pan/raw callback density can be high while final HUD remains below 120. Recognizer class/callback count alone is not sufficient. PR #283 closed unmerged.

### Build281

Target-device `CAROUSEL≈90 / CAROUSEL PAN≈90 / CAROUSEL PAN LATCH≈90`. Latest-real-input display-link latching changed publication cadence without improving final presentation. Frame alignment/latching alone is rejected. PR #284 closed unmerged.

### Build282 TREE PANLOAD

Build282 asks whether active Pan processing/load alone can lower an otherwise synthetic device-max full carousel tree. The corrected exact product source is `58801ef0acc6084c3168e8d7635a1258925cc382`; the preceding `9babebb...` source failed compile only because the new `UIViewRepresentable` omitted required `updateUIView`, and the final correction adds only that required no-op method.

Target-device result, 2026-09-01, recording off: **both `TREE FULL` and `TREE PANLOAD` initially reach 120 FPS but cannot sustain it and can decay to roughly 50 FPS.** Because the control tree itself decays, active Pan callback processing/load is not sufficient to explain the decay.

### Build282 sustained simple controls — 2026-09-01

User target-device result with recording off:

- `DISPLAYLINK`: **stable 120 FPS** for the sustained comparison duration.
- `SWIFTUI`: **stable 120 FPS** for the sustained comparison duration.

This is the required control gate from the previous checkpoint. The same device/package can sustain device-max `CADisplayLink → native CALayer` and `CADisplayLink → @Published → SwiftUI` motion while the real carousel TREE modes decay. Therefore do **not** attribute the TREE decay first to generic device thermal/power/high-refresh policy, main-thread display-link scheduling, Combine/`@Published`, or SwiftUI publication capability.

The supplied `OnePlayer-App-1788248167.log` contains Home settle/detail/network activity and logo request timeouts but no `HomeCarouselPipelineProbe` mode/cadence records, so it does not provide a competing pipeline measurement. The system FPS HUD observation remains controlling evidence for this round.

## Rejected / do not repeat without new evidence

- blur30 removal as the primary limiter;
- reducing foreground page residency/compositing count as the primary limiter;
- generic UIKit vs SwiftUI rewrite;
- generic ProMotion opt-in speculation;
- recognizer replacement by itself;
- callback-density maximization by itself;
- latest-real-input frame latch as a sufficient fix;
- Pan-load-only attribution;
- interpolation, prediction or synthetic intermediate render positions;
- timer/watchdog/retry/fallback smoothing;
- a second transition/progress owner.

No Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN code is in scope.

## Validation state

- Build282 code written: ✅
- Exact-source CI passed: ✅
- IPA produced + independently verified: ✅
- Target-device `TREE FULL` / `TREE PANLOAD` sustained-decay result: ✅
- Active-Pan-load-only hypothesis rejected: ✅
- Target-device sustained `DISPLAYLINK=120 / SWIFTUI=120`: ✅
- Generic sustained system/display-link/SwiftUI ceiling as primary cause: rejected ✅
- Sustained `TREE HERO` / `TREE BACKDROP` equal-duration split: pending ❌
- New runtime code justified at this exact checkpoint: ❌ — existing Build282 already contains the narrower discriminator
- Stable/frozen reopened performance task: ❌

## Next exact action

Use the **same installed Build282 / 0.15.15**, iPhone 15 Pro Max / iOS 17.0, screen recording off.

Run each for at least the same sustained duration that makes `TREE FULL` decay:

1. `PIPE TREE HERO`
2. `PIPE TREE BACKDROP`

Report the sustained HUD result, for example:

`TREE HERO 120→120 / TREE BACKDROP 120→50`

Interpretation:

- If **only HERO decays**, the next diagnostic may instrument/split Hero's clear artwork/mask versus foreground/compositing subpaths.
- If **only BACKDROP decays**, the next diagnostic may instrument/split the persistent backdrop blend/image/blur commit path, without reusing the already-rejected blur-off product behavior as a fix.
- If **both individually decay**, investigate common transition-scope invalidation/commit behavior before component-specific removal.
- If **both individually remain stable 120 while TREE FULL decays**, the evidence points to the combined simultaneous Hero+Backdrop invalidation/commit budget; the next build should measure that combined boundary rather than guess a visual patch.

Do not create Build284 before this same-package A/B unless new evidence makes these existing probes unusable.
