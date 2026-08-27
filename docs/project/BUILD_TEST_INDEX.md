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
| **Build204 / 0.14.37** | Poster warm-cache cell-entry reduction | **Owned by poster-scroll.** CI/IPA passed; target-device tested on Home and library 3×3 and rejected because visible stop/catch-up hitching remains. A separately-created carousel Build204 package was retired because this identity was already occupied and must not be used for attribution. |
| **Build205 / 0.14.38** | 80% carousel travel + whole-range `progress²` visual mapping | CI/IPA verified; target-device rejected the curve as final: drag start is over-restrained and the whole-range nonlinear tail feels like unnatural easing. |
| **Build206 / 0.14.39** | Poster-scroll hitch diagnostics | **Owned by the independent poster task.** CI/IPA verified and target-device App-log captured: 17 diagnostic gaps (row 7, grid 10; grid max 118.7 ms), all with `load_ahead=none`; motion-aware correlation is still required. Diagnostic-only; not stable. |
| **Build207 / 0.14.40** | 80% soft-start / linear-tail carousel mapping | CI/IPA verified; target-device rejected as final. First visible displacement still too large and screenshots exposed structural foreground overlap: full-width foreground pages were only `0.80 × width` apart while EX preserved visible page separation. |
| **Build208 / 0.14.41** | Full-width carousel foreground page slots | **Current carousel candidate.** Uses `pageStep = width`, preserving ~56pt content separation with existing `width-56` foreground content; earliest attenuation tightened only for first samples. CI/IPA passed and independently verified; real-device pending. |
| **Build209 / 0.14.42** | Motion-aware poster-scroll diagnostics | Target-device App log proved three Home motion hitches but grid attribution was invalid because Home/grid shared one global observed-scroll owner. Diagnostic tested; not stable. |
| **Build210 / 0.14.43** | Multi-owner poster-scroll diagnostics | **Current poster diagnostic baseline.** Target-device log validates simultaneous Home/grid ownership (`registered_scrolls=2`) and correct grid routing. Four Home dragging hitches all landed 6.2–11.0 ms after image commit; the single grid record was programmatic/micro-motion (`phase=moving`, `delta_y=0.33`) and not yet a user-drag grid stall. Real-device diagnostic tested; no performance fix claimed; not stable. |

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

Target-device result: lifecycle/settle/reversal okay, minimum/subtle movement still too coarse versus EX. Input architecture retained.

### Build200 rejected visual mapping

- source: `4d3afe36768b7749d9d0bd0081725f3d947b2099`
- run/job: `32991758526` / `98250719262`
- artifact ID: `9614995121`
- IPA SHA-256: `509395ca7fb847548110c22ec0a3f6b005e6b3f4521f911eb9b3f765ca6d1b1a`
- real-device: rejected because foreground became fixed and no longer slid horizontally.

### Build201 partially positive real-device result

- tested source: `e61070146d91bac45400e3f95e28eead756faa81`
- run/job: `32993286519` / `98255950676`
- artifact ID: `9615585817`
- IPA SHA-256: `d889f2c36b3f617b429e4f39ba54d39d7f2826a058a2d4f874bc7a9bb574db58`
- horizontal foreground travel `0.15 × Hero width`, linear opacity blend.
- target-device result: **“有点那种感觉了”**, but total travel was insufficient.

### Build203 real-device result

- identity: **0.14.36 / 203**
- tested source: `69beee45b93dc11c7c5be2ee4b81a5a0157f2653`
- durable cleanup head: `edafd5d784cfacdcf8c451fad93535a55fb880fb`
- run/job: `32995898318` / `98264917294` — success
- artifact ID: `9616576496`
- IPA SHA-256: `cee7241b73c4dc38efb6593c3d6ec9f54981f8e5a609be78a491b869df685226`
- target-device: 30% total travel remained insufficient and the larger raw-linear mapping exposed coarse first displacement/jitter again.
- conclusion: visual spatial mapping, not the single UIKit lifecycle owner, remained the problem.

### Build204 carousel collision — retired

A carousel `0.14.37 / Build204` package was produced briefly, but the poster-scroll task already owned Build204. The carousel Build204 package is retired and must not be used for attribution.

### Build205 real-device result

- identity: **0.14.38 / 205**
- tested source: `e5f2e7b4135eca333d5dda24545f19ee8d0be439`
- durable cleanup head: `70d6cca676911e656591aae6b342c771cc92b9fe`
- run/job: `32998533448` / `98273968966` — success
- artifact ID: `9617634710`
- IPA SHA-256: `fe4a81ebee9d330526c108edf2ab4652632ae5b204719864e0b5dee486086479`
- 80% foreground travel; foreground/backdrop opacity and spatial offset both used clamped `progress²`.
- target-device: start over-restrained and whole-range nonlinear tail felt unnatural; curve rejected as final.

### Build207 real-device result — structural overlap discovered

- identity: **0.14.40 / 207**
- branch: `perf/home-carousel-soft-start-linear-tail-build207`
- tested source: `06936503a6c382d1d39d3cdd52f23bfe2058901e`
- durable cleanup head: `7044ca68c7082cd055a7e4ce42dda6f00fe29674`
- run/job: `33000526138` / `98280846494` — success
- artifact ID: `9618484884`
- IPA SHA-256: `bbd7c9c22c2a79a89f41e0d94db16023cf7cd2a720ffeb3c4f31cb9066a15a21`
- foreground page travel remained `0.80 × Hero width`; visual progress was `progress * (1 - 0.60 * (1-progress)^6)`.
- latest target-device screenshots on 2026-08-27 show two direct failures: earliest visible displacement is still too long, and adjacent foreground Logo/title/rating/overview content overlaps while EX shows a clear gap.
- source explains the overlap deterministically: each `carouselHeroForeground` is a full-width page, but outgoing/incoming page centers were kept only `0.80 × width` apart, forcing 20% page-frame overlap at every transition progress.
- existing page content width is `width - 56`; full-width page centers therefore imply ~56pt content separation.
- evidence: **Code written / CI passed / IPA produced+verified / real-device tested / foreground layout rejected / not stable.**

### Build208 current carousel candidate

- identity: **0.14.41 / 208**
- branch: `perf/home-carousel-page-slots-build208`
- base: Build207 durable cleanup head `7044ca68c7082cd055a7e4ce42dda6f00fe29674`
- tested source: **`2ad089f0ea8b4b6827257bb3a91a67c2d3748e5f`**
- durable cleanup head: **`51c366b6840d77c818eae20e1f3f43c0dbd75c72`**
- tested-source → cleanup-head delta: temporary Build208 workflow deletion only; product/runtime source unchanged.
- runtime delta is limited to `Sources/Core/AppIdentity.swift` + `Sources/UI/EmbyHomeCarouselStateV3.swift`.
- foreground page step is **`pageStep = width`**.
- outgoing offset = `-direction × visualProgress × pageStep`; incoming offset = `direction × (1 - visualProgress) × pageStep`.
- page-center separation is exactly one Hero width for all progress values; existing `contentWidth = width - 56` gives ~56pt constant content separation.
- earliest visual attenuation is clamped `progress * (1 - 0.85 * (1-progress)^6)`; this reduces only the first few-percent displacement versus Build207 while mid/late progress rapidly returns near linear and endpoint/tail remain natural.
- foreground/backdrop opacity uses the same visual progress.
- raw `transitionProgress`, 0.28 commit, 0.48×width predicted gate, reversal/settle ownership and first↔last modulo lookup are unchanged.
- source/Frozen guard: PASS.
- run/job: **`33004390654` / `98294100402` — success**.
- artifact: `OnePlayer-0.14.41-build208-home-carousel-page-slots`.
- artifact ID: **`9620046266`**.
- artifact digest / independently downloaded ZIP SHA-256: **`4ace3db785c131b987bfd9e18dc931e1bdeaf9f7528d85b8807214b45774afbb`**.
- IPA SHA-256: **`24f47ac5cd5685f6eea85b1c3a4fad2841d81f6169a90cd0629bea85a2072308`**.
- source ZIP SHA-256: **`807d03947c0d087ddc54f295e63fdabc37ac0ddfbe0e0f03da4477eb750e95ee`**.
- independent validation: artifact digest exact match; IPA/source hashes match embedded checksums; IPA `unzip -t` passed; bundle `com.embyplayerlab.app`; version/build `0.14.41 (208)`; OnePlayer primary/alternate icons; `MinimumOSVersion=15.0`; source snapshot confirms `pageStep = width`, `0.85` mapping and existing `width - 56` content width.
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
- target-device recording confirms stop-frame/catch-up hitch remains.

### Build204 — real-device rejected

- identity: **0.14.37 / 204**; canonical Build204 owner.
- exact CI source: `e6a97b5083691ed10795a402edc0fd30f996cffc`; durable cleanup head `170778c3934a280d9b539fb45f0bfef673687825`.
- run/job `32996847597` / `98268250117` — success; artifact ID `9617026984`; IPA SHA-256 `b4ba266086674f95a09ef92500c78926b4bc9cfd022c637075985cd55c598130`.
- target-device: visible hitching remains on both Home poster-heavy scrolling and library 3×3 pages.
- conclusion: no-op image-subscriber removal and warm-cache first-body seeding are retained reductions but are not sufficient to explain/fix the cross-page hitch.

### Build206 — target-device diagnostic capture obtained

- identity: **0.14.39 / 206**; poster-scroll owns this identity.
- exact diagnostic source: **`351c62694ac25404c2bd4eb36a03314dd58ffed2`**.
- runtime diagnostic scope: shared poster path only; one `CADisplayLink` while poster cells are visible, logging `PosterScrollHitch` only for display gaps ≥30 ms, with nearest cell-appear, image-commit and grid-load-ahead timestamps.
- no change to scroll mechanics, lazy-container semantics, image request sizing/caching policy, NavigationLink behavior, carousel input/state owner, Player/MPV/PiP/Transport/Cache/Session.
- run/job: **`33000992493` / `98282482225` — success**; artifact ID **`9618646972`**.
- IPA SHA-256: **`ee981133777c316305c4890aaa1a99b8906792783cad1496d880bf786611e18c`**.
- target-device App log contains **17** `PosterScrollHitch` records: row 7 / grid 10; grid max 118.7 ms.
- all 17 have `load_ahead=none`; 8/10 grid records happened >1 s after both most recent recorded cell appearance and image commit.
- exact-source limitation: diagnostics are not active-scroll/motion gated, so captured gaps cannot all be classified as proven user-visible scrolling stalls. Motion-aware correlation remains required.
- evidence: **Code written / CI passed / IPA produced+verified / target-device diagnostic capture / root-cause attribution incomplete / not stable.**

### Build209 — current motion-aware diagnostic candidate

- identity: **0.14.42 / 209**; poster-scroll owns this identity.
- Build206 base: `351c62694ac25404c2bd4eb36a03314dd58ffed2`.
- exact CI source: **`e95d73b75938ad92f2c4d7f06a3ba2d441bb92f4`**.
- exact Build206→Build209 delta is six files only: AppIdentity, Home scroll probe, shared grid probe, shared diagnostics, Build209 changelog and poster checker.
- runtime remains diagnostic-only: Home/shared 3-column routes resolve the real ancestor vertical non-paging `UIScrollView`; the existing single poster `CADisplayLink` samples `contentOffset.y`; `PosterScrollHitch` is emitted only for **gap ≥30 ms AND `delta_y != 0`**.
- each hitch adds `scroll_route`, `phase=dragging/decelerating/moving`, `offset_y`, `delta_y`, `velocity_y`, while retaining cell/image/load-ahead timing.
- no second display link, KVO polling, timer, retry/fallback, scroll-physics, image-policy, NavigationLink, carousel-owner or P0 playback/transport/cache/session change.
- Build208 / 0.14.41 is owned by Home-carousel; a poster package briefly built with that identity was retired before distribution and is not valid for poster attribution.
- run/job: **`33006881819` / `98302809290` — success**.
- artifact: `OnePlayer-0.14.42-build209-poster-motion-diagnostics`; artifact ID **`9621031556`**.
- artifact digest / independently downloaded artifact ZIP SHA-256: **`dc9d9aec4b266543fd894f8e6cdc6a5e811f88113c4a5fc7e1da83f1545dae7e`**.
- IPA SHA-256: **`85f6649352718a8cac2b269ee090e19bfbb173881845462ed1493e1d90129572`**.
- source ZIP SHA-256: **`4437f8e1c7af4f28ac4682c6eea05cbfdd86f2f2a806a793ec81f91353cb716b`**.
- independent validation: embedded checksums match; IPA `unzip -t` passed; bundle `com.embyplayerlab.app`; OnePlayer `0.14.42 (209)`; `MinimumOSVersion=15.0`; source snapshot confirms the motion gate, Home/grid probes, exactly one poster `CADisplayLink`, and no retired poster Build208 changelog.
- target-device App-log capture: **pending**.
- evidence: **Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device diagnostic pending / performance fix not claimed / not stable.**

### Build210 — target-device multi-owner diagnostic result

- exact source `9d8fd6a62e6e7d281d4fae5ab8442754a6362f47`; run/job `33009322419 / 98311176681`; artifact ID `9621956333`; IPA SHA-256 `813811fe0301cd8c942511e3e7786c184a80966960bf029ed3366d6edaa23701`.
- latest target-device log `OnePlayer-App-1787807430.log` contains five motion-gated hitches: Home 68.9 / 34.9 / 74.5 / 39.8 ms and grid 70.4 ms.
- all four Home entries are `phase=dragging` and are only 6.2–11.0 ms after the latest shared image commit, while last cell appearance is 6.6–14.3 s old.
- grid attribution now works: `scroll_route=grid registered_scrolls=2 moving_scrolls=1`. Its only entry is `phase=moving`, `delta_y=0.33`, velocity 0, image age 855.4 ms and cell age 1151.0 ms, so it is not yet a proven user-drag grid hitch.
- exact source confirms image decode is detached; image commit timestamp follows MainActor `@Published image` assignment. Home carousel image callback then synchronously runs Core Image contrast analysis and may update root Home state. This is the strongest Home lead, but shared image events lack source identity and the active Home-carousel task owns the likely callback/state files.
- evidence: **real-device diagnostic tested / multi-owner attribution validated / Home image correlation strong but not yet causal / grid user-drag attribution still incomplete / performance root cause unresolved / not stable.**

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
