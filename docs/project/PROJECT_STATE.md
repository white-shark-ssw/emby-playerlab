# OnePlayer Project State

_Last updated 2026-08-30: Build257 Home auto-advance gating is target-device verified as fallback-only containment, not the preferred final smoothness architecture. Build258 target-device cadence diagnostics establish a shared ~16.67 ms 3×3 baseline across Library/Search/detail-filter on the 120 Hz target device. Build259 / 0.14.92 is the current device-max-refresh A/B; CI/IPA verified, target-device pending. Search Build256 remains stable/merged and its recommendation semantics are protected._

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

Build241 manual horizontal interaction/presentation remains frozen. New 2026-08-30 target-device evidence has reopened only the automatic-transition scheduling sub-contract: auto-advance overlapping Home vertical inertia causes a repeatable large hitch. Do not retune Build241 manual drag/release/presentation behavior from this evidence.

## Completed: Search page optimization — Build256 / 0.14.89

Search is complete and stable for its functional task. Build256 exact product source `723d803c70326dee49aabc75f15ce445b7de947e` was accepted on iPhone 15 Pro Max / iOS 17.0; run/job `33271528610 / 99150738764`; artifact `9720282077`; IPA SHA-256 `01cf29fa117df904307286066c131d68be0e89b8f8f4a26b8b960c29ae6afce5`; MinOS 15.0. PR #264 merged at `647c1f66e5836fcd20a23a57600211488eeafb3d`. Final contract: no app-start recommendation fetch; Search entry starts a fresh lifetime with initial 9 Movie/Series Random Items; incremental +6 batches exclude displayed IDs; detail push/pop preserves the loaded dataset; Dock switch away destroys it; re-entry starts fresh. Shared image caches remain independent.

The active poster-smoothness task now profiles the shared 3×3 presentation also used by Search. That performance work does not reopen the accepted Search data source, pagination semantics, state lifetime or Dock behavior.

## Active: Poster-heavy scrolling smoothness

### 2026-08-30 Build257 fallback acceptance → Build258 cadence evidence → Build259 high-refresh A/B

Build257 / 0.14.90 is target-device tested: its real-`UIScrollView` drag/deceleration gate prevents a new Home auto-advance transition from beginning during vertical motion and contains the previously repeatable large overlap hitch. The user explicitly classifies this as a fallback/workaround rather than the preferred final solution; PR #265 is closed without merge. Build241 manual carousel interaction/presentation remains frozen.

Build258 / 0.14.91 exact source `165dffac8690c85283e7a53f4a0b7a20eeb52f8c` is target-device diagnostic tested. `OnePlayer-App-1788082165.log` shows Library fixed `60→60` and Search full-results fixed `18→18` repeatedly clustering around display p50/p95 `16.67 ms` while `maximum_fps=120`; detail-filter shows the same baseline. Cell churn and load-ahead are not universal correlates. Search `推荐观看` uses the already-accepted Build256 implementation and shows an additional append-tail during four +6 batches (`15→39`, display p99 34.84 ms, max 52.39 ms), but that cannot explain the fixed-item baseline. Search Build256 / PR #264 is already merged at `647c1f66e5836fcd20a23a57600211488eeafb3d`; its functional contract remains protected.

Build259 / 0.14.92 exact source `39168e560d7e626557de8ebde6a88a5d38b3478b`, Draft PR #267, directly extends Build258 by changing only AppIdentity, the existing cadence owner, changelog and checker. The existing single cadence `CADisplayLink` requests an 80→device-max frame-rate range only while a real shared-3×3 drag/deceleration session is active, then returns to `.default`. No Grid/image/paging/Search/Home runtime/Player/Transport behavior changes. Xcode 16.4 run/job `33304743577 / 99239168487` succeeded; artifact `9730129850`, digest `sha256:ac44fcb213597b8ea8cc536c35dc21a157bb2832b869fac33cf5c17633085a1a`; IPA SHA `6d257396ba7a77178e62535c5dd04db58621ea25cf4a30e7e9bf415c7628a18a`; source ZIP SHA `dd121c94b7392abf647ec5471506a6dec903652c7f7f68a19f29ac567660710a`; MinOS 15.0. Evidence remains CI/IPA only for Build259; target-device hand-feel/cadence A/B is pending.

### Poster Build228 device evidence → Build229 off-main persistence candidate

Build228 / 0.14.61 is now target-device diagnostic tested and **not** accepted as a smoothness fix; the user reports continued jitter and at times strong jitter. `OnePlayer-App-1787905589.log` captures a 55.1 ms real grid dragging long frame in the `StartIndex=60` pagination window. New Build228 instrumentation reports 0.0 ms latest image publish/Combine→UIKit adoption, 0.3 ms page apply, and 39.7 ms synchronous Library persistent-snapshot serialization/write ending ~8 ms before that hitch. This isolates Build213 Library persistence as a direct current severe-hitch contributor candidate, while Build212 remains the guardrail that it cannot explain the entire historical grid-hitch family.

Build229 / 0.14.62 exact source `f5e3e3eb144578c863b172e3bd3a1aa13e5c2177` makes one evidence-supported runtime change: Library snapshot state is still captured on the `@MainActor`, then its JSON conversion/serialization/atomic write is awaited on one serial utility queue. Snapshot identity/schema/content/order are retained; Favorites persistence is unchanged. Exact Build228→229 scope is five paths only. Dedicated Xcode 16.4 run/job `33156266871 / 98799654927` succeeded; artifact `9679803873`; IPA SHA-256 `49efcb8766cc9414a3f35e3d8fe75a04eaf6adf2ba86a40f526a5e53c40acd4c`; source ZIP SHA-256 `1de13e01617a575bf5b204e9dd546af443b8a7fdf79003e3eba1399edfb06e5a`; MinOS 15.0 independently verified. **Evidence: Code written / exact scope+checker / CI passed / IPA produced+verified / target-device pending / not stable.**

### Build229 package Home-only supporting capture

The immediate follow-up recording/log after Build229 does **not** exercise the intended Library 3×3 route. It is Home vertical scrolling, and its log contains only `HomeCarousel settled` events with no Library snapshot/pagination timing. This Home-only capture did not validate the Library hypothesis; the subsequent Library 3×3 target-device result below supersedes that pending state and confirms overall hitching remains.

The Home recording is 30 fps / 15.47 s. By filename timing, carousel settles land at approximately +5.214 s and +12.211 s, while frame motion shortly afterward shows near-zero/duplicate-frame → catch-up signatures. The roughly 7 s repetition matches the normal auto-advance/settle cadence in exact Build229 Home source. This is a plausible correlation for a periodic “sudden twitch” subtype, but it is not measured main-thread hitch proof because no `PosterScrollHitch` was emitted and 30 fps capture can duplicate frames. Build222 already proved that blocking new offscreen auto-advance does not remove overall Home vertical jitter, so no repeat of that patch is justified.

Work: `DEV-poster-grid-smoothness`.

### 2026-08-29 Build229 residual hitch / poster candidate collision

Build229 / 0.14.62 is now target-device tested for Library scrolling and overall 3×3 jitter still exists. The latest captured 77.2 ms moving hitch occurs about 7.3 s after page apply/snapshot completion and ~0.77 s after the latest image publish, so the off-main persistence change is not sufficient for the whole hitch family and this sample is not directly attributable to those recorded events. The earlier Build228 39.7 ms synchronous persistence remains a valid pagination-adjacent contributor only.

The historical poster `deba1534e55bfc73f4d3cf43f2682c854a04cb39` diagnostic head used the colliding 0.14.66/Build233 identity and remains invalid for attribution. That identity has now been retired. The real poster branch / Draft PR #259 head is `53a704c2ed752adf023ea3c7f08d7f90f7559133`, which relabels only AppIdentity/changelog to unique OnePlayer **0.14.76 / Build243** while retaining the already-written measurement-only background-image-work diagnostics.

Build243 is now Xcode 16.4 CI/IPA verified. Exact Build229→243 scope is four paths only; poster checker and package guards passed. Run/job `33300155220 / 99226651825`; artifact `9728697893`, digest `sha256:33ebe84f2864ba4494c4b6c164f77730d2eb383a969e2e0d9c98aac8cc0b9cf1`; IPA SHA-256 `f8a7d792f70c970314080a56ef78a9f5734697e7a27373bf67b44dd3d4871d75`; source ZIP SHA-256 `641a720cae3550b160fce7cf223d0ec397df0c3aac6041b0a17f60c8ee37c2f9`; package `com.embyplayerlab.app`, `0.14.76 (243)`, MinOS 15.0 independently verified. Build243 only records active poster image disk-read / detached-decode / network / disk-write work at existing hitch timing; it does not change image policy or scrolling behavior. **Evidence: Code written / exact scope+checker / CI passed / IPA produced+verified / target-device pending / not stable.**

- Build212 remains the route-split evidence authority: Home hitches correlate with the separate 1400px carousel image path, while 11 real grid dragging hitches correlated with newly visible `network/display/Primary/378` publication. Home and grid are separate runtime paths.
- Build218 introduced the grid/display-only UIKit image surface so surrounding SwiftUI poster cells no longer observe display-loader image publication. Home remained visibly hitchy and the package exposed a shared transparent-Logo background regression; the latter was corrected without touching carousel owner source.
- Build220 / 0.14.53 exact tested source **`6198466a749a54603a67c6c32bc0efcf9d7e2082`** is synchronized onto accepted Build216 main and carries that transparency correction. Exact seven-path scope/checker passed; run/job **`33083504023 / 98556783889`** success; artifact **`9651230376`**; artifact SHA-256 `fc1cd17fe974b6e35b2eda03eb32718ca3fca6fa4034406016385a9aa5c1f729`; IPA SHA-256 `a73a33866745418663d1dcc35634f5b21b0a73436a91f40ed8a4f6dc6bbcf574`; source ZIP SHA-256 `7c222973433e8e94608946fc5ffda4e5ec4442a9c6200be4b98e84d680695fad`; OnePlayer 0.14.53 (220), MinOS 15.0 independently verified.
- **2026-08-27 target-device result:** user reports the intended 3×3 scrolling feel is **“基本一样”**. This is controlling evidence; Build220 is not accepted as a smoothness improvement.
- Uploaded `OnePlayer-App-1787845216.log` contains two grid hitch records. The stronger user-drag sample is **33.3 ms**, `phase=dragging`, `delta_y=5.33`; latest `network/display/Primary/378` commit age **35.8 ms**, latest cell/load-ahead age **171.7 ms**, and the `StartIndex=60` request began about 164 ms before the hitch. A second **74.1 ms** `phase=moving` sample has image age **1010.1 ms** and cell/load-ahead age **1146.1 ms**, so it does not support an immediate image-publish trigger.
- Exact source shows Build220 still assigns decoded images to `@Published image` on the MainActor; that synchronous assignment delivers through Combine to the UIKit surface and then `UIImageView.image`. Current `imageDidCommit` timing is recorded only after the assignment and does not measure this publish/sink/adoption cost or bursts. Thus Build220 rejects only the surrounding SwiftUI poster-cell observation hypothesis as sufficient; it does not clear the remaining main-thread image-adoption/compositor path.
- The first sample is also pagination-adjacent. Build216's library page model applies appended items on MainActor and synchronously persists the page snapshot. That should be timed separately, but Build212 predates Build213 persistent caching, so persistence cannot be the universal historical cause of the 3×3 hitch family.
- Current evidence: **Code written / synchronized scope+checker / CI passed / IPA produced+verified / target-device tested / 3×3 basically unchanged / candidate rejected as sufficient / root cause unresolved / not stable**.

Next: target-device test the already-built Build243 diagnostic candidate on Library 3×3 and correlate each `PosterScrollHitch` / `PosterScrollTiming` with active background image work. Do not introduce another smoothing patch until this evidence exists. Home carousel remains frozen/owned separately.

## Parallel integration rule

Build216 is the accepted overall runtime baseline after the detail episode-range inertia closeout. Home-carousel acceptance is horizontal drag/swipe behavior; Build225 proved target-Hero first presentation contributes materially to roughness; Build226 now has materially positive horizontal real-device evidence and validates three-slot Hero residency as the current presentation direction; Build227 is the current CI/IPA-verified foreground title-shimmer A/B pending target-device testing; Build221 is rejected as final and Build222–224 remain supporting vertical diagnostics only; poster-scroll Build243 remains the independent Active diagnostic line, with Build229 still controlling the latest target-device runtime verdict. These keep separate branches/evidence. If a candidate is accepted on the target device, resync its durable product diff against then-current `main` in a separate integration step. If that resync materially changes source, rerun affected validation/CI; old-base CI cannot be treated as proof for changed merged source.


## Active: Search page / recommendations — Build247 / 0.14.80

Build246 / 0.14.79 is now target-device tested and rejected as final: Search keyboard focus still lifts the bottom Dock, the recommendation wall is still slow on entry/later posters, the required Movie/Series whitelist was not sufficiently enforced at the returned-item level, and recommendation load-more still causes visible container twitch.

Build247 exact CI product source `5f693d82041bbb59d3fe481aa708b22a5feda42d` changes the Search-owned path only. The visible Search Dock is mounted by `EmbyServerRootViewV3` instead of the nested Search `NavigationView`; returned recommendations are hard-filtered to actual Emby `Movie`/`Series` types; `RootView` starts one process-lifetime bounded 60-item recommendation warm after `SessionStore.restore()`; the warm reuses the existing `EmbyImageDiskCache` and `EmbyDecodedImageRenderPool` for the exact Search poster URLs; and the Search recommendation grid no longer performs incremental Suggestions requests or item-count growth while the user scrolls. Keyword Search remains separate because its term is unavailable at app launch. Shared `EmbyPosterGrid.swift` / `EmbySharedImageAndNavigation.swift` and all Player/Transport/playback-cache/PiP/Frozen contracts are unchanged.

Dedicated Xcode 16.4 Release run/job `33258792907 / 99117036605` succeeded; artifact `9716657082`; artifact digest `sha256:9628b0c608488edbfc5af477199e847e5a35b119d4ab96edbecd036cbde4bfd1`; IPA SHA-256 `952b2daeef4bc01fe62476611c6620cf7ce79d3905d87bd82336e4650d0d69b0`; source ZIP SHA-256 `44494de6213883b8bee16b6e99336b33073ed38b17a53062f9be7a2cff22b73d`; independently verified identity `com.embyplayerlab.app`, `0.14.80 (247)`, MinOS 15.0, IPA integrity passed. Evidence: **Code written ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device tested ❌ / stable/frozen ❌**.


## Search Build247 device rejection → Build248 candidate — 2026-08-29

Build247 / 0.14.80 was target-device tested and rejected as final. The supplied screenshot shows the root-owned Search Dock below the normal server-page vertical band and partially outside the physical screen. Exact source explains this: Search root overlay aligned to `fullHeight = geometry.size.height + geometry.safeAreaInsets.bottom` without compensating the extra bottom inset. The same build also remained indefinitely on the recommendation spinner because its startup preloader attempted to collect 60 items while each library Suggestions request asked for up to 100 items, despite the product requirement being only an up-to-3×3 recommendation wall.

Build248 / 0.14.81 exact CI source `dc601099ded1074fafc0c7a4e000b8c6fd4c7338` keeps the Build247 ownership correction but adds bottom-safe-area compensation to the root Search Dock. The recommendation preloader is bounded to 9 visible Movie/Series items and each library request asks only for the remaining slots. Returned-item Movie/Series hard filtering, startup one-shot warm, existing image disk/decoded cache ownership, and removal of recommendation load-more remain. Dedicated run/job `33259763303 / 99119574495` passed; artifact `9716945819`; artifact digest `sha256:b15d327e7f628188e9df6a500ff0e26227a149a60a03b6bd1595c9aa82fffd2a`; IPA SHA-256 `8eb734bb26b77f377314223acbf7306da72ac9254a20586bfc443d59fea940c5`; source ZIP SHA-256 `94ce1911d3981d8f5ad53bc59a8a7413a1ddf54a54c1a97e49642b1b909f1bec`; bundle `com.embyplayerlab.app`; MinOS 15.0; IPA integrity independently verified. Evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending / not stable**.


## Search Build248 log evidence → Build249 recommendation traversal candidate — 2026-08-29

Build248 / 0.14.81 is now target-device tested. The user confirms the Search Dock vertical position is correct and focusing the input no longer moves it; preserve this accepted Dock ownership/safe-area behavior. Recommendations still remain on the spinner. Uploaded `OnePlayer-App-1788018797.log` shows Suggestions calls at 15:53:02.153, 04.609, 07.188, 09.961, 12.498, 14.952 and 17.412, so the network is not stuck on a single request: the Search preloader is serially traversing user libraries. Exact Build248 source asks every `userViews` entry for Movie+Series and only publishes after accumulating 9 accepted items or exhausting all views, allowing incompatible/non-video views to consume full request latency while contributing zero accepted items.

Build249 / 0.14.82 exact CI source `f49ed220367de1ffbf9e9a5aba097d2ce160dac7` changes only the Search recommendation preloader runtime plus changelog. It uses the already-decoded real `CollectionType`, queries only `movies`, `tvshows`, and `mixed`, maps requests to Movie / Series / Movie+Series respectively, preserves the hard returned-item Movie/Series whitelist, 9-item cap, startup one-shot warm and existing image caches, and adds diagnostics for total/eligible views and returned/accepted counts. Run/job `33261820598 / 99124950794` passed; artifact `9717502081`; digest `sha256:3cc924d6733cb4590361fa255d85ef2c31f879f07538e11523a6e246da487510`; IPA SHA-256 `0c62d51d488197b55dbfb98ab104c48404dd0caac77d786523f753c75acbb7a0`; bundle `com.embyplayerlab.app`; MinOS 15.0; IPA integrity independently verified. Evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / Build249 real-device pending / not stable**.


## Search Build249 nil-Type rejection → Build250 candidate — 2026-08-30

Build249 / 0.14.82 is target-device rejected for recommendation first paint while its inherited Search Dock remains accepted. Uploaded `OnePlayer-App-1788020447.log` shows `recommendation warm libraries total=21 eligible=19`; the first Movie Suggestions call returns 9 items in about 2.8 s but `accepted=0`, and the first TV call returns 9 in about 2.5 s but `accepted=0`. Exact source required returned `LibraryItem.type` to be non-nil, so Emby Suggestions responses lacking a usable `Type` were all discarded even though each request was already constrained by `IncludeItemTypes=Movie` or `Series`. This forced serial traversal through many eligible libraries and explains the endless spinner.

Build250 / 0.14.83 exact successful CI source `6e7ae960bd3cc353b8d6146aea363f3876e9e8e8` preserves CollectionType source selection and Movie/Series request filtering. If returned `Type` exists, actual Movie/Series remains mandatory; if Suggestions omits `Type`, the exact server-side `IncludeItemTypes` request is accepted as whitelist authority only when all requested types are Movie/Series. The Search view consumes this validated result without the old second `Type != nil` filter. Final run/job `33263279291 / 99128762968` passed; artifact `9717900754`; digest `sha256:f5cad646e230ffe1666e30fd2b6ce472b5d16cace168a850c9f07cf0e43e35e0`; IPA SHA-256 `f213b3d6f30ac101d563e3894c3352fdcd9c9bcb46c7a266faa48c8577e73ada`; bundle `com.embyplayerlab.app`; MinOS 15.0; IPA integrity independently verified. A prior intermediate run `33263000305` failed compilation due an accidental stale Search-view replacement and produced no candidate IPA; it is superseded and is not product evidence. Build250 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device pending / not stable**.


## Search Build250 rejection → Build251 global Suggestions candidate — 2026-08-30

Build250 / 0.14.83 is target-device rejected for recommendation first paint: the Search page still remained on the spinner. The user then compared the same server in official Emby Web, where entering Search immediately produced built-in `更多推荐` with normal movie/series content. This evidence supersedes the per-library traversal direction.

Source inspection showed OnePlayer already used Emby's `/Users/{userId}/Suggestions`, but added `ParentId` and serially traversed `UserViews`. Build251 exact runtime source `cc1806d7f606581e138579b44d94e16dc9ff7135` changes only this scope: one user-global Suggestions request, no `ParentId`, `IncludeItemTypes=Movie,Series`, `Limit=9`. Existing Movie/Series whitelist, startup warm, image disk cache, decoded-image cache, accepted Dock behavior and all Player/Transport/P0 contracts remain unchanged.

Build251 / 0.14.84 run/job `33264608646 / 99132347141` passed Xcode 16.4 Release build/package. Artifact `9718288974`, digest `sha256:da474aaa24a3d8ff65e41ed990b861ba377f6a92938670bfe89a9625d8cc4470`; IPA SHA-256 `4923368ddca5bca9e3d9db83234b19547b12673feb22af50fd3e3279b08cc750`; bundle `com.embyplayerlab.app`; MinOS 15.0; IPA integrity passed. Evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device pending / not stable**.


## Search Build251 real-device result → Build252 direct Suggestions payload — 2026-08-30

Build251 target-device testing changed the diagnosis again: the global Suggestions request now completes quickly, but the Search page shows no recommendation content. Uploaded `OnePlayer-App-1788023908.log` records one global `/Users/{userId}/Suggestions` call with `Limit=9&IncludeItemTypes=Movie,Series`, followed by `returned=9 nilType=0 accepted=0`. Thus the server delivered a full 3×3 payload; OnePlayer discarded it locally.

Build252 exact product source `dbfd323ec4a14e12dc57293c98b1fe6fbe239c5e` removes only that second local rejection and consumes the exact Emby global Suggestions payload. The request remains server-constrained to Movie/Series, startup warm/image caches remain, and Build248 Dock behavior plus all Player/Transport/P0 contracts are untouched. Run/job `33265539007 / 99134824511` passed; artifact `9718566319`; IPA SHA-256 `b4dd85fb880692e0b24c481d58079d2bb33db1609669d7e93a3244c53fc8e236`; MinOS 15.0. Build252 awaits target-device validation.


## Search Build252 Tag-content rejection → Build253 random Items candidate — 2026-08-30

Build252 is target-device rejected for recommendation semantics. OnePlayer surfaced `情趣内衣` and its detail page reports the object type as `Tag`, while the same server in official Emby Web Search shows actual movie/series recommendation titles. This demonstrates that `/Users/{userId}/Suggestions` is not the correct Search landing source for this server/client behavior.

Source evidence from `bpking1/embyExternalUrl` classifies Emby Web `/Users/(.*)/Items` requests with `SortBy=Random` as `searchSuggest`. Build253 exact product source `fc9e5bdf1c24e694c3d28e6c7f4a8f1609bfb5a5` therefore switches Search landing recommendations to one normal `/Users/{userId}/Items` request with `Recursive=true`, `SortBy=Random`, `Limit=9`, `IncludeItemTypes=Movie,Series`. No per-library traversal or `/Suggestions` call remains in the Search preloader. Existing startup/image cache and accepted Dock behavior remain unchanged.

Build253 / 0.14.86 run/job `33266680237 / 99137850447` passed Xcode 16.4 Release build/package. Artifact `9718894001`, digest `sha256:e687831d57682a1e3e86462c4ba7cd25ea196cc593a6b174af081f862e1e464e`; IPA SHA-256 `1c9454f49530ea8e41b6164fdcb88bee56bea9338a444c3485b0a2f28965cbf5`; MinOS 15.0. Evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device pending / not stable**.

## Search Build256 accepted and merged — 2026-08-30

The user accepted Build256 / OnePlayer 0.14.89 as the final Search implementation on iPhone 15 Pro Max / iOS 17.0. Exact tested product source `723d803c70326dee49aabc75f15ce445b7de947e`; Xcode 16.4 Release run/job `33271528610 / 99150738764`; artifact `9720282077`; IPA SHA-256 `01cf29fa117df904307286066c131d68be0e89b8f8f4a26b8b960c29ae6afce5`; MinOS 15.0. PR #264 merged to `main` at `647c1f66e5836fcd20a23a57600211488eeafb3d`. Final contract: Search recommendations load on Search entry rather than app startup; initial 9 + incremental 6 use normal Movie/Series Items with Random and exclusion paging; detail return preserves the current Search lifetime; manual Dock switch destroys it; re-entry starts fresh; accepted Dock/keyboard and append-layout behavior remain intact. Search is stable/final.
