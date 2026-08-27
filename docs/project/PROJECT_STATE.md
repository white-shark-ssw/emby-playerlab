# OnePlayer Project State

_Last updated after Build218 / 0.14.51 poster-grid candidate target-device Home testing. Build216 remains the latest real-device accepted overall runtime baseline for merged product work; Home-carousel Build217 remains an independent diagnostic line, while poster Build218 is CI/IPA verified but not accepted: Home still visibly hitches, grid A/B is pending, and a shared transparent-Logo presentation regression was identified and corrected in source only._

## Current accepted overall baseline

- Product: **OnePlayer 0.14.49 / Build216**
- Canonical branch: `main` after PR #261 integration
- Final merge PR: **#261**
- Final merge commit: `f5ad126b7b47e9713b1949780a6507fb3f0ca50f`
- Accepted/tested product source: `dc00cac9f35ee4a3b950e4bb030bb324baf90b18`
- Dedicated standard MPV CI run/job: `33064051545 / 98489652724` — success
- Artifact: `OnePlayer-0.14.49-build216-detail-range-inertia`; ID `9643031850`
- Artifact digest: `sha256:9cbccc582be719b2daa10077293da2951f0cbce8016625128de8ef9d85b27f48`
- IPA SHA-256: `e3054a53398e1df48134fecd8c30671e10ecaa8a93df5483936adcf10e055075`
- Source ZIP SHA-256: `98e1b5b52ebe5d8b2e3fbf754d3dfb18d0ea082fd77bcd9e6905b0bcb56e0f6f`
- Deployment Target / built MinOS: **iOS 15.0**
- Target device: **iPhone 15 Pro Max / iOS 17.0**
- Real-device result: **user reported Build216 acceptance on 2026-08-27**
- Evidence: **Code written / CI passed / IPA produced / real-device accepted / stable/frozen for the detail episode-range inertia contract / merged to main**

Build216 inherits all accepted/frozen player, PiP, transport, playback-cache, episode-ordering, Build182 detail-presentation, Build191 detail-selection, Build195 player-episode and Build199 server-management contracts. Its only new stable runtime scope is stopping active detail episode-row native deceleration before the existing range selection/jump; the Build213 page-persistence milestone remains inherited and unchanged.

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
- **Build213**: Favorites + Library 7-tab disk-backed warm presentation cache; cached-first after relaunch, live refresh remains authoritative, successful accepted state writes through, failed refresh retains old snapshot; target-device accepted through PR #260.
- **Build216**: detail range-pill taps synchronously stop active native episode-row deceleration before the existing Build191 range-first selection and 0.32 s target scroll; target-device accepted and merged through PR #261.

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

### Current carousel candidate: Build215 / 0.14.48

Build208 is now the real-device video reference rather than the current candidate. A/B versus EX showed a hold-then-jump acquisition and prolonged visual lag from the easing workaround, while EX behaved like a short take-up followed by nearly 1:1 motion and kept foreground substantially more opaque.

Build215 retains Build198 one-UIKit-owner lifecycle and Build208 full-width `pageStep = width`, but horizontal acquisition now establishes a render baseline and does not publish the already accumulated touch-down distance. Post-acquisition spatial motion is `currentTranslation - acquisitionTranslation`, with no whole-range easing. Release/commit remains touch-down based with the original 0.28 and 0.48×width gates, including one-sample fast release. Foreground transition pages remain opaque while backdrop crossfade is independent. Wrapping, cancellation/settle and P0/Frozen paths are unchanged.

Carousel Build214 / 0.14.47 passed CI/IPA but was retired before distribution because parallel poster work claimed that identity. Build215 is the valid carousel attribution package.

- tested source `d22634ece2f29eba2e60de01182bf15d4ba554a7`; durable cleanup head `01a13615fc056fd3b13296d98abfaa7a6aa2b46d` (workflow deletion only).
- run/job `33058337107 / 98470624555` — success.
- artifact ID `9640692378`; digest `sha256:31a054244bcfbeb39cc5db663aa7580cb4cc742fe88ca998ce9c9ba7a01e2939`.
- IPA SHA-256 `6551a5e9e8a28a66bd4f105118387e8fc9378b72bd47778897f013b411c06c97`; source ZIP SHA-256 `00d2a0aba071dbbce3554d31dba64f0caa70c22b6e067dedeee0bb3b22ebd694`.
- independent artifact/IPA/source/identity/MinOS/source-contract verification passed.
- real-device result: acquisition-relative start and opaque foreground are positively confirmed; initial drag is now about as fine as EX and foreground blur/ghosting is gone, but overall tactile smoothness still trails EX ("smooth glass" vs "rough paper"). 30fps recording no longer shows the old macro hold/jump; residual micro-continuity/cadence cause remains unresolved and backdrop timing is only a hypothesis.
- evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device tested / partial success / not stable**.

Next action: inspect the post-acquisition touch→state→SwiftUI render/compositing cadence for evidence of sub-frame irregularity. Do not retune travel/easing or change backdrop timing solely from the current subjective residual gap; backdrop timing remains an unproven hypothesis.

## Active: Poster-heavy scrolling smoothness

Work: `DEV-poster-grid-smoothness`.

- Build212 remains the controlling route-split diagnostic: Home dragging hitches correlate with 1400px carousel callback-role image publication, while 11 true grid dragging hitches correlate with newly visible `network/display/Primary/378` publication. Home and grid remain separate runtime paths.
- Build218 / 0.14.51 exact tested source `ccc3a69f3b77c56a730593f072a2c7dfde599073`; run/job `33066739271 / 98498551491` success; artifact ID `9644109849`; artifact SHA-256 `16096a2c3a1b4dcb4ed3bcfa8524e3839f9114eb040e7ee419279555c1e71c4e`; IPA SHA-256 `104eb5266c304102c912eaa2b9e95a4f0ae6183b0bf071fd377b3a52ea8d57bc`; source ZIP SHA-256 `41dfb97a0bfd38cb65ed000b3f9fc2679dc7bf471abe7635020895a5f4f12b90`; MinOS 15.0.
- Build218 changed only the pure display-image presentation path: no callback/no spinner images receive the existing loader output through a UIKit `UIImageView` surface so surrounding SwiftUI poster cells do not observe the loader's image publication. Carousel owner files were not modified.
- 2026-08-27 target-device result: the user still feels **obvious Home vertical jitter**. The supplied 510×1108@30fps recording retains stop/catch-up frames, so Build218 must not be claimed as a Home fix. This turn does not provide a Library/Favorites/Search/Tag/Person 3×3 A/B result; grid effectiveness is still pending.
- The same target-device screenshot exposed a white rectangle behind a transparent carousel movie Logo. Exact source inspection proves `EmbyHomeHeroV3.swift` is unchanged from Build216, but its Logo call matches Build218's new shared UIKit display path. The new surface retained `secondarySystemBackground` after the image loaded, unlike the old path, so transparent pixels exposed a rectangular background. This is a poster-task shared-image regression, not a carousel-owner edit.
- Poster branch head `ac8a8cd0b87c4ee544c8817fec13edeea226826b` contains the minimal source correction: loaded images set the shared UIKit surface background to clear; nil-image placeholder state remains `secondarySystemBackground`. No carousel owner source is touched. This corrected head is only **Code written**; no new CI/IPA or target-device evidence exists yet.
- Current evidence: **Build218 CI/IPA verified / Build218 Home real-device still hitches / Build218 grid A/B pending / Build218 package visual regression confirmed / transparency correction code written / corrected-source CI+IPA pending / not stable**.

Next: keep Home runtime ownership with the active carousel task; validate/package the corrected grid UIKit-display candidate under a new unique Build identity, then explicitly A/B the real 3×3 routes. Do not infer grid failure from the Home-only Build218 test.

## Active: Aether manual playback-engine comparison

Work: `DEV-aether-multi-engine-comparison`.

Build219 / OnePlayer 0.14.52 is the first normal-App Aether comparison package. Exact source `b1a06cb2b3dc9cf715fc5d49a7b324780aa23981` passed Xcode 26.3 Release CI (`33096553966 / 98602865604`) and produced artifact `9656814369`; IPA SHA-256 `8df11d2db597fd6841a3708976824b21879ee0d47257c1766d1704cc4196d06d`, source ZIP SHA-256 `61148b209d543c233502c8412f9448fffa143a97f5753c25595626c72b3e31e4`, built MinOS 16.0. AetherEngine 6.50.0 is manual-only; MPV remains default/automatic authority. Aether reuses existing UnifiedTransport/Session Cache through exact-byte IOReader demand; NAS relay, a second 115/CDN network stack and time→byte proportional Seek are forbidden. Frozen PiP is not redesigned and Aether currently does not claim PiP/audio-track/subtitle-selection capability.

Current evidence: **Code written / CI passed / IPA produced+verified / real-device not yet tested / not stable**. Build216 remains the latest accepted overall runtime baseline until the user reports Build219 target-device behavior.

## Parallel integration rule

Build216 is the accepted overall runtime baseline after the detail episode-range inertia closeout. Home-carousel Build215 and poster-scroll remain independent Active lines with separate branches/evidence. If a candidate is accepted on the target device, resync its durable product diff against then-current `main` in a separate integration step. If that resync materially changes source, rerun affected validation/CI; old-base CI cannot be treated as proof for changed merged source.
