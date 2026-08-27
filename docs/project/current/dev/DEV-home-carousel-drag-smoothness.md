# DEV-home-carousel-drag-smoothness

## Status

**Active — Build217 / 0.14.50 cadence-diagnostic IPA is CI/IPA verified and awaiting target-device logging. Build215 remains the latest real-device carousel behavior evidence: acquisition-relative start and opaque foreground fixed the coarse start/ghosting, but the overall drag still trails EX in micro-smoothness. Build217 deliberately does not retune motion; it measures delivered/coalesced touch cadence, progress publication, SwiftUI render-probe updates, passive display-frame gaps and nearest Hero/persistent/preload 1400px image callbacks so the residual “smooth glass vs rough paper” gap can be attributed from real-device timing evidence.**

- Work ID: `DEV-home-carousel-drag-smoothness`
- Routing aliases / keywords: 轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- Accepted overall baseline is OnePlayer **0.14.49 / Build216** on `main`; Build217 is an independent diagnostic candidate and does not replace it.
- Target device: iPhone 15 Pro Max / iOS 17.0.
- Build206/209/210/212 belong to the independent poster-scroll diagnostics task. Build212 established a Home-specific 1400px carousel image-presentation correlation; poster Build218 is a separate grid/display candidate and does not modify carousel owner files.

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
- Current valid carousel behavior identity: **OnePlayer 0.14.48 / Build215**.
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
- evidence: **Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / partial success / not stable.**

## 2026-08-27 Build215 second real-device result

Latest target-device feedback after testing the acquisition-relative candidate:

- **initial drag is now very fine and feels close to EX**;
- **foreground no longer has the previous blurred / ghosted feel**;
- despite those two fixes, the overall drag still does **not** have EX's refined tactile smoothness;
- the user's best qualitative description is: **EX feels like sliding on smooth glass, while OnePlayer still feels like sliding on rough paper**.

The new 510×1108@30fps recording does not show the old large hold-then-jump foreground failure or a clear stop-one-frame / catch-up-next-frame macro hitch. Early foreground increments are now small and continuous. Therefore Build215 positively validates acquisition-relative render baseline and foreground-alpha decoupling, but it does **not** prove the complete carousel interaction solved.

30fps capture cannot fully resolve the 120Hz device's sub-frame / frame-to-frame tactile cadence. A measured difference in backdrop crossfade timing versus EX exists, but this is currently **only a candidate explanation** for the remaining glass-vs-paper feel. Do not change the backdrop curve merely to complete a patch, and do not add smoothing/interpolation/timers.

Retain from Build215 unless contrary device evidence appears:

- one UIKit interaction owner;
- acquisition-relative foreground X (`currentTranslation - acquisitionTranslation`);
- touch-down authority for 0.28 / 0.48 release semantics;
- foreground opacity held at 1 during interactive transition;
- full-width `pageStep = width` page slots;
- existing reversal/cancel/settle/wrap contracts.

## Build217 / 0.14.50 cadence diagnostic evidence

Build217 is a diagnostic-only successor to Build215. It preserves the retained carousel behavior and adds observation only:

- branch: `diag/home-carousel-cadence-build217`;
- tested product source: **`088dcfb0f112d4f2a66371bb98272b5af9f49283`**;
- durable cleanup head: **`ab65b795b8e99d2eeb61cbfc8740bc18c82c49a4`**; cleanup removed only temporary workflow/patch/trigger helpers after the successful package;
- run/job: **`33069670314 / 98508381540` — success**;
- artifact: `OnePlayer-0.14.50-build217-home-carousel-cadence`; ID **`9645320748`**;
- GitHub artifact digest / independently recalculated artifact ZIP SHA-256: **`6948f8b7796b01d0dbc31c2555fcc5b78687e1e9a161341ceeb3cab1d676409d`**;
- IPA SHA-256: **`a2cf700b791cc66a60416b0250d501758aec532371dd029272066eaac4722bef`**;
- source ZIP SHA-256: **`675b04524e9d56b9fc91c99e3ec6419a989493b74f6f633d4e814221bf86668e`**;
- independent IPA/archive/hash/identity verification passed: `com.embyplayerlab.app`, OnePlayer **0.14.50 (217)**, `MinimumOSVersion=15.0`;
- exact Build215→217 runtime scope is `AppIdentity`, new `EmbyHomeCarouselCadenceDiagnosticsV3`, small observation hooks in `EmbyHomeCarouselInteractionV3` and `EmbyHomeHeroV3`; `EmbyHomeCarouselStateV3`, `EmbyHomeCoreV3`, shared image infrastructure and all P0/Frozen paths are unchanged;
- cadence display link is passive and does not request a preferred frame rate; coalesced touches are measured only and never drive movement;
- one aggregated `HomeCarouselCadence` App-log summary is emitted per horizontal drag; no per-frame logging, interpolation, timer, debounce, throttle, watchdog, retry or fallback was added.

Evidence: **Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device pending / diagnostic conclusion pending / not stable.**

## Next exact action

Install Build217 on iPhone 15 Pro Max / iOS 17.0, keep App logging enabled, and perform several ordinary left/right drags including slow micro-drags and direction reversals. Then export the App log. Attribute the residual gap from `HomeCarouselCadence` touch/progress/SwiftUI/display/image timing before changing any motion mapping. Do not retune travel/easing/backdrop timing or add smoothing until the target-device log supplies evidence.
