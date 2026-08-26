# DEV-poster-grid-smoothness

## Status

**Active — baseline/source ownership confirmed; first implementation must stay grid-local**

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
- Base commit for this task：`d0c9f5fb5237041f09f46e9468240fc09986aca0`（latest main at task creation; latest commit is documentation/evidence sync for the independent Build198 carousel task）。
- Required device：iPhone 15 Pro Max / iOS 17.0。
- Deployment Target：15.0。

## Working branch / PR / head commit

- Working branch：`perf/poster-grid-smoothness`。
- Branch created from：`d0c9f5fb5237041f09f46e9468240fc09986aca0`。
- Current head at task creation：`d0c9f5fb5237041f09f46e9468240fc09986aca0`。
- PR：none。

## Build candidate

- **Unallocated.** Do not reuse Build198. Allocate a new unique build/version identity only after the first testable source candidate exists and current Active checkpoints / CI identities are rechecked.

## Evidence

Current evidence level：**source/baseline audit only; no code written yet for this task**。

Confirmed source facts:

1. `Sources/UI/EmbyPosterGrid.swift` is the shared modern 3-column grid. It already uses `LazyVGrid`; therefore replacing an eager grid with a lazy grid is not a valid optimization direction.
2. Library item/trailer/collection/favorite tabs, genres, genre grids, folders and favorites/search-style poster pages route through `EmbyPosterGrid` and commonly render `V3PosterCard` / related grid cards.
3. `V3PosterCard` uses the grid-provided cell width and requests a screen-scale-sized poster for the 3-column path; do not assume the grid currently decodes full-resolution artwork.
4. `EmbyCachedRemoteImage` already has memory-render cache, disk cache, detached ImageIO decode/downsampling and cancellation. Do not add a duplicate image cache/decoder merely for this task.
5. Static inspection shows potential avoidable work in the global image loader (redundant published loading/image transitions when loading UI is hidden), but `EmbyCachedRemoteImage` is also consumed by the active Build198 Home carousel Hero and its `onImageLoaded` metrics path. That shared dependency is deliberately deferred in Stage 1 to keep parallel tasks isolated.

## Files / modules in scope

Stage 1 writable scope:

- `Sources/UI/EmbyPosterGrid.swift` — primary shared 3-column layout/render wrapper.
- A task-specific source-contract checker under `scripts/` if needed.
- Task changelog / checkpoint / project docs when a real code or test milestone exists.

Read/inspect-only unless new evidence justifies expansion:

- `Sources/UI/EmbyServerBrowseV3.swift` — library/genre/folder/favorites/search call sites and pagination ownership.
- `Sources/UI/EmbyServerSharedV3.swift` — `V3PosterCard` geometry/image request sizing.
- `Sources/UI/EmbySharedImageAndNavigation.swift` — shared image loader/navigation; **deferred from Stage 1 because it is a shared dependency with active Build198 carousel rendering**.

## State owner / shared dependencies

- Grid geometry owner：`EmbyPosterGrid.containerWidth` + `EmbyPosterGridMetrics`。
- Grid navigation owner：`EmbyPosterGridNavigationState`。
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
- Stage 1 of this task does **not** modify those files and does not modify carousel gesture state ownership.
- A shared dependency exists at `EmbyCachedRemoteImage` / `EmbySharedImageAndNavigation.swift` because Home Hero also consumes it. Therefore global image-loader optimization is deferred until Build198 is completed/resynced or an explicit stacked dependency is recorded.
- Build198 owns version/build **0.14.31 / 198**; this task will not reuse that identity.

## Completed

- New-task routing confirmed from the user's explicit functional-session/new-task instruction.
- Read current project authority docs, Module Status and technical/build decisions.
- Confirmed current main head and accepted Build199 runtime baseline.
- Read the active Build198 checkpoint and compared files/state owners.
- Located the shared 3-column grid and its modern library/favorite/genre/folder call sites.
- Confirmed current image pipeline already performs background downsample/decode and caching; rejected duplicate-cache/redecode speculation.
- Created isolated branch `perf/poster-grid-smoothness` from current main.

## Validation state

- Code written：❌
- CI passed：❌
- IPA produced：❌
- Real-device tested：❌
- Stable / frozen：❌

## Pending

- Make the first grid-local, behavior-preserving reduction in per-cell SwiftUI view-graph/update work only where the current source proves redundancy.
- Add/adjust a narrow source contract check if the implementation needs one.
- Compare branch diff against base and verify no Build198/P0/Frozen files are touched.
- Only after a testable source candidate exists: allocate a unique Build/version identity, run CI/produce IPA, then request target-device A/B validation.
- If Stage 1 does not materially improve target-device smoothness, gather concrete frame/hitch evidence before expanding into the shared image loader; do not guess.

## Next exact action

1. Re-read `EmbyPosterGrid` body and its consumers as the implementation source of truth.
2. First candidate should reduce repeated per-cell wrapper work while preserving exactly the same grid geometry, navigation environment and pagination trigger semantics; do not touch global `EmbyCachedRemoteImage` in Stage 1.
3. Add a focused contract check that rejects regression back to per-cell environment ownership/eager grid behavior if such a change is made.
4. Compare exact diff against `main@d0c9f5fb...`; stop if any carousel/P0/Frozen path appears.
5. Do not claim performance solved until target-device evidence exists.

## Rejected / do-not-repeat

- Replacing `LazyVGrid` with another lazy grid merely because the symptom is scrolling jank.
- Adding a second poster cache/decoder; the current shared image pipeline already has decoded-memory cache, disk cache and detached downsample/decode.
- Blindly changing page size, truncating item arrays or reducing image quality before evidence shows those are the bottleneck.
- Global image-loader changes while Build198 is concurrently active, unless the work is explicitly made stacked/dependent.
- Timer/debounce/throttle/watchdog/retry/fallback as a generic smoothness fix.

## Open questions / risks

- No target-device trace/log has yet isolated whether remaining visible hitching is dominated by SwiftUI per-cell view graph, pagination updates, image-state publications, or another render path. Stage 1 must therefore stay minimal and reversible.
- If the first grid-only candidate has little effect, the next useful evidence should be target-device A/B or frame/hitch instrumentation rather than additional speculative patches.
