# DEV-page-cache-optimization

## Status

**Active — persistence-model reconciliation completed against synchronized source. The first-batch disk warm-cache direction remains valid for Favorites and the Library 7 top tabs. A corrective product commit `45227825a2d1f96da9858c12367d2128c2b5a4f7` stops persisting Library `sortBy` as page-cache state. `selectedTab` restoration, scroll-position restoration, Favorites root-page session retention, Genre/Person warm caches, and Search disk caching are explicitly deferred from the first milestone. Current code still requires post-correction CI and target-device validation; no Build candidate is allocated.**

- **Work ID**: `DEV-page-cache-optimization`
- **Routing aliases / keywords**: 页面缓存优化 / 持久化页面缓存 / 磁盘页面缓存 / 收藏页面缓存 / 库页面标签缓存 / library page cache / favorites cache
- **Task**: 优化非播放 UI 页面缓存。第一批只处理收藏主页与 Library Browser 顶部 7 个标签页的内容 warm snapshot / 必要分页恢复；不建立统一巨型页面 Store。

## User intent / first-milestone acceptance criteria

- 收藏页面；
- Library 顶部标签页：内容、建议、预告片、合集、类别、我的收藏、文件夹；
- App 重启后进入这些页面时，有有效磁盘快照则先显示上一次成功展示的数据；
- 页面/标签进入仍执行 live Emby refresh，磁盘数据不是 fresh authority；
- fresh 请求成功进入现有 owner 后才覆盖磁盘快照；
- refresh 失败不得把有效旧快照写空；
- page content 必须按当前 Emby 用户/页面身份安全隔离；
- 不引入 TTL、timer、watchdog、speculative retry、fallback 或第二业务 authority；
- 不触碰 Player / MPV / PiP / UnifiedTransport / playback Session Cache / STRM→302→115/CDN P0 合同。

## Accepted persistence classification — 2026-08-27

页面状态必须先分类，再决定生命周期：

1. **Presentation snapshot**：上一次成功展示的数据，可短暂过期；live API 最终权威。适合磁盘 warm cache。
2. **Browse session state**：当前 tab、分页 frontier / nextStartIndex / hasMore / 已加载 ID，以及可选滚动位置。内容/分页恢复优先于位置恢复。
3. **Preference**：例如 sortBy。长期用户选择，不属于 page cache，应由独立 Preference owner 管理。
4. **Transient interaction state**：loading/error/isFetching/generation/sheet/button 等，不持久化。
5. **Authoritative business state**：Favorite/Played/PlaybackPosition/Session/CDN URL/Transport range 等不得复制出第二套长期 authority；只允许作为展示快照字段存在并由 live owner 更新。

## Lifecycle decisions after reconciliation

### First milestone — retained

- Favorites 内容磁盘 warm snapshot。
- Library 7 tabs 内容磁盘 warm snapshot。
- Library 已加载内容所需分页 frontier / `nextStartIndex` / `hasMore` / restored seen IDs。
- 每次页面/标签进入继续 fresh refresh。
- fresh success 后重新持久化；failure 保留旧数据。

### Explicitly deferred — no product change now

#### Library `selectedTab`

`selectedTab` 是 `V3LibraryBrowserView` 自己的 `@State`，属于 browse-session state，但不是用户本次“重启后立即看到旧内容”要求的必要条件。第一里程碑继续默认 `.items`，不新增磁盘 owner；后续若用户要求“重进库直接回到上次标签”再单独设计。

#### Scroll position

属于第二阶段位置恢复 UX，不是内容缓存正确性的前置条件。本阶段不保存。

#### Favorites root session retention

`EmbyServerRootViewV3` 当前只在 `selectedTab == .favorites` 时构造 `V3EmbyFavoritesView`；切走底部 Tab 会释放 Favorites page/model。源码确认这是一个**会话内 View 生命周期问题**，与 App relaunch warm snapshot 是两个问题。

本阶段不修改 Root、不把 Favorites 常驻，也不把 model 提升到新全局 Store：用户当前明确需求是跨 App 重启的内容持久化，而 root retention 会扩 owner/文件范围并可能改变隐藏页面 refresh 生命周期。后续如果用户明确要求底部 Tab 往返保留现场，再单独处理 session-local retention。

#### Search / Genre / Person

- Search：默认 session-only，不做跨重启结果磁盘缓存。
- Genre result / Person media：第二优先级候选，尚未获准进入第一批。

## `sortBy` reconciliation

Accepted classification明确：Library `sortBy` 是 Preference，不是 page snapshot。

Initial implementation曾把 `SortBy` 写入 `Library/Caches/OnePlayer/PagePresentation`。这已在 `45227825a2d1f96da9858c12367d2128c2b5a4f7` 收紧：

- 磁盘写入不再包含 `SortBy`；
- 读取历史/开发期 schema-1 快照时忽略旧 `SortBy`，Library owner恢复为现有默认 `DateCreated`；
- 当前页面内用户排序行为仍由原 `V3LibraryBrowserViewModel.sortBy` 管理；
- 本任务不顺手新增 UserDefaults 排序偏好。若以后要持久化排序，必须另按 Preference owner 设计。

这里保留 `V3LibraryPersistentSnapshot.sortBy` 作为现有 owner 构造接口的内部值，但磁盘 page cache 已不再保存/恢复用户排序选择。后续如需进一步移除该字段，必须在不扩大 `EmbyServerBrowseV3.swift` 风险的前提下做窄化整理；它不是当前运行时 Preference authority。

## Exact source findings

### Library top tabs

`V3LibraryBrowserView`：

- 一次 Library Browser presentation 创建一个 `V3LibraryBrowserViewModel`；
- `selectedTab` 是 View-owned `@State`；
- `.task(id: selectedTab)` 负责每个 tab 进入时调用 `model.load(tab:)`；
- sort menu 调用 model `changeSort`；
- current persistent implementation restores content synchronously in ViewModel init before first render。

`V3LibraryBrowserViewModel` 当前相关 state：

- `tabItems`：items/trailers/collections/favorites；
- suggestions resume/latest/generic + recommendation sections；
- `genres`；
- `folderItems`；
- `loadedTabs`；
- paged `pageStates`；
- in-memory `sortBy`。

Fresh reset fetch 不先清空 cached visible array，因此 warm content 可继续显示到 live result 成功替换。

### Favorites root

`V3FavoritesViewModel.init` 从 page disk snapshot 恢复 Movie/Series/Episode/Person sections。`V3EmbyFavoritesView.onAppear` 每次仍 `load()`，成功后覆盖 snapshot；失败保留旧内容/旧磁盘快照。

### Server root lifecycle

`EmbyServerRootViewV3`：

- Home 始终挂载，只切 opacity/hit testing；
- Favorites/Search/Settings 仍是条件构造；
- 因而 Favorites bottom-tab 往返可重建 ViewModel；
- 第一里程碑不改变这个 root 生命周期。

## Persistent cache contract

Product files in the first implementation:

1. `Sources/UI/EmbyPagePersistentCache.swift`
2. `Sources/UI/EmbyServerBrowseV3.swift`

Storage:

- directory: `Library/Caches/OnePlayer/PagePresentation`
- schema version: 1
- JSON + atomic write
- decode/read failure = no snapshot + `PagePersistentCache` diagnostic log
- no retry/fallback/timer
- snapshot includes presentation `LibraryItem` / recommendation metadata and necessary loaded/page state

### Identity note / multi-route risk

Current cache file key is:

`client.baseURL + client.userId + page scope (+ library.id)`

This is **safe against cross-route data leakage**, but Build199 supports multiple URLs for the same Emby Server ID. Therefore a different best route on a later launch can produce a cache miss even though server/user are logically the same.

Do **not** solve this by using only `serverName`, because that weakens identity isolation. The accepted Home precedent keys by `session.serverId + user.id`. A route-transparent page-cache key would require plumbing stable Server ID to these page owners/cache calls. Current active Home-carousel rules explicitly forbid casually editing `EmbyHomeCoreV3.swift`, and SessionStore/server-management is already stable at Build199. Therefore this is recorded as a real first-milestone risk to resolve before final acceptance, not patched through a weaker guessed identity or broad owner refactor.

## Parallel conflict reconciliation

### `DEV-poster-grid-smoothness`

Current page-cache product files do not touch shared poster image/decode/scroll owner `EmbySharedImageAndNavigation.swift`. If poster work later modifies `EmbyServerBrowseV3.swift`, resync before final CI/merge.

### `DEV-home-carousel-drag-smoothness`

Do not modify `EmbyHomeCoreV3.swift`, `EmbyHomeCarouselStateV3.swift`, `EmbyHomeHeroV3.swift`, or carousel gesture/state ownership for this task. The Server-ID cache-key issue must not be “fixed” by silently editing the active carousel owner.

## Baseline / branch / PR identity

- Accepted overall runtime baseline: **OnePlayer 0.14.32 / Build199**.
- Task creation base: `d3d96c2c18c7a7209293b4fe4a9261fefc2ed2d4`.
- Current target/base after synchronization: `main` at `7e7e82ccf548b960567445e848260b71ab8a50b2` when PR #260 was created/synced.
- Working branch: `perf/page-cache-optimization`.
- Draft PR: **#260** — `Persist Favorites and library tab page cache`.
- Initial implementation: `bb18736eac80494d2912cf4032d584c15a1897fc` + `fdd364f9bad0b0820177b42d69afdbf06200c0fe`.
- Main synchronization commit: `c70472f78033f89acdfef3d5917bf00ac4f9a31e`.
- Earlier project-doc sync head: `daf5e8dc9dd1513cbb51d9192d8123a28543be40`.
- Current product correction: **`45227825a2d1f96da9858c12367d2128c2b5a4f7`**.
- Build/version candidate: **not allocated**.
- Target device: iPhone 15 Pro Max / iOS 17.0.
- Deployment Target: keep iOS 15.0.

## Validation evidence

### `daf5e8d…` pre-reconciliation head

- `Build KSPlayer Lab IPA` run `33049382287` completed **success** and compiled the full `Sources` tree.
- This establishes that the first implementation had a real Swift compile-success baseline.
- `Validate Source` failed before compile because that generic workflow still hard-codes obsolete `0.13.3 / Build69` source-version assertions; do not count it as current-code compile failure or CI success.
- `Build MDK Lab IPA` failed its separate MDK local-file contract before compiling this product path; not evidence against page-cache Swift code.

### Current head after `45227825…`

Because source changed after the successful KSPlayer run:

- Code written: ✅
- Persistence classification reconciled: ✅
- `sortBy` removed from disk persistence: ✅
- Prior-head full-source compile success: ✅ (`daf5e8d…` only)
- Current-head CI passed: ❌ pending
- Standard MPV IPA produced: ❌
- Real-device tested: ❌
- Stable / frozen: ❌

## Current first-milestone decisions

1. Retain Favorites + Library 7-tab disk presentation snapshots.
2. Retain refresh-on-entry and fresh-success write-through semantics.
3. Retain necessary pagination frontier/content IDs; do not persist transient request state.
4. Do **not** add Library selected-tab restoration in first milestone.
5. Do **not** add scroll restoration in first milestone.
6. Do **not** change Favorites root lifetime/session retention in first milestone.
7. Do **not** persist `sortBy` through page cache.
8. Do **not** expand to Search/Genre/Person yet.
9. Do **not** weaken server identity to `serverName` merely to make multi-route cache reuse easier.
10. Resolve or explicitly test the current baseURL-key multi-route cache-miss risk before claiming final first-milestone acceptance.

## Next exact action

1. Review PR #260 diff after `45227825…` and confirm only intended page-cache/documentation scope remains.
2. Decide the narrowest safe way to make cache identity route-transparent using real `EmbySession.serverId` without editing active Home-carousel owner files or inventing a duplicate server identity. If no narrow safe path exists, keep current safe route-scoped key and make route-change behavior an explicit test/known limitation rather than weakening isolation.
3. Run current-head compile validation after identity decision.
4. Recheck active Build reservations, then allocate a unique standard MPV test Build only when code is CI-ready.
5. Target-device test must separately cover: force-quit/relaunch warm display, fresh refresh replacement, offline/refresh failure retention, Library pagination continuation, and same-server route change behavior.

## Rejected / do-not-repeat

- Do not treat all page state as one global persistence problem.
- Do not persist loading/error/isFetching/generation/sheets/buttons.
- Do not make disk snapshots live business authority.
- Do not clear valid old data before fresh success.
- Do not persist Library sort preference inside page cache.
- Do not add selectedTab/scroll/root-retention merely because they are technically possible.
- Do not add TTL/timer/watchdog/retry/fallback.
- Do not use `serverName` alone as server identity.
- Do not modify playback Session Cache/Transport for this UI problem.
- Do not reopen Home or Build182 Detail owner for “cache unification”.
- Do not silently edit poster/shared-image or active Home-carousel owner files.
