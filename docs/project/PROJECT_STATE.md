# OnePlayer Project State

_Last updated after Build225 / 0.14.58 horizontal target-Hero A/B CI/IPA verification. Build216 remains the accepted overall runtime baseline. Build221 is horizontally real-device tested and rejected as the final frozen-persistent strategy because overall feel still trails EX and a pale/white transition regression is visible. Build225 restores normal persistent crossfade and defers only target Hero clear-image mounting during active horizontal drag; target-device horizontal testing is pending. Build222–224 remain supporting vertical diagnostics only._

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

### 2026-08-28 acceptance-scope correction

The user explicitly corrected the task scope after Build224: **optimize the carousel itself**. Home vertical inertial scrolling can expose shared rendering pressure, but it is not the acceptance criterion for `DEV-home-carousel-drag-smoothness`. Build224 still showed visible vertical jitter after removing Hero clear artwork, but no horizontal carousel verdict was gathered from that test. Therefore Build222–224 are closed as a supporting vertical diagnostic detour. The direct carousel lane resumes at Build221 / 0.14.54, which is already CI/IPA verified and isolates persistent backdrop presentation only during active horizontal drag. No new vertical-only candidate should be created before Build221 is tested horizontally on the target device.

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

### Retained carousel behavior baseline: Build215 / 0.14.48

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

Build217 then measured the unchanged Build215 interaction at roughly 50–60 Hz delivered/publish/render/display cadence despite `maximum_fps=120`; Build219 isolated the frame-rate request and raised the same chain to roughly 98–110 Hz on the target device. The user's on-screen FPS recording repeatedly reaches 118–120 FPS, proving the request is effective. Remaining discrete 34–50 ms gaps frequently occur within ~3–25 ms of Hero/persistent 1400px image callbacks, so the active carousel investigation now shifts to that image publication/presentation path rather than new motion easing or coalesced-touch authority.

Build219 remains the controlling real-device diagnostic evidence: the 120 Hz request is effective, and its strongest repeatable residual pattern is a 50 ms display gap ~19.6–25.3 ms after target persistent 1400px callbacks. Source inspection shows those callbacks occur after an already-decoded image is adopted by a newly mounted full-screen persistent SwiftUI image that also carries `scaleEffect(1.12)` and `blur(radius: 30)`; Build212 already ruled out the synchronous callback/contrast calculation itself as a 50 ms cost.

Build221 / 0.14.54 is now target-device tested for the intended horizontal interaction. It kept Build219 high refresh and Build215 motion semantics while freezing the outgoing persistent backdrop during active drag. The user reports acceptable initial take-up but overall hand feel still trailing EX, and the supplied recording visibly shows pale/white washed intermediate frames. Because Hero current/target artwork still crossfades while persistent is frozen, the A/B creates a mismatched backing during transition; this visual regression must not be retained. Build221 therefore rejects the whole-drag frozen-persistent strategy as a sufficient/final solution. Next horizontal diagnostic should isolate Hero clear-image presentation while restoring normal persistent behavior; do not continue vertical Home A/Bs.

### Build222 Home vertical architecture A/B result

Independent Build222 / 0.14.55 tested one narrow lifecycle hypothesis from the accepted Build216/main product baseline: once Home has scrolled away from the top, `autoAdvanceCarouselIfNeeded()` no longer starts a new automatic transition. It intentionally leaves persistent backdrop, preload, Hero and horizontal interaction unchanged and does not stack Build221. CI/IPA passed (`33101409110 / 98619779746`, artifact `9658757261`, tested source `694221315c727ea055ea3b5ef7a9ea03a260fe80`, IPA SHA-256 `8cf6d454bf7eec64207875e9c20a1bbc6b125578f11fb777bfdda4fa6b5c5bfe`, MinOS 15.0). Target-device feedback still perceives Home vertical hitching, so offscreen auto-advance alone is rejected as a sufficient fix. The supplied 30fps recording cannot prove the remaining 120Hz micro-stutter; its clearest zero→jump points coincide with new swipe starts. Next vertical A/B should isolate the root-level always-mounted persistent backdrop only, keeping preload and Build221 separate.

### Build223 Home vertical persistent-backdrop A/B

Build223 / 0.14.56 is the next independent Home vertical diagnostic from accepted Build216/main behavior, not a stack on Build221 or Build222. Its only runtime presentation change is that immersive Home no longer mounts the always-on full-screen `persistentCarouselBackdrop`; `persistentCarouselBackdrop` / `carouselPersistentImage` and the existing 30pt blur implementation remain in source, `carouselPreloadLayer` stays mounted, Hero artwork is unchanged, normal Build216 auto-advance behavior remains, and horizontal interaction/P0/Frozen paths are untouched. Dedicated Xcode 16.4 run/job `33110117601 / 98650408622` succeeded; tested source `af54d693d91303ea9bd201b5525e24f3e15ad931`; artifact `9662245993`; IPA SHA-256 `a925714dceb138df7808079b5784f3337afe92245bd790c42c290eac82ccd73c`; source ZIP SHA-256 `b14860b0a5889b39be17eeac8aeacf0621c6c68784058f463f00eae3057a5432`; OnePlayer 0.14.56 (223) and MinOS 15.0 were independently re-opened/verified. Target-device result on iPhone 15 Pro Max / iOS 17.0: **obvious Home vertical jitter remains**, so persistent full-screen removal is rejected as a sufficient fix. The unchanged Home Dock still uses `.ultraThinMaterial`; removing the full-screen backdrop changed the surface behind that material and produced the reported gray/translucent Dock strip. This is an unintended Build223 diagnostic visual regression, not an intentional Dock redesign, and must not be carried forward. Evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device tested / hypothesis rejected as sufficient / Dock visual regression observed / not stable**. Next vertical candidate must restore the accepted Build216 background/Dock presentation and isolate one remaining carousel-owned presentation component at a time.

### Build224 Home vertical Hero-artwork A/B

Build224 / 0.14.57 removed only the clear Hero 1400px artwork mounts while retaining the accepted persistent background/Dock, preload, persistent blur, foreground, auto-advance and horizontal interaction. Dedicated Xcode 16.4 run/job `33142773132 / 98757057369` succeeded; artifact `9674622017`; IPA SHA-256 `5b8c973cb5d34cf843f2649bda72f6a3f48ab5766c023b9c3e587f9eb4d9c845`; MinOS 15.0. Target-device feedback on 2026-08-28 still reports visible **Home vertical inertial-scroll jitter**. This is now recorded as vertical supporting evidence only: the user clarified that the active goal is horizontal carousel swipe/drag smoothness, and this Build224 test did not provide a horizontal verdict. Do not continue the carousel task with another vertical-only A/B.

### Build225 horizontal target-Hero A/B

Build225 / 0.14.58 branches from the exact Build219 tested 120Hz carousel source rather than stacking Build221 or the vertical Build222–224 experiments. Normal persistent current/target crossfade is restored. During active horizontal drag the already-visible current Hero remains opaque and target `carouselHeroArtwork` 1400px clear-image mounting is deferred until drag ends; foreground page motion, acquisition-relative input, release gates, preload and exact device-max refresh remain unchanged. Dedicated Xcode 16.4 run/job `33149313932 / 98777365879` succeeded; tested source `350fd5d07ae2e77907bcf497deb819dfea6a28b1`; artifact `9677114082`; artifact SHA-256 `5e6d94602ef2c08ff3611bb8d749c6c9bd69df8a5f5bdeb089677ffa15cf3914`; IPA SHA-256 `221162e47de335b665cad6e0dd48aa82a8e27bb50cadcc24c2c6888d26db000a`; source ZIP SHA-256 `2849308d7a8e8f5c479a17e30ef6645bcf87f5f358065ba8b6dba7608623095e`; OnePlayer 0.14.58 (225) and MinOS 15.0 were independently verified. Evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / diagnostic only / not stable**. Next action is target-device horizontal carousel A/B only.

## Active: Poster-heavy scrolling smoothness

Work: `DEV-poster-grid-smoothness`.

- Build212 remains the route-split evidence authority: Home hitches correlate with the separate 1400px carousel image path, while 11 real grid dragging hitches correlated with newly visible `network/display/Primary/378` publication. Home and grid are separate runtime paths.
- Build218 introduced the grid/display-only UIKit image surface so surrounding SwiftUI poster cells no longer observe display-loader image publication. Home remained visibly hitchy and the package exposed a shared transparent-Logo background regression; the latter was corrected without touching carousel owner source.
- Build220 / 0.14.53 exact tested source **`6198466a749a54603a67c6c32bc0efcf9d7e2082`** is synchronized onto accepted Build216 main and carries that transparency correction. Exact seven-path scope/checker passed; run/job **`33083504023 / 98556783889`** success; artifact **`9651230376`**; artifact SHA-256 `fc1cd17fe974b6e35b2eda03eb32718ca3fca6fa4034406016385a9aa5c1f729`; IPA SHA-256 `a73a33866745418663d1dcc35634f5b21b0a73436a91f40ed8a4f6dc6bbcf574`; source ZIP SHA-256 `7c222973433e8e94608946fc5ffda4e5ec4442a9c6200be4b98e84d680695fad`; OnePlayer 0.14.53 (220), MinOS 15.0 independently verified.
- **2026-08-27 target-device result:** user reports the intended 3×3 scrolling feel is **“基本一样”**. This is controlling evidence; Build220 is not accepted as a smoothness improvement.
- Uploaded `OnePlayer-App-1787845216.log` contains two grid hitch records. The stronger user-drag sample is **33.3 ms**, `phase=dragging`, `delta_y=5.33`; latest `network/display/Primary/378` commit age **35.8 ms**, latest cell/load-ahead age **171.7 ms**, and the `StartIndex=60` request began about 164 ms before the hitch. A second **74.1 ms** `phase=moving` sample has image age **1010.1 ms** and cell/load-ahead age **1146.1 ms**, so it does not support an immediate image-publish trigger.
- Exact source shows Build220 still assigns decoded images to `@Published image` on the MainActor; that synchronous assignment delivers through Combine to the UIKit surface and then `UIImageView.image`. Current `imageDidCommit` timing is recorded only after the assignment and does not measure this publish/sink/adoption cost or bursts. Thus Build220 rejects only the surrounding SwiftUI poster-cell observation hypothesis as sufficient; it does not clear the remaining main-thread image-adoption/compositor path.
- The first sample is also pagination-adjacent. Build216's library page model applies appended items on MainActor and synchronously persists the page snapshot. That should be timed separately, but Build212 predates Build213 persistent caching, so persistence cannot be the universal historical cause of the 3×3 hitch family.
- Current evidence: **Code written / synchronized scope+checker / CI passed / IPA produced+verified / target-device tested / 3×3 basically unchanged / candidate rejected as sufficient / root cause unresolved / not stable**.

Next: make the next poster build diagnostic-only. Measure MainActor image-assignment duration including synchronous Combine→`UIImageView` delivery and publish bursts, and separately measure pagination result application plus persistent snapshot serialization/write. Do not introduce another smoothing patch until those costs are separated. Home remains owned by the independent carousel task.

## Parallel integration rule

Build216 is the accepted overall runtime baseline after the detail episode-range inertia closeout. Home-carousel acceptance is horizontal drag/swipe behavior; Build225 is the current CI/IPA-verified target-Hero horizontal A/B pending target-device testing; Build221 is real-device rejected as final and Build222–224 remain supporting vertical diagnostics only; poster-scroll Build220 remains an independent Active line. These keep separate branches/evidence. If a candidate is accepted on the target device, resync its durable product diff against then-current `main` in a separate integration step. If that resync materially changes source, rerun affected validation/CI; old-base CI cannot be treated as proof for changed merged source.
