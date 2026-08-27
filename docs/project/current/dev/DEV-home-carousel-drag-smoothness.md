# DEV-home-carousel-drag-smoothness

## Status

**Active — Build221 / 0.14.54 is the current CI/IPA-verified carousel diagnostic A/B; target-device testing is pending. Build219 proved the drag-local maximum-refresh request works and raised the delivered-touch → progress → SwiftUI-render → display chain to roughly 98–110 Hz. Its remaining strongest repeated hitch pattern is a 50 ms display gap about 19.6–25.3 ms after a persistent 1400px callback. Build221 keeps all Build215/219 motion and 120 Hz contracts, but during active drag holds the current blurred persistent backdrop at opacity 1 and does not mount the transition-target persistent image; Hero transition remains unchanged.**

- Work ID: `DEV-home-carousel-drag-smoothness`
- Routing aliases / keywords: 轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- Accepted overall baseline is OnePlayer **0.14.49 / Build216** on `main`; Build217 is an independent diagnostic result and does not replace it.
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
- Build208: changed to full-width page-slot spacing and became the real-device reference for motion analysis.
- Build215: acquisition-relative foreground X + opaque foreground fixed the coarse start and ghosting, but overall tactile refinement still trailed EX.
- Build217: target-device cadence log shows the residual issue is upstream timing/granularity, not another travel/easing problem.

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
- acquisition-relative foreground X;
- opaque interactive foreground;
- current release/commit/settle contracts.

Reject as the primary solution:

- more 15%/30%/80% travel tuning;
- another whole-range easing formula;
- re-coupling foreground opacity to backdrop blend;
- changing backdrop timing based only on subjective feel;
- speculative smoothing/interpolation/timers.

## Build214 / Build215 implementation evidence

- Carousel Build214 / 0.14.47 was rebuilt cleanly from the Build208 durable source and passed CI/IPA verification, but was retired before distribution when independent poster work claimed that identity. Never use the carousel Build214 package for attribution.
- Current valid carousel behavior identity before diagnostics: **OnePlayer 0.14.48 / Build215**.
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

30fps capture cannot fully resolve the 120Hz device's sub-frame / frame-to-frame tactile cadence. A measured difference in backdrop crossfade timing versus EX exists, but this is currently **only a candidate explanation** and is now lower priority than the Build217 cadence evidence.

## Build217 / 0.14.50 cadence diagnostic evidence

Build217 is a diagnostic-only successor to Build215. It preserves the retained carousel behavior and adds observation only:

- branch: `diag/home-carousel-cadence-build217`;
- tested product source: **`088dcfb0f112d4f2a66371bb98272b5af9f49283`**;
- durable cleanup head: **`ab65b795b8e99d2eeb61cbfc8740bc18c82c49a4`**; cleanup removed only temporary workflow/patch/trigger helpers after the successful package;
- run/job: **`33069670314 / 98508381540` — success**;
- artifact: `OnePlayer-0.14.50-build217-home-carousel-cadence`; ID **`9645320748`**;
- artifact ZIP SHA-256: **`6948f8b7796b01d0dbc31c2555fcc5b78687e1e9a161341ceeb3cab1d676409d`**;
- IPA SHA-256: **`a2cf700b791cc66a60416b0250d501758aec532371dd029272066eaac4722bef`**;
- source ZIP SHA-256: **`675b04524e9d56b9fc91c99e3ec6419a989493b74f6f633d4e814221bf86668e`**;
- independently verified `com.embyplayerlab.app`, OnePlayer **0.14.50 (217)**, `MinimumOSVersion=15.0`, archive/hash integrity and built `CADisableMinimumFrameDurationOnPhone=true`;
- exact Build215→217 runtime scope is `AppIdentity`, new `EmbyHomeCarouselCadenceDiagnosticsV3`, small observation hooks in `EmbyHomeCarouselInteractionV3` and `EmbyHomeHeroV3`; `EmbyHomeCarouselStateV3`, `EmbyHomeCoreV3`, shared image infrastructure and all P0/Frozen paths are unchanged;
- cadence display link is passive and does not request a preferred frame rate; coalesced touches are measured only and never drive movement.

### 2026-08-27 target-device App-log result

User exported `OnePlayer-App-1787833843.log` after Build217 horizontal-drag testing. The log contains **13 horizontal drag summaries** totaling ~28.0 s.

Strongest measured result:

- `maximum_fps=120` on every drag;
- normal moving drags deliver the main `UITouch` callback at about **16.5–19 ms**, with ~**17.3 ms** average across the non-paused samples — roughly 60 Hz rather than 120 Hz;
- the same `UIEvent` exposes far denser coalesced touch data, usually about **4.17–5.7 ms** between samples; across the full log there are **5021 coalesced samples vs 1486 delivered samples**;
- `transitionProgress` publication follows delivered-touch cadence almost one-for-one: **1421 distinct publish changes**;
- the SwiftUI render probe follows those publications almost one-for-one: **1415 render changes**, so only 6 distinct publications fail to produce a distinct probe update;
- normal publish/render gaps are again around **17–18 ms**; `publish_to_render_max_ms` remains below ~13 ms in every drag, which rejects a large SwiftUI backlog/coalescing loss as the primary explanation;
- across **1603** passive display-link intervals, **all 1603 are >=12.5 ms**. Moving-path p95 is typically **16.67 ms**, with no observed 8.33 ms cadence despite the device reporting 120 Hz capability;
- some long pauses intentionally let ProMotion downshift further, so 30–40 ms display gaps in those stationary periods are not treated as pure jank evidence.

Interpretation: the most consistent current bottleneck is **upstream input/publication granularity**. The hardware/UIEvent stream contains high-fidelity samples, but the carousel owner renders only the main delivered touch, so new foreground positions are usually published at ~60 Hz. SwiftUI then reflects nearly all of those publications. This matches the user's “rough paper” description better than another easing or backdrop curve.

Secondary evidence remains:

- occasional **33–45 ms** display gaps exist;
- in roughly half of the worst-gap samples, the most recent `persistent` 1400px callback is only ~10–13 ms old, consistent with Build212's image-presentation correlation;
- other worst gaps reference image callbacks hundreds or thousands of milliseconds old, so the correlation is not universal;
- therefore large-image presentation is a plausible **secondary episodic hitch source**, but it does not explain the persistent baseline texture by itself.

Build217 evidence: **Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device diagnostic tested ✅ / ~60 Hz baseline established / not stable.**

## Build219 / 0.14.52 120 Hz request target-device result

Build219 preserves Build215/217 motion, ownership, page-slot, foreground-alpha, release and backdrop contracts. Its only runtime experiment beyond identity is the existing drag-local diagnostic `CADisplayLink` requesting the device maximum frame-rate range when `maximumFramesPerSecond > 60`; coalesced and predicted touches still do not drive interactive movement.

- tested source: `0b894bc37fcd0086aeaf9e1a29de0e85f5b0ee94`;
- durable cleanup head: `a5050075ccceaf46196696bfa3b812293800f340`;
- run/job: `33080240879 / 98545151906` — success;
- artifact ID `9649815558`; artifact SHA-256 `f4303434b3ed1215f122093a02ddc774492c4406b6916876b2e777858a69ca49`;
- IPA SHA-256 `a0b7bad3c563f76e3e560f55da6eec67697a8bf609b70b5a672ee1a0ed1ab85`; source ZIP SHA-256 `85815c74acf37840375e245d15752a40184bf72f3aa76aebbb2091e8b5ec2ec1`;
- independently verified OnePlayer `0.14.52 (219)`, bundle `com.embyplayerlab.app`, MinOS 15.0 and `CADisableMinimumFrameDurationOnPhone=true`.

Target-device log `OnePlayer-App-1787841410.log` contains 11 horizontal drags totaling ~10.76 s. Every record reports `maximum_fps=120 requested_fps=120`.

Compared with Build217's 13-drag diagnostic capture:

- delivered touch throughput rose from ~53.0 Hz to ~102.6 Hz;
- distinct progress publication rose from ~50.7 Hz to ~99.4 Hz;
- SwiftUI render-probe throughput rose from ~50.5 Hz to ~98.2 Hz;
- display-link throughput rose from ~57.2 Hz to ~109.8 Hz;
- coalesced-touch throughput remained broadly similar (~179 → ~187 Hz), as expected because Build219 does not change raw touch sampling;
- Build217 had 1603/1603 display intervals >=12.5 ms; Build219 has 41/1181 (~3.5%), and ordinary moving-drag p95 is now usually 8.34 ms.

The user also supplied a 510×1108@30fps recording with an on-screen FPS meter. It visibly reaches 118–120 FPS repeatedly during drag, while also showing intermittent drops into roughly 60–97 FPS. This independently agrees with the diagnostic log: the high-refresh request works, but runtime cadence is not perfectly stable under all presentation load.

Remaining episodic hitch evidence is now stronger: Build219 still recorded 13 display gaps >=30 ms. Among the 15 recorded worst-gap samples >=25 ms, 11 occurred within 30 ms of the latest Hero/persistent image callback. Multiple drags show a 50 ms gap ~19–25 ms after a persistent 1400px callback; Hero callbacks also precede some ~27–39 ms gaps by ~11 ms. A few large gaps have stale image ages, so image publication is not a universal explanation, but it is now the strongest source-correlated lead for the remaining discrete knocks after the baseline cadence improved.

**Build219 evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device diagnostic tested ✅ / 120 Hz request effectiveness proven ✅ / residual image-presentation hitch lead strengthened / stable ❌.**

## Build221 / 0.14.54 persistent-drag isolation candidate

Source inspection after Build219 established that the transition target is first mounted on the first non-zero post-acquisition render sample. Both target Hero and target persistent use their own `EmbyCachedRemoteImage` instances. With preload/render-pool hits, each loader synchronously adopts the already-decoded 1400px `UIImage`, but the target persistent path then presents it as a full-screen layer with `scaleEffect(1.12)` and `blur(radius: 30)`. Build212 already measured the synchronous callback/contrast work at only ~1–3 ms, so the repeatable later 50 ms gap is more consistent with subsequent presentation/compositing than decode or contrast itself.

Build221 makes one diagnostic presentation isolation only:

- branch `diag/home-carousel-persistent-drag-isolation-build221`;
- tested source `26fc82771b6778af14974fdac293ece0685fc76d`; durable cleanup head `1d6df7f2490a5ef5968cafb229a46cba93c622db` (temporary CI workflow/trigger deletion only);
- during `isCarouselDragging`, current persistent stays opacity 1 and transition-target persistent is not mounted;
- on release, the existing persistent transition path resumes; Hero target/crossfade is unchanged;
- Build219 exact device-max refresh request remains unchanged; coalesced/predicted touches still do not drive interactive render;
- Interaction, State, Core, shared image infrastructure and P0/Frozen paths are unchanged;
- run/job `33090175887 / 98580579889` — success;
- artifact ID `9654120029`; artifact SHA-256 `f2d18a723ae769c9ad4a3f396919567afe2a07affe8d47610777d6dd5f7029d4`;
- IPA SHA-256 `d2ee4fb2d40c251399951bc72ba6ad35fbe8ba3bfd72b861274b9b2c38fe0d9c`; source ZIP SHA-256 `aa6b700ab2aec163893c78316f80a09ab8d711797f01380ee3ed3d1e72576e97`;
- OnePlayer `0.14.54 (221)`, bundle, MinOS 15.0, ProMotion key and source contracts independently verified.

**Build221 evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending ❌ / diagnostic only / stable ❌.**

## Next exact action

Install Build221 on the target device, repeat the same horizontal-drag cadence test with the on-screen FPS meter if convenient, and export App logs. The decisive comparison is whether active-drag `persistent` callbacks and their repeatable 50 ms gaps disappear while Hero callbacks remain. Also note whether the drag itself improves but release/settle gains a new hitch, because Build221 intentionally resumes the existing persistent transition after touch release. Do not promote persistent suppression to a final design until this A/B is measured.
