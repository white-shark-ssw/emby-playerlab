# DEV-home-carousel-drag-smoothness

## Status

**Active — Build205 / 0.14.38 was target-device tested and its whole-range `progress²` visual mapping felt over-restrained at drag start and unnaturally accelerated through the tail. Build207 / 0.14.40 keeps the 80% total travel and single UIKit owner, but changes only the visual curve to a soft-start-only attenuation that converges to linear progress; CI/IPA independently verified, real-device pending.**

- Work ID: `DEV-home-carousel-drag-smoothness`
- Routing aliases / keywords: 轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- Accepted overall baseline remains OnePlayer **0.14.32 / Build199** on `main`.
- Target device: iPhone 15 Pro Max / iOS 17.0.
- Build206 is owned by the independent poster-scroll diagnostics task; carousel therefore uses Build207.

## Retained input contract

Build198 remains the input foundation:

`one UIKit interaction surface → one begin/move/end/cancel owner → one V3HomeCarouselTransitionState → SwiftUI render`

Do not change without new direct evidence:

- 0.5pt axis acquisition;
- vertical acquisition yields to Home `UIScrollView`;
- horizontal acquisition owns the gesture through end/cancel;
- actual touch drives raw `transitionProgress`; predicted touch is release-only;
- commit threshold 0.28;
- predicted-distance gate 0.48 × width;
- existing settle ownership/timings;
- no second SwiftUI drag/release owner;
- no interpolation/timer/watchdog/retry/debounce/throttle.

Player / MPV / PiP / Transport / Cache / Emby Session / STRM→302→115/CDN client-direct paths remain outside this task.

## Key real-device history

- Build185/187: first visible/useful horizontal motion remained much coarser than EX even with 120 Hz available.
- Build189/193: split native move / separate SwiftUI release ownership could freeze between pages; rejected architecture.
- Build198 / 0.14.31: single UIKit owner fixed lifecycle/settle/reversal behavior, but minimum/subtle drag still felt too coarse versus EX.
- Build200 / 0.14.33: fully fixed foreground passed CI/IPA but was rejected because foreground stopped sliding horizontally. Fully fixed foreground must not return.
- Build201 / 0.14.34: 15% horizontal travel restored directional slide; user reported **“有点那种感觉了”**, proving visual mapping can reduce perceived initial jump, but total travel was too short.
- Build203 / 0.14.36: 30% travel + `progress²` opacity, while spatial motion still used raw progress. Target device showed 30% remained too short and initial displacement became perceptible again. This narrowed the issue to raw-progress → spatial mapping rather than gesture ownership.

## Retired carousel Build204 identity collision

A carousel `0.14.37 / Build204` package with 80% + `progress²` spatial mapping completed CI, but the independent poster-scroll task already owned **0.14.37 / Build204**. Carousel Build204 is retired and must not be distributed or used for attribution. Canonical Build204 ownership remains poster-scroll.

## Build205 — target-device result

Build205 / OnePlayer 0.14.38:

- branch: `perf/home-carousel-eased-travel-build205`
- tested source: `e5f2e7b4135eca333d5dda24545f19ee8d0be439`
- durable cleanup head: `70d6cca676911e656591aae6b342c771cc92b9fe`
- run/job: `32998533448` / `98273968966` — success
- artifact ID: `9617634710`
- IPA SHA-256: `fe4a81ebee9d330526c108edf2ab4652632ae5b204719864e0b5dee486086479`
- total foreground travel: `0.80 × Hero width`;
- foreground/backdrop opacity and spatial offset used the same clamped `progress²` visual progress;
- raw gesture progress remained the release/commit authority.

Latest target-device result on 2026-08-27:

- the start is **too restrained**; user requested relaxing the start slightly;
- the whole-range curve feels like an easing effect through both beginning and tail and **“目前这样感觉怪怪的”**;
- user requested that start/tail not feel like a conventional ease-in/ease-out style motion.

Interpretation: keep the 80% total travel and single UIKit owner, but stop applying `progress²` over the entire transition. The next mapping should attenuate only the earliest part and then converge to raw linear progress so the tail is not artificially accelerated or slowed.

**Build205 = Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / visual curve rejected as final / not stable.**

## Build207 — current candidate

Identity/evidence:

- OnePlayer **0.14.40 / Build207**
- branch: `perf/home-carousel-soft-start-linear-tail-build207`
- base: Build205 durable cleanup head `70d6cca676911e656591aae6b342c771cc92b9fe`
- tested source: **`06936503a6c382d1d39d3cdd52f23bfe2058901e`**
- durable cleanup head: **`7044ca68c7082cd055a7e4ce42dda6f00fe29674`**
- tested-source → cleanup-head delta: temporary Build207 workflow deletion only; product/runtime source unchanged.

Runtime delta from Build205 is deliberately limited to `Sources/Core/AppIdentity.swift` and `Sources/UI/EmbyHomeCarouselStateV3.swift`:

- total foreground travel remains **`0.80 × Hero width`**;
- old whole-range `progress²` mapping is removed;
- new clamped visual progress is:
  `progress * (1 - 0.60 * (1 - progress)^6)`;
- implementation uses multiplication only, no timer/interpolator/new state owner;
- start slope is approximately **0.40** instead of Build205's 0, so initial motion is less restrained;
- around raw progress 0.05, visual progress is ~0.028; around 0.10 it is ~0.068;
- the attenuation rapidly decays, mid/late drag converges closely to raw progress;
- endpoint remains exactly 1.0 and tail derivative tends to **1.0**, avoiding Build205's continued whole-range acceleration;
- foreground/backdrop opacity and foreground spatial offset use the same visual progress;
- raw `transitionProgress`, 0.28 commit, 0.48×width predicted-distance release gate, direction/reversal/settle ownership are unchanged;
- left/right and first↔last wrapping still use existing direction sign + modulo neighbor lookup.

Scoped source/Frozen guard passed. CI run/job **`33000526138` / `98280846494` — success**. Release build, app identity, MinOS, IPA/source packaging and upload all passed.

Artifact evidence:

- artifact: `OnePlayer-0.14.40-build207-home-carousel-soft-start-linear-tail`
- artifact ID: **`9618484884`**
- artifact digest / independently downloaded ZIP SHA-256: **`c6a60537969f4d49f90f2ae47b033094640233f1085db6f5b1e75d18a86b62e4`**
- IPA SHA-256: **`bbd7c9c22c2a79a89f41e0d94db16023cf7cd2a720ffeb3c4f31cb9066a15a21`**
- source ZIP SHA-256: **`ecb6f4dbfb0609194406dbb5e0efc3ecde8907ed22992ee7aa4dcf6a886bc275`**
- independent artifact/IPA `unzip -t`: PASS;
- independent Info.plist: bundle `com.embyplayerlab.app`, OnePlayer, `0.14.40 (207)`, MinOS `15.0`, primary `OnePlayerIcon`, alternate `OnePlayerAltIcon`;
- independent source snapshot check confirms 80% travel + new soft-start curve and confirms old `return progress * progress` is absent.

**Build207 = Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device pending / not stable.**

## Next exact action

Target-device A/B Build207 against Build205 and EX:

1. First few millimeters: start should move earlier/more freely than Build205, but remain calmer than raw-linear Build203.
2. Mid drag: should converge naturally without a noticeable catch-up event.
3. Tail: should feel essentially linear, without the Build205 whole-range acceleration sensation.
4. Verify left/right, first→last, last→first, reversal, cancel/commit, vertical Hero scroll, detail tap and auto-advance.
5. Do not alter UIKit ownership or raw release thresholds unless new real-device evidence directly requires it.
