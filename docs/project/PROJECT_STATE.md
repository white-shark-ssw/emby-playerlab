# OnePlayer Project State

_Last updated after poster-scroll Build212 / 0.14.45 target-device source-aware diagnostics split the remaining Home and grid hitch into two evidence-backed paths. Build199 remains the latest real-device accepted overall baseline. Build211 / 0.14.44 remains owned by the independent carousel line; no Build212 runtime fix is accepted yet._

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
- Build200: fully fixed foreground was rejected because foreground horizontal motion disappeared.
- Build201 / 0.14.34: 15% travel received partially positive **“有点那种感觉了”** feedback but total travel was too short.
- Build203 / 0.14.36: 30% travel was still too short and raw-linear mapping exposed coarse first displacement again.
- Build205 / 0.14.38: 80% + whole-range `progress²` was rejected because the start was over-restrained and the tail felt unnaturally eased.
- Build207 / 0.14.40: early-only soft-start/linear-tail mapping removed the whole-range easing problem, but target-device screenshots showed first displacement still too long and, more importantly, adjacent foreground content structurally overlapping while EX showed a clear gap.

### Build207 structural-layout conclusion

Build207 evidence:

- branch: `perf/home-carousel-soft-start-linear-tail-build207`
- tested source: `06936503a6c382d1d39d3cdd52f23bfe2058901e`
- durable cleanup head: `7044ca68c7082cd055a7e4ce42dda6f00fe29674`
- run/job: `33000526138` / `98280846494` — success
- artifact ID: `9618484884`
- IPA SHA-256: `bbd7c9c22c2a79a89f41e0d94db16023cf7cd2a720ffeb3c4f31cb9066a15a21`

Source inspection plus screenshots establish:

- every `carouselHeroForeground` is already a full Hero-width page;
- Build207 offset math kept outgoing/incoming page centers only `0.80 × width` apart;
- therefore those full-width page frames overlap by 20% throughout drag, which explains the visible Logo/title/rating/overview overlap;
- existing foreground content width is `width - 56`;
- if page centers are exactly one `width` apart, content edges keep ~56pt separation, matching the user's “one screen-width frame per item” model and the EX comparison more closely.

Build207 evidence is therefore **real-device tested / foreground layout rejected / not stable**. This is not evidence to change the UIKit gesture owner.

### Current carousel candidate: Build208 / 0.14.41

- branch: `perf/home-carousel-page-slots-build208`
- base: Build207 durable cleanup head `7044ca68c7082cd055a7e4ce42dda6f00fe29674`
- tested source: **`2ad089f0ea8b4b6827257bb3a91a67c2d3748e5f`**
- durable cleanup head: **`51c366b6840d77c818eae20e1f3f43c0dbd75c72`**
- tested-source → cleanup-head: temporary Build208 workflow deletion only; product/runtime source unchanged.
- runtime product delta from Build207: `Sources/Core/AppIdentity.swift` + `Sources/UI/EmbyHomeCarouselStateV3.swift` only.
- foreground uses full-width page slots: **`pageStep = width`**.
- outgoing offset = `-direction × visualProgress × pageStep`; incoming offset = `direction × (1 - visualProgress) × pageStep`.
- outgoing/incoming page-center separation is exactly one Hero width for every progress value.
- existing `contentWidth = width - 56` stays unchanged, so adjacent foreground content keeps ~56pt constant separation rather than structural overlap.
- no new HStack/ScrollView/gesture owner is introduced; this is the same two visible foreground pages and state owner with corrected slot spacing.
- earliest attenuation is `progress * (1 - 0.85 * (1-progress)^6)` after clamping.
- compared with Build207, approximate actual displacement at raw 1% / 2% / 4% falls from ~0.35% / 0.75% / 1.70% width to ~0.20% / 0.49% / 1.34% width; around 10% raw progress it has essentially caught up.
- mid/late drag remains near-linear; endpoint/tail derivative remains 1.0.
- foreground/backdrop opacity continues to use the same visual progress.
- raw `transitionProgress`, 0.28 commit, 0.48×width predicted release gate, reversal/settle and first↔last modulo ownership remain unchanged.
- Frozen Player/MPV/PiP/UnifiedTransport/Cache/Emby playback/session paths untouched.

Build208 CI / IPA:

- run/job: **`33004390654` / `98294100402` — success**
- source/Frozen guard, Release build, app identity, MinOS, IPA/source packaging and upload all passed.
- artifact: `OnePlayer-0.14.41-build208-home-carousel-page-slots`
- artifact ID: **`9620046266`**
- artifact digest / independently downloaded ZIP SHA-256: **`4ace3db785c131b987bfd9e18dc931e1bdeaf9f7528d85b8807214b45774afbb`**
- IPA SHA-256: **`24f47ac5cd5685f6eea85b1c3a4fad2841d81f6169a90cd0629bea85a2072308`**
- source ZIP SHA-256: **`807d03947c0d087ddc54f295e63fdabc37ac0ddfbe0e0f03da4477eb750e95ee`**
- independently verified: artifact digest exact match; IPA/source embedded checksums match; IPA `unzip -t` passed; bundle `com.embyplayerlab.app`; version/build `0.14.41 (208)`; OnePlayer primary/alternate icons; MinOS 15.0; source snapshot confirms full-width page step, 0.85 earliest attenuation and existing `width - 56` content width.
- evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / not stable.**

Next action: target-device A/B Build208 against Build207 and EX. First verify adjacent foreground content keeps a visible stable gap through left/right drag, then verify earliest displacement is reduced without introducing a mid/tail catch-up. Also test first↔last wraps, reversal, cancel/commit, vertical Hero scroll, detail tap and auto-advance. Do not alter gesture ownership before that evidence.

## Active: Poster-heavy scrolling smoothness

Work: `DEV-poster-grid-smoothness`.

- Build202 and Build204 were target-device rejected; Build206/209/210 progressively established reliable motion attribution.
- Build212 / 0.14.45 exact source `4f0a89ab026cd2103f66e5854a1f352d34852e45`; run/job `33045869471 / 98429601490`; artifact `9635696107`; IPA SHA-256 `dcdec181dd16e9b3b666882de8347a76671c743ab8392aa27791d40599eec7a1`; MinOS 15.0.
- target-device log `OnePlayer-App-1787813666.log` contains 5 Home dragging hitches (43.6–73.8 ms), all following `memory/callback/Primary/1400` image publish by 8.3–12.2 ms. Measured callback/contrast durations are only 1.0–3.2 / 1.0–3.0 ms, so contrast analysis is no longer the primary suspect. The stronger Home lead is carousel large-image publish/presentation during vertical scrolling; this overlaps the active carousel task.
- the same log contains 11 true grid dragging hitches (31.0–37.3 ms), all following `network/display/Primary/378` publish by 0.0–20.1 ms with a newly appeared grid cell 118.8–177.8 ms old. Carousel callback/contrast timestamps are stale and unrelated.
- therefore the previous universal cross-page-root-cause assumption is rejected. Home and grid should receive separate minimal runtime candidates.
- Home runtime changes require explicit reconciliation with `DEV-home-carousel-drag-smoothness`; poster work must not independently modify carousel owner files.
- Grid next step is exact-source inspection of the display-only image publish/render path, preserving 378px rendered-device requirement and forbidding delay/throttle/debounce/timer workarounds.
- evidence: **Build212 target-device diagnostic tested / Home callback-cost hypothesis rejected / real grid dragging stalls captured / route split established / performance fix not tested / not stable.**

Next: reconcile the Home evidence with the carousel task, and independently design the smallest grid display-image publication/render candidate. Keep P0 Player/MPV/PiP/Transport/Cache/Session and iOS 15.0 contracts untouched.

## Parallel integration rule

Build199 remains the accepted overall baseline. Home-carousel Build208 and poster-scroll are independent Active lines with separate branches/evidence. If a candidate is accepted on the target device, resync its durable product diff against then-current `main` in a separate integration step. If that resync materially changes source, rerun affected validation/CI; old-base CI cannot be treated as proof for changed merged source.
