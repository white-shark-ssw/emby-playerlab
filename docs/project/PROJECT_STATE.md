# OnePlayer Project State

_Last updated 2026-08-29: Home-carousel Build241 remains the user-accepted frozen carousel contract. Search Build244 has now been target-device tested and rejected as final; Search Build245 / OnePlayer 0.14.78 is CI/IPA verified and pending target-device validation. Build216 remains the accepted packaged overall runtime identity._

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

## Completed / frozen: Home carousel interaction — Build241 / 0.14.74

Work `DEV-home-carousel-drag-smoothness` is complete. The controlling product/runtime result is **Build241 / OnePlayer 0.14.74**, explicitly selected by the user as the final carousel version after target-device testing on iPhone 15 Pro Max / iOS 17.0.

Final Build241 behavior retains the evidence-backed single UIKit interaction owner, acquisition handling, full-width page slots, three-slot Hero residency, page-level foreground `compositingGroup()`, exact device-max refresh through settle, persistent white-flash correction, ordinary progress commit `>=0.28`, direction-aware latest-delivered fling commit `>=500 pt/s`, commit `.easeOut(duration: 0.22)` and cancel `.easeOut(duration: 0.18)`. No debounce accumulation, second SwiftUI gesture owner, interpolation, timer/watchdog/retry smoothing, or Build240 release-handoff diagnostic is part of the final contract.

Build241 exact tested source: `997a93a5f2c3c6544908ad112df5e714d2538e65`; run/job `33247149430 / 99086484795`; artifact `9713225510`; artifact digest `sha256:3ea36257c97b4a7947bb46e9aa1e0a5d2dcbd1a96ddf1977d58e0cada180525f`; IPA SHA-256 `338cd80de1671da4fedabdeecd9a001e98074dd119dcf331fda548b420f1f236`; source ZIP SHA-256 `b1e37c1c79f08552ad9de6819838cbca1b5b95cd4cc8a95c5b3ebf08a73ab664`; built MinOS 15.0. Evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested and user accepted ✅ / carousel stable-frozen ✅**.

The historical Build241 development branch was not merged wholesale because it had diverged from current `main` and contained unrelated temporary workflows/history. Instead, PR #262 integrated only the five exact Build241 runtime blobs (`EmbyHomeCarouselCadenceDiagnosticsV3.swift`, `EmbyHomeCarouselInteractionV3.swift`, `EmbyHomeCarouselStateV3.swift`, `EmbyHomeCoreV3.swift`, `EmbyHomeHeroV3.swift`) onto current `main`. PR #262 merged at `75d9f53d0984ee7f32e7e3fa02cd9bf8794b56e3`. Independent integration compile run/job `33248884259 / 99090990039` verified those exact blob identities, Release compilation for generic iOS, and MinOS 15.0. This integration CI is not a new real-device build; Build241 remains the real-device acceptance authority.

**Build242 / OnePlayer 0.14.75 is not a final version.** It was an intentionally altered diagnostic package that disabled the carousel presentation/runtime stack for Home-performance attribution and, per the user's final correction, the test modifications made it unsuitable/broken as normal carousel product behavior. Never inherit product behavior from Build242 and never call it stable/final. Its only durable diagnostic conclusion is that the user perceived little/no Home vertical-scroll difference versus Build241, so the whole carousel stack is not demonstrated to be a major Home-wide performance bottleneck. Normal settings behavior also returns `carouselItems == []` when the carousel is disabled, preventing the expensive persistent backdrop/Hero/preload/interaction presentation stack from mounting.

Do not reopen the carousel task unless new real-device regression evidence or an explicit new product requirement appears.

## Active: Search page optimization — Build245 / 0.14.78

Work `DEV-search-page-optimization` remains Active on `feat/search-page-optimization`, draft PR #264.

Build244 / OnePlayer 0.14.77 was the first competitor-aligned Search package and is now **target-device tested but rejected as final**. The user's iPhone 15 Pro Max / iOS 17.0 screenshots established five concrete defects: the leading gear was too large; focusing Search still changed root geometry and pushed the Dock upward; one active Emby target still showed the grouped row instead of entering full results directly; recommendations were artificially capped/filtered; and the landing title/input/history geometry remained visibly larger/lower than the supplied competitor.

Build245 / OnePlayer 0.14.78 makes only those evidence-backed Search changes. Exact tested product source `4c5f286ee870589bd2eac05119a516631a31391a`: gear font reduced exactly 40%; Search-owned title/input/history spacing and sizes tightened; Search keyboard safe-area ownership moved onto the actual root `GeometryReader`; exactly one active server now routes directly to the full paginated 3-column results page; recommendations now start at 12, carry no media-type filter and increase requested Emby Suggestions by 6 on approach to the end. The Emby Suggestions API has no `StartIndex`, so this uses increasing `Limit` plus deduplicated replacement rather than inventing pagination. Shared `EmbyPosterGrid.swift` remains untouched; Search uses its existing `horizontalPadding` input only.

Dedicated Xcode 16.4 Release/MPV run/job `33253244567 / 99102435848` succeeded. Artifact `OnePlayer-0.14.78-Build245-Search`, ID `9715042997`, digest `sha256:7b4fc1baab92d4a05feb3c7a1d9989ab688c6bf01a00907d51ca863abe431ffd`; IPA SHA-256 `19f69ca62928a65fb23bfdb44c67a916a7ba9edea20c3c3755f0875bb65a6514`; source ZIP SHA-256 `31b116e57265aee94bcfb577dc60f0fb86e61739728d50a94e536299db936349`. Independent download verification reproduced both hashes, IPA archive validation passed, and packaged identity is `com.embyplayerlab.app`, OnePlayer `0.14.78 (245)`, `MinimumOSVersion=15.0`. Temporary CI files were removed after packaging; cleanup branch head `e45c82f41d3dcf3a7d72c7f4e510627fbeada20f` does not change the exact tested runtime snapshot.

Evidence: **Build244 real-device tested/rejected as final; Build245 Code written ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device tested ❌ / stable-frozen ❌**. Next gate is the user's Build245 target-device comparison against the same competitor layout and five requirements.

## Active: Poster-heavy scrolling smoothness

### Poster Build228 device evidence → Build229 off-main persistence candidate

Build228 / 0.14.61 is now target-device diagnostic tested and **not** accepted as a smoothness fix; the user reports continued jitter and at times strong jitter. `OnePlayer-App-1787905589.log` captures a 55.1 ms real grid dragging long frame in the `StartIndex=60` pagination window. New Build228 instrumentation reports 0.0 ms latest image publish/Combine→UIKit adoption, 0.3 ms page apply, and 39.7 ms synchronous Library persistent-snapshot serialization/write ending ~8 ms before that hitch. This isolates Build213 Library persistence as a direct current severe-hitch contributor candidate, while Build212 remains the guardrail that it cannot explain the entire historical grid-hitch family.

Build229 / 0.14.62 exact source `f5e3e3eb144578c863b172e3bd3a1aa13e5c2177` makes one evidence-supported runtime change: Library snapshot state is still captured on the `@MainActor`, then its JSON conversion/serialization/atomic write is awaited on one serial utility queue. Snapshot identity/schema/content/order are retained; Favorites persistence is unchanged. Exact Build228→229 scope is five paths only. Dedicated Xcode 16.4 run/job `33156266871 / 98799654927` succeeded; artifact `9679803873`; IPA SHA-256 `49efcb8766cc9414a3f35e3d8fe75a04eaf6adf2ba86a40f526a5e53c40acd4c`; source ZIP SHA-256 `1de13e01617a575bf5b204e9dd546af443b8a7fdf79003e3eba1399edfb06e5a`; MinOS 15.0 independently verified. **Evidence: Code written / exact scope+checker / CI passed / IPA produced+verified / target-device pending / not stable.**

### Build229 package Home-only supporting capture

The immediate follow-up recording/log after Build229 does **not** exercise the intended Library 3×3 route. It is Home vertical scrolling, and its log contains only `HomeCarousel settled` events with no Library snapshot/pagination timing. Therefore Build229 remains target-device pending for its actual off-main persistence hypothesis.

The Home recording is 30 fps / 15.47 s. By filename timing, carousel settles land at approximately +5.214 s and +12.211 s, while frame motion shortly afterward shows near-zero/duplicate-frame → catch-up signatures. The roughly 7 s repetition matches the normal auto-advance/settle cadence in exact Build229 Home source. This is a plausible correlation for a periodic “sudden twitch” subtype, but it is not measured main-thread hitch proof because no `PosterScrollHitch` was emitted and 30 fps capture can duplicate frames. Build222 already proved that blocking new offscreen auto-advance does not remove overall Home vertical jitter, so no repeat of that patch is justified.

Work: `DEV-poster-grid-smoothness`.

### 2026-08-29 Build229 residual hitch / poster candidate collision

Build229 / 0.14.62 is now target-device tested for Library scrolling and overall 3×3 jitter still exists. The latest captured 77.2 ms moving hitch occurs about 7.3 s after page apply/snapshot completion and ~0.77 s after the latest image publish, so the off-main persistence change is not sufficient for the whole hitch family and this sample is not directly attributable to those recorded events. The earlier Build228 39.7 ms synchronous persistence remains a valid pagination-adjacent contributor only.

The poster branch/PR head is currently `deba1534e55bfc73f4d3cf43f2682c854a04cb39`, which materialized a diagnostic-only 0.14.66/Build233 commit on top of Build229. That candidate identity is invalid because the independent Home task already owns Build233 with CI/IPA evidence; Home also allocated Build234 and Aether reserves Build235. Under the current resume-identity rules, poster product development is paused until the user explicitly releases/reallocates the poster candidate and a fresh collision check passes. No poster Build233 CI/IPA/stability claim is valid.

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

Build216 is the accepted overall runtime baseline after the detail episode-range inertia closeout. Build241 is the frozen Home-carousel runtime contract integrated through PR #262. Search Build245 is an independent CI/IPA-verified candidate awaiting target-device validation; poster and Aether remain separate Active lines. If any active candidate is accepted on the target device, resync its durable product diff against then-current `main` in a separate integration step. If that resync materially changes source, rerun affected validation/CI; old-base CI cannot be treated as proof for changed merged source.


## Search Build252 Tag-content rejection → Build253 random Items candidate — 2026-08-30

Build252 is target-device rejected for recommendation semantics. OnePlayer surfaced `情趣内衣` and its detail page reports the object type as `Tag`, while the same server in official Emby Web Search shows actual movie/series recommendation titles. This demonstrates that `/Users/{userId}/Suggestions` is not the correct Search landing source for this server/client behavior.

Source evidence from `bpking1/embyExternalUrl` classifies Emby Web `/Users/(.*)/Items` requests with `SortBy=Random` as `searchSuggest`. Build253 exact product source `fc9e5bdf1c24e694c3d28e6c7f4a8f1609bfb5a5` therefore switches Search landing recommendations to one normal `/Users/{userId}/Items` request with `Recursive=true`, `SortBy=Random`, `Limit=9`, `IncludeItemTypes=Movie,Series`. No per-library traversal or `/Suggestions` call remains in the Search preloader. Existing startup/image cache and accepted Dock behavior remain unchanged.

Build253 / 0.14.86 run/job `33266680237 / 99137850447` passed Xcode 16.4 Release build/package. Artifact `9718894001`, digest `sha256:e687831d57682a1e3e86462c4ba7cd25ea196cc593a6b174af081f862e1e464e`; IPA SHA-256 `1c9454f49530ea8e41b6164fdcb88bee56bea9338a444c3485b0a2f28965cbf5`; MinOS 15.0. Evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device pending / not stable**.

## Search Build253 acceptance → Build254 incremental recommendations — 2026-08-30

Build253 / 0.14.86 is target-device accepted for Search recommendation content: the user confirmed all 9 initial cards are normal playable media. The authority remains normal `/Users/{userId}/Items` with `Recursive=true`, `SortBy=Random`, and `IncludeItemTypes=Movie,Series`; `/Suggestions` remains rejected for this Search role.

Build254 / 0.14.87 exact source `addddc6611a6210437271e4e6715aa88986afa23` adds only incremental recommendation loading: the accepted first 9 remain unchanged; when the current last lazy-grid card enters the viewport, OnePlayer requests 6 more with the same Items/Random/Movie+Series contract plus `ExcludeItemIds` containing every already-visible recommendation ID, then appends only new IDs. Newly fetched poster URLs are warmed through the existing `EmbyImageDiskCache`/decoded pool; no new cache, `StartIndex + Random`, timer, debounce, retry, fallback, watchdog or load-more ProgressView was introduced. Build248 Dock/keyboard behavior is unchanged.

Xcode 16.4 Release run/job `33268846116 / 99143580223` passed. Artifact `9719501314`, digest `sha256:3acf642efefccc6b6ea440e6e383bfb2b6cb80a449ca52d89efc39a909d2dc3f`; IPA SHA-256 `7714f225b55a4c93e96aa35951820d43e6be33fa911e14ff378755ac23884130`; `com.embyplayerlab.app`; `0.14.87 (254)`; MinOS 15.0; IPA integrity passed. Evidence: **Build253 initial recommendation semantics real-device accepted ✅ / Build254 Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / incremental load-more target-device pending / not stable**.
