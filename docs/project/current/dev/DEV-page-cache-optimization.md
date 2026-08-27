# DEV-page-cache-optimization

## Status

**Active — task requirement refined: Favorites and the library page's top tabs must move from memory-only UI data retention to persistent disk-backed cache semantics. App relaunch should immediately present the last persisted data, then normal page-entry refresh updates both visible state and the persisted snapshot. Implementation has not started. This task remains isolated from playback/session cache and is preflight-blocked from touching files/state owned by `DEV-poster-grid-smoothness` until exact page/cache ownership is inspected and overlap is reconciled.**

- **Work ID**: `DEV-page-cache-optimization`
- **Routing aliases / keywords**: 页面缓存优化 / 持久化页面缓存 / 磁盘页面缓存 / 收藏页面缓存 / 库页面标签缓存 / library page cache / favorites cache
- **Task**: 优化非播放 UI 页面缓存，首批明确范围为收藏页面，以及库页面顶部几个标签页；将当前仅内存级缓存升级为磁盘持久化缓存。

## User intent / acceptance criteria

Current explicit scope from the user:

- 收藏页面；
- 库页面顶部的几个标签页；
- 当前问题不是页面内短生命周期的内存复用本身，而是 **App 重启后内存缓存消失，必须重新请求完成后才能看到数据**；
- 正确用户体验是：已有持久化缓存时，冷启动/重启 App 后进入这些页面应立即显示上一次成功保存的旧数据，不先出现无内容等待完整网络加载；
- 页面每次进入时仍按现有刷新语义获取新数据；新数据成功后更新当前页面，并继续写回磁盘，成为下一次冷启动可立即展示的快照。

Required cache behavior:

1. **Disk persistence is required** for the scoped page data; memory-only retention is insufficient.
2. **Cached-first presentation**: if a valid persisted snapshot exists for the current server/user/page identity, load it first so relaunch can show prior content immediately.
3. **Refresh-on-entry remains required**: persisted data is presentation/bootstrap data, not a reason to suppress the normal page-entry refresh.
4. **Refresh success replaces persistence**: after fresh server data is accepted by the existing state owner, persist that same accepted state for the next launch.
5. **No second data authority**: disk persistence must serialize/restore the existing page data owner's state rather than inventing a parallel business-state model.
6. Existing explicit refresh/reload behavior must continue to work.
7. Server/account identity boundaries must be respected so data from one Emby server/user is never shown as another server/user's cache.
8. Do not introduce speculative TTL/timer/watchdog/retry/fallback logic unless exact current source and a concrete failure mode justify it.

Out of scope unless source inspection proves direct necessity:

- playback Session Cache;
- UnifiedTransport/media-byte cache;
- Player / MPV / PiP;
- STRM / 302 / Range / 206 / 115 CDN transport;
- unrelated Home carousel or poster-scroll performance changes;
- speculative scroll-position persistence or selected-tab persistence beyond what current page-state ownership naturally already includes.

## Baseline

- Accepted overall runtime baseline: OnePlayer **0.14.32 / Build199** on `main`.
- Task creation base branch: `main`.
- Task creation base commit: `d3d96c2c18c7a7209293b4fe4a9261fefc2ed2d4`.
- Target device: iPhone 15 Pro Max / iOS 17.0.
- Deployment Target: keep iOS 15.0.

## Working branch / PR / head commit

- Working branch: `perf/page-cache-optimization`
- Branch created from: `d3d96c2c18c7a7209293b4fe4a9261fefc2ed2d4`
- PR: none yet
- Head commit: `d3d96c2c18c7a7209293b4fe4a9261fefc2ed2d4` — verified against GitHub after requirement refinement; product code has not changed.

## Build candidate

- Not allocated.
- Do not allocate until this task has a real testable implementation and uniqueness is rechecked against other Active checkpoints and `BUILD_TEST_INDEX.md`.

## Evidence

- User explicitly requested a **new development task** for page-cache optimization.
- Current repository already contains this exact independent task/checkpoint/branch, so do not create a duplicate Work ID or duplicate feature branch.
- User explicitly clarified the required architecture direction: current memory-only page cache is insufficient; scoped page data must survive App restart through disk persistence, be shown cached-first, then be refreshed on page entry and persisted again.
- Repository routing rules require one independent checkpoint + branch per Active development task.
- `MODULE_STATUS.md` marks playback Session cache and UnifiedTransport as Frozen core; this task is UI-page data persistence only.
- Existing `DEV-poster-grid-smoothness` covers library/favorites and shared poster-heavy page infrastructure, so parallel overlap risk is real and must be resolved before code edits.
- The repository already has a real-device accepted precedent for **presentation-only persistent cache** on the detail page (Build182), but that does not prove the same owner/API/file should be reused here; inspect the actual page data owners first.

## Files / modules in scope

**To be confirmed by exact-source inspection before implementation.** Functional areas only, not yet approved file edits:

- 收藏页面 UI/data owner;
- 库页面 root / top-tab selection owner;
- per-tab loaded-data state and refresh/invalidation owner;
- existing memory cache owner used by those pages;
- persistent cache storage/serialization utilities if an appropriate existing non-playback owner already exists;
- server/user/page identity key construction required to keep persisted snapshots isolated.

Do not infer file names or APIs until real definitions and call sites are inspected.

## State owner / shared dependencies

Must determine before code change:

- which object currently owns library/favorites loaded item arrays;
- where the current memory-only cache lives and whether it stores API models, presentation models, or page snapshots;
- whether top-tab switching recreates view models or only views;
- which layer owns request deduplication / refresh semantics;
- whether page entry already performs cached-first memory restore before refresh;
- whether existing disk-cache infrastructure from another non-playback UI path can be reused without creating a second authority;
- what exact server/user identity is available at the page-data owner for cache partitioning;
- whether any relevant owner/source file is shared with `DEV-poster-grid-smoothness`.

## Intended lifecycle contract

The desired lifecycle, subject to exact-source mapping, is:

`page/app launch → restore last valid disk snapshot into existing page owner → render immediately → run existing page-entry refresh → accept fresh server state → render fresh state → atomically persist accepted snapshot`

Important constraints:

- Disk data is allowed to be stale at first paint because it is immediately followed by the normal refresh path.
- A failed refresh must not erase a previously valid persisted snapshot merely because the network request failed.
- Persist only data that the existing owner has accepted as valid page state; do not persist half-built/transient request state.
- Cache invalidation/partitioning must follow real server/user/page identity and existing explicit reset/logout/server-switch semantics discovered in source.
- Do not add an arbitrary TTL unless current product semantics require one; the user's requested model is cached-first + refresh-on-entry.

## Frozen / do-not-touch

Unless direct evidence makes them necessary, do not modify:

- Player / MPV / PiP;
- UnifiedTransport / Range / 206;
- playback Session cache;
- Emby playback Resume / Session;
- STRM → 302 → 115/CDN client-direct path;
- Home carousel gesture/state owner;
- native Push/Pop ownership.

NAS must never relay media bytes.

## Parallel conflicts checked against

### `DEV-poster-grid-smoothness`

**Conflict risk: YES.** That task currently includes library/favorites/search/tag/person poster-heavy pages and shared image infrastructure. This page-cache task must not independently edit the same source file, shared image owner, or shared page state without reconciliation. Prefer serial work if exact-source inspection shows overlap.

The page-cache task's requirement is data persistence/lifecycle, not poster decode/image source/scroll diagnostics. If exact-source inspection shows the same large shared UI source file but independent state owners, record the precise safe edit boundary before parallel work; otherwise serialize the tasks.

### `DEV-home-carousel-drag-smoothness`

No intended functional overlap. Do not touch Home carousel interaction/state/Hero/Core files.

## Completed

- Development session/task identity is explicit.
- Work ID assigned: `DEV-page-cache-optimization`.
- Independent branch exists: `perf/page-cache-optimization`.
- Branch identity rechecked against GitHub; head remains task base `d3d96c2c18c7a7209293b4fe4a9261fefc2ed2d4`.
- Existing Active task overlap reviewed at checkpoint level.
- User requirement refined from generic page retention to explicit **disk-persistent cached-first + refresh-on-entry + persist-fresh** semantics.
- No Build candidate allocated.
- No product code changed.

## Validation state

- Code written: ❌
- CI passed: ❌
- IPA produced: ❌
- Real-device tested: ❌
- Stable / frozen: ❌

## Pending

1. Inspect exact source definitions/call sites/state owners for Favorites and library top tabs.
2. Trace the existing memory-cache lifecycle and determine precisely what is lost on App termination.
3. Identify the current page-entry refresh trigger and accepted-state assignment point.
4. Identify server/user/page identity boundaries and existing reset/logout/server-switch invalidation hooks.
5. Compare exact candidate files/state owners with `DEV-poster-grid-smoothness` and decide safe parallel vs serial/stacked execution.
6. Check whether the accepted Build182 detail presentation persistent-cache utility is reusable in principle without coupling unrelated state owners.
7. Only then make the smallest evidence-backed implementation for persistent restore/write-through behavior.

## Next exact action

Read the exact source on `perf/page-cache-optimization` / base `d3d96c2c18c7a7209293b4fe4a9261fefc2ed2d4` for the Favorites page and library top-tab container/data owners. Trace **view lifecycle → existing memory cache restore → page-entry load/refresh trigger → accepted data assignment → reset/invalidation**, then identify the narrowest place to add disk restore/persist around the existing owner. Before editing, list the concrete files/state owners and reconcile any overlap with `DEV-poster-grid-smoothness`.

## Rejected / do-not-repeat

- Do not leave the scoped feature as memory-only caching; surviving App restart is an explicit requirement.
- Do not create a second generic cache layer just because the task is named “页面缓存”.
- Do not treat a disk snapshot as authoritative fresh server data; it is cached-first presentation followed by normal refresh.
- Do not suppress page-entry refresh merely because disk cache exists.
- Do not use timers, arbitrary TTLs, watchdogs, retries or fallback copies without a demonstrated failure mode.
- Do not cache server/user-specific content under a global unpartitioned key.
- Do not modify playback Session Cache or transport cache for a UI-page lifecycle problem.
- Do not silently parallel-edit files/state currently owned by `DEV-poster-grid-smoothness`.

## Open questions / risks

- Exact data format and persistence owner remain unknown until source inspection; do not guess Codable compatibility or file layout.
- Exact current memory-cache owner is not yet confirmed.
- Persisted snapshots need identity-safe invalidation on server/user changes; exact hooks must come from real source.
- Shared source/state overlap with active poster-grid diagnostics may require serial execution even though the functional goals differ.
- Whether scroll position or selected tab should persist is **not** part of the current explicit requirement; do not add it unless existing owner semantics make it naturally inseparable or the user later requests it.
