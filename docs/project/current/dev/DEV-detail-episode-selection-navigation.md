# DEV-detail-episode-selection-navigation

## Status

**Active**

- **Work ID**：`DEV-detail-episode-selection-navigation`
- **Routing aliases / keywords**：详情页选集交互 / 完整选集返回位置 / 详情页剧集蓝框 / episode selection navigation / episode picker return
- **Task**：统一剧集详情页与完整选集页的选集语义：详情页横向剧集卡单击只选择、不立即播放；当前选中集用既有蓝框表达，并在“即将播放”标题/区间行下方、横向剧集卡上方用较小字体显示当前选中集摘要。完整选集页点击某集仍直接播放，但关闭播放器后应返回完整选集页并保持用户原先停留的滚动位置。
- **Acceptance**：1）详情页横向剧集卡单击只更新 `selectedEpisodeID`，不直接进入播放器；2）详情页主播放/继续播放按钮播放当前选中集；3）收藏页 Episode → Series detail 的 `initialEpisodeID` 蓝框定位行为保持；4）完整选集页点击 Episode 后不主动 pop/dismiss 完整选集页，播放器关闭后回到同一完整选集页，原 ScrollView 实例/位置不被人为销毁；5）完整选集页播放后详情 model 的选中集同步到刚播放的 Episode；6）不修改 canonical episode order、Player/Transport/Cache/PiP、Build182 detail scroll/presentation-cache owner 或 iOS 15.0 deployment target。
- **Accepted runtime base**：OnePlayer **0.14.17 / Build184**，`main@dcd6cc6d01319e13ccb991967a190ae1f915053b`。其中产品 runtime 仍是已接受/合并的 Build184；`dcd6cc...` 仅包含其后的项目文档/并行任务状态更新。
- **Working branch**：`feat/detail-episode-selection-navigation`
- **Branch base**：`dcd6cc6d01319e13ccb991967a190ae1f915053b`
- **PR**：none
- **Build / version candidate**：暂不分配。并行 `DEV-home-carousel-drag-smoothness` 已明确下一方向为 Build186；本任务在形成可测产品基线前不改 `AppIdentity.swift`，避免并行共享 build-identity 文件冲突。

## Source evidence before implementation

- `Sources/UI/EmbyMediaDetailView.swift`
  - `episodePreviewCard(_:)` 当前真实 action 为 `model.selectEpisode(episode); Task { await model.play(episode) }`，因此蓝框选择与播放被绑定在一次点击中。
  - `primaryPlayableItem` 已优先返回 `selectedEpisodeID` 对应 Episode，因此只要卡片点击改为“只选择”，详情页现有主播放按钮天然会播放该选中集，无需新增第二套播放选择状态。
  - 收藏页 Episode 进入 Series detail 的现有路径通过 `initialEpisodeID` 进入同一个 `EmbyMediaDetailViewModel`，现有 `applyInitialEpisodeSelection()` 已负责季/区间/蓝框/横向 scroll target。
- `Sources/UI/EmbyEpisodePickerView.swift`
  - `episodeRow(_:)` 当前先 `presentationMode.wrappedValue.dismiss()`，随后固定 sleep 100ms 再 `model.play(episode)`；这个主动 dismiss 直接解释了播放器关闭后只能回详情页。
  - 完整选集页本身由同一个 detail model 驱动。优先方案是取消主动 dismiss 与固定 100ms 延迟，让原 picker ScrollView 留在导航栈中，从而自然保持容器位置；只有真机证明系统仍重建/丢位置时，才考虑显式 scroll-position state。

## Parallel / frozen boundaries

- 并行首页轮播任务拥有 `EmbyHomeCarouselStateV3.swift` / `EmbyHomeCoreV3.swift` 等 Home owner，本任务不触碰。
- Build182 detail Hero scroll isolation / persistent presentation cache 已 Frozen，本任务不修改 `EmbyDetailPerformanceState.swift` 的缓存/scroll owner。
- Build176 player episode-session replacement、Build178 Emby canonical episode ordering、Build173 PiP、MPV fast Seek、UnifiedTransport、Range/302/115 client-direct、Session cache、Emby Resume/progress 均保持不变。
- 不新增 timer/watchdog/retry/fallback/compatibility shim；尤其不为“保持完整选集位置”先加手工 offset 缓存。

## Next exact action

1. 在任务分支基于真实 Build184 source 做最小修改：详情页横向卡只选择；增加小号选中集摘要；完整选集点击不 dismiss/不 sleep，直接走现有 `model.play(episode)`。
2. 增加窄静态 contract，锁定“detail card select-only / picker no dismiss-delay / existing main play owner / initialEpisodeID route / frozen files unchanged”。
3. 先做 source/static validation；形成可测基线后再检查并行任务最新 Build identity，分配不冲突的 Build/版本并跑 Release CI/IPA。
