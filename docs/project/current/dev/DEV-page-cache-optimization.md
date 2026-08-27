# DEV-page-cache-optimization

## Status

**Active — first persistent-cache implementation is written on `perf/page-cache-optimization`. Exact source inspection confirmed Favorites and the library top tabs are owned by `V3FavoritesViewModel` / `V3LibraryBrowserViewModel` in `Sources/UI/EmbyServerBrowseV3.swift`; their prior retention was memory-only. The implementation restores page snapshots synchronously from disk for immediate presentation, keeps page-entry refresh authoritative, and atomically persists accepted fresh state. Static diff review is in progress; CI/IPA and target-device validation have not yet occurred.**

- **Work ID**: `DEV-page-cache-optimization`
- **Routing aliases / keywords**: 页面缓存优化 / 持久化页面缓存 / 磁盘页面缓存 / 收藏页面缓存 / 库页面标签缓存 / library page cache / favorites cache
- **Task**: 优化非播放 UI 页面缓存，首批明确范围为收藏页面，以及库页面顶部几个标签页；将当前仅内存级缓存升级为磁盘持久化缓存。

## User intent / acceptance criteria

- 收藏页面；
- 库页面顶部标签页：内容、建议、预告片、合集、类别、我的收藏、文件夹；
- App 重启后进入这些页面时，如果已有有效快照，应先立即显示上一次成功保存的数据；
- 页面/标签每次进入仍执行服务器刷新，不因为存在磁盘缓存而跳过；
- 新数据成功进入现有页面状态 owner 后，再原子覆盖磁盘快照；
- 刷新失败不得把已有有效快照写成空数据；
- server/user/page 必须隔离；
- 不持久化 selected tab、scroll position 等未要求 UI 状态；
- 不引入 TTL、timer、watchdog、retry、fallback 或第二业务状态 authority。

## Baseline / identity

- Accepted overall runtime baseline: OnePlayer **0.14.32 / Build199** on `main`.
- Task creation base: `d3d96c2c18c7a7209293b4fe4a9261fefc2ed2d4`.
- Working branch: `perf/page-cache-optimization`.
- PR: none yet.
- Current implementation head before this checkpoint commit: `fdd364f9bad0b0820177b42d69afdbf06200c0fe`.
- Target device: iPhone 15 Pro Max / iOS 17.0.
- Deployment Target remains iOS 15.0.

## Build candidate

- Not allocated yet.
- Allocate only after compile/test baseline exists and uniqueness is rechecked against `BUILD_TEST_INDEX.md` plus all Active checkpoints.

## Exact source findings

### Library top tabs

`V3LibraryBrowserView` creates one `V3LibraryBrowserViewModel` per library browser presentation and uses `.task(id: selectedTab)` to enter/load each top tab.

The model previously stored all tab state only in memory:

- `tabItems` for items/trailers/collections/favorites;
- suggestion resume/latest/generic arrays and recommendation sections;
- genres;
- folder items;
- `loadedTabs` and pagination state;
- sort state.

There was no disk restore path. App termination therefore destroyed this state.

### Favorites root

`EmbyServerRootViewV3` conditionally constructs `V3EmbyFavoritesView` only while the Favorites server tab is selected. `V3FavoritesViewModel` previously kept its Movie/Series/Episode/Person sections only in memory. Switching away can recreate the view/model later, and App termination always destroys it.

### Existing precedent

Build182's frozen detail presentation cache already proves the accepted storage principle: `Library/Caches` via `.cachesDirectory`, JSON snapshot, server/user/item partition key, atomic write. This task reuses that storage principle without modifying the frozen detail module.

## Implementation

Product files changed from task base:

1. `Sources/UI/EmbyPagePersistentCache.swift` — new page-presentation disk snapshot serializer/store.
2. `Sources/UI/EmbyServerBrowseV3.swift` — existing page owners restore/persist their own accepted state and keep refresh-on-entry semantics.

### Persistent cache contract

- Storage directory: `Library/Caches/OnePlayer/PagePresentation`.
- Schema version: 1.
- Key includes `client.baseURL`, `client.userId`, and page scope; library scope additionally includes `library.id`.
- File names are URL-safe base64 of the identity key, versioned by schema.
- Writes use `.atomic`.
- Read/decode failure returns no snapshot and logs under `PagePersistentCache`; it does not mutate server state or trigger retry/fallback.

### Library lifecycle

`V3LibraryBrowserViewModel.init` restores any persisted snapshot synchronously into the same existing owner before first render.

`.task(id: selectedTab)` still drives entry. `load(tab:)` now refreshes the selected tab even when restored data is already loaded. Existing visible arrays are not cleared before reset fetch, so cached content remains visible while fresh data is requested.

Successful page fetch/pagination, suggestions updates, genres/folders refresh, and user-data replacement persist the accepted current snapshot. Network errors retain both visible cached data and the previous disk snapshot.

### Favorites lifecycle

`V3FavoritesViewModel.init` restores persisted Movie/Series/Episode/Person sections synchronously.

`V3EmbyFavoritesView.onAppear` now always invokes `load()`, so restored content is immediately visible while each page entry still refreshes. Only a successful `favoriteBrowseItems` result replaces sections and persists the new snapshot.

## Parallel conflict reconciliation

### `DEV-poster-grid-smoothness`

Exact current overlap was inspected. The poster task owns shared image/scroll diagnostic paths such as `EmbySharedImageAndNavigation.swift`; this page-cache implementation does **not** edit those files or image/decode/scroll state. It edits the page data owner file plus a new persistence helper. Conceptual Favorites/Library scope overlaps, but exact current file/state ownership is independent enough for this patch to proceed in parallel.

If the poster task later advances into `EmbyServerBrowseV3.swift` before this task merges, synchronization must be rechecked before final CI/merge.

### `DEV-home-carousel-drag-smoothness`

No product file overlap. Do not modify `EmbyHomeCoreV3.swift`, carousel state/Hero files, or gesture ownership.

## Frozen / protected

Untouched:

- Player / MPV / PiP;
- UnifiedTransport / Range / 206;
- playback Session cache;
- Emby playback Resume / Session;
- STRM → 302 → 115/CDN direct path;
- Home carousel owner files;
- native Push/Pop ownership.

NAS remains excluded from media-byte relay.

## Validation state

- Code written: ✅
- Exact base→head scope reviewed: ✅ — two product files only; `EmbyServerBrowseV3.swift` diff is narrow, no truncation.
- CI passed: ❌ pending
- IPA produced: ❌
- Real-device tested: ❌
- Stable / frozen: ❌

## Pending

1. Complete static compile-risk review of the new serializer and ViewModel restore/persist wiring.
2. Open an isolated draft PR and run the normal compile/CI path.
3. If CI passes, allocate a unique Build/version candidate only after rechecking active tasks and `BUILD_TEST_INDEX.md`.
4. Produce a test IPA if the project workflow for this line requires it.
5. Target-device test: warm existing pages, terminate OnePlayer, relaunch, enter Favorites/library tabs and verify old data appears before refresh completes; verify refreshed content then persists for the next relaunch.
6. Also test refresh failure/offline behavior: valid old snapshot remains visible and is not erased.
7. Before merge, recheck whether `main` or poster-scroll advanced into the same owner file.

## Next exact action

Perform final static diff/source review, then open a draft PR from `perf/page-cache-optimization` to `main` to obtain real compiler/CI evidence. Do not claim runtime success before CI/IPA and target-device testing.

## Rejected / do-not-repeat

- Do not revert to memory-only cache for the scoped pages.
- Do not make disk snapshot authoritative fresh data; refresh-on-entry remains authoritative.
- Do not clear old visible/disk data before a fresh request succeeds.
- Do not add TTL/timer/watchdog/retry/fallback logic.
- Do not persist selected tab or scroll position under this requirement.
- Do not modify playback Session Cache/Transport for UI presentation caching.
- Do not silently edit poster/shared-image or Home-carousel owner files.
