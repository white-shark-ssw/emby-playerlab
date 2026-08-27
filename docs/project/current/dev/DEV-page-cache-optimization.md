# DEV-page-cache-optimization

## Status

**Active — an initial disk-backed presentation-cache implementation already exists on `perf/page-cache-optimization`, but further product-code progression is intentionally paused while the persistence model is refined. On 2026-08-27 the user accepted the state-classification plan below and asked to record it in this task before making further implementation decisions. This turn updates planning/checkpoint documentation only; no product code, CI, IPA, or runtime evidence changes.**

- **Work ID**: `DEV-page-cache-optimization`
- **Routing aliases / keywords**: 页面缓存优化 / 持久化页面缓存 / 磁盘页面缓存 / 收藏页面缓存 / 库页面标签缓存 / library page cache / favorites cache
- **Task**: 优化非播放 UI 页面缓存。当前已实现的首批代码范围是收藏页面，以及库页面顶部 7 个标签页；后续是否扩展到页面现场恢复、类别结果页、人物作品页等，必须按本文件的状态分类和生命周期边界逐项决定，不做统一大 Store 或无差别持久化。

## User intent / current acceptance criteria

### Current implemented first batch

- 收藏页面；
- 库页面顶部标签页：内容、建议、预告片、合集、类别、我的收藏、文件夹；
- App 重启后进入这些页面时，如果已有有效内容快照，应先立即显示上一次成功保存的数据；
- 页面/标签进入仍执行服务器刷新，不因为存在磁盘缓存而跳过 live refresh；
- 新数据成功进入现有页面状态 owner 后，再原子覆盖磁盘快照；
- 刷新失败不得把已有有效快照写成空数据；
- server/user/page 必须隔离；
- 不引入 TTL、timer、watchdog、speculative retry、fallback 或第二业务状态 authority。

### Newly accepted planning boundary — 2026-08-27

“页面持久化”不能视为一个单一功能。后续所有候选状态先按以下五类归属，再决定保存位置和生命周期：

1. **内容展示快照（presentation snapshot）**
   - 保存“上一次成功展示过什么”，目标是重进页面时避免白屏和强制等待网络。
   - 允许短暂过期；live Emby/API 数据始终是最终权威。
   - fresh 请求成功后覆盖快照；请求失败保留旧快照。
   - 适合磁盘 warm cache，但不能把快照升级为业务 authority。

2. **浏览会话状态（browse session state）**
   - 保存“用户刚才浏览到哪里”，与媒体业务数据分开。
   - 包括：当前 Library tab、分页 frontier/nextStartIndex、hasMore、必要的已加载 ID 集合，以及可选滚动位置。
   - 再分两层：
     - **内容/分页恢复**：关系到恢复后继续分页是否正确；优先级较高。
     - **位置恢复**：例如滚动到第几屏/哪个海报附近；属于第二阶段 UX，不与内容缓存绑死。

3. **用户偏好（preference）**
   - 例如排序方式、首页库显示偏好等。
   - 这是长期用户选择，不属于 cache；应由独立 Preference/UserDefaults owner 管理，直到用户主动更改。
   - 清页面缓存不得顺带清除用户偏好。

4. **临时交互状态（transient interaction state）**
   - loading/error、isFetching、request generation、refresh spinner、sheet/popup 是否打开、按钮按压等。
   - 默认不持久化，不为恢复它们新增 owner。

5. **权威业务状态（authoritative business state）**
   - Emby 收藏状态、Played、PlaybackPositionTicks、UnplayedItemCount、播放 Session、CDN/302 最终地址、Transport byte ranges 等。
   - 绝不能因为页面缓存而复制出第二套长期 authority。
   - 这些字段可以作为展示快照的一部分出现，但必须继续通过现有 live API / UserData refresh / Session / Transport owner 更新。

## Lifecycle strategy

### Server Root 一级页面

收藏、搜索、设置属于 `EmbyServerRootViewV3` 的一级页面。这里要严格区分两件事：

- **切底部 Tab 后回来**：首先是内存生命周期/页面是否被销毁的问题，优先考虑让正确的页面/Store 在 server session 内保持，而不是把所有 UI 现场都写磁盘。
- **App 终止/重启后回来**：如确有立即展示价值，再由 presentation snapshot 提供磁盘 warm start。

因此，一级页面允许“会话内内存保留 + 内容磁盘快照”同时存在，但两者必须服务不同生命周期，不能变成重复业务 owner。

### Navigation 深层页面

Library Browser、类别结果、人物作品等页面在 Pop 后本来就可以正常销毁 View。如果产品希望重新进入时仍立即恢复之前已加载内容，才考虑磁盘 warm snapshot；不因为 View 被销毁就强制把所有 StateObject 永久化。

### 不建立统一巨型 Store

- 不把 Favorites、Library、Search、Genre、Person、Detail 全塞进一个全局页面 Store。
- 优先由现有真实 owner 保存自己的 presentation/browse 状态，必要时共享一个纯序列化/磁盘设施。
- Home 与 Detail 已有成熟持久化 owner，除非出现新回归证据，本任务不重构它们。

## Scope classification matrix

| 页面/状态 | 内容快照 | 分页/内容恢复 | 当前 Tab | 滚动位置 | 偏好 | 当前规划 |
|---|---|---|---|---|---|---|
| 首页 | 已有 | 不需要扩展 | 不适用 | 暂不扩 | 已有部分 | **不碰现有 owner** |
| 收藏主页 | 应保留/完善 | 视真实接口需要 | 不适用 | 第二阶段 | 无 | **第一优先级**；一级页另评估会话内内存保留 |
| Library 7 tabs | 应保留/完善 | **应做** | **应做候选** | 第二阶段 | sortBy 单独处理 | **第一优先级** |
| 类别结果页 | 可做 | 若做则一起保存分页 frontier | 不适用 | 第二阶段 | 无 | **第二优先级候选**，尚未批准实现 |
| 人物作品页 | 可做 | 若做则一起保存分页 frontier | 不适用 | 第二阶段 | 无 | **第二优先级候选**，尚未批准实现 |
| 搜索页 | 默认不做跨重启磁盘结果缓存 | 会话内即可 | 不适用 | 不优先 | 搜索历史另议 | **待产品决定**；倾向 session-only |
| 详情页 | Build182 已有 | 现有 owner 足够 | 不扩 | 不扩 | 无 | **Frozen，不动** |
| Library sortBy | 不适用 | 不适用 | 不适用 | 不适用 | 可独立持久化 | **Preference 问题，不混入 page snapshot** |

## Baseline / identity

- Accepted overall runtime baseline: OnePlayer **0.14.32 / Build199** on `main`.
- Task creation base: `d3d96c2c18c7a7209293b4fe4a9261fefc2ed2d4`.
- Working branch: `perf/page-cache-optimization`.
- PR: none yet.
- Initial implementation head recorded by the earlier checkpoint: `fdd364f9bad0b0820177b42d69afdbf06200c0fe`.
- Current branch head before this documentation update: `c70472f78033f89acdfef3d5917bf00ac4f9a31e` (`Merge current main into page cache task`).
- Because the branch was synchronized with current `main` after the initial implementation review, affected final diff/compile validation must be rechecked before CI/PR claims.
- Target device: iPhone 15 Pro Max / iOS 17.0.
- Deployment Target remains iOS 15.0.

## Build candidate

- Not allocated yet.
- Allocate only after the planning boundary is settled, compile/test baseline exists, and uniqueness is rechecked against `BUILD_TEST_INDEX.md` plus all Active checkpoints.

## Exact source findings

### Library top tabs

`V3LibraryBrowserView` creates one `V3LibraryBrowserViewModel` per library browser presentation and uses `.task(id: selectedTab)` to enter/load each top tab.

The model's relevant state includes:

- `tabItems` for items/trailers/collections/favorites;
- suggestion resume/latest/generic arrays and recommendation sections;
- genres;
- folder items;
- `loadedTabs` and pagination state;
- sort state;
- `selectedTab` is currently View-owned `@State` rather than part of the ViewModel/cache owner.

Before this task's initial implementation there was no disk restore path for the tab content. App termination therefore destroyed the content state. The newly accepted classification also identifies `selectedTab` as **browse session state** rather than transient state; whether/how to restore it must be reviewed separately from content snapshot serialization.

### Favorites root

`EmbyServerRootViewV3` conditionally constructs `V3EmbyFavoritesView` only while the Favorites server tab is selected. `V3FavoritesViewModel` previously kept its Movie/Series/Episode/Person sections only in memory. Switching away can recreate the view/model later, and App termination always destroys it.

This creates two distinct problems that must not be conflated:

1. bottom-tab switching destroys session-local page state;
2. app relaunch loses previous presentation content.

The first is primarily a root-page lifecycle/retention question; the second is the disk presentation-snapshot question already addressed by the initial implementation.

### Search root

`V3EmbySearchView` currently owns `searchText` as local `@State`, and `V3SearchViewModel` owns result/pagination state. Because the root only constructs Search while selected, switching away destroys that search session.

Accepted direction: treat search as **session-local browse/interactivity state by default**, not as a required cross-relaunch disk cache. Search history would be a separate preference/product feature if ever requested.

### Genre result pages

`V3LibraryGenreGridView` owns a dedicated `V3LibraryGenreGridViewModel` with items, `hasMore`, `hasLoaded` and pagination state. Leaving the page releases that state. This is a second-priority candidate for warm cache only if the product wants re-entry restoration beyond normal navigation lifetime.

### Person media pages

`EmbyPersonMediaView` owns a dedicated model with paged `items`, `nextStartIndex`, `seenItemIDs`, `hasMore` and `hasLoaded`. It has the same deep-navigation restoration shape as Genre and is a second-priority candidate, not automatically part of the first batch.

### Existing precedent / explicit exclusions

- Home already persists libraries/resume/latest/carousel presentation snapshots keyed by server/user and performs live refresh. Treat it as a precedent, not a target for this task.
- Build182 detail presentation cache already uses memory + `Library/Caches` warm snapshots and is Frozen. Do not reopen it without new regression evidence.
- Existing image disk cache is separate presentation infrastructure and is not this task's page-state authority.

## Existing implementation on this branch

Product files changed by the initial implementation from the task base:

1. `Sources/UI/EmbyPagePersistentCache.swift` — new page-presentation disk snapshot serializer/store.
2. `Sources/UI/EmbyServerBrowseV3.swift` — existing Favorites/Library page owners restore/persist accepted content state and keep refresh-on-entry semantics.

### Persistent content-cache contract

- Storage directory: `Library/Caches/OnePlayer/PagePresentation`.
- Schema version: 1.
- Key includes `client.baseURL`, `client.userId`, and page scope; library scope additionally includes `library.id`.
- File names are URL-safe base64 of the identity key, versioned by schema.
- Writes use `.atomic`.
- Read/decode failure returns no snapshot and logs under `PagePersistentCache`; it does not mutate server state or trigger retry/fallback.

### Current Library implementation

`V3LibraryBrowserViewModel.init` restores persisted content snapshot synchronously into the same existing owner before first render.

`.task(id: selectedTab)` still drives entry. `load(tab:)` refreshes the selected tab even when restored data is already loaded. Existing visible arrays are not cleared before reset fetch, so cached content remains visible while fresh data is requested.

Successful page fetch/pagination, suggestions updates, genres/folders refresh, and user-data replacement persist the accepted current content snapshot. Network errors retain both visible cached data and the previous disk snapshot.

**Important planning delta:** current code does **not** restore `selectedTab` or scroll position. Under the accepted classification, this is no longer documented as a permanent prohibition. `selectedTab` is a browse-session restoration candidate; scroll position remains a second-stage UX candidate. No code change for either is authorized by this documentation-only turn.

### Current Favorites implementation

`V3FavoritesViewModel.init` restores persisted Movie/Series/Episode/Person sections synchronously.

`V3EmbyFavoritesView.onAppear` invokes `load()`, so restored content is immediately visible while each page entry still refreshes. Only a successful `favoriteBrowseItems` result replaces sections and persists the new snapshot.

**Important planning delta:** disk content restore solves relaunch warm-start, but does not by itself answer whether the root Favorites View/Store should remain alive across bottom-tab switching. That lifecycle question must be evaluated separately to avoid redundant ownership.

## Parallel conflict reconciliation

### `DEV-poster-grid-smoothness`

Exact current overlap was previously inspected. The poster task owns shared image/scroll diagnostic paths such as `EmbySharedImageAndNavigation.swift`; this page-cache implementation does **not** edit those files or image/decode/scroll state. Conceptual Favorites/Library scope overlaps, but exact current file/state ownership is independent enough for the existing patch to remain isolated.

If the poster task advances into `EmbyServerBrowseV3.swift` before this task merges, synchronization must be rechecked before final CI/merge.

### `DEV-home-carousel-drag-smoothness`

No intended product file overlap. Do not modify `EmbyHomeCoreV3.swift`, carousel state/Hero files, or gesture ownership.

## Frozen / protected

Untouched and must remain untouched unless new evidence directly requires otherwise:

- Player / MPV / PiP;
- UnifiedTransport / Range / 206;
- playback Session cache;
- Emby playback Resume / Session authority;
- STRM → 302 → 115/CDN direct path;
- Home carousel owner files;
- Build182 Detail cache owner;
- native Push/Pop ownership.

NAS remains excluded from media-byte relay.

## Validation state

- Existing code written: ✅
- Initial implementation static scope review: ✅ at the earlier implementation checkpoint.
- Post-`c70472f` synchronization final diff/compile-risk review: ❌ pending.
- Newly accepted persistence-classification reconciliation: ✅ documented; product-code reconciliation not yet performed.
- CI passed: ❌ pending.
- IPA produced: ❌.
- Real-device tested: ❌.
- Stable / frozen: ❌.

## Pending decisions / ordered next work

1. **Do not immediately open PR/CI.** First review the existing two-file implementation against the accepted five-class model and the `c70472f` synchronized source.
2. Decide whether the first implementation milestone should additionally restore **Library `selectedTab`** as browse-session state. This is distinct from disk content snapshot and must have one clear owner.
3. Review whether Favorites bottom-tab switching should be solved by **session-local root-page retention** in addition to the existing relaunch disk snapshot; do not create duplicate content authorities.
4. Keep scroll-position restoration as a **second-stage UX option**, not a prerequisite for content-cache correctness.
5. Keep `sortBy` out of page snapshot design; if persistence is desired later, treat it as a separate user Preference decision.
6. Genre result and Person media pages remain **second-priority candidates**. Do not add them until the user explicitly accepts expanding implementation scope after this planning review.
7. Search remains **session-only by default**; do not add cross-relaunch search-result disk persistence unless the product requirement changes.
8. Once the above boundary is settled, perform final diff/source review, then proceed to draft PR/CI if the implementation still matches the accepted scope.
9. Allocate Build/version only after CI-ready code exists and active-task uniqueness is rechecked.
10. Eventual target-device validation must separately test:
   - page/tab switch retention where applicable;
   - force-quit/relaunch warm content presentation;
   - fresh server refresh replacing snapshots;
   - refresh/offline failure retaining valid old presentation data;
   - pagination continuation correctness if browse frontier is persisted.

## Next exact action

**Documentation/planning checkpoint only:** inspect the synchronized current source and existing implementation against the accepted state-classification/lifecycle model. Do not add more cache state, open CI/IPA, or claim the current implementation is final until this reconciliation is complete.

## Rejected / do-not-repeat

- Do not treat “页面缓存” as one undifferentiated global persistence problem.
- Do not revert scoped presentation data to memory-only when cross-relaunch warm content is required.
- Do not make disk snapshot authoritative fresh data; live Emby/API refresh remains authoritative.
- Do not clear valid visible/disk data before a fresh request succeeds.
- Do not persist loading/error/isFetching/generation/sheet/button transient state.
- Do not put long-term user preferences such as sort order into the page snapshot merely for convenience.
- Do not treat `selectedTab` as permanently forbidden from restoration; it is now classified as browse-session state and requires an explicit owner decision.
- Do not treat scroll-position restoration as required for first-stage content correctness.
- Do not add TTL/timer/watchdog/speculative retry/fallback logic.
- Do not modify playback Session Cache/Transport for UI presentation caching.
- Do not reopen Home or frozen Build182 Detail cache merely to “统一缓存”.
- Do not silently edit poster/shared-image or Home-carousel owner files.
