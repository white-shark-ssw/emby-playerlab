# DEV-detail-episode-selection-navigation

## Status

**Active**

- **Work ID**：`DEV-detail-episode-selection-navigation`
- **Routing aliases / keywords**：详情页选集交互 / 完整选集返回位置 / 详情页剧集蓝框 / episode selection navigation / episode picker return
- **Task**：统一剧集详情页与完整选集页的选集语义：详情页横向剧集卡单击只选择、不立即播放；当前选中集用既有蓝框表达，并在“即将播放”标题/区间行下方、横向剧集卡上方用小号字体显示当前选中集摘要。完整选集页点击某集仍直接播放，但关闭播放器后应返回完整选集页并保持用户原先停留的滚动位置。
- **Acceptance**：1）详情页横向剧集卡单击只更新选中集，不直接进入播放器；2）详情页主播放/继续播放按钮播放当前选中集；3）收藏页 Episode → Series detail 的 `initialEpisodeID` 蓝框定位行为保持；4）完整选集页点击 Episode 后不主动 pop/dismiss，不使用旧固定 100ms 延迟；播放器关闭后回到同一完整选集页，原 ScrollView 实例/位置不被人为销毁；5）完整选集页播放时详情 model 的选中集同步到刚播放的 Episode；6）不修改 canonical episode order、Player/Transport/Cache/PiP、Build182 detail scroll/presentation-cache owner 或 iOS 15.0 deployment target。
- **Accepted runtime base**：OnePlayer **0.14.17 / Build184**。任务产品分支创建自 `main@dcd6cc6d01319e13ccb991967a190ae1f915053b`；该 commit 的产品 runtime 仍是已接受/合并 Build184。
- **Working branch**：`feat/detail-episode-selection-navigation`
- **Branch base**：`dcd6cc6d01319e13ccb991967a190ae1f915053b`
- **PR**：none
- **Build / version candidate**：**OnePlayer 0.14.20 / Build187**。
- **Target artifact**：`OnePlayer-0.14.20-build187-detail-episode-selection-navigation`
- **Current branch head at candidate reservation**：`1858ef01d2566f01812428e4462b591a7d1c7f82`。

## Source evidence before implementation

- `Sources/UI/EmbyMediaDetailView.swift`
  - `episodePreviewCard(_:)` 原真实 action 为 `model.selectEpisode(episode); Task { await model.play(episode) }`，因此蓝框选择与播放被绑定在一次点击中。
  - `primaryPlayableItem` 已优先返回 `selectedEpisodeID` 对应 Episode，因此卡片改为“只选择”后，现有主播放按钮天然播放该选中集，无需新增第二套播放选择状态。
  - 收藏页 Episode 进入 Series detail 的现有路径通过 `initialEpisodeID` 进入同一个 `EmbyMediaDetailViewModel`，`applyInitialEpisodeSelection()` 已负责季/区间/蓝框/横向 scroll target。
- `Sources/UI/EmbyEpisodePickerView.swift`
  - `episodeRow(_:)` 原先先 `presentationMode.wrappedValue.dismiss()`，随后固定 sleep 100ms 再 `model.play(episode)`；该主动 dismiss 直接解释了播放器关闭后只能回详情页。
  - 完整选集页由同一个 detail model 驱动，没必要创建第二个 source/playback owner。

## Implemented candidate

### Detail horizontal cards

- `episodePreviewCard(_:)` 现在只调用 `model.selectEpisode(episode)`；不直接 `play`。
- 既有蓝色 outline 继续由 `model.selectedEpisodeID` 驱动，语义固定为“当前选中集”。
- `selectEpisode(_:)` 同时把 `selectedEpisodeRangeOffset` 对齐到该集所在的 10 集区间，避免选中第 45 集时仍高亮 `1-10` 等不一致状态；使用现有 canonical selected-season array，不增加排序 owner。
- “即将播放”header/range 行下方、横向卡片上方增加固定 16pt 高度的选中集摘要；正文 12pt medium。真实标题存在时显示 `第 N 集 · 标题`，无标题/通用集名时显示 `第 N 集`。未显式选择时保留透明固定高度，避免容器上下跳动。
- 详情页现有主 Play / Resume 按钮及 `primaryPlayableItem` owner 不变，因此选中后由主按钮播放该集。

### Full episode picker return path

- 删除 `@Environment(\.presentationMode)`、主动 `dismiss()` 和固定 100ms `Task.sleep`。
- picker row 现在先 `model.selectEpisode(episode)`，再直接走现有 `model.play(episode)`。
- `model.selectedSource` 仍是唯一 playback-source presentation state owner。
- 可见的 `EmbyEpisodePickerView` 直接挂载现有 `fullScreenCover(item: $model.selectedSource)`；底层 detail 的 player cover 通过 `detailPlaybackSourceBinding` 在 `showAllEpisodes == true` 时对 getter 返回 nil，避免两个 route 同时竞争展示同一 source。
- 没有新增手工 scroll offset、timer、retry、watchdog 或 fallback。picker 导航 entry/ScrollView 不再主动销毁，因此关闭 player 后应自然露出同一 picker 及原位置；是否真机完全保持位置仍需 Build187 验证。

## Validation so far

- Product diff vs branch base仅涉及：
  - `Sources/UI/EmbyMediaDetailView.swift`
  - `Sources/UI/EmbyEpisodePickerView.swift`
  - `Sources/Core/AppIdentity.swift`（仅 Build187 version identity）
  - 新静态 contract / changelog。
- Detail source blob：`e1f0f1e65a7fbe23e73d3a415c66aad5fbe41555`；Picker source blob：`c450c7581f87206edcc3e49b1aa4caede789c21c`。两者与本地已验证源树 hash 一致。
- Narrow local checks passed：
  - `check_detail_episode_selection_navigation.py`
  - `check_detail_episode_range_jump.py`
  - `check_detail_resume_button.py`
  - `check_detail_visual_hierarchy.py`
  - `check_adaptive_hero_reveal.py`
  - `check_detail_page_performance.py`
  - `check_series_episode_ordering.py`
  - `check_season_id_episode_grouping.py`
- 一个旧 `check_user_data_refresh.py` 在 untouched Build184 source 上也会因其 Home 字符串断言失败，属于既有 stale/unrelated check，不作为本任务回归结论。
- 为克服 GitHub connector 对超大整文件写入的限制，曾在 feature branch 临时加入一次精确 `replace` workflow；run `32860336514` 仅执行 source patch，成功后 helper 已删除。该 run **不是 Build187 CI，也没有编译/IPA 证据**。

## Parallel / frozen boundaries

- `DEV-home-carousel-drag-smoothness` 已占用 **OnePlayer 0.14.19 / Build186**；本任务因此使用唯一的 **0.14.20 / Build187**，不复用 Build186。
- `DEV-add-emby-page-optimization` 仅计划 `ServerListView.swift` / AddServer UI，与本任务详情/选集文件及状态 owner 无重叠；当前未分配 Build。
- Build182 detail Hero scroll isolation / persistent presentation cache 已 Frozen，本任务不修改 `EmbyDetailPerformanceState.swift`。
- Build176 player episode-session replacement、Build178 Emby canonical episode ordering、Build173 PiP、MPV fast Seek、UnifiedTransport、Range/302/115 client-direct、Session cache、Emby Resume/progress 均保持不变。

## Evidence level

- **Code written：YES**
- **Source/static validation：YES**
- **Build187 Release CI：pending**
- **IPA：pending**
- **Real-device：pending**
- **Stable / frozen：NO**

## Next exact action

1. 为 Build187 增加独立、临时 Release CI helper，只针对本 branch；跑 selection/navigation contract + inherited detail/order/P0 zero-diff checks + Xcode 16.4 Release + 0.14.20 (187) identity + MinOS 15.0 + IPA packaging。
2. CI/IPA 成功后立即删除临时 helper，同轮更新本 checkpoint 与 `BUILD_TEST_INDEX.md`；accepted overall baseline仍保持 Build184，不能提前升级。
3. 用户真机重点验证：
   - 详情横向卡单击只蓝框选择，主播放按钮才进入播放；小号标题位置/字号是否合适；
   - 完整选集滑到较深位置 → 点某集播放 → 关闭 player，是否仍回完整选集且原位置完全不变；
   - 收藏 Episode → Series detail 的自动蓝框定位是否仍正常；Resume/已看刷新是否正常。
