# DEV-search-page-optimization

- Status: Completed — Build256 target-device accepted and merged to `main` through PR #264 at `647c1f66e5836fcd20a23a57600211488eeafb3d`
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Final PR: #264 — merged at `647c1f66e5836fcd20a23a57600211488eeafb3d`
- Build248 identity: **OnePlayer 0.14.81 / Build248** — Dock/keyboard behavior accepted on target device
- Build249 identity: **OnePlayer 0.14.82 / Build249** — recommendation rejected on target device
- Build250 identity: **OnePlayer 0.14.83 / Build250** — recommendation rejected on target device
- Build251 exact runtime source: `cc1806d7f606581e138579b44d94e16dc9ff7135`
- Build251 identity: **OnePlayer 0.14.84 / Build251**
- Build251 run/job: `33264608646 / 99132347141` — success
- Build251 artifact: `OnePlayer-0.14.84-Build251-Search`, ID `9718288974`
- Build251 IPA SHA-256: `4923368ddca5bca9e3d9db83234b19547b12673feb22af50fd3e3279b08cc750`
- Build252 exact product source: `dbfd323ec4a14e12dc57293c98b1fe6fbe239c5e`
- Build252 identity: **OnePlayer 0.14.85 / Build252**
- Build252 run/job: `33265539007 / 99134824511` — success
- Build252 artifact: `OnePlayer-0.14.85-Build252-Search`, ID `9718566319`, digest `sha256:15343da3075db72f32349250d0dc9a1a7b67ecb325bbcd507ea22276084abb9c`
- Build252 IPA SHA-256: `b4dd85fb880692e0b24c481d58079d2bb33db1609669d7e93a3244c53fc8e236`
- Build253 exact product source: `fc9e5bdf1c24e694c3d28e6c7f4a8f1609bfb5a5`
- Build253 identity: **OnePlayer 0.14.86 / Build253**
- Build253 run/job: `33266680237 / 99137850447` — success
- Build253 artifact: `OnePlayer-0.14.86-Build253-Search`, ID `9718894001`, digest `sha256:e687831d57682a1e3e86462c4ba7cd25ea196cc593a6b174af081f862e1e464e`
- Build253 IPA SHA-256: `1c9454f49530ea8e41b6164fdcb88bee56bea9338a444c3485b0a2f28965cbf5`
- Build254 exact product source: `addddc6611a6210437271e4e6715aa88986afa23`
- Build254 identity: **OnePlayer 0.14.87 / Build254**
- Build254 run/job: `33268846116 / 99143580223` — success
- Build254 artifact: `OnePlayer-0.14.87-Build254-Search`, ID `9719501314`, digest `sha256:3acf642efefccc6b6ea440e6e383bfb2b6cb80a449ca52d89efc39a909d2dc3f`
- Build254 IPA SHA-256: `7714f225b55a4c93e96aa35951820d43e6be33fa911e14ff378755ac23884130`
- Build255 exact product source: `99af35f86229ca5fb0cf9699fb41ef1bf5c754d2`
- Build255 identity: **OnePlayer 0.14.88 / Build255**
- Build255 run/job: `33270048487 / 99146794862` — success
- Build255 artifact: `OnePlayer-0.14.88-Build255-Search`, ID `9719867060`, digest `sha256:a39fcdd34b8016f35ac8e952740879cc0e43e2373437a7e3bd2e8d02d1de1a1f`
- Build255 IPA SHA-256: `2dbc76a146d4716eee0965c6861823e0df5592324812584fe261a30afb98019e`
- Build256 exact product source: `723d803c70326dee49aabc75f15ce445b7de947e`
- Build256 identity: **OnePlayer 0.14.89 / Build256**
- Build256 run/job: `33271528610 / 99150738764` — success
- Build256 artifact: `OnePlayer-0.14.89-Build256-Search`, ID `9720282077`, digest `sha256:e9c3f0756cb4dbd7a0fa9f2785594fa3df7e41964f472426a14e6c50a231615e`
- Build256 IPA SHA-256: `01cf29fa117df904307286066c131d68be0e89b8f8f4a26b8b960c29ae6afce5`
- Built/target MinOS: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0

## Accepted Search Dock baseline

Build248 target-device testing confirmed the Search Dock position matches the other server pages and focusing the Search input no longer moves it. Preserve this behavior unchanged.

## Build250 target-device result — 2026-08-30

Build250 still remained on the recommendation spinner. The user then demonstrated official Emby Web Search on the same account/server immediately shows built-in `更多推荐`, which superseded OnePlayer's per-library traversal direction.

## Build251 target-device result — 2026-08-30

Build251 switched Search recommendations to one user-global `/Users/{userId}/Suggestions` request with no `ParentId`, `Limit=9`, and `IncludeItemTypes=Movie,Series`. The spinner now ends quickly, but no recommendation content appears.

Uploaded `OnePlayer-App-1788023908.log` proves the global request itself succeeds: `/Users/{userId}/Suggestions?...Limit=9&IncludeItemTypes=Movie,Series` returned 9 items, `nilType=0`, while the local post-filter accepted 0. Therefore Build251 fixed request scope/latency but still discarded the complete Emby Suggestions payload after receipt.

Build251 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / request latency improved ✅ / recommendation display rejected ❌ / not stable**.

## Build252 correction

Exact product source `dbfd323ec4a14e12dc57293c98b1fe6fbe239c5e` keeps the single user-global Suggestions request with `IncludeItemTypes=Movie,Series` and removes only the incompatible second client-side type rejection. Search now consumes the exact 9-item Suggestions payload returned by that already constrained Emby request. A returned-type histogram diagnostic is retained for evidence.

No library traversal, retry, fallback, timer, watchdog, second cache, shared poster-grid edit, Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115, Resume/progress, credentials or Deployment Target change.

Build252 / OnePlayer 0.14.85 run/job `33265539007 / 99134824511` passed Xcode 16.4 Release build/package. Artifact `9718566319`; IPA SHA-256 `b4dd85fb880692e0b24c481d58079d2bb33db1609669d7e93a3244c53fc8e236`; bundle `com.embyplayerlab.app`; MinOS 15.0; IPA integrity passed.

Build252 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ❌ / stable/frozen ❌**.

## Build252 target-device content result → Build253 Emby Web-aligned random Items — 2026-08-30

Build252 / OnePlayer 0.14.85 is target-device rejected for recommendation semantics. The user opened an item surfaced from OnePlayer Search recommendations and the detail page identified it as `Tag` (`情趣内衣`), while official Emby Web Search on the same server shows actual movie/series titles. This proves `/Users/{userId}/Suggestions` is not the same data source as Emby Web Search landing recommendations in this environment, even when OnePlayer sends `IncludeItemTypes=Movie,Series`.

External source inspection of `bpking1/embyExternalUrl`, which classifies real Emby Web `/Users/(.*)/Items` traffic, shows requests with `SortBy=Random` are explicitly classified as `searchSuggest`. This matches the official Web behavior and supersedes the `/Suggestions` direction.

Build253 exact product source `fc9e5bdf1c24e694c3d28e6c7f4a8f1609bfb5a5` adds a Search-specific normal Items query: `/Users/{userId}/Items?Recursive=true&Limit=9&SortBy=Random&IncludeItemTypes=Movie,Series`. The Search preloader now uses only this query; startup warm, persistent image cache, decoded-image cache and Build248-accepted Dock/keyboard behavior are unchanged. No retry, fallback, timer, watchdog, per-library traversal or second cache was added.

Build253 / OnePlayer 0.14.86 run/job `33266680237 / 99137850447` passed Xcode 16.4 Release build/package. Artifact `9718894001`, digest `sha256:e687831d57682a1e3e86462c4ba7cd25ea196cc593a6b174af081f862e1e464e`; IPA SHA-256 `1c9454f49530ea8e41b6164fdcb88bee56bea9338a444c3485b0a2f28965cbf5`; bundle `com.embyplayerlab.app`; MinOS 15.0; IPA integrity passed.

## Build253 target-device result — 2026-08-30

The user confirmed on iPhone 15 Pro Max / iOS 17.0 that all 9 Search landing recommendations are normal media items. The prior Tag/Genre metadata-object problem is resolved for the tested Build253 path, and the `Items + SortBy=Random + IncludeItemTypes=Movie,Series` recommendation semantics are accepted as the current baseline.

Build253 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / 9-item recommendation semantics accepted ✅ / stable/frozen ❌**.

## Next exact action

Evaluate and implement incremental recommendation loading below the accepted initial 3×3 wall without changing the accepted Build253 recommendation source. Preferred direction is to keep `/Users/{userId}/Items` + `SortBy=Random` + `IncludeItemTypes=Movie,Series`, request another small batch when the user approaches the bottom, and exclude already-present item IDs so appended recommendations do not duplicate existing cards. Do not use `StartIndex` as the primary anchor for a random sort.

## Build253 target-device acceptance → Build254 incremental recommendations — 2026-08-30

The user target-device tested Build253 / OnePlayer 0.14.86 and confirmed all 9 Search landing recommendations are normal playable movie/series items. This accepts the Search recommendation data source contract: `/Users/{userId}/Items` + `SortBy=Random` + `Recursive=true` + `IncludeItemTypes=Movie,Series`. Build248 Dock/keyboard behavior remains accepted. Search remains Active because the user now requests continued recommendation loading while scrolling.

Build254 reserves OnePlayer 0.14.87 / Build254. It preserves the accepted first 9 exactly, then requests 6 more only when the current last recommendation card reaches the lazy-grid viewport. The follow-up request uses the same normal Items/Random/Movie+Series contract plus Emby's supported `ExcludeItemIds` containing every already-visible recommendation ID. New unique items append in place; no `StartIndex + Random`, timer, debounce, retry, fallback, watchdog, second cache or load-more ProgressView is added. Newly fetched posters reuse the existing persistent `EmbyImageDiskCache`, decoded image pool and Search-lifetime pinning.

## Build254 CI / IPA evidence — 2026-08-30

Exact product source `addddc6611a6210437271e4e6715aa88986afa23` preserves the Build253 first 9 recommendation request and adds only incremental +6 retrieval using the same `/Users/{userId}/Items` + `SortBy=Random` + `Recursive=true` + `IncludeItemTypes=Movie,Series` contract with `ExcludeItemIds` for all already-visible IDs. The current last lazy-grid card triggers the request; returned unique IDs append in place. No `StartIndex + Random`, timer, debounce, retry, fallback, watchdog, second cache or load-more ProgressView was added.

Xcode 16.4 Release run/job `33268846116 / 99143580223` passed source validation, MPVKit resolution, Release build, packaged identity verification and IPA integrity. Artifact `9719501314`, digest `sha256:3acf642efefccc6b6ea440e6e383bfb2b6cb80a449ca52d89efc39a909d2dc3f`; IPA SHA-256 `7714f225b55a4c93e96aa35951820d43e6be33fa911e14ff378755ac23884130`; bundle `com.embyplayerlab.app`; version `0.14.87 (254)`; MinOS 15.0. Evidence: **Code written ✅ / CI passed ✅ / IPA produced+independently verified ✅ / incremental load-more real-device tested ❌ / not stable**.

## Next exact action

Target-device test Build254. Verify the accepted first 9 remain fast/correct, reaching the last visible recommendation appends 6 new non-duplicate Movie/Series items, repeated downward scrolling continues in +6 batches without container twitch, earlier posters remain resident/cached, and the accepted Dock/keyboard behavior is unchanged.

## Build254 target-device result → Build255 container stability correction — 2026-08-30

Build254 / OnePlayer 0.14.87 is now target-device tested on iPhone 15 Pro Max / iOS 17.0. The user reports only one remaining issue: incremental recommendation loading works, but the Search recommendation container visibly twitches when the +6 append occurs. The accepted first 9 Movie/Series semantics, continued loading, duplicate exclusion and Build248 Dock/keyboard behavior otherwise remain accepted for this test. Build254 is therefore rejected as the final incremental-loading candidate and is not stable.

Source inspection shows Search landing uniquely wraps the dynamically growing recommendation grid in an outer `LazyVStack`, while the established paginated poster page in `V3LibraryBrowserView.pagedPosterTab` uses a normal `VStack` around `EmbyPosterGrid` as pages append. Build255 reserves OnePlayer 0.14.88 / Build255 and changes only this Search landing layout owner from `LazyVStack` to `VStack`. The inner `EmbyPosterGrid` remains lazy, the accepted last-card +6 trigger remains unchanged, and there is no new timer, debounce, retry, fallback, watchdog, spinner, cache or shared poster-grid modification.

## Build255 CI / IPA evidence — 2026-08-30

Exact product source `99af35f86229ca5fb0cf9699fb41ef1bf5c754d2` changes only the Search landing section owner from outer `LazyVStack` to `VStack`. The dynamically growing poster collection remains the existing inner `EmbyPosterGrid`/`LazyVGrid`; the Build254 last-card +6 trigger, `ExcludeItemIds` duplicate exclusion, accepted Movie/Series recommendation request, image caches/pins and Build248 Dock/keyboard behavior are unchanged. No shared poster-grid, Player, MPV, Transport, playback Session Cache, Resume/progress, PiP or Deployment Target code changed.

Dedicated Xcode 16.4 Release run/job `33270048487 / 99146794862` passed source validation, MPVKit resolution, Release build, identity verification, IPA packaging/integrity and artifact upload. Artifact `9719867060`, digest `sha256:a39fcdd34b8016f35ac8e952740879cc0e43e2373437a7e3bd2e8d02d1de1a1f`; independently verified IPA SHA-256 `2dbc76a146d4716eee0965c6861823e0df5592324812584fe261a30afb98019e`; bundle `com.embyplayerlab.app`; version `0.14.88 (255)`; `MinimumOSVersion=15.0`. Evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / Build255 target-device tested ❌ / stable/frozen ❌**.

## Next exact action

Target-device test Build255 on iPhone 15 Pro Max / iOS 17.0. Repeatedly scroll through the initial 9 recommendations into successive +6 appends and verify the visible Search container/viewport no longer twitches or jumps while load-more still continues and displayed IDs remain non-duplicate.

## Build255 target-device result → Build256 Search-tab lifetime correction — 2026-08-30

Build255 / OnePlayer 0.14.88 is target-device tested. After loading recommendation batches beyond the initial 9, opening a movie detail and returning causes Search to return to the initial state: the appended recommendation items are lost and only 9 remain. This is a lifecycle/state-ownership rejection; Build255 is not stable.

Source inspection identifies two concrete owners that conflict with the requested behavior: app startup calls `V3SearchRecommendationPreloader.shared.start(...)` and the shared preloader retains initial recommendation metadata by session; meanwhile `V3EmbyGlobalSearchView` owns its `V3GlobalSearchViewModel` locally and its `.task` calls `loadRecommendations` without guarding already-loaded items. Build256 reserves OnePlayer 0.14.89 / Build256 and changes those exact owners: no app-start Search recommendation fetch; a fresh Search model is created only when Dock enters Search; the server root retains that model while Search pushes/pops detail; initial load runs only while the retained model has no recommendation items; manually switching Dock away from Search sets the model to nil, so recommendation metadata is destroyed; re-entering Search creates a fresh model and fetches a new initial 9. The shared preloader no longer retains recommendation metadata/tasks across Search lifetimes. Existing image disk/decoded caches remain shared and unchanged.

## Build256 CI / IPA evidence — 2026-08-30

Exact product source `723d803c70326dee49aabc75f15ce445b7de947e` removes app-start Search recommendation fetching, removes session-global recommendation metadata/task retention from `V3SearchRecommendationPreloader`, moves the Search model lifetime to `EmbyServerRootViewV3`, and prevents initial recommendation reload when the retained model already has items. The model survives Search detail push/pop while the selected Dock tab remains Search; switching Dock away from Search sets the model to nil, so recommendation metadata is destroyed; re-entering Search creates a fresh model and fetches a new initial 9. Shared image disk/decoded caches remain unchanged.

Dedicated Xcode 16.4 Release run/job `33271528610 / 99150738764` passed source validation, MPVKit resolution, Release build, identity verification, IPA packaging/integrity and artifact upload. Artifact `9720282077`, digest `sha256:e9c3f0756cb4dbd7a0fa9f2785594fa3df7e41964f472426a14e6c50a231615e`; independently verified IPA SHA-256 `01cf29fa117df904307286066c131d68be0e89b8f8f4a26b8b960c29ae6afce5`; bundle `com.embyplayerlab.app`; version `0.14.89 (256)`; `MinimumOSVersion=15.0`. Evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / Build256 target-device tested ❌ / stable/frozen ❌**.

## Next exact action

Target-device test Build256. Verify app startup does not fetch Search recommendations; first entering Search fetches the initial 9; after several +6 appends, opening a detail and returning preserves the already-loaded recommendation list while remaining on Search; manually switching Dock away from Search destroys that list; re-entering Search performs a fresh initial-9 load.

## Build256 target-device acceptance — 2026-08-30

The user accepted Build256 / OnePlayer 0.14.89 on the target device as the final Search implementation. Accepted behavior: app startup performs no Search recommendation fetch; entering Search creates a fresh Search lifetime and loads the initial 9 Movie/Series recommendations; incremental random recommendation loading continues in +6 batches without duplicates or the Build254 container twitch; opening a recommendation detail and returning preserves the already-loaded recommendation dataset while Search remains the selected Dock page; manually switching Dock away from Search destroys that Search dataset; re-entering Search creates a fresh lifetime and fetches a new initial 9. Build248 Dock/keyboard behavior, Build253 Items+Random recommendation authority, Build254 ExcludeItemIds pagination contract, and Build255 non-lazy outer section owner are all retained.

Final accepted Build256 evidence: exact product source `723d803c70326dee49aabc75f15ce445b7de947e`; Xcode 16.4 Release run/job `33271528610 / 99150738764`; artifact `9720282077`; artifact digest `sha256:e9c3f0756cb4dbd7a0fa9f2785594fa3df7e41964f472426a14e6c50a231615e`; IPA SHA-256 `01cf29fa117df904307286066c131d68be0e89b8f8f4a26b8b960c29ae6afce5`; `com.embyplayerlab.app`; `0.14.89 (256)`; `MinimumOSVersion=15.0`; IPA integrity passed. Evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅ / user accepted ✅ / merged to main ✅ / stable for the Search functional contract ✅**.

## Final merge — 2026-08-30

Build256 was accepted on the target device and PR #264 merged to `main` at `647c1f66e5836fcd20a23a57600211488eeafb3d`. Search is now stable/final for this task. Reopen only for new regression evidence or an explicit new requirement.
