# OnePlayer Project State

_Last updated after Home-carousel Build203 target-device testing rejected the 30% raw-linear spatial mapping as final, after carousel Build205 / 0.14.38 completed CI/IPA with 80% `progress²` spatial+opacity mapping, and after poster-scroll Build202 was target-device rejected while canonical poster Build204 / 0.14.37 completed CI/IPA. Build199 remains the latest real-device accepted overall baseline. Home-carousel Build205 and poster-scroll Build204 are independent Active candidates; neither is stable or merged._

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
- Build203 / 0.14.36: increased travel to `0.30 × Hero width` and used `progress²` opacity while spatial offset still used raw linear progress. Target-device feedback on 2026-08-27 showed 30% still too short overall, yet the larger raw-linear mapping exposed the coarse first visible displacement/jitter again. User requested spatial motion use the same restrained-start/accelerating-later curve as opacity and total travel increase to 80%.

Build203 evidence:

- tested source `69beee45b93dc11c7c5be2ee4b81a5a0157f2653`
- durable cleanup head `edafd5d784cfacdcf8c451fad93535a55fb880fb`
- run/job `32995898318` / `98264917294` — success
- artifact ID `9616576496`
- IPA SHA-256 `cee7241b73c4dc38efb6593c3d6ec9f54981f8e5a609be78a491b869df685226`
- evidence: **CI/IPA verified / real-device tested / rejected as final parameterization / not stable**.

### Build204 carousel identity collision — retired

A carousel package was briefly produced as `0.14.37 / Build204` with the intended 80% eased visual mapping. Mandatory global state resync then showed that the independent poster-scroll task already owned **Build204 / 0.14.37** with its own source/artifact. The carousel Build204 package is therefore retired before distribution and must not be used for attribution. Canonical Build204 ownership remains poster-scroll.

### Current carousel candidate: Build205 / 0.14.38

- branch: `perf/home-carousel-eased-travel-build205`
- base: Build203 durable cleanup head `edafd5d784cfacdcf8c451fad93535a55fb880fb`
- tested source: **`e5f2e7b4135eca333d5dda24545f19ee8d0be439`**
- durable cleanup head: **`70d6cca676911e656591aae6b342c771cc92b9fe`**
- tested-source → cleanup-head: temporary Build205 workflow deletion only; product/runtime source unchanged.
- runtime product delta from Build203: `Sources/Core/AppIdentity.swift` + `Sources/UI/EmbyHomeCarouselStateV3.swift` only.
- foreground total travel: **`0.80 × Hero width`**.
- `visualProgress = clamp(transitionProgress)²` is used for both foreground spatial interpolation and foreground/backdrop opacity.
- outgoing offset = `-direction × visualProgress × travel`; incoming offset = `direction × (1 - visualProgress) × travel`.
- raw `transitionProgress` remains linear and remains the 0.28 commit / 0.48×width predicted release authority; visual easing does not feed back into gesture thresholds.
- at raw progress 0.10, Build203 moved `0.03 width`; Build205 moves `0.008 width`, despite the much larger 80% final travel.
- existing direction sign + `(index + direction + count) % count` remains left/right and first↔last authority; no boundary-specific state machine was added.
- Build198 gesture owner/release/settle remain unchanged.
- Frozen Player/MPV/PiP/UnifiedTransport/Cache/Emby playback/session paths untouched.

Build205 CI / IPA:

- run/job: **`32998533448` / `98273968966` — success**
- artifact: `OnePlayer-0.14.38-build205-home-carousel-eased-travel`
- artifact ID: **`9617634710`**
- artifact digest / independently downloaded ZIP SHA-256: **`3efb42f2ff3bf7ea7ed31a58f188b30c449e4cb0b703b111ee47ef98e3a51671`**
- IPA SHA-256: **`fe4a81ebee9d330526c108edf2ab4652632ae5b204719864e0b5dee486086479`**
- source ZIP SHA-256: **`b556620d0d312259e6d2e823c7f8079109f44c13e00c56b1718cfcfea4cd38f1`**
- independently verified: artifact digest exact match; embedded checksums match; IPA `unzip -t` passed; bundle `com.embyplayerlab.app`; version/build `0.14.38 (205)`; OnePlayer primary/alternate icons; MinOS 15.0.
- evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / not stable.**

Next action: target-device A/B Build205 against Build203 and EX, focusing first on the first few millimeters of drag, then mid/late acceleration, total travel, left/right and first↔last wraps, reversal, cancel/commit, vertical Hero scroll, detail tap and auto-advance. Do not alter gesture ownership before that evidence.

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

### Current poster candidate: Build204 / 0.14.37

Canonical Build204 ownership belongs to poster-scroll.

- exact CI source: **`e6a97b5083691ed10795a402edc0fd30f996cffc`**
- durable cleanup head: **`170778c3934a280d9b539fb45f0bfef673687825`**
- runtime delta from Build202: `Sources/Core/AppIdentity.swift` + `Sources/UI/EmbySharedImageAndNavigation.swift` only.
- no-callback ordinary poster images install no no-op `loader.$image` subscriber.
- ordinary warm-cache cells seed the loader from existing decoded-memory cache so `onAppear` avoids a second synchronous cached-image publication.
- Hero/detail/carousel callback paths keep prior publication/dedup/callback semantics.
- run/job: **`32996847597` / `98268250117` — success**
- artifact ID: **`9617026984`**
- IPA SHA-256: **`b4ba266086674f95a09ef92500c78926b4bc9cfd022c637075985cd55c598130`**
- evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / not stable.**

Next action for poster-scroll remains its own Build204 target-device A/B. Do not mix poster Build204 and carousel Build205 attribution.

## Parallel integration rule

Build199 remains the accepted overall baseline. Home-carousel Build205 and poster-scroll Build204 are independent feature candidates with different Build identities and branches. If either is accepted on the target device, resync its durable product diff against then-current `main` in a separate integration step. If that resync materially changes source, rerun affected validation/CI; old-base CI cannot be treated as proof for changed merged source.
