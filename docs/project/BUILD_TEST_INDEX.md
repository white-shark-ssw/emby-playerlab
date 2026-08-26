# OnePlayer Build / Test Index

This is a milestone index, not a list of every experiment. Evidence levels remain distinct: Code written → CI passed → IPA produced → real-device tested → stable/frozen.

| Milestone | Main purpose | Result / current meaning |
|---|---|---|
| Build84 / 0.13.17 | MDK RecoveryIsolation | Protected app/exit lifecycle better; did not prove abnormal media solved. |
| Build96 | MDK single-generation safety | Avoided unsafe same-process MDK generation rebuild after failure. |
| Build111 / 0.13.44 | MDK Seek experiments | Real-device long-tail Seek remained worse than MPV. |
| Build131 / 0.13.64 | MPV intent Seek | Recovered fast double-tap latency; exact scrub exposed precision/latency trade-off. |
| Build145 / 0.13.78 | MPV fast keyframe Seek | Current fast-Seek architecture established. |
| **Build173 / 0.14.6** | PiP completion/return simplification | PiP freeze point. |
| **Build176 / 0.14.9** | Episode overlay completion | Real-device accepted; source-owned episode-session replacement and trusted-natural-end auto-next stable. |
| **Build178 / 0.14.11** | Canonical Emby episode ordering | Real-device accepted; `/Shows/{SeriesId}/Episodes` order is canonical. |
| **Build179 / 0.14.12** | Carousel candidate | Real-device rejected: small-drag dead zone/reversal issues. |
| **Build180 / 0.14.13** | Carousel reversal continuity | Reversal improved; initial motion still coarse. |
| **Build182 / 0.14.15** | Detail scroll/presentation cache | Real-device accepted/frozen. |
| **Build183 / 0.14.16** | Fixed-foreground carousel experiment | Felt finer but changed required horizontal-slide semantics. |
| **Build184 / 0.14.17** | Detail visual hierarchy | Real-device accepted; merged. |
| **Build185 / 0.14.18** | Carousel page-slide refinement | Real-device rejected: first visible movement ~10/12/16 px vs EX ~1/1/2 px. |
| **Build187 / 0.14.20** | Carousel cadence diagnostics | Target device: first useful samples ~4.33/8.00/15.67/11.00pt; 120 Hz available. |
| **Build189 / 0.14.22** | Native carousel movement | Real-device rejected: split move/release owner could freeze between pages. |
| **Build191 / 0.14.24** | Detail episode selection/navigation | Real-device accepted; merged. |
| **Build193 / 0.14.26** | Passive native move + SwiftUI release | Real-device rejected; split-owner architecture rejected. |
| **Build195 / 0.14.28** | Lazy large player episode row | Real-device accepted; merged. |
| **Build198 / 0.14.31** | Single UIKit carousel lifecycle owner | CI/IPA verified; real-device lifecycle/settle/reversal okay, but minimum drag still too coarse. Single-owner input architecture retained. |
| **Build199 / 0.14.32** | Add/Edit Emby completion | Dedicated CI/IPA passed; target-device accepted; merged. **Current accepted overall baseline.** |
| **Build200 / 0.14.33** | Fixed-spatial foreground + linear blend | CI/IPA verified; target-device rejected because foreground stopped sliding horizontally. |
| **Build201 / 0.14.34** | 15% short-travel horizontal slide + linear blend | CI/IPA verified; target-device feedback: **“有点那种感觉了”**. Direction partially positive; not final. |
| **Build202 / 0.14.35** | Poster-heavy scrolling smoothness | CI/IPA verified, but target-device recording still shows stop/catch-up hitch; rejected for smoothness. |
| **Build203 / 0.14.36** | 30% carousel travel + accelerating opacity | CI/IPA verified. Target-device: 30% still too short overall while raw-progress spatial mapping makes the initial displacement/jitter perceptible again. Rejected as final parameterization; input owner retained. |
| **Build204 / 0.14.37** | Poster warm-cache cell-entry reduction | **Owned by poster-scroll.** CI/IPA passed and independently verified; target-device validation pending. A separately-created carousel Build204 package was retired because this identity was already occupied and must not be used for attribution. |
| **Build205 / 0.14.38** | 80% carousel travel + eased spatial/opacity mapping | **Current carousel candidate.** Spatial offset and opacity both use clamped `progress²`; raw gesture progress/commit/release remain unchanged. CI/IPA passed and independently verified; target-device validation pending. |

## Current accepted baseline

- Product: **OnePlayer 0.14.32 / Build199**
- canonical branch: `main`
- final merge PR: `#256`
- final merge commit: `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`
- tested product source / dedicated CI source: `2b5f3bef073754371443c6c7a345657dbfa2a09a`
- CI run: `32942618979` — success
- artifact ID: `9597143667`
- IPA SHA-256: `8f0f43f62705e5e13ae666cc54d32fd047c596df1d0e9335668b01a25b6eb003`
- Deployment Target / built MinOS: iOS 15.0
- target device: iPhone 15 Pro Max / iOS 17.0
- evidence: **Code written / CI passed / IPA produced / real-device accepted / stable for accepted Add/Edit Emby requirements / merged to main**

Build199 inherits the accepted/frozen player, PiP, transport, cache, episode-ordering, detail-presentation and episode-selection contracts. Home-carousel and poster-scroll remain independent Active lines.

## Home-carousel evidence

### Build198 retained input foundation

- one UIKit interaction surface owns begin/move/end/cancel;
- vertical acquisition yields to Home `UIScrollView`;
- actual touch drives raw render progress; predicted touch is release-only;
- 0.5pt axis acquisition, 0.28 commit, 0.48×width predicted-distance gate and settle timings remain unchanged;
- no second SwiftUI drag/release owner.

Build198 successful CI source `a569155d443433a5f4769dfe506fec6ab9bdd0e6`; run/job `32987054824` / `98235720724`; artifact ID `9613342337`; IPA SHA-256 `9432928b31898c0c3f05e7e0affb6949c23339a37edd8f14c1d47343ff31f3d8`.

Target-device result: lifecycle/settle/reversal okay, minimum/subtle movement still too coarse versus EX. Input architecture retained; full-width raw visual mapping not final.

### Build200 rejected visual mapping

- source: `4d3afe36768b7749d9d0bd0081725f3d947b2099`
- run/job: `32991758526` / `98250719262`
- artifact ID: `9614995121`
- IPA SHA-256: `509395ca7fb847548110c22ec0a3f6b005e6b3f4521f911eb9b3f765ca6d1b1a`
- real-device: rejected because foreground became fixed and no longer slid horizontally.

### Build201 partially positive real-device result

- branch: `perf/home-carousel-short-travel-build201`
- tested source: `e61070146d91bac45400e3f95e28eead756faa81`
- run/job: `32993286519` / `98255950676`
- artifact ID: `9615585817`
- IPA SHA-256: `d889f2c36b3f617b429e4f39ba54d39d7f2826a058a2d4f874bc7a9bb574db58`
- visual mapping: horizontal foreground travel `0.15 × Hero width`, linear opacity blend.
- target-device result on 2026-08-27: user reported **“有点那种感觉了”**; 15% was closer partly because total movement was very small, but total travel was insufficient.
- evidence: **Code written / CI passed / IPA produced+verified / real-device tested / direction partially positive / not stable.**

### Build203 real-device result

- identity: **0.14.36 / 203**
- branch: `perf/home-carousel-accelerating-blend-build203`
- tested source: `69beee45b93dc11c7c5be2ee4b81a5a0157f2653`
- durable cleanup head: `edafd5d784cfacdcf8c451fad93535a55fb880fb`
- foreground travel: `0.30 × Hero width`.
- backdrop + foreground opacity blend: clamped `progress²`.
- spatial offset still used raw linear `transitionProgress`.
- existing `(index + direction + count) % count` remained first↔last authority.
- run/job: `32995898318` / `98264917294` — success
- artifact ID: `9616576496`
- IPA SHA-256: `cee7241b73c4dc38efb6593c3d6ec9f54981f8e5a609be78a491b869df685226`
- target-device result on 2026-08-27: 30% total travel still felt insufficient, while the larger raw-linear spatial mapping exposed the coarse first visible displacement/jitter again. User requested the spatial motion itself use the same restrained-start/accelerating-later curve as opacity and total travel increase to 80%.
- conclusion: remaining issue is more specifically **raw progress → spatial offset mapping**, not gesture lifecycle ownership.
- evidence: **Code written / CI passed / IPA produced+verified / real-device tested / rejected as final parameterization / not stable.**

### Build204 carousel collision — retired

A carousel package was briefly produced as `0.14.37 / Build204` with the intended 80% + `progress²` spatial mapping. During mandatory global state resync, `DEV-poster-grid-smoothness` was found to already own Build204 / 0.14.37. Therefore the carousel Build204 package is retired before distribution and must not be used for source/IPA attribution. Canonical Build204 ownership remains poster-scroll.

### Build205 current carousel candidate

- identity: **0.14.38 / 205**
- branch: `perf/home-carousel-eased-travel-build205`
- base: Build203 durable cleanup head `edafd5d784cfacdcf8c451fad93535a55fb880fb`
- tested source: **`e5f2e7b4135eca333d5dda24545f19ee8d0be439`**
- durable cleanup head: **`70d6cca676911e656591aae6b342c771cc92b9fe`**
- tested-source → cleanup-head delta: temporary Build205 workflow deletion only; product/runtime source unchanged.
- runtime delta from Build203: `Sources/Core/AppIdentity.swift` + `Sources/UI/EmbyHomeCarouselStateV3.swift` only.
- total foreground travel: **`0.80 × Hero width`**.
- `visualProgress = carouselBackdropBlendProgress(transitionProgress)` and the helper remains clamped `progress²`.
- outgoing offset = `-direction × visualProgress × travel`; incoming offset = `direction × (1 - visualProgress) × travel`.
- foreground/backdrop opacity uses the same `progress²` blend.
- raw `transitionProgress`, 0.28 commit, 0.48×width predicted gate and settle ownership remain unchanged.
- at raw progress 0.10, Build203 spatial displacement was `0.03 width`; Build205 is `0.008 width`, despite the much larger final travel.
- left/right and first↔last boundaries still use existing direction + modulo neighbor ownership; no edge-specific state machine.
- run/job: **`32998533448` / `98273968966` — success**
- artifact: `OnePlayer-0.14.38-build205-home-carousel-eased-travel`
- artifact ID: **`9617634710`**
- artifact digest / independently downloaded ZIP SHA-256: **`3efb42f2ff3bf7ea7ed31a58f188b30c449e4cb0b703b111ee47ef98e3a51671`**
- IPA SHA-256: **`fe4a81ebee9d330526c108edf2ab4652632ae5b204719864e0b5dee486086479`**
- source ZIP SHA-256: **`b556620d0d312259e6d2e823c7f8079109f44c13e00c56b1718cfcfea4cd38f1`**
- independent validation: artifact digest exact match; IPA/source hashes match embedded checksums; IPA `unzip -t` passed; bundle `com.embyplayerlab.app`; version/build `0.14.38 (205)`; OnePlayer primary/alternate icons; `MinimumOSVersion=15.0`.
- evidence: **Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending / not stable.**

## Poster-scroll evidence

### Build202 — real-device rejected

- task: `DEV-poster-grid-smoothness`
- branch / draft PR: `perf/poster-grid-smoothness` / #259
- identity: **0.14.35 / 202**
- tested source: `a05dd3424bb499e46dc0834e69cf55654fb7733e`
- durable cleanup head: `6e16865d1589a953f58bf65885d9fb01ff6374e0`
- run/job: `32993726508` / `98257448257` — success
- artifact ID: `9615751921`
- IPA SHA-256: `f6e3a30206acf2cfd877df74f41aa13f1575e1614407eff79466884f9ec51279`
- latest target-device recording around 4.067 s shows approximately `-6.36 px → 0 px → -26.19 px`, confirming the stop-frame/catch-up hitch remains.
- result: **Code written / CI passed / IPA produced+verified / real-device tested / smoothness rejected / not stable.**

### Build204 — current poster-scroll candidate

- identity: **0.14.37 / 204**; this is the canonical Build204 owner.
- exact CI source: `e6a97b5083691ed10795a402edc0fd30f996cffc`.
- durable cleanup head: `170778c3934a280d9b539fb45f0bfef673687825`.
- runtime delta from Build202 is limited to `AppIdentity.swift` and `EmbySharedImageAndNavigation.swift`.
- ordinary images without `onImageLoaded` no longer install a no-op `loader.$image` Combine subscriber.
- ordinary warm-cache cells initialize from the existing decoded-memory cache so `onAppear` avoids a second synchronous cached-image publication.
- run/job: `32996847597` / `98268250117` — success.
- artifact ID: `9617026984`.
- IPA SHA-256: `b4ba266086674f95a09ef92500c78926b4bc9cfd022c637075985cd55c598130`.
- evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / not stable.**

## Accepted foundation evidence

- Build176: source-owned episode-session replacement + trusted natural-end auto-next; merged PR #253.
- Build178: Emby `/Shows/{SeriesId}/Episodes` canonical order; merged PR #254.
- Build182: detail high-rate scroll isolation + presentation-only persistent cache; real-device accepted/frozen.
- Build184: detail visual hierarchy; merged PR #255.
- Build191: select-only detail episode browsing/navigation; merged PR #257.
- Build195: SeasonId-first player grouping + lazy large episode row; merged PR #258.
- Build199: Add/Edit Emby modern editor, same-server route selection, cached-first startup, retained password + optional iCloud Keychain sync; merged PR #256.

## Maintenance rule

Update this index when a build materially changes architectural understanding, becomes a real-device reference point, rejects/freezes a direction, or becomes the accepted baseline. Never treat CI success or IPA production as real-device acceptance.
