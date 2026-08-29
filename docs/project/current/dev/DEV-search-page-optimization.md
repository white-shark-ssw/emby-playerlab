# DEV-search-page-optimization

- Status: Active — Build246 target-device tested and rejected as final; Build247 follow-up reserved
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Draft PR: #264
- Build244 tested source: `0710fa4cf0a59dbf7e6748e951db2e3cddf2b82c`
- Build245 exact tested product source: `4c5f286ee870589bd2eac05119a516631a31391a`
- Build246 exact tested product source: `748d6f31bf724d4f1ec7dab4765d25c9b6a195ac`
- Build246 run/job: `33255278229 / 99107775908`; artifact `9715650501`; IPA SHA-256 `184082a21d850e7203c1be717e27d7fb95301caa5a36de6b814e4930b30750b9`
- Reserved test candidate: **OnePlayer 0.14.80 / Build247**
- Target device: iPhone 15 Pro Max / iOS 17.0

## Build246 target-device result — 2026-08-29

The user installed Build246 and reported five controlling failures/follow-ups. This supersedes the former Build246 real-device-pending state.

1. Focusing the Search input still lifts the bottom Dock. This has survived multiple candidate versions, so the prior root `GeometryReader.ignoresSafeArea(.keyboard)` placement is rejected as sufficient.
2. The recommendation requirement is an explicit **client-visible whitelist**: only items whose actual Emby type is `Movie` or `Series` may be displayed. Sending `IncludeItemTypes=Movie,Series` alone is not considered sufficient enforcement if the returned payload contains another type.
3. The recommendation poster wall is still too slow when entering Search. Because the query is not known at app launch, this report refers to the Search landing recommendation wall. New direction: execute recommendation metadata/image warming once in the background at app startup instead of starting the first recommendation request only when Search appears.
4. Scrolling downward while recommendations expand still causes visible container twitching. Build246 append-only replacement and removal of the bottom spinner were therefore insufficient.
5. Posters in the later/more recommendation area remain visibly slow. The user suspects non-Movie/Series items may contribute; Build247 must enforce the whitelist on returned items and warm the real poster URLs ahead of Search presentation.

Build246 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / rejected as final ✅ / not stable**.

## Current source / ownership evidence

- `EmbyServerRootViewV3` owns `selectedTab` and `serverTabBar`. In Build246 Search, the Dock is passed as an `AnyView` into `V3EmbyGlobalSearchView` and mounted by an `.overlay(alignment: .bottom)` inside the Search `NavigationView` content. The outer root ignores the keyboard, but the nested navigation/content tree still owns the Search Dock presentation. Build247 will move Search Dock presentation back to the root owner while Search remains selected, rather than adding more keyboard timers or state.
- `V3GlobalSearchViewModel` currently requests recommendations when the Search view `.task` runs. It uses `librarySuggestions(... includeItemTypes: ["Movie", "Series"])` but does not independently reject an unexpected returned type.
- Build246 still performs incremental recommendation network work by increasing the requested Suggestions limit while the user approaches the grid end. Even though existing IDs are appended rather than replaced, this remains an asynchronous list-size mutation during active scrolling.
- `EmbyPosterGrid` triggers `onApproachingEnd` from cells in the last nine item IDs. Search must not modify this shared poster-task-owned grid. Build247 will instead remove recommendation-side incremental network expansion by preloading a fixed recommendation set once per app process and presenting that fixed set.
- `EmbyImageDiskCache` is the existing persistent byte cache; `EmbyDecodedImageRenderPool` is the existing shared decoded-memory cache. Build247 must reuse them and must not introduce another disk image cache.
- App startup restoration occurs in `RootView.onAppear` via `sessionStore.restore()`, providing a concrete place to start a Search-only background preloader after saved sessions are available.

## Build247 planned minimal scope

- Search Dock: root-owned overlay only while `selectedTab == .search`; pass an empty nested Dock into Search so the keyboard-responsive `NavigationView` can no longer move the real Dock.
- Recommendation whitelist: enforce actual returned `LibraryItem.type` against exactly `Movie` / `Series` in addition to the server query parameter.
- Startup warm: after `SessionStore.restore()`, start one Search recommendation preload for saved sessions. Fetch a bounded fixed set, publish metadata to a shared Search-only in-memory owner, and warm the exact poster URLs into existing image caches in the background.
- Search landing: consume the already-started/preloaded fixed recommendation set. Do not issue `onApproachingEnd` incremental recommendation loads; this removes the active-scroll network/list-growth trigger rather than adding debounce/timer/watchdog logic.
- Keep existing keyword Search behavior separate; a keyword cannot be precomputed at app launch.

## Parallel / candidate guard

- Search branch remains `feat/search-page-optimization`, Draft PR #264.
- PR head at the start of this cycle was `52da10c61d354d5f6093250c1abec85387847a10`.
- Active poster task owns Build243; Active Aether task owns Build235. Current project index/checkpoints do not allocate Build247, so Search reserves **0.14.80 / Build247**.
- Build247 will not edit `EmbyPosterGrid.swift` or `EmbySharedImageAndNavigation.swift`, avoiding the active poster task's shared owners.

## Frozen / do-not-touch

No Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115 client-direct media path, Emby Resume/progress, credential storage, shared poster-grid owner, or Deployment Target change. Deployment Target remains iOS 15.0.

## Validation state

- Build246: **target-device tested and rejected as final**.
- Build247: **reserved / not yet written**.
- Real-device tested: no.
- Stable/frozen: no.

## Next exact action

Implement the narrow Build247 Search-only preloader/whitelist/root-Dock changes without editing shared poster-owned files, run syntax/diff checks, then produce and independently verify a 0.14.80 / Build247 Release IPA before handing it back for target-device validation.
