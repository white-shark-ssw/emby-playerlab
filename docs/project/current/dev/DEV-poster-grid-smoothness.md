# DEV-poster-grid-smoothness

## Status

**Active — Stage 1 code written on draft PR #259; CI / IPA / target-device A/B pending**

- **Work ID**：`DEV-poster-grid-smoothness`
- **Routing aliases / keywords**：3×3页面流畅度 / 3列海报流畅度 / 库页流畅度 / 海报网格优化 / poster grid smoothness
- **Task**：优化 OnePlayer 首页体系内的收藏/搜索等 3 列海报页、媒体库页、分类/文件夹等复用 3 列海报网格的滚动与增量加载流畅度。当前阶段不把首页 Hero/轮播手势作为本任务范围。

## User intent / acceptance criteria

- iPhone 15 Pro Max / iOS 17.0 上，现代 3 列海报页面连续上下滚动应更跟手，尤其图片陆续出现、分页接近末尾和大量项目场景不应出现明显掉帧/顿挫。
- 保持现有 3 列布局、海报比例、标题/年份/播放状态展示与系统原生导航语义。
- 不以删数据、截断列表、降低到模糊图片、分页假数据或延迟交互来换取“流畅”。
- Deployment Target 保持 iOS 15.0。
- 不触碰 Player / MPV / PiP / UnifiedTransport / Cache / Emby Resume/Session / STRM→302→115/CDN 客户端直连等冻结合同。
- 只有用户目标真机结果才能升级为 Real-device tested / Stable；CI 或 IPA 不能代替真机结论。

## Baseline

- Accepted overall runtime baseline：OnePlayer **0.14.32 / Build199**。
- Accepted product merge：PR #256 / `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`。
- Base branch：`main`。
- Base source commit for this task：`d0c9f5fb5237041f09f46e9468240fc09986aca0`。
- Main advanced at task creation only by this task's control-plane checkpoint commit before PR #259 was opened; no accepted product source changed by that docs commit.
- Required device：iPhone 15 Pro Max / iOS 17.0。
- Deployment Target：15.0。

## Working branch / PR / head commit

- Working branch：`perf/poster-grid-smoothness`。
- Branch created from：`d0c9f5fb5237041f09f46e9468240fc09986aca0`。
- Current branch head：`1ef1624285f7e125e2bfe5f9ca18f45bbff211ce`。
- Draft PR：**#259** — `Optimize shared 3-column poster grid wrapper cost`。
- PR base at creation：`main@2cdbf4913898aedda66225381b30ab13d52cecd6`。

## Build candidate

- **Unallocated.** Build198 remains owned by the active carousel task. This task intentionally does not touch `AppIdentity.swift` yet because that file is already in the concurrent Build198 diff; allocate a unique test Build only when a dedicated IPA candidate is actually needed and the parallel identity/file overlap is explicitly rechecked.

## Evidence

Current evidence level：**Code written; exact diff scoped; draft PR opened; CI not observed yet**。

Confirmed source facts:

1. `Sources/UI/EmbyPosterGrid.swift` is the shared modern 3-column grid. It already uses `LazyVGrid`; replacing an eager grid with a lazy grid is not a valid optimization direction.
2. Library item/trailer/collection/favorite tabs, genres, genre grids, folders and other modern poster pages route through `EmbyPosterGrid` and commonly render `V3PosterCard` / related grid cards.
3. Before this task, every grid item separately applied the same two Environment modifiers: `embyPosterGridNavigationState` and `embyPosterGridCellWidth`. Those values are grid-owned and identical for all cells.
4. Stage 1 commit `90b27d4ecaba9e8ad3031e8579cddf9af728b1ee` moves those two stable Environment injections to the `LazyVGrid` ancestor. Cell content, frame, contentShape, load-ahead `onAppear`, grid geometry and native navigation state semantics remain otherwise unchanged.
5. Commit `1ef1624285f7e125e2bfe5f9ca18f45bbff211ce` adds `scripts/check_poster_grid_smoothness.py` to reject regression back to per-cell Environment ownership and to require the existing lazy grid/load-ahead contract.
6. Exact compare `main-source-base d0c9f5fb... → perf/poster-grid-smoothness@1ef1624...` changes only `Sources/UI/EmbyPosterGrid.swift` (3 additions / 3 deletions) and the new 23-line task checker. No Build198 carousel file and no Player/MPV/PiP/UnifiedTransport/Cache/Emby playback path is in the diff.
7. `V3PosterCard` already uses the grid-provided cell width and requests a screen-scale-sized poster for the 3-column path; do not assume the grid currently decodes full-resolution artwork.
8. `EmbyCachedRemoteImage` already has memory-render cache, disk cache, detached ImageIO decode/downsampling and cancellation. Do not add a duplicate image cache/decoder merely for this task.
9. Static inspection also shows possible avoidable work in the global image loader, but `EmbyCachedRemoteImage` is consumed by the active Build198 Home Hero and its `onImageLoaded` metrics path. That shared dependency remains deferred in Stage 1.
10. Immediately after opening draft PR #259, the connector returned no pull-request workflow run yet for head `1ef1624...`; therefore CI must remain **not passed / not observed**, not inferred from PR creation.

## Files / modules in scope

Stage 1 writable scope:

- `Sources/UI/EmbyPosterGrid.swift` — primary shared 3-column layout/render wrapper.
- `scripts/check_poster_grid_smoothness.py` — task-specific source contract.
- Task checkpoint / relevant project docs.

Read/inspect-only unless new evidence justifies expansion:

- `Sources/UI/EmbyServerBrowseV3.swift` — library/genre/folder/favorites/search call sites and pagination ownership.
- `Sources/UI/EmbyServerSharedV3.swift` — `V3PosterCard` geometry/image request sizing.
- `Sources/UI/EmbySharedImageAndNavigation.swift` — shared image loader/navigation; **deferred from Stage 1 because it is a shared dependency with active Build198 carousel rendering**.

## State owner / shared dependencies

- Grid geometry owner：`EmbyPosterGrid.containerWidth` + `EmbyPosterGridMetrics`。
- Grid navigation owner：`EmbyPosterGridNavigationState`。
- Stage 1 moves Environment propagation ownership to the grid ancestor; it does not create a second navigation or width state owner.
- Page data/pagination owners remain their existing ViewModels (`V3LibraryBrowserViewModel`, genre/folder/favorites/search models). This task must not create a second paging/list-state owner.
- Image cache/decode owner remains `EmbyDecodedImageRenderPool` + `EmbyImageDiskCache` + `EmbyCachedImageLoader`; Stage 1 does not replace or duplicate them.
- Native navigation remains system-owned.

## Frozen / do-not-touch

- Player / MPV fast Seek / PiP。
- UnifiedTransport / playback Cache / Range 206 / STRM 302 / 115 CDN client-direct media path。
- Emby playback session / Resume/progress ownership。
- Native iOS navigation ownership。
- Build198 carousel gesture lifecycle/state owner files unless this task is explicitly stacked after that task.
- No debounce/throttle timer, watchdog, speculative retry/fallback, duplicate grid cache/state owner, or unrelated UI refactor.

## Parallel conflicts checked against

Checked against Active `DEV-home-carousel-drag-smoothness` / Build198:

- Build198 direct source scope includes `EmbyHomeCoreV3.swift`, `EmbyHomeHeroV3.swift`, `EmbyHomeCarouselStateV3.swift`, `EmbyHomeCarouselInteractionV3.swift`, `AppIdentity.swift`, its CI helper/checker/changelog.
- Stage 1 of this task modifies none of those files and does not modify carousel gesture state ownership.
- A shared dependency exists at `EmbyCachedRemoteImage` / `EmbySharedImageAndNavigation.swift` because Home Hero also consumes it. Global image-loader optimization remains deferred until Build198 is completed/resynced or an explicit stacked dependency is recorded.
- Build198 owns version/build **0.14.31 / 198**; this task does not reuse that identity and currently has no Build candidate.

## Completed

- New-task routing confirmed from the user's explicit functional-session/new-task instruction.
- Read current project authority docs, Module Status and technical/build decisions.
- Confirmed current main source head and accepted Build199 runtime baseline.
- Read the active Build198 checkpoint and compared files/state owners.
- Located the shared 3-column grid and its modern library/favorite/genre/folder call sites.
- Confirmed current image pipeline already performs background downsample/decode and caching; rejected duplicate-cache/redecode speculation.
- Created isolated branch `perf/poster-grid-smoothness`.
- **Code written:** hoisted the two stable grid Environment modifiers from each cell to the `LazyVGrid` ancestor without changing geometry, item content, load-ahead behavior or navigation owner.
- Added task-specific source contract checker.
- Exact branch compare confirms only the intended grid file + checker are changed.
- Opened draft PR #259 to establish a review/test surface without claiming acceptance.

## Validation state

- Code written：✅ — branch head `1ef1624285f7e125e2bfe5f9ca18f45bbff211ce`
- Exact diff / Frozen scope check：✅ — 2 files only; no carousel/P0/Frozen media path
- Source-contract checker present：✅ — not yet promoted to CI-pass evidence
- CI passed：❌ / not observed yet
- IPA produced：❌
- Real-device tested：❌
- Stable / frozen：❌

## Pending

- Observe/execute PR validation for head `1ef1624...`; record the exact run/job/SHA if GitHub schedules it.
- If CI exposes a real source/compile issue, fix only that issue; do not expand scope because of generic CI noise.
- Do not allocate a Build/IPA identity until a dedicated target-device candidate is needed and Build198/AppIdentity overlap is rechecked.
- Target-device A/B should compare long 3-column pages, including image-arrival and pagination-near-end behavior, against accepted Build199 behavior.
- If this Stage 1 change does not materially improve target-device smoothness, gather concrete frame/hitch evidence before expanding into the shared image loader; do not guess.

## Next exact action

1. Check PR #259 validation state for exact head `1ef1624285f7e125e2bfe5f9ca18f45bbff211ce`.
2. If no CI job is scheduled, do not fabricate a pass; keep the candidate at Code-written evidence and decide separately whether a dedicated workflow is justified.
3. If validation passes and a test IPA is requested/needed, re-run parallel identity guard before touching `AppIdentity.swift` or assigning a Build number.
4. Preserve the current minimal diff unless new evidence identifies another bottleneck.
5. Do not claim performance solved until target-device evidence exists.

## Rejected / do-not-repeat

- Replacing `LazyVGrid` with another lazy grid merely because the symptom is scrolling jank.
- Adding a second poster cache/decoder; the current shared image pipeline already has decoded-memory cache, disk cache and detached downsample/decode.
- Blindly changing page size, truncating item arrays or reducing image quality before evidence shows those are the bottleneck.
- Global image-loader changes while Build198 is concurrently active, unless the work is explicitly made stacked/dependent.
- Timer/debounce/throttle/watchdog/retry/fallback as a generic smoothness fix.

## Open questions / risks

- No target-device trace/log has yet isolated whether remaining visible hitching is dominated by SwiftUI per-cell view graph, pagination updates, image-state publications, or another render path. Stage 1 is intentionally minimal and reversible.
- The Stage 1 optimization has a clear source-level reduction in repeated view wrappers, but its real-device effect size is unknown until A/B testing.
- If the first grid-only candidate has little effect, the next useful evidence should be target-device A/B or frame/hitch instrumentation rather than additional speculative patches.
