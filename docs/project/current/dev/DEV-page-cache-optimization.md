# DEV-page-cache-optimization

## Status

**Active — task created from current `main`; implementation has not started. This task is intentionally isolated from playback/session cache and is currently preflight-blocked from touching files/state owned by `DEV-poster-grid-smoothness` until exact page/cache ownership is inspected and overlap is reconciled.**

- **Work ID**: `DEV-page-cache-optimization`
- **Routing aliases / keywords**: 页面缓存优化 / 收藏页面缓存 / 库页面标签缓存 / library page cache / favorites cache
- **Task**: 优化非播放 UI 页面缓存，首批明确范围为收藏页面，以及库页面顶部几个标签页。

## User intent / acceptance criteria

Current explicit scope from the user:

- 收藏页面；
- 库页面顶部的几个标签页；
- 用户当前消息以顿号/逗号结尾，可能还会继续补充范围；未明确的页面暂不自行扩张。

Current safe acceptance direction:

- 返回已访问页面或在库顶部标签之间切换时，避免没有必要的数据重取、页面重建或可见内容闪空；
- 尽可能保留合理的已加载 UI 数据与页面状态，但具体缓存粒度、生命周期、失效条件必须先根据真实源码状态所有权确定；
- 刷新、服务器切换、用户切换、内容真实变化等现有语义不得被缓存吞掉；
- 不引入 speculative timer/watchdog/retry/fallback/第二状态所有者；
- 不把本任务与播放 Session Cache、UnifiedTransport、媒体字节缓存混为一谈。

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
- Head commit: same as creation base until product code is changed

## Build candidate

- Not allocated.
- Do not allocate until this task has a real testable implementation and uniqueness is rechecked against other Active checkpoints and `BUILD_TEST_INDEX.md`.

## Evidence

- User explicitly requested a **new development task** for page-cache optimization.
- Repository routing rules require one independent checkpoint + branch per Active development task.
- `MODULE_STATUS.md` marks playback Session cache and UnifiedTransport as Frozen core; this task is UI-page caching only.
- Existing `DEV-poster-grid-smoothness` explicitly covers library/favorites and shared poster-heavy page infrastructure, so parallel overlap risk is real and must be resolved before code edits.

## Files / modules in scope

**To be confirmed by exact-source inspection before implementation.** Expected functional areas only, not yet approved file edits:

- 收藏页面 UI/data owner;
- 库页面 root / top-tab selection owner;
- per-tab loaded-data state and refresh/invalidation owner;
- navigation return behavior affecting those pages.

Do not infer file names or APIs until real definitions and call sites are inspected.

## State owner / shared dependencies

To determine before code change:

- which object currently owns library/favorites loaded item arrays;
- whether top-tab switching recreates view models or only views;
- which layer owns request deduplication / refresh semantics;
- whether page state is already partially cached and the observed issue is lifecycle rather than network fetch;
- whether any relevant owner is shared with `DEV-poster-grid-smoothness`.

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

### `DEV-home-carousel-drag-smoothness`

No intended functional overlap. Do not touch Home carousel interaction/state/Hero/Core files.

## Completed

- Development session/task identity is explicit.
- Work ID assigned: `DEV-page-cache-optimization`.
- Independent branch created: `perf/page-cache-optimization`.
- Base identity recorded from current `main`.
- Existing Active task overlap reviewed at checkpoint level.
- No Build candidate allocated.
- No product code changed.

## Validation state

- Code written: ❌
- CI passed: ❌
- IPA produced: ❌
- Real-device tested: ❌
- Stable / frozen: ❌

## Pending

1. User may add more pages to the requested scope.
2. Inspect exact source definitions/call sites/state owners for Favorites and library top tabs.
3. Identify the actual current cache/reload lifecycle before proposing any patch.
4. Compare exact candidate files/state owners with `DEV-poster-grid-smoothness` and decide safe parallel vs serial/stacked execution.
5. Define explicit cache lifetime + invalidation semantics from current behavior and user expectation.
6. Only then make the smallest evidence-backed code change.

## Next exact action

Read the exact current `main` source for the Favorites page and library top-tab container/data owners, trace view lifecycle → load trigger → request/cache owner → refresh/invalidation paths, and list the concrete files/state owners. Do **not** write cache code until that inspection proves where the redundant reload/recreation occurs and confirms whether the active poster-grid task owns any of the same source/state.

## Rejected / do-not-repeat

- Do not create a second generic cache layer just because the task is named “页面缓存”.
- Do not use timers, arbitrary TTLs, watchdogs, retries or fallback copies without a demonstrated failure mode.
- Do not cache stale server/user-specific content without explicit invalidation ownership.
- Do not modify playback Session Cache or transport cache for a UI-page lifecycle problem.
- Do not silently parallel-edit files/state currently owned by `DEV-poster-grid-smoothness`.

## Open questions / risks

- User may still append additional pages to this task scope.
- Exact desired retained state (data only vs scroll position vs selected tab vs all) has not yet been specified; source inspection should first determine current behavior, then user-visible semantics can be pinned down from concrete findings rather than guessed.
- There may already be cache/state retention in the current architecture; if evidence shows the problem is view identity/lifecycle rather than missing cache, fix the lifecycle owner instead of adding another cache.
