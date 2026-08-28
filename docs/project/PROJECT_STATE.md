# OnePlayer Project State

_Last updated after Build230 target-device slow-drag title-shimmer remained and carousel Build231 / 0.14.64 foreground-compositing CI/IPA verification. Build216 remains the accepted overall runtime baseline; Build226 Hero residency + Build228 release-through-settle remain the positive carousel foundation._

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

### Build225 horizontal target-Hero A/B — positive real-device diagnostic

Build225 / 0.14.58 established that deferring target clear-Hero first presentation out of active drag makes the carousel noticeably finer. This remains direct evidence that active-drag target-Hero first presentation was a material contributor, but Build225 itself is diagnostic because incoming clear Hero is withheld until release.

### Build226 horizontal three-slot Hero residency — materially positive real-device direction

Build226 / 0.14.59 keeps current+previous+next clear Heroes resident so both adjacent targets are already presented before finger tracking while normal Hero and persistent crossfades are restored. The user now reports the overall carousel is **fairly close to EX and much better than the original OnePlayer carousel**, validating residency as the current presentation direction. The user still wants further refinement, and the supplied slow-drag recording exposes visible large white movie-title shimmer. Both recordings are 510×1108@30fps; they support visual findings but do not independently prove 120Hz parity. Frame inspection shows title, metadata and overview moving as one foreground page rather than a title-only geometry jump. Build226 is real-device materially positive but not stable/frozen.

### Build227 horizontal foreground physical-pixel A/B

Build227 / 0.14.60 isolates the new title-shimmer finding. It keeps Build226 behavior and rounds only the final foreground page X presentation to the current display physical-pixel grid. No new owner/state/timer/interpolation/offscreen-compositing layer is added. Dedicated Xcode 16.4 run/job `33153825917 / 98791806487` succeeded; tested source `7ac8de30b76192ee3cd9c9382edca74b9ff5e69d`; artifact `9678871748`; IPA SHA-256 `b24d8abcd91f4faa74e06d8485bac3611725c561d9c99144c17def4b8ef26766`; source ZIP SHA-256 `16bc14dd82cae7d2599f23fefaf7b5e4d9c95db6a17dbaa08921e3749f41d278`; OnePlayer 0.14.60 (227) / MinOS 15.0 independently verified. Evidence: **Code written / scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / diagnostic only / not stable**.

### Carousel Build228 release-tail result — accepted for now

Carousel Build228 / 0.14.61 (`perf/home-carousel-release-refresh-build228`) returns to the Build226 visual baseline and extends the already-proven device-max refresh request through interactive settle/cancel. Target-device feedback is **“差不多了，尾巴这里先这样吧”**. Treat this as acceptance of the release-tail subproblem for the current phase: retain max-refresh-through-settle and stop changing the existing 0.22 s commit / 0.18 s cancel easing, duration or velocity mapping unless new regression evidence appears.

This does **not** close the carousel task. Build227 physical-pixel foreground rounding is rejected because movie-title shimmer remained, and slow-drag title shimmer / residual overall refinement versus EX are still open. Build226 three-slot Hero residency remains the evidence-backed presentation foundation. Carousel Build228 evidence: tested source `bdf63c7562fcd1edc1d224872230e988ac462281`, run/job `33156739621 / 98801196041`, artifact `9679963420`, IPA SHA-256 `cda90b62e3cabd3199e1cfbc1b2e1c77b8a84d023a7c7b9c8e2ff66ab9edcf44`, MinOS 15.0. A separate poster task also used Build228/0.14.61; build number alone is not valid attribution.

### Carousel Build230 persistent residency — CI/IPA candidate

Build230 / 0.14.63 starts from the cleaned carousel Build228 foundation and reuses the existing current+previous+next resident window for `persistentCarouselBackdrop`. Normal current→target persistent opacity blending is unchanged; unlike Build221, the outgoing background is not frozen. This moves the adjacent target persistent 1400px + `scaleEffect(1.12)` + `blur(radius: 30)` presentation creation out of active finger tracking without adding another residency owner.

This candidate follows the remaining evidence after Build226: Hero first presentation was already moved out of active drag and improved hand feel, while Build227 still showed slow-drag title shimmer/cadence variability and exact source still created target persistent only after a drag transition began. Build230 does not claim the title is itself a persistent-layer bug; it tests whether the visible title shimmer is a high-contrast symptom of remaining whole-page cadence stalls.

CI/package: tested source `6324bb2063bf1631b8b922abc8e11149bd7a86b0`; Xcode 16.4 run/job `33167765310 / 98837170851` success; artifact `9684378135`; IPA SHA-256 `6cea81f8e806ec159d9e811871076c18aa41fceb99b3c621516c490cfc339b4e`; source ZIP SHA-256 `f0955926306e502d34e1835d9b5daffd7499c5bdc15abede9b31744eba9ee4ec`; OnePlayer 0.14.63 (230), MinOS 15.0 independently verified. Real-device pending. Acceptance must include both active-drag improvement and absence of a new post-settle hitch when the resident window rotates a new far neighbor.

### Build230 target-device result → Build231 foreground compositing A/B

Build230 target-device slow-drag feedback reports the movie-title shimmer still remains. Therefore pre-residing persistent neighbors is rejected as a sufficient title-shimmer fix; this report does not establish an overall-feel or post-settle verdict for Build230. Build231 returns to cleaned Build228 and isolates foreground child-layer presentation with one page-level `compositingGroup()` before unchanged opacity/X offset. Build231 exact source `d30092b8354553063c6d96b62a6f2f4387676601`, run/job `33169864030 / 98844082214`, artifact `9685231197`, IPA SHA-256 `b92eb47971c546cfe7044ebdbd94cc27a108f0febead32ec811d55e400df4571`, MinOS 15.0. Real-device pending; not stable.

## Active: Poster-heavy scrolling smoothness

### Poster Build228 device evidence → Build229 off-main persistence candidate

Build228 / 0.14.61 is now target-device diagnostic tested and **not** accepted as a smoothness fix; the user reports continued jitter and at times strong jitter. `OnePlayer-App-1787905589.log` captures a 55.1 ms real grid dragging long frame in the `StartIndex=60` pagination window. New Build228 instrumentation reports 0.0 ms latest image publish/Combine→UIKit adoption, 0.3 ms page apply, and 39.7 ms synchronous Library persistent-snapshot serialization/write ending ~8 ms before that hitch. This isolates Build213 Library persistence as a direct current severe-hitch contributor candidate, while Build212 remains the guardrail that it cannot explain the entire historical grid-hitch family.

Build229 / 0.14.62 exact source `f5e3e3eb144578c863b172e3bd3a1aa13e5c2177` makes one evidence-supported runtime change: Library snapshot state is still captured on the `@MainActor`, then its JSON conversion/serialization/atomic write is awaited on one serial utility queue. Snapshot identity/schema/content/order are retained; Favorites persistence is unchanged. Exact Build228→229 scope is five paths only. Dedicated Xcode 16.4 run/job `33156266871 / 98799654927` succeeded; artifact `9679803873`; IPA SHA-256 `49efcb8766cc9414a3f35e3d8fe75a04eaf6adf2ba86a40f526a5e53c40acd4c`; source ZIP SHA-256 `1de13e01617a575bf5b204e9dd546af443b8a7fdf79003e3eba1399edfb06e5a`; MinOS 15.0 independently verified. **Evidence: Code written / exact scope+checker / CI passed / IPA produced+verified / target-device pending / not stable.**

### Build229 package Home-only supporting capture

The immediate follow-up recording/log after Build229 does **not** exercise the intended Library 3×3 route. It is Home vertical scrolling, and its log contains only `HomeCarousel settled` events with no Library snapshot/pagination timing. Therefore Build229 remains target-device pending for its actual off-main persistence hypothesis.

The Home recording is 30 fps / 15.47 s. By filename timing, carousel settles land at approximately +5.214 s and +12.211 s, while frame motion shortly afterward shows near-zero/duplicate-frame → catch-up signatures. The roughly 7 s repetition matches the normal auto-advance/settle cadence in exact Build229 Home source. This is a plausible correlation for a periodic “sudden twitch” subtype, but it is not measured main-thread hitch proof because no `PosterScrollHitch` was emitted and 30 fps capture can duplicate frames. Build222 already proved that blocking new offscreen auto-advance does not remove overall Home vertical jitter, so no repeat of that patch is justified.

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

Build216 is the accepted overall runtime baseline after the detail episode-range inertia closeout. Home-carousel acceptance is horizontal drag/swipe behavior; Build225 proved target-Hero first presentation contributes materially to roughness; Build226 now has materially positive horizontal real-device evidence and validates three-slot Hero residency as the current presentation direction; Build227 is the current CI/IPA-verified foreground title-shimmer A/B pending target-device testing; Build221 is rejected as final and Build222–224 remain supporting vertical diagnostics only; poster-scroll Build220 remains an independent Active line. These keep separate branches/evidence. If a candidate is accepted on the target device, resync its durable product diff against then-current `main` in a separate integration step. If that resync materially changes source, rerun affected validation/CI; old-base CI cannot be treated as proof for changed merged source.
