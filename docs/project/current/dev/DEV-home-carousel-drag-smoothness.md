# DEV-home-carousel-drag-smoothness

## Status

**Active — Build200 target-device rejected because foreground became fixed; Build201 restores horizontal foreground slide with short travel. CI/IPA verified; target-device test pending.**

- Work ID: `DEV-home-carousel-drag-smoothness`
- Routing aliases / keywords: 轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- Accepted overall baseline remains OnePlayer **0.14.32 / Build199** on `main`; this carousel line is independent and not stable.

## Retained contract

Build198 remains the input foundation:

`one UIKit interaction surface → one begin/move/end/cancel owner → one V3HomeCarouselTransitionState → SwiftUI render`

Do not change without new direct evidence:

- 0.5pt axis acquisition;
- vertical acquisition yields to Home `UIScrollView`;
- horizontal acquisition owns the gesture through end/cancel;
- actual touch drives rendering, predicted touch is release-only;
- commit threshold 0.28;
- predicted-distance release gate 0.48 × width;
- existing settle ownership/timings;
- no second SwiftUI drag/release owner;
- no interpolation/timer/watchdog/retry/debounce/throttle.

Player / MPV / PiP / Transport / Cache / Emby Session / STRM→302→115/CDN client-direct paths remain outside this task.

## Evidence before Build200

- Build185: first visible movement was roughly 10/12/16 px versus EX roughly 1/1/2 px.
- Build187: first useful horizontal samples roughly 4.33/8.00/15.67/11.00pt, maxFPS=120, Low Power Mode off.
- Build189 and Build193: split move/end ownership could freeze between pages; that hybrid architecture is rejected.
- Build198 / 0.14.31: CI/IPA passed; target device reported release/settle/reversal and other tested behavior okay, but minimum/subtle drag still “比较大” and less delicate than EX.
- Build198 durable base: `c769f2c4c05fffdb36e90d78d8baddec5e0e7c21`.

## Build200 — rejected fixed-foreground experiment

Build200 retained Build198 input ownership but set foreground offset to zero and used linear `1-progress / progress` crossfade.

- version/build: `0.14.33 / 200`
- source: `4d3afe36768b7749d9d0bd0081725f3d947b2099`
- CI run/job: `32991758526` / `98250719262` — success
- artifact: `OnePlayer-0.14.33-build200-home-carousel-ex-blend`
- artifact ID: `9614995121`
- IPA SHA-256: `509395ca7fb847548110c22ec0a3f6b005e6b3f4521f911eb9b3f765ca6d1b1a`
- target-device result on 2026-08-27: **rejected regression** — foreground content became fixed and no longer slid horizontally.

**Build200 = Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / rejected / not stable.**

Do not restore a fully fixed foreground as the default carousel behavior.

## Build201 — current candidate

Build201 restores horizontal foreground motion while reducing total visual travel:

- `travel = width * 0.15`;
- outgoing offset = `-direction * progress * travel`;
- incoming offset = `direction * (1-progress) * travel`;
- foreground opacity remains linear `1-progress / progress`;
- Build198 UIKit owner, thresholds, reversal, release, settle, Hero/Core ownership, vertical scrolling, tap and auto-advance are unchanged.

Identity/evidence:

- version/build: **OnePlayer 0.14.34 / Build201**
- branch: `perf/home-carousel-short-travel-build201`
- tested source: `e61070146d91bac45400e3f95e28eead756faa81`
- runtime delta from Build198: `Sources/Core/AppIdentity.swift` + `Sources/UI/EmbyHomeCarouselStateV3.swift`; no Frozen/P0 runtime path touched.
- initial one-shot `32992912212` stopped before compilation because the inherited check script still hard-coded Build198 version `0.14.31`; product code did not fail.
- contract script was minimally updated for Build201 version/15%-travel/blend contracts.
- successful run/job: **`32993286519` / `98255950676`**
- source contract/Frozen guard, Xcode 16.4, icons, dependencies, Release build, app validation, MinOS, packaging and upload: **all success**
- artifact: `OnePlayer-0.14.34-build201-home-carousel-short-travel`
- artifact ID: **`9615585817`**
- artifact digest: `sha256:95dcc70016c72c3dcab2a918331ebb5c5e3a9d1348a4ac3139fbc647c3dea231`
- IPA SHA-256: **`d889f2c36b3f617b429e4f39ba54d39d7f2826a058a2d4f874bc7a9bb574db58`**
- source ZIP SHA-256: **`5f0392a2e472ed1e863c265a05a695ba1788b02c163f0c21e3117b0be002ea6e`**
- independently verified: bundle `com.embyplayerlab.app`, version/build `0.14.34 / 201`, MinOS `15.0`, primary/alternate icons, IPA/source hashes.
- one-shot `main` helper deleted after artifact capture; cleanup commit `a041d883dc153cc3b9be57dc4a8f4160ab779c02` changes CI helper only.

**Build201 = Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending / not stable.**

## Next exact action

Target-device A/B Build201 against Build198/Build200/EX:

1. Foreground Logo/rating/year/type/overview must clearly slide horizontally again, not remain fixed as Build200 did.
2. Tiny initial drag should feel finer than Build198.
3. Slow micro-drag and repeated reversal must remain continuous.
4. Small release must fully cancel; committed drag/flick must fully complete.
5. Vertical Hero drag, detail tap and auto-advance must remain unchanged.
6. Compare portrait and landscape `drag / visual continuity / settle` with EX.

Do not change the 15% travel factor again until this target-device result establishes whether it is too large, too small or acceptable.
