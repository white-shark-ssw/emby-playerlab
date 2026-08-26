# OnePlayer Project State

_Last updated after Home-carousel Build205 target-device testing rejected whole-range `progress²` as the final visual curve and Build207 / 0.14.40 completed CI/IPA with a soft-start / linear-tail visual mapping. Build199 remains the latest real-device accepted overall baseline. Home-carousel Build207 is Active and real-device pending. Poster-scroll remains an independent Active line; canonical Build204 belongs to poster-scroll and Build206 is reserved by its diagnostics work._

## Current accepted overall baseline

- Product: **OnePlayer 0.14.32 / Build199**
- Canonical branch: `main`
- Final merge PR: **#256**
- Final merge commit: `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`
- Accepted product / dedicated CI source: `2b5f3bef073754371443c6c7a345657dbfa2a09a`
- Dedicated standard MPV CI run: `32942618979` — success
- Artifact ID: `9597143667`
- IPA SHA-256: `8f0f43f62705e5e13ae666cc54d32fd047c596df1d0e9335668b01a25b6eb003`
- Deployment Target / built MinOS: **iOS 15.0**
- Target device: **iPhone 15 Pro Max / iOS 17.0**
- Evidence: **Code written / CI passed / IPA produced / real-device accepted / stable for accepted Add/Edit Emby requirements / merged to main**

Build199 inherits all accepted/frozen player, PiP, transport, cache, episode-ordering, detail-presentation and episode-selection contracts.

## Frozen / protected contracts

- MPV remains the main playback engine; MDK is manual/experimental backup.
- Left double-tap immediately rewinds; right double-tap immediately fast-forwards; rapid repeated double-tap must not wait for debounce accumulation.
- MPV fast Seek remains one native `absolute+keyframes` Seek; no hidden exact correction loop.
- Real player byte demand / HTTP Range demand is authoritative. Never restore `targetTime / duration × fileSize` as a Seek/Transport anchor.
- Media path remains `Emby / STRM → HTTP 302 → 115/CDN → iPhone`; NAS must never relay media bytes.
- Range/206, session cache, Emby Resume/progress, abnormal-short-media/premature-EOF tolerance and diagnostics remain protected.
- PiP remains frozen at Build173 architecture.
- Player/Transport/Cache/Emby Session core lifetime must not depend on SwiftUI View lifecycle.
- Native iOS push/pop and interactive pop remain system-owned.
- Deployment Target should remain iOS 15.0 and must not exceed iOS 17.0.

## Accepted product foundations

- **Build176**: source-owned episode-session replacement + trusted natural-end auto-next; merged PR #253.
- **Build178**: Emby `/Shows/{SeriesId}/Episodes` is canonical series order; merged PR #254.
- **Build182**: detail high-frequency scroll isolation + presentation-only persistent cache; real-device accepted/frozen.
- **Build184**: detail visual hierarchy; merged PR #255.
- **Build191**: select-only detail episode browsing/navigation; merged PR #257.
- **Build195**: SeasonId-first player grouping + lazy very-large episode row; merged PR #258.
- **Build199**: Add/Edit Emby modern editor, same-server route selection, cached-first auto-start, local retained password and optional synchronizable Keychain password for iCloud; merged PR #256.

## Active: Home carousel interaction

Work: `DEV-home-carousel-drag-smoothness`.

### Retained architecture

Build198 remains the input foundation:

`one UIKit interaction surface → one begin/move/end/cancel owner → one V3HomeCarouselTransitionState → SwiftUI render`

Retained values/ownership:

- 0.5pt axis acquisition;
- vertical acquisition yields to Home `UIScrollView`;
- horizontal acquisition owns the gesture through end/cancel;
- actual touch drives raw `transitionProgress`; predicted touch is release-only;
- commit threshold 0.28;
- predicted-distance release gate 0.48 × width;
- existing settle ownership/timing;
- no second SwiftUI drag/release owner;
- no interpolation/timer/watchdog/retry/debounce/throttle.

### Real-device history controlling the current direction

- Build198: lifecycle/settle/reversal became acceptable, but minimum/subtle movement remained too coarse versus EX.
- Build200: fully fixed foreground + crossfade passed CI/IPA but was rejected because foreground no longer slid horizontally. Fully fixed foreground is rejected.
- Build201 / 0.14.34: restored horizontal motion with `0.15 × Hero width`; target-device feedback was partially positive — **“有点那种感觉了”** — proving smaller visual mapping can reduce the perceived initial jump, but 15% total travel was too short.
- Build203 / 0.14.36: increased travel to `0.30 × Hero width` and used `progress²` opacity while spatial offset still used raw linear progress. Target-device feedback showed 30% still too short overall and the larger raw-linear mapping exposed the coarse first visible displacement/jitter again.
- Build205 / 0.14.38: raised total travel to `0.80 × Hero width` and applied whole-range clamped `progress²` to opacity + spatial interpolation. Target-device feedback then established that the start is over-restrained and the continued nonlinear tail feels like an unnatural easing effect. The 80% travel and single UIKit owner are retained; the whole-range `progress²` visual curve is rejected as final.

### Build204 carousel identity collision — retired

A carousel package was briefly produced as `0.14.37 / Build204`, but mandatory global state resync showed the independent poster-scroll task already owned **Build204 / 0.14.37**. The carousel Build204 package is retired and must not be used for attribution. Canonical Build204 ownership remains poster-scroll.

### Build205 real-device reference

- branch: `perf/home-carousel-eased-travel-build205`
- tested source: `e5f2e7b4135eca333d5dda24545f19ee8d0be439`
- durable cleanup head: `70d6cca676911e656591aae6b342c771cc92b9fe`
- run/job: `32998533448` / `98273968966` — success
- artifact ID: `9617634710`
- IPA SHA-256: `fe4a81ebee9d330526c108edf2ab4652632ae5b204719864e0b5dee486086479`
- evidence: **Code written / CI passed / IPA produced+verified / real-device tested / visual curve rejected as final / not stable**.

### Current carousel candidate: Build207 / 0.14.40

Build206 is owned by the independent poster diagnostics task, so the carousel line uses Build207.

- branch: `perf/home-carousel-soft-start-linear-tail-build207`
- base: Build205 durable cleanup head `70d6cca676911e656591aae6b342c771cc92b9fe`
- tested source: **`06936503a6c382d1d39d3cdd52f23bfe2058901e`**
- durable cleanup head: **`7044ca68c7082cd055a7e4ce42dda6f00fe29674`**
- tested-source → cleanup-head: temporary Build207 workflow deletion only; product/runtime source unchanged.
- runtime product delta from Build205: `Sources/Core/AppIdentity.swift` + `Sources/UI/EmbyHomeCarouselStateV3.swift` only.
- foreground total travel remains **`0.80 × Hero width`**.
- whole-range `progress²` is removed.
- new visual progress is clamped `progress * (1 - 0.60 * (1-progress)^6)` for both foreground/backdrop opacity and foreground spatial interpolation.
- initial slope is approximately **0.40**, so the first movement is less suppressed than Build205; raw progress 0.05 maps to visual ~0.028 and 0.10 maps to ~0.068.
- attenuation rapidly decays and mid/late drag converges closely to raw linear progress.
- endpoint stays 1.0 and the tail derivative tends to **1.0**, avoiding the whole-range acceleration/deceleration sensation.
- raw `transitionProgress` remains linear and remains the 0.28 commit / 0.48×width predicted release authority; the visual curve does not feed back into gesture thresholds.
- existing direction sign + `(index + direction + count) % count` remains left/right and first↔last authority; no boundary-specific state machine was added.
- Build198 gesture owner/release/settle remain unchanged.
- Frozen Player/MPV/PiP/UnifiedTransport/Cache/Emby playback/session paths untouched.

Build207 CI / IPA:

- run/job: **`33000526138` / `98280846494` — success**
- source/Frozen guard, Release build, app identity, MinOS, IPA/source packaging and upload all passed.
- artifact: `OnePlayer-0.14.40-build207-home-carousel-soft-start-linear-tail`
- artifact ID: **`9618484884`**
- artifact digest / independently downloaded ZIP SHA-256: **`c6a60537969f4d49f90f2ae47b033094640233f1085db6f5b1e75d18a86b62e4`**
- IPA SHA-256: **`bbd7c9c22c2a79a89f41e0d94db16023cf7cd2a720ffeb3c4f31cb9066a15a21`**
- source ZIP SHA-256: **`ecb6f4dbfb0609194406dbb5e0efc3ecde8907ed22992ee7aa4dcf6a886bc275`**
- independently verified: artifact/IPA integrity, embedded checksums, bundle `com.embyplayerlab.app`, version/build `0.14.40 (207)`, OnePlayer primary/alternate icons, MinOS 15.0; source snapshot confirms 80% travel + new soft-start curve and confirms whole-range `return progress * progress` is absent.
- evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / not stable.**

Next action: target-device A/B Build207 against Build205 and EX. Focus on whether the first few millimeters move earlier/more freely than Build205 without restoring Build203's initial jump, then whether mid/late drag and tail feel essentially linear. Also verify left/right, first↔last, reversal, cancel/commit, vertical Hero scroll, detail tap and auto-advance. Do not alter gesture ownership before that evidence.

## Active: Poster-heavy scrolling smoothness

Work: `DEV-poster-grid-smoothness`.

### Build202 real-device conclusion

- identity: **OnePlayer 0.14.35 / Build202**
- branch / draft PR: `perf/poster-grid-smoothness` / #259
- tested source: `a05dd3424bb499e46dc0834e69cf55654fb7733e`
- durable cleanup head: `6e16865d1589a953f58bf65885d9fb01ff6374e0`
- run/job: `32993726508` / `98257448257` — success
- artifact ID: `9615751921`
- IPA SHA-256: `f6e3a30206acf2cfd877df74f41aa13f1575e1614407eff79466884f9ec51279`
- latest target-device recording around 4.067 s shows approximately `-6.36 px → 0 px → -26.19 px`, confirming the stop-frame/catch-up hitch remains.
- conclusion: **Build202 = CI/IPA verified / real-device tested / smoothness rejected / not stable.**

### Poster Build204 / Build206 line

Canonical Build204 ownership belongs to poster-scroll.

- Build204 exact CI source: `e6a97b5083691ed10795a402edc0fd30f996cffc`.
- Build204 durable cleanup head: `170778c3934a280d9b539fb45f0bfef673687825`.
- Build204 runtime delta from Build202: `Sources/Core/AppIdentity.swift` + `Sources/UI/EmbySharedImageAndNavigation.swift` only.
- Build204 run/job: `32996847597` / `98268250117` — success.
- Build204 artifact ID: `9617026984`.
- Build204 IPA SHA-256: `b4ba266086674f95a09ef92500c78926b4bc9cfd022c637075985cd55c598130`.
- Build206 identity is reserved by the poster-scroll diagnostic work visible on current `main`; carousel must not reuse it.

Poster task evidence/state remains owned by `DEV-poster-grid-smoothness`; do not infer poster real-device acceptance from carousel work.

## Parallel integration rule

Build199 remains the accepted overall baseline. Home-carousel Build207 and poster-scroll are independent Active lines with separate branches/evidence. If a candidate is accepted on the target device, resync its durable product diff against then-current `main` in a separate integration step. If that resync materially changes source, rerun affected validation/CI; old-base CI cannot be treated as proof for changed merged source.
