# DEV-search-page-optimization

- Status: Active — Build245 target-device rejected as final; Build246 follow-up code written / CI in progress
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Draft PR: #264
- Build244 tested source: `0710fa4cf0a59dbf7e6748e951db2e3cddf2b82c`
- Build245 exact tested product source: `4c5f286ee870589bd2eac05119a516631a31391a`
- Build245 artifact: `OnePlayer-0.14.78-Build245-Search`, ID `9715042997`, IPA SHA-256 `19f69ca62928a65fb23bfdb44c67a916a7ba9edea20c3c3755f0875bb65a6514`
- Build246 exact source candidate: `748d6f31bf724d4f1ec7dab4765d25c9b6a195ac`
- Reserved test candidate: **OnePlayer 0.14.79 / Build246**
- Target device: iPhone 15 Pro Max / iOS 17.0

## Build245 target-device result — 2026-08-29

The user installed Build245 and supplied `RPReplay_Final1788008520.mp4`. This is now the controlling Search evidence and supersedes the former Build245 real-device-pending state.

Observed/requested follow-ups:

1. The Search/recommendation container visibly twitches while scrolling/loading more.
2. The Search settings gear is now too small; enlarge it **15% from Build245**.
3. On the same Emby server the competitor presents the first Search poster wall in under roughly one second, while OnePlayer waits much longer. The same OnePlayer Library route can show posters immediately, so the Search-specific request/presentation path requires correction rather than blaming server/network speed.
4. Recommendations must be whitelisted to Emby `Movie` and `Series` only.
5. Recommendation posters that have already appeared should not fall back to placeholders when the user scrolls away and returns. The shared image stack already writes image bytes to the persistent `EmbyImageDiskCache`; the visible problem is lazy-cell reconstruction/decoded-image eviction causing a disk re-read/decode placeholder. Search should retain already-presented decoded posters for the Search view-model lifetime while continuing to use the existing persistent disk cache.

Build245 evidence is therefore: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / rejected as final ✅ / not stable**.

## Build246 evidence-backed implementation

Exact source candidate `748d6f31bf724d4f1ec7dab4765d25c9b6a195ac` makes only the following narrow Search changes:

- Gear: Build245 `16.2 pt / 26 pt frame` → Build246 `18.6 pt / 30 pt frame`, approximately +15%.
- Search latency: Build245 full-grid Search waited for a 60-item `searchItemsPage` response carrying `commonBrowseFields`, including metadata not required to draw the first poster wall. Build246 adds Search-specific `searchPosterItemsPage` with only poster-list fields (`ImageTags`, `PrimaryImageAspectRatio`, `UserData`, `ProductionYear`, `SeriesName`, `SeriesId`) and Primary-image options. Direct/grouped Search poster pages request 18 items at a time. Existing search sorting and item-type semantics remain unchanged.
- Recommendation whitelist: Emby Suggestions now requests exactly `Movie,Series`.
- Recommendation load-more stability: increased-limit Suggestions results append only IDs not already visible instead of replacing the whole existing prefix, and the incremental bottom ProgressView/layout insertion is removed. This eliminates two deterministic layout-rebuild triggers observed in the Build245 implementation; real-device confirmation is still required.
- Recommendation poster retention: after a recommendation poster is first decoded/presented, Search keeps a non-`@Published` strong `UIImage` pin keyed by item ID for the current Search view-model lifetime. Recreated lazy cells can show the pinned image immediately. The existing shared persistent disk cache remains the byte-level persistence authority; no second disk cache is introduced.

No retry, timer, watchdog, speculative fallback, duplicate session authority, or shared poster-grid modification was added.

## Source / ownership evidence

- Added-server authority remains `SessionStore.sessions`.
- Per-server route/client authority remains `SessionStore.clientForBestRoute(for:)`.
- Existing general `searchItemsPage` remains unchanged for other callers; Build246 adds an additive poster-only Search API rather than weakening global Emby browse fields.
- Recommendation API remains the real `librarySuggestions(parentId:limit:includeItemTypes:)`; it has no `StartIndex`.
- Shared persistent image bytes remain owned by `EmbyImageDiskCache`; shared decoded pool remains `EmbyDecodedImageRenderPool`.
- Search still consumes `EmbyPosterGrid` and `EmbyPosterDetailLink` without editing poster-task-owned `EmbyPosterGrid.swift`, `EmbyServerSharedV3.swift`, or `EmbySharedImageAndNavigation.swift`.

## Parallel / candidate guard

- Search branch remains `feat/search-page-optimization`, PR #264.
- Build246 collision search returned no existing Build246 before materialization.
- Poster and Aether remain separate Active lines; Build246 does not modify their owned Player or shared poster source files.

## Frozen / do-not-touch

No Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115 client-direct media path, Emby Resume/progress, server credential storage, shared poster-grid owner, or Deployment Target change. Deployment Target remains iOS 15.0.

## Validation state

- Build245: **real-device tested and rejected as final** for the current four follow-up areas plus the recorded container twitch.
- Build246 code written: **yes** — source `748d6f31bf724d4f1ec7dab4765d25c9b6a195ac`.
- Build246 local syntax parse of modified Swift files: **passed** in the patch workflow.
- Build246 dedicated Xcode 16.4 Release/MPV packaging: **in progress**, run `33255278229`.
- Build246 real-device tested: **no**.
- Stable/frozen: **no**.

## Next exact action

Finish Build246 Release/IPA CI. If successful, independently verify the artifact identity/checksums/MinOS, remove temporary Build246 packaging files, synchronize `PROJECT_STATE.md`, `MODULE_STATUS.md`, `BUILD_TEST_INDEX.md` and PR #264, then hand the IPA to the user for target-device validation. Do not describe Build246 as fixing the device issue until that test is reported.
