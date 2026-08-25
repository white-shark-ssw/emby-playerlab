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
- **Current Build / version candidate**：**OnePlayer 0.14.21 / Build188**。
- **Target artifact**：`OnePlayer-0.14.21-build188-detail-episode-selection-navigation`
- **Build188 CI source**：`f5ec3668bb43461015ea7838daf9f61af3143568`
- **Workflow-restored branch head**：`991b62c9de4e5e75a825416aa5699162a3994ec1`

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
- `selectEpisode(_:)` 同时把 `selectedEpisodeRangeOffset` 对齐到该集所在的 10 集区间；使用现有 canonical selected-season array，不增加排序 owner。
- “即将播放”header/range 行下方、横向卡片上方增加固定 16pt 高度的选中集摘要；正文 12pt medium。真实标题存在时显示 `第 N 集 · 标题`，无标题/通用集名时显示 `第 N 集`。未显式选择时保留透明固定高度，避免容器上下跳动。
- 详情页现有主 Play / Resume 按钮及 `primaryPlayableItem` owner 不变，因此选中后由主按钮播放该集。

### Full episode picker return path

- 删除 `@Environment(\.presentationMode)`、主动 `dismiss()` 和固定 100ms `Task.sleep`。
- picker row 现在先 `model.selectEpisode(episode)`，再直接走现有 `model.play(episode)`。
- `model.selectedSource` 仍是唯一 playback-source presentation state owner。
- 可见的 `EmbyEpisodePickerView` 直接挂载现有 `fullScreenCover(item: $model.selectedSource)`；底层 detail 的 player cover 通过 `detailPlaybackSourceBinding` 在 `showAllEpisodes == true` 时对 getter 返回 nil，避免两个 route 同时竞争展示同一 source。
- 没有新增手工 scroll offset、timer、retry、watchdog 或 fallback。picker 导航 entry/ScrollView 不再主动销毁，因此关闭 player 后应自然露出同一 picker 及原位置；是否真机完全保持位置仍需 Build188 验证。

## Retired detail Build187 identity

- 同一功能源码曾以 **0.14.20 / Build187** 跑过 dedicated Release CI，run `32861023477` 成功，artifact ID `9568302131`，详情 IPA SHA-256 `c99513ec6a57a2a2cde0854520ff1259d46dff0313e536379e0e89dbc1609d01`。
- 在同步 `BUILD_TEST_INDEX.md` 时确认并行 `DEV-home-carousel-drag-smoothness` 已先正式占用 **0.14.20 / Build187** 作为其可导出日志的 carousel diagnostic identity。
- 因此详情 Build187 **仅保留“代码可编译 / IPA 可生产”的历史证据，身份作废、未分发、不得用于真机或日志归因**。其临时 workflow 已删除。
- 详情任务顺延到唯一的 **0.14.21 / Build188**；相对上述成功详情 Build187，功能源码不变，只调整 `AppIdentity.swift` 与 changelog/candidate identity。

## Build188 CI / IPA evidence

- Dedicated Release run：**`32864835934` — success**。
- CI source：`f5ec3668bb43461015ea7838daf9f61af3143568`。
- Workflow-restored branch head：`991b62c9de4e5e75a825416aa5699162a3994ec1`。
- Artifact：`OnePlayer-0.14.21-build188-detail-episode-selection-navigation`。
- Artifact ID：`9569812832`。
- Artifact digest：`sha256:dd6baba9ee01fe5e0abe79bf5abeaf5306931042a392a341119a409faf84a53d`。
- IPA：`OnePlayer-0.14.21-build188-detail-episode-selection-navigation-unsigned.ipa`。
- IPA SHA-256：`c82fcca99162f4840d8b0fccdb7c2f6203426d12901ef5d6ac4f4879db78b9ff`；下载 artifact 后二次校验与 artifact 内 `.sha256` 一致。
- Source ZIP SHA-256：`bed6e5da780398a0d823b89ed0805229a22d6b73afc529ea4cdb01604348bf25`。
- CI passed：selection/navigation contract、detail range jump、Resume button、Build184 visual hierarchy、Hero、Build182 detail performance、Build178 canonical episode ordering、SeasonId grouping、Xcode 16.4 Release device build、0.14.21 (188) app identity、iOS 15.0 MinOS、IPA packaging/upload。
- 临时 Build188 workflow 已在 CI 成功后从 feature branch 删除。

## Validation so far

- Product diff vs branch base仅涉及：
  - `Sources/UI/EmbyMediaDetailView.swift`
  - `Sources/UI/EmbyEpisodePickerView.swift`
  - `Sources/Core/AppIdentity.swift`（仅候选 version identity）
  - 新静态 contract / changelog。
- Detail source blob：`e1f0f1e65a7fbe23e73d3a415c66aad5fbe41555`；Picker source blob：`c450c7581f87206edcc3e49b1aa4caede789c21c`。
- Narrow checks passed：`check_detail_episode_selection_navigation.py`、`check_detail_episode_range_jump.py`、`check_detail_resume_button.py`、`check_detail_visual_hierarchy.py`、`check_adaptive_hero_reveal.py`、`check_detail_page_performance.py`、`check_series_episode_ordering.py`、`check_season_id_episode_grouping.py`。
- 一个旧 `check_user_data_refresh.py` 在 untouched Build184 source 上也会因其 Home 字符串断言失败，属于既有 stale/unrelated check，不作为本任务回归结论。
- 为克服 GitHub connector 对超大整文件写入的限制，曾在 feature branch 临时加入一次精确 `replace` workflow；run `32860336514` 仅执行 source patch，成功后 helper 已删除。该 run 不是 Release CI。

## Parallel / frozen boundaries

- `DEV-home-carousel-drag-smoothness` 已占用 **0.14.20 / Build187**；本任务占用 **0.14.21 / Build188**。
- `DEV-add-emby-page-optimization` 当前未分配 Build，且仅计划 AddServer UI，与本任务文件/state owner 无重叠。
- Build182 detail Hero scroll isolation / persistent presentation cache 已 Frozen，本任务不修改 `EmbyDetailPerformanceState.swift`。
- Build176 player episode-session replacement、Build178 Emby canonical episode ordering、Build173 PiP、MPV fast Seek、UnifiedTransport、Range/302/115 client-direct、Session cache、Emby Resume/progress 均保持不变。

## Evidence level

- **Code written：YES**
- **Source/static validation：YES**
- **Retired detail Build187 Release CI / IPA：PASSED / PRODUCED, identity collided, NOT DISTRIBUTED**
- **Build188 Release CI：PASSED**
- **Build188 IPA：PRODUCED**
- **Real-device：pending**
- **Stable / frozen：NO**

## Next exact action

1. 用户真机安装 Build188，重点验证：详情横向卡只蓝框选择；主按钮才播放；小号标题位置/字号；完整选集深位置播放后关闭 player 是否原位返回；收藏 Episode → Series detail 自动蓝框定位；Resume/已看刷新。
2. 若真机确认通过，再升级 evidence 为 real-device accepted，并进入 PR/merge 收尾；若完整选集位置仍丢失，只针对真实重建证据考虑显式 scroll-position state，不能预先增加 offset 缓存。
3. Accepted overall baseline 在真机验收前仍保持 Build184。
