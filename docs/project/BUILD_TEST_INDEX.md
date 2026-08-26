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
| **Build201 / 0.14.34** | 15% short-travel horizontal slide + linear blend | CI/IPA verified; target-device feedback: **“有点那种感觉了”**. Direction partially positive; user requested 30% travel and slower-start/faster-later opacity. Not final. |
| **Build202 / 0.14.35** | Poster-heavy scrolling smoothness | Independent poster task. CI/IPA verified; candidate real-device A/B pending. |
| **Build203 / 0.14.36** | 30% carousel travel + accelerating opacity | CI/IPA passed and independently verified. Uses `0.30 × Hero width` and direction-independent `progress²` blend with existing first↔last modulo wrapping. Target-device validation pending. |

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
- actual touch drives render; predicted touch is release-only;
- 0.5pt axis acquisition, 0.28 commit, 0.48×width predicted-distance gate and settle timings remain unchanged;
- no second SwiftUI drag/release owner.

Build198 successful CI source `a569155d443433a5f4769dfe506fec6ab9bdd0e6`; run/job `32987054824` / `98235720724`; artifact ID `9613342337`; IPA SHA-256 `9432928b31898c0c3f05e7e0affb6949c23339a37edd8f14c1d47343ff31f3d8`.

Target-device result: lifecycle/settle/reversal okay, minimum/subtle movement still too coarse versus EX. Input architecture retained; full-width visual mapping not final.

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
- target-device result on 2026-08-27: user reported **“有点那种感觉了”**, then requested travel `15% → 30%` and opacity that changes little at drag start and increasingly faster later, including left/right and first↔last boundaries.
- evidence: **Code written / CI passed / IPA produced+verified / real-device tested / direction partially positive / not stable.**

### Build203 current carousel candidate

- identity: **0.14.36 / 203**
- branch: `perf/home-carousel-accelerating-blend-build203`
- base: Build201 tested source `e61070146d91bac45400e3f95e28eead756faa81`
- tested source: `69beee45b93dc11c7c5be2ee4b81a5a0157f2653`
- durable cleanup head: `edafd5d784cfacdcf8c451fad93535a55fb880fb`
- tested-source → cleanup-head delta: temporary Build203 workflow deletion only; product/runtime source unchanged.
- runtime delta is limited to `AppIdentity.swift` and `EmbyHomeCarouselStateV3.swift`.
- foreground travel: `0.30 × Hero width`.
- backdrop + foreground blend: clamped `progress²`; outgoing `1-blend`, incoming `blend`.
- existing modulo neighbor lookup `(index + direction + count) % count` remains the first↔last authority, so no edge-specific state owner was added.
- Build198 gesture owner/thresholds/release/settle remain unchanged.
- run/job: **`32995898318` / `98264917294` — success**
- artifact: `OnePlayer-0.14.36-build203-home-carousel-accelerated-blend`
- artifact ID: **`9616576496`**
- artifact digest / independently downloaded ZIP SHA-256: `5df63c68c6a8f97d5c41d12040c297e5d4ca6e58d00aae89b0c17ce5a6441310`
- IPA SHA-256: **`cee7241b73c4dc38efb6593c3d6ec9f54981f8e5a609be78a491b869df685226`**
- source ZIP SHA-256: **`4b916a508e258949f9c17b449d38e782030a1130e36d08868cd1c54797a00135`**
- independent validation: artifact/IPA integrity, bundle `com.embyplayerlab.app`, `0.14.36 (203)`, OnePlayer icons, MinOS 15.0; build log contains `** BUILD SUCCEEDED **`.
- evidence: **Code written ✅ / scoped diff+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending / not stable.**

## Build202 poster-scroll evidence

- task: `DEV-poster-grid-smoothness`
- branch / draft PR: `perf/poster-grid-smoothness` / #259
- identity: **0.14.35 / 202**
- tested source: `a05dd3424bb499e46dc0834e69cf55654fb7733e`
- durable cleanup head: `6e16865d1589a953f58bf65885d9fb01ff6374e0`
- user recording proves an existing stop-frame/catch-up hitch; that proves the baseline problem, not the candidate fix.
- run/job: `32993726508` / `98257448257` — success
- artifact ID: `9615751921`
- artifact digest: `sha256:1fa9236d08210440a80b2f9af2fcef24e5608aac6f8c52be602295b40ec68777`
- IPA SHA-256: `f6e3a30206acf2cfd877df74f41aa13f1575e1614407eff79466884f9ec51279`
- source ZIP SHA-256: `19ebc6a2bcefd61d53eb4a9eea7617d5e98be7f8ae7b4f2dbf027ff62d8fabfe`
- candidate real-device result: pending.

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