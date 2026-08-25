# DEV-detail-episode-selection-navigation

## Status

**Active**

- **Work ID**：`DEV-detail-episode-selection-navigation`
- **Routing aliases / keywords**：详情页选集交互 / 完整选集返回位置 / 详情页剧集蓝框 / episode selection navigation / episode picker return
- **Task**：统一剧集详情页与完整选集页的选集语义，并修正真机发现的默认选择/快速跳集状态问题。
- **Accepted runtime base**：OnePlayer **0.14.17 / Build184**，已合并 `main`；Build182 详情滚动/冷启动展示缓存保持 Frozen。
- **Working branch**：`feat/detail-episode-selection-navigation`
- **Branch base**：`dcd6cc6d01319e13ccb991967a190ae1f915053b`
- **PR**：none
- **Current candidate reservation**：**OnePlayer 0.14.23 / Build190**。
- **Target artifact**：`OnePlayer-0.14.23-build190-detail-selection-defaults`。

## Agreed interaction contract

1. 详情页横向剧集卡单击只选择、不立即播放；蓝框表示当前选中集。
2. 详情页现有主 Play / Resume 按钮播放 `selectedEpisodeID` 对应集，不新增第二播放 owner。
3. “即将播放”区间行下方、横向卡片上方显示固定高度的 12 pt 当前选中集摘要：有真实标题时 `第 N 集 · 标题`，否则 `第 N 集`。
4. 收藏 Episode → Series detail 的既有 `initialEpisodeID` 自动季/区间/蓝框定位保持。
5. 完整选集页点击某集仍直接播放，但不得先 dismiss picker，也不得使用旧固定 100 ms 延迟；关闭 player 后应回到同一个 picker 实例并自然保持 ScrollView 位置。没有真机重建证据前不增加手工 offset 缓存。
6. 不修改 canonical episode order、Player/Transport/Cache/PiP、Build182 detail performance/cache owner 或 iOS 15.0 Deployment Target。

## Build188 implementation / CI evidence

Build188 / OnePlayer 0.14.21 已实现基础交互：

- `episodePreviewCard(_:)` 只调用 `model.selectEpisode(episode)`，不直接 `play`。
- 既有蓝色 outline 由 `selectedEpisodeID` 驱动。
- 选中集摘要位于“即将播放”header/range 行下方、横向卡片上方，12 pt medium，固定 16 pt 高度。
- `selectEpisode(_:)` 同步对应 10 集 range offset。
- picker row 删除 `presentationMode.dismiss()` 和固定 100 ms sleep，先 `selectEpisode` 再直接走现有 `model.play(episode)`。
- picker 可见时由 picker 自己通过共享 `model.selectedSource` 展示 fullscreen player；底层 detail 的 `detailPlaybackSourceBinding` 在 `showAllEpisodes == true` 时不竞争同一 source。
- 没有新增第二个 playback source owner、scroll offset owner、timer、retry、watchdog 或 fallback。

Build188 CI / IPA：

- Dedicated run：`32864835934` — success。
- CI source：`f5ec3668bb43461015ea7838daf9f61af3143568`。
- Restored branch head：`991b62c9de4e5e75a825416aa5699162a3994ec1`。
- Artifact：`OnePlayer-0.14.21-build188-detail-episode-selection-navigation`，ID `9569812832`。
- IPA SHA-256：`c82fcca99162f4840d8b0fccdb7c2f6203426d12901ef5d6ac4f4879db78b9ff`。
- Xcode 16.4 Release、0.14.21 (188) identity、iOS 15.0 MinOS、selection/navigation、range jump、Resume、Build184 visual、Hero、Build182 detail performance、Build178 episode ordering、SeasonId grouping 均通过。

## Build188 real-device result — FOLLOW-UP REQUIRED

用户在目标真机测试后明确给出两条新问题，证据优先级高于 CI：

1. **进入剧集详情页后应默认选中上次播放的集，或者第一集。** Build188 当前进入普通 Series 时虽然 `primaryPlayableItem` 能算出 Resume/默认可播集，但 `applyInitialEpisodeSelection()` 的 fallback 分支主动把 `selectedEpisodeID = nil`，因此页面没有默认蓝框/摘要。
2. **点击“即将播放”右侧快速跳集按钮会清空选中集，导致下面集名称消失。** Build188 的 `selectEpisodeRange(_:)` 明确执行 `selectedEpisodeID = nil`，直接解释该真机现象。

因此 Build188 = **Code written / CI passed / IPA produced / real-device tested / follow-up required / NOT accepted / NOT stable**。用户本次反馈没有证明完整 picker 返回位置等其他 acceptance 已全部通过，不能擅自宣称其余项已验收。

## Source evidence for follow-up

- `LibraryItem` / `EmbyUserItemData` 当前有 `playbackPositionTicks` / `playbackProgress` / played 状态，但没有可用于可靠排序“最近一次已完成播放”的 `LastPlayedDate` 字段。
- 因此“上次播放的集”当前只能安全落在现有 Emby Resume 语义：`playbackProgress > 0.001 && !isPlayed` 的可续播 Episode；没有 Resume Episode 时按用户要求选择 canonical `episodes.first`，不能猜测最近完整播放集。
- `applyInitialEpisodeSelection()` 同时用于 warm snapshot 初始化和 live episodes/seasons 刷新后，因此修正后仍由同一个 owner 决定 visible selection；live refresh 会继续覆盖 warm presentation 数据。

## Build190 implemented follow-up

功能源码已在 feature branch 完成以下最小修正：

### Default detail selection

`applyInitialEpisodeSelection()` 当前优先级固定为：

1. 有效显式 `initialEpisodeID`；
2. `episodes.first(where: { $0.playbackProgress > 0.001 && !$0.isPlayed })`；
3. canonical `episodes.first`。

选中 target 后统一设置：

- `selectedSeason = seasonNumber(for: target)`；
- `selectedEpisodeID = target.id`；
- `selectedEpisodeRangeOffset` 对齐 target 所在 10 集区间；
- `episodeScrollTargetID = target.id`，使默认蓝框集进入横向可视区域。

没有新增 last-played 推测、排序 fallback 或第二套状态。

### Quick range selection

`selectEpisodeRange(_:)` 不再清空 selection；现在把 range offset 规范化后，直接 `selectedEpisodeID = episode(at: normalized)?.id`。因此快速跳到 `11-20` 等区间时会直接选中该区间第一集，蓝框、12 pt 摘要和主 Play/Resume target 保持一致。

### Contracts

- `check_detail_episode_selection_navigation.py` 已增加 default resume→first 与 range-first selection 断言。
- 旧 `check_season_id_episode_grouping.py` 曾硬编码原实现字符串 `if let playable = primaryPlayableItem, let season = seasonNumber(for: playable)`；Build190 改成统一 target 后，该脚本已更新为验证真实 `seasonNumber(for:)` / SeasonId grouping 以及 `selectedSeason = seasonNumber(for: target)`，没有放松 SeasonId 语义。
- 窄检查已通过：selection/navigation、range jump、Resume；正式 Build190 CI 仍需跑完整继承合同。

## Build identity collision history

- 首页轮播当前 `BUILD_TEST_INDEX.md` 已明确占用 **Build189 / OnePlayer 0.14.22** 作为 `Carousel native raw/coalesced-touch input` 候选，并已有 CI/IPA 证据。
- 本详情 follow-up 曾短暂以 0.14.22 / Build189 启动 Release CI；发现权威索引冲突后立即退休该详情身份，不分发、不用于真机/日志归因。
- **详情 follow-up 当前唯一身份改为 OnePlayer 0.14.23 / Build190。** `DEV-add-emby-page-optimization` 截至本 reservation 尚未分配 Build，repository/main 未发现 Build190 占用。

## Frozen / parallel boundaries

- Build182 detail Hero scroll isolation / persistent presentation cache保持 Frozen；不修改 `EmbyDetailPerformanceState.swift`。
- Build176 player episode-session replacement、Build178 canonical Emby episode ordering、Build173 PiP、MPV fast Seek、UnifiedTransport、Range/302/115 client-direct、Session cache、Emby Resume/progress 不变。
- 首页轮播 Active task owns Home carousel state/files；本任务不触碰 Home owner。
- Add Emby Active task当前范围为 AddServer / Session / startup routing，多数与本任务详情/选集文件不重叠；最终 merge 前再次检查 main 前进和共享 `AppIdentity`。

## Evidence level

- Build188：**Code written / CI passed / IPA produced / real-device tested / follow-up required / not stable**。
- Build190 product follow-up：**Code written / narrow static checks passed**。
- Build190 Release CI：pending。
- Build190 IPA：pending。
- Build190 real-device：pending。
- Accepted overall baseline：仍为 **Build184 / 0.14.17**。

## Next exact action

1. 跑 Build190 dedicated Xcode 16.4 Release CI：selection/navigation + range + Resume + visual + Hero + detail performance + canonical ordering + SeasonId + Sources scope + 0.14.23 (190) identity + iOS 15.0 MinOS + IPA。
2. CI/IPA 成功后删除临时 workflow，同轮更新 `BUILD_TEST_INDEX.md` / `PROJECT_STATE.md`，但不提升 accepted baseline。
3. 真机重点验证：
   - 有 Resume 的 Series 进入后默认蓝框/摘要指向 Resume Episode；
   - 无 Resume 的 Series 默认选中 canonical 第一集；
   - `11-20 / 21-30 ...` 快速跳集后选中该区间第一集，摘要不再消失；
   - Build188 的“横向卡只选择、主按钮播放”和完整 picker 返回路径没有回退。
