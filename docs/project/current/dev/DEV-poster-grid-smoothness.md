# DEV-poster-grid-smoothness

## Status

**Active — new target-device recording confirms real scroll hitch; Stage 1 grid-only hypothesis is insufficient; shared poster-image update path now in scope**

- **Work ID**：`DEV-poster-grid-smoothness`
- **Routing aliases / keywords**：3×3页面流畅度 / 3列海报流畅度 / 库页流畅度 / 海报网格优化 / poster grid smoothness
- **Task**：优化首页、媒体库、收藏/更多、搜索、标签搜索、演员搜索等海报密集页面的纵向滚动流畅度。用户最新真机结果优先于此前“只看 3 列 LazyVGrid”的初始假设。

## User intent / acceptance criteria

- Target device：iPhone 15 Pro Max / iOS 17.0。
- 用户明确反馈：首页、库页、收藏页、收藏中“更多”、搜索、标签搜索、演员搜索，只要是这种海报密集页面，连续上下滑动都会感到抖动/掉帧。
- 滚动需要连续、跟手；不能出现停一帧后下一帧追位的视觉顿挫。
- 保持现有海报数量、清晰度、3 列布局、标题/年份/播放状态和系统原生导航语义。
- 不通过截断列表、降低图片质量、延迟输入、timer/debounce/throttle/watchdog 等方式掩盖卡顿。
- Deployment Target 保持 iOS 15.0。
- 不触碰 Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Resume/Session / STRM→302→115/CDN 客户端直连冻结合同。

## Baseline / identity

- Accepted overall runtime baseline：OnePlayer **0.14.32 / Build199**。
- Accepted product merge：PR #256 / `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`。
- Base branch/source：`main@d0c9f5fb5237041f09f46e9468240fc09986aca0`。
- Working branch：`perf/poster-grid-smoothness`。
- Draft PR：**#259**。
- Current product branch head：`069a6064db9ded6fc87954276ac2cde9259f38ca`。
- Build candidate：**unallocated**。Do not reuse Build198.

## New real-device video evidence — 2026-08-27

User supplied `RPReplay_Final1787760518.mp4` from the target-device usage path.

Measured recording facts:

- H.264 screen recording: **510×1108, constant 30 fps, 280 frames, 9.333 s**.
- The recording is only 30 fps, so it cannot quantify every 120 Hz frame miss on the iPhone 15 Pro Max; it can still prove stalls lasting at least one recorded 33.3 ms frame.
- Around **6.80 s**, while content is already moving vertically, one frame is effectively repeated: robust feature tracking gives prior-frame vertical motion about **-2.74 px**, the 6.80 s frame **0 px**, then the next frame about **-10.36 px**. Mean image difference for the stalled frame pair is only about **0.069**, followed by a large visual delta on the catch-up frame.
- This is direct recording evidence of a **stop-one-frame → catch-up-next-frame** cadence, consistent with the user's visible “抖一下/掉帧” report.

Important scope correction:

- The supplied recording shows Home vertical scrolling.
- Home poster sections do **not** use `EmbyPosterGrid`; source shows `posterRow` is `ScrollView(.horizontal) + LazyHStack + V3PosterCard` inside the Home vertical scroll.
- Therefore the same visible hitch on Home cannot be explained by per-cell `EmbyPosterGrid` Environment wrappers. The initial grid-local change may remain a small source cleanup, but it is **not sufficient as the cross-page root-cause theory**.

## Source facts after the recording

1. `EmbyPosterGrid` is still the shared modern 3-column `LazyVGrid` used by library/favorites/genre/folder/person-style result pages.
2. Home uses `V3PosterCard` in `LazyHStack`, outside `EmbyPosterGrid`, yet shows the same reported hitch.
3. Person result pages also use `EmbyCachedRemoteImage` directly, so `V3PosterCard` alone is not universal across every reported page.
4. `EmbyCachedRemoteImage` is a real common rendering dependency across Home posters, 3-column media cards and person-result cards.
5. The existing image pipeline already has decoded-memory cache, disk cache, ImageIO downsampling and detached decode; a second image cache/decoder is still rejected.
6. A concrete redundant SwiftUI state update exists in `EmbyCachedRemoteImage`: every loaded image previously wrote `reportedImageIdentifier` even when `onImageLoaded == nil`. Normal poster cards do not need that state; Home/Detail carousel Hero paths with a real callback do need callback deduplication.
7. Commit `58c0c434dedaa3ed25f035453692204c9e25f269` makes the minimal behavior-preserving correction: URL-change reset of `reportedImageIdentifier` happens only when a callback exists, and the image publisher exits immediately when there is no `onImageLoaded` callback. Real callback paths retain identifier deduplication and callback behavior.
8. Commit `069a6064db9ded6fc87954276ac2cde9259f38ca` extends the task checker to require this no-callback fast path.
9. Exact branch compare from task base now changes only:
   - `Sources/UI/EmbyPosterGrid.swift` — 3 additions / 3 deletions;
   - `Sources/UI/EmbySharedImageAndNavigation.swift` — 3 additions / 2 deletions;
   - `scripts/check_poster_grid_smoothness.py` — source contract.
10. No Player/MPV/PiP/UnifiedTransport/Cache/Emby playback-session file is in the diff.

## Stage history

### Stage 1 — grid wrapper reduction

- Commit `90b27d4ecaba9e8ad3031e8579cddf9af728b1ee` hoisted the two identical grid Environment modifiers from every `EmbyPosterGrid` cell to the `LazyVGrid` ancestor.
- This is still behavior-preserving and removes repeated grid wrappers.
- **New video evidence proves this cannot by itself explain/fix the whole user-visible problem**, because Home does not use `EmbyPosterGrid` and still hitches.

### Stage 2 — shared image callback-state churn reduction

- Commit `58c0c434dedaa3ed25f035453692204c9e25f269` removes one redundant `@State` write/invalidation for ordinary poster images that have no `onImageLoaded` consumer.
- Hero/carousel/detail images that actually supply `onImageLoaded` preserve their callback and duplicate-image guard semantics.
- This is a source-proven common-path reduction; its real-device effect size is still unproven.

## Parallel dependency / Build198 handling

- Active `DEV-home-carousel-drag-smoothness` owns Build198 / 0.14.31 on `perf/home-carousel-single-owner-build198`.
- Build198 does not directly modify `EmbySharedImageAndNavigation.swift`, but its Home Hero consumes `EmbyCachedRemoteImage` with a real `onImageLoaded` callback.
- Stage 2 is therefore recorded as a **shared dependency change with preserved callback semantics**, not a silent independent assumption.
- Build198's already-built IPA/source remains unchanged; this task does not rewrite its evidence.
- If either task is later merged, the other task must resync against then-current `main` and rerun affected validation. Old CI does not prove the combined source.
- Do not touch Build198 gesture/state-owner files from this task.

## Validation state

- Code written：✅ — current branch head `069a6064db9ded6fc87954276ac2cde9259f38ca`
- Exact diff / Frozen scope check：✅ — 3 paths only; no P0 media path
- New target-device symptom evidence：✅ — baseline recording confirms at least one 33.3 ms stop/catch-up stall
- Candidate real-device improvement tested：❌ — the recording is evidence of the **existing problem**, not evidence that current branch fixes it
- CI passed for current head：❌ / not yet established
- IPA produced：❌
- Stable / frozen：❌

## Next exact action

1. Treat the 30 fps recording as proof of the existing hitch, not as a complete 120 Hz frame-time trace.
2. Check/establish compile + source-contract validation for branch head `069a6064...`; do not claim CI before a real run/job exists.
3. Continue source audit around the other common scrolling costs before allocating a Build: in particular ordinary poster image `isLoading` publications and eager/native NavigationLink destination construction must be inspected, but **do not change them without proving redundant work/ownership first**.
4. Do not spend more time optimizing only `EmbyPosterGrid`; Home evidence has already falsified that as the sole bottleneck.
5. Once the shared-path source candidate is coherent, re-run identity guard, allocate a unique Build/version candidate, produce an IPA, then A/B the same Home/library/favorites/search/person flows on iPhone 15 Pro Max / iOS 17.0.
6. Acceptance requires the user to report materially smoother continuous scrolling; CI/IPA alone cannot close this task.

## Rejected / do-not-repeat

- Treating `LazyVGrid` vs another lazy container as the root cause.
- Treating the Stage 1 Environment hoist as a complete fix after the Home recording.
- Adding a second poster cache/decoder.
- Reducing page size/list length/image quality without bottleneck evidence.
- Generic debounce/throttle/timer/watchdog/retry/fallback.
- Changing frozen playback/transport/cache/PiP/session contracts.
- Claiming the current Stage 2 shared-image cleanup fixed the real-device hitch before a new IPA is tested.

## Open questions / risks

- The recording proves at least one recorded-frame stall but, because iOS screen recording is 30 fps here, cannot identify every 120 Hz hitch or directly attribute the stall to one SwiftUI component.
- Shared poster rendering now has one proven redundant state update removed, but remaining cost could still involve image loading-state publications, destination construction, compositing/clipping, page model updates, or more than one cause.
- Any expansion into shared Home dependencies must preserve Build198 callback/interaction semantics and be resynced before final integration.
