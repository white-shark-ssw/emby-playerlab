# DEV-home-carousel-drag-smoothness

## Status

**Active — Build215 / 0.14.48 is the current carousel candidate. Build208 real-device video analysis proved the remaining EX gap was acquisition-origin + foreground-alpha behavior; Build215 implements acquisition-relative 1:1 render motion while preserving touch-down release authority, keeps full-width page slots, and decouples foreground alpha. CI/IPA are verified; real-device A/B is pending.**

- Work ID: `DEV-home-carousel-drag-smoothness`
- Routing aliases / keywords: 轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- Accepted overall baseline remains OnePlayer **0.14.32 / Build199** on `main`.
- Target device: iPhone 15 Pro Max / iOS 17.0.
- Build206/209/210 belong to the independent poster-scroll diagnostics task. That task currently has a Home-specific image-metric lead inside carousel files, but it must not modify carousel state/Hero/Core without reconciling this task.

## Retained input contract

Build198 remains the input foundation:

`one UIKit interaction surface → one begin/move/end/cancel owner → one V3HomeCarouselTransitionState → SwiftUI render`

Retain unless new direct device evidence proves otherwise:

- vertical acquisition yields to Home `UIScrollView`;
- horizontal acquisition owns the gesture through end/cancel;
- predicted touch is release-only;
- commit threshold 0.28;
- predicted-distance gate 0.48 × width;
- existing settle/reversal ownership;
- no second SwiftUI drag/release owner;
- no timer/watchdog/retry/debounce/throttle/interpolator.

Player / MPV / PiP / Transport / Cache / Emby Session / STRM→302→115/CDN client-direct paths remain outside this task.

## Retained real-device history

- Build185/187: first useful horizontal samples were already coarse even with 120 Hz available.
- Build189/193: split native-move / SwiftUI-release ownership could freeze between pages; rejected.
- Build198: single UIKit owner fixed lifecycle/settle/reversal, but subtle movement remained too coarse versus EX.
- Build200: fixed foreground rejected because horizontal slide disappeared.
- Build201: 15% travel got partially positive “有点那种感觉了” feedback but was too short overall.
- Build203: 30% still too short and exposed initial displacement again.
- Build205: 80% + whole-range `progress²` rejected because start was over-restrained and tail easing felt unnatural.
- Build207: screenshots proved `0.80 × width` spacing between full-width foreground pages structurally overlapped adjacent content.
- Build208: changed to full-width page-slot spacing and is the current real-device reference for motion analysis.

## Build208 identity / evidence

- OnePlayer **0.14.41 / Build208**
- branch: `perf/home-carousel-page-slots-build208`
- tested source: `2ad089f0ea8b4b6827257bb3a91a67c2d3748e5f`
- durable cleanup head: `51c366b6840d77c818eae20e1f3f43c0dbd75c72`
- run/job: `33004390654` / `98294100402` — success
- artifact ID: `9620046266`
- IPA SHA-256: `24f47ac5cd5685f6eea85b1c3a4fad2841d81f6169a90cd0629bea85a2072308`
- source ZIP SHA-256: `807d03947c0d087ddc54f295e63fdabc37ac0ddfbe0e0f03da4477eb750e95ee`
- MinOS 15.0 independently verified.

Build208 foreground geometry:

- `pageStep = width`;
- outgoing/incoming foreground page centers remain exactly one Hero width apart at every progress value;
- existing page content width remains `width - 56`, so page-slot geometry preserves ~56pt content separation;
- page-slot correction is retained; do not return to arbitrary 15%/30%/80% center spacing.

Build208 visual mapping still uses:

`progress * (1 - 0.85 * (1-progress)^6)`

for foreground spatial motion and foreground/backdrop blend.

**Build208 = Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / still not EX-level smooth / not stable.**

## 2026-08-27 Build208 vs EX recording analysis

User supplied two direct screen recordings: first OnePlayer Build208, second EX. Both recordings are **510 × 1108 at 30 fps**, so the visible difference is not caused by one recording having a higher capture frame rate.

Frame-by-frame tracking used the visible touch indicator plus the outgoing `今晚正好` foreground title as the horizontal reference.

### 1. OnePlayer still has a hold-then-jump start

In the OnePlayer recording:

- touch indicator remains near its initial X, then the first large recorded touch movement is about **17–20 recording px**;
- foreground title remains stationary through that onset;
- its first visible horizontal update is about **6 px in one recorded frame**.

In EX:

- the first visible title movement is about **1 px**;
- the following early steps are approximately **2 px, 4 px, 2 px, 1 px...** rather than one larger burst.

Because 510 recorded px correspond to the 430pt screen width, 6 recorded px is roughly 5pt of visible motion. This matches the user's perception that OnePlayer's first displacement is still too long.

### 2. EX is almost linear after a short acquisition take-up; OnePlayer keeps easing too long

Using paired touch/title positions in the mid drag range (recorded finger displacement 30–120 px):

- EX fit: `title displacement ≈ 0.997 × finger displacement - 12.96 px`, RMSE ~**0.65 px**;
- OnePlayer fit: `title displacement ≈ 0.975 × finger displacement - 21.28 px`, RMSE ~**2.11 px**.

In the earlier 14–60 px range:

- EX slope is already ~**0.997**;
- OnePlayer slope is only ~**0.728**.

Interpretation: EX behaves much more like **a short acquisition/take-up distance followed by nearly 1:1 linear tracking**. OnePlayer's sixth-power visual attenuation continues suppressing motion over a much longer portion of the drag, so the page lags behind the finger and later has to catch up. That nonlinear lag is visible as less direct / less delicate motion.

The EX linear-fit intercept (~13 recording px) corresponds to roughly **11pt** on this screen. This is evidence for a short acquisition-relative baseline, not for another whole-range easing curve.

### 3. Source explains why the first jump survives every visual curve

`V3HomeCarouselInteractionRecognizer` currently stores `origin` in `touchesBegan`. When horizontal axis acquisition occurs, it immediately calls:

`onHorizontalChanged?(translation)`

where `translation` is still measured from the original touch-down point.

Therefore if the first delivered useful horizontal touch sample is already several points away — exactly what Build187 previously measured — the first render receives that **already accumulated touch-down translation**. Builds 201/203/205/207/208 have been trying to hide this with travel scaling/easing, but that necessarily distorts the rest of the drag.

This is now the strongest source + device explanation for the remaining initial jump.

### 4. Foreground opacity behavior also differs materially from EX

Tracking the outgoing foreground title brightness while it moves:

Approximate brightness ratio at 20 / 40 / 60 / 80 / 100 recorded px of title displacement:

- OnePlayer: **0.948 / 0.922 / 0.914 / 0.898 / 0.872**
- EX: **0.976 / 0.959 / 0.976 / 0.971 / 0.956**

Compression/backdrop content can affect the exact numbers, but the trend is clear: EX keeps the moving foreground title nearly opaque over this range, while OnePlayer progressively fades it because foreground opacity is tied to the same visual progress used for motion/backdrop blending.

This makes OnePlayer look softer/ghosted during drag and weakens the stable visual anchor. EX appears closer to **spatial page movement + viewport/edge presentation**, while backdrop blending is a separate effect.

## Current architectural conclusion

Retain:

- one UIKit gesture owner;
- full-width page slots (`pageStep = width`);
- first↔last modulo neighbor ownership;
- current release/commit/settle contracts.

Reject as the primary solution:

- more 15%/30%/80% travel tuning;
- another whole-range easing formula to hide the first sample;
- coupling foreground opacity to the same progress curve used to compensate spatial input.

The next evidence-backed direction is:

1. keep the original touch-down translation available for release/commit/predicted-distance semantics;
2. when horizontal ownership is acquired, establish a **render/acquisition baseline** so interactive page X starts near zero from that point rather than applying the already accumulated touch-down translation;
3. after acquisition, use essentially **1:1 linear spatial tracking** instead of a long visual easing curve;
4. decouple foreground alpha from backdrop blend; test foreground as stable/near-opaque spatial page content while backdrop crossfade remains independently controlled;
5. do not change UIKit ownership or P0/Frozen modules.

## Build214 / Build215 implementation evidence

- Carousel Build214 / 0.14.47 was rebuilt cleanly from the Build208 durable source and passed CI/IPA verification, but was retired before distribution when independent poster work claimed that identity. Never use the carousel Build214 package for attribution.
- Current valid carousel identity: **OnePlayer 0.14.48 / Build215**.
- branch `perf/home-carousel-acquisition-relative-build215`.
- tested source / CI head **`d22634ece2f29eba2e60de01182bf15d4ba554a7`**; durable cleanup head **`01a13615fc056fd3b13296d98abfaa7a6aa2b46d`**, with temporary workflow deletion only between them.
- horizontal acquisition establishes the render baseline and does not publish the already accumulated touch-down distance.
- post-acquisition render is exactly `currentTranslation - acquisitionTranslation`; no whole-range easing/interpolator.
- release remains touch-down authoritative with the existing 0.28 commit and 0.48×width predicted-distance gate, including one-sample fast release.
- foreground transition pages stay opaque; backdrop crossfade remains independent; full-width `pageStep = width` and first↔last modulo ownership remain unchanged.
- no new state owner/timer/watchdog/retry/debounce/throttle and no P0/Frozen path change.
- run/job **`33058337107 / 98470624555` — success**; artifact ID **`9640692378`**; digest **`sha256:31a054244bcfbeb39cc5db663aa7580cb4cc742fe88ca998ce9c9ba7a01e2939`**.
- IPA SHA-256 **`6551a5e9e8a28a66bd4f105118387e8fc9378b72bd47778897f013b411c06c97`**; source ZIP SHA-256 **`00d2a0aba071dbbce3554d31dba64f0caa70c22b6e067dedeee0bb3b22ebd694`**.
- independent verification passed for artifact digest, embedded hashes, IPA archive, OnePlayer `0.14.48 (215)`, MinOS 15.0, icons and exact source contracts.
- evidence: **Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending / not stable.**

## Next exact action

Target-device A/B Build215 against the recorded Build208 and EX reference. Focus on first visible movement, post-acquisition 1:1 feel, foreground solidity, page separation, reversal through the acquisition baseline, cancel/commit including one-sample fast release, and first↔last wrapping. Do not retune easing/travel percentages before this device evidence.
