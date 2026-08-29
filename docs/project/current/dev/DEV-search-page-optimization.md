# DEV-search-page-optimization

- Status: Active — Build253 recommendation data path target-device accepted; Build254 incremental recommendation candidate implementation/CI in progress
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Draft PR: #264
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
