# OnePlayer Project State

_Last updated after Home-carousel Build201 target-device feedback became partially positive and Build203 completed CI/IPA, and after poster-scroll Build202 was target-device rejected while Build204 completed CI/IPA. Build199 remains the latest real-device accepted overall baseline. Home-carousel Build203 and poster-scroll Build204 are independent Active candidates; neither is stable or merged._

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
- actual touch drives rendering; predicted touch is release-only;
- commit threshold 0.28;
- predicted-distance release gate 0.48 × width;
- existing settle ownership/timing;
- no second SwiftUI drag/release owner;
- no interpolation/timer/watchdog/retry/debounce/throttle.

### Real-device history that controls the current direction

- Build198: lifecycle/settle/reversal behavior became acceptable, but minimum/subtle page movement remained too coarse versus EX.
- Build200: fully fixed foreground + linear crossfade passed CI/IPA but was rejected on the target device because foreground stopped sliding horizontally. Fully fixed foreground is rejected.
- Build201 / 0.14.34: restored horizontal motion with total travel `0.15 × Hero width` and linear blend. CI/IPA passed and was independently verified. On 2026-08-27 the user reported **“有点那种感觉了”**, then requested `15% → 30%` travel plus opacity that changes little at drag start and increasingly faster later, including left/right and first↔last wrapping.

Build201 evidence:

- branch: `perf/home-carousel-short-travel-build201`
- tested source: `e61070146d91bac45400e3f95e28eead756faa81`
- run/job: `32993286519` / `98255950676`
- artifact ID: `9615585817`
- IPA SHA-256: `d889f2c36b3f617b429e4f39ba54d39d7f2826a058a2d4f874bc7a9bb574db58`
- evidence: **real-device tested / direction partially positive / not stable**.

### Current candidate: Build203 / 0.14.36

Build202/Build204 belong to the independent poster-scroll task, so carousel uses Build203.

- branch: `perf/home-carousel-accelerating-blend-build203`
- base: Build201 tested source `e61070146d91bac45400e3f95e28eead756faa81`
- tested source: `69beee45b93dc11c7c5be2ee4b81a5a0157f2653`
- durable cleanup head: `edafd5d784cfacdcf8c451fad93535a55fb880fb`
- tested-source → cleanup-head: temporary Build203 workflow deletion only; product/runtime source unchanged.
- runtime product delta from Build201: `Sources/Core/AppIdentity.swift` + `Sources/UI/EmbyHomeCarouselStateV3.swift` only.
- foreground total travel: **`0.30 × Hero width`**.
- backdrop and foreground blend: **clamped `progress²`**.
- outgoing opacity: `1 - blend`; incoming opacity: `blend`.
- requested perceptual behavior: minimal opacity change at drag start, increasingly faster change later.
- blend is direction-independent; existing `(index + direction + count) % count` neighbor lookup remains first↔last wrapping authority, so no boundary-specific state machine was added.
- Build198 gesture owner/thresholds/release/settle remain unchanged.
- Frozen Player/MPV/PiP/UnifiedTransport/Cache/Emby playback/session paths untouched.

Build203 CI / IPA:

- run/job: **`32995898318` / `98264917294` — success**
- artifact: `OnePlayer-0.14.36-build203-home-carousel-accelerated-blend`
- artifact ID: **`9616576496`**
- artifact digest / independently downloaded ZIP SHA-256: `5df63c68c6a8f97d5c41d12040c297e5d4ca6e58d00aae89b0c17ce5a6441310`
- IPA SHA-256: **`cee7241b73c4dc38efb6593c3d6ec9f54981f8e5a609be78a491b869df685226`**
- source ZIP SHA-256: **`4b916a508e258949f9c17b449d38e782030a1130e36d08868cd1c54797a00135`**
- independently verified: artifact/IPA integrity, bundle `com.embyplayerlab.app`, version/build `0.14.36 (203)`, OnePlayer icons, MinOS 15.0, `** BUILD SUCCEEDED **`.
- evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / not stable.**

Next action: install/test Build203 on target device; compare tiny drag, later opacity acceleration, normal left/right, first↔last/last↔first wraps, reversal, cancel/commit, vertical Hero scroll, detail tap and auto-advance. Do not alter gesture ownership before that evidence.

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
- source ZIP SHA-256: `19ebc6a2bcefd61d53eb4a9eea7617d5e98be7f8ae7b4f2dbf027ff62d8fabfe`
- latest target-device recording `RPReplay_Final1787766039.mp4`: **510×1108 / 30 fps / 205 frames / 6.833 s**.
- around **4.067 s**, vertical movement is approximately **`-6.36 px → 0 px → -26.19 px`** across consecutive recorded transitions, directly confirming the stop-frame/catch-up hitch remains.
- recording starts after Hero is scrolled away and the stall occurs while poster rows continue entering view; visible posters are already rendered and there is no obvious single network image-arrival event exactly at the freeze.
- conclusion: **Build202 = Code written / CI passed / IPA produced+verified / real-device tested / smoothness rejected / not stable.**

### Current poster candidate: Build204 / 0.14.37

Build203 belongs to the independent carousel task, so poster-scroll uses Build204.

Source evidence after Build202 rejection identified two deterministic ordinary-poster cell-entry costs still present in Build202:

- every ordinary image installed `loader.$image` subscriber machinery even when it had no `onImageLoaded` consumer;
- a newly-created warm-cache ordinary cell hit the decoded-memory pool during `onAppear` and synchronously published `image = rendered`, immediately invalidating the just-created SwiftUI cell a second time.

Build204 therefore makes only the following common-path change:

- no-callback ordinary poster images install no image-publisher subscriber;
- only no-callback ordinary images seed `EmbyCachedImageLoader` from the existing decoded-memory cache at StateObject construction, allowing a warm-cache UIImage to be present on the first body pass;
- the later `onAppear` sees the same URL/image and returns without the second cached-image publication;
- real `onImageLoaded` paths used by Hero/detail/carousel retain their previous publisher/dedup/callback semantics and are not warm-seeded;
- existing Build202 lazy-layout, image-size, loading-state and nil-publication reductions remain;
- no NavigationLink rewrite is made because the current recording/profile evidence does not tie destination construction to the stall.

Build204 evidence:

- exact CI source: **`e6a97b5083691ed10795a402edc0fd30f996cffc`**
- durable cleanup head: **`170778c3934a280d9b539fb45f0bfef673687825`**
- tested-source → cleanup-head: temporary Build204 feature workflow deletion only; product/runtime source unchanged.
- runtime delta from Build202: `Sources/Core/AppIdentity.swift` + `Sources/UI/EmbySharedImageAndNavigation.swift` only.
- run/job: **`32996847597` / `98268250117` — success**
- artifact: `OnePlayer-0.14.37-build204-poster-warm-cache`
- artifact ID: **`9617026984`**
- artifact digest / independently downloaded artifact ZIP SHA-256: **`7115be086057ba9254012df365e2e3f9b0f2d30a2d587b9e6bfcb65756c0f794`**
- IPA SHA-256: **`b4ba266086674f95a09ef92500c78926b4bc9cfd022c637075985cd55c598130`**
- source ZIP SHA-256: **`9f04a9f40f7f2617b0c9edee6cd2844cd4d3d7beed169eb5431ecbef5c01c506`**
- independently verified: artifact/IPA/source integrity, bundle `com.embyplayerlab.app`, version/build `0.14.37 (204)`, OnePlayer icons, MinOS 15.0, `** BUILD SUCCEEDED **`.
- no Player/MPV/PiP/Transport/Cache/Session or active carousel owner file changed.
- evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / not stable.**

Next action: test Build204 first on the same Home poster-row path, especially while lower rows enter view, then library 3×3, favorites/more, search, tag search and actor/person results. If the stop/catch-up remains, do not jump to NavigationLink/container rewrites without new evidence.

## Parallel integration rule

Build199 remains the accepted overall baseline. Build203 and Build204 are independent feature candidates with different Build identities and branches. If either is accepted on the target device, resync its durable product diff against then-current `main` in a separate integration step. If that resync materially changes source, rerun affected validation/CI; old-base CI cannot be treated as proof for changed merged source.