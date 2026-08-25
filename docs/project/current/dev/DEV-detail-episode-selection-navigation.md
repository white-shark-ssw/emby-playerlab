# DEV-detail-episode-selection-navigation

## Status

**Active**

- **Work ID**：`DEV-detail-episode-selection-navigation`
- **Routing aliases / keywords**：详情页选集交互 / 完整选集返回位置 / 详情页剧集蓝框 / episode selection navigation / episode picker return
- **Task**：统一剧集详情页与完整选集页的选集语义，并修正真机发现的默认选择/快速跳集状态与选中集摘要一致性问题。
- **Accepted runtime base**：OnePlayer **0.14.17 / Build184**，已合并 `main`；Build182 详情滚动/冷启动展示缓存保持 Frozen。
- **Working branch**：`feat/detail-episode-selection-navigation`
- **Branch base**：`dcd6cc6d01319e13ccb991967a190ae1f915053b`
- **PR**：none
- **Current candidate**：**OnePlayer 0.14.23 / Build190**。
- **Artifact**：`OnePlayer-0.14.23-build190-detail-selection-defaults`。

## Agreed interaction contract

1. 详情页横向剧集卡单击只选择、不立即播放；蓝框表示当前选中集。
2. 详情页现有主 Play / Resume 按钮播放 `selectedEpisodeID` 对应集，不新增第二播放 owner。
3. “即将播放”区间行下方、横向卡片上方显示固定高度的 12 pt 当前选中集摘要：有真实标题时 `第 N 集 · 标题`，只有通用“第几集”名称时显示 `第 N 集`。
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

## Source evidence for default-selection follow-up

- `LibraryItem` / `EmbyUserItemData` 当前有 `playbackPositionTicks` / `playbackProgress` / played 状态，但没有可用于可靠排序“最近一次已完成播放”的 `LastPlayedDate` 字段。
- 因此“上次播放的集”当前只能安全落在现有 Emby Resume 语义：`playbackProgress > 0.001 && !isPlayed` 的可续播 Episode；没有 Resume Episode 时按用户要求选择 canonical `episodes.first`，不能猜测最近完整播放集。
- `applyInitialEpisodeSelection()` 同时用于 warm snapshot 初始化和 live episodes/seasons 刷新后，因此修正后仍由同一个 owner 决定 visible selection；live refresh 会继续覆盖 warm presentation 数据。

## Build190 implemented follow-up

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

### Contracts / CI / IPA

- `check_detail_episode_selection_navigation.py` 已增加 default resume→first 与 range-first selection 断言。
- 旧 `check_season_id_episode_grouping.py` 曾硬编码原实现字符串 `if let playable = primaryPlayableItem, let season = seasonNumber(for: playable)`；Build190 改成统一 target 后，该脚本已更新为验证真实 `seasonNumber(for:)` / SeasonId grouping 以及 `selectedSeason = seasonNumber(for: target)`，没有放松 SeasonId 语义。
- Dedicated Build190 run：**`32870600458` — success**。
- CI source：`943930e5113d0a55472f0bcbf80812bd82e05dd9`；临时 workflow 已删除，feature branch 后续 head `5a574ff9abd489504d9a65d7d4132f86c9ccd69d`。
- Artifact：`OnePlayer-0.14.23-build190-detail-selection-defaults`；ID **`9572070999`**；artifact digest `sha256:65cf97d9c6d775125fcc5270063081ab668f4e777a9ae0172692308af99e7098`。
- IPA：`OnePlayer-0.14.23-build190-detail-selection-defaults-unsigned.ipa`；SHA-256 **`2f05197cebe43b6a50c2eb84225b7d134f364f82baf58772f86d10653f2f298c`**。
- Source ZIP SHA-256：`58e31ab327a05dd0d5976642e4b815c47a00ee006954ae0c8f00ea571f7b15db`。
- CI passed：selection/navigation、range jump、Resume、Build184 visual hierarchy、Hero、Build182 detail performance、Build178 canonical ordering、SeasonId grouping、Sources scope、Xcode 16.4 Release、0.14.23 (190) identity、iOS 15.0 MinOS、IPA packaging/upload。

## Build190 real-device result — PARTIAL / SUMMARY NAMING FOLLOW-UP

用户在 iPhone 15 Pro Max / iOS 17.0 的 Build190 真机截图确认：

- 快速切换 `10-19` / `20-24` 等区间后，目标区间第一集保持蓝框选中，选中集摘要不再被清空。**Build188 的“快速跳集会清空选择/标题”问题已有正向真机证据。**
- 同时发现新的纯展示一致性问题：第 10 集摘要显示 `第 10 集 · 第十集`，而第 20 集摘要显示 `第 20 集`。

真实源码原因已锁定：

- `selectedEpisodeSelectionSummary` 读取 Emby 原始 `episode.name`；若 `isGenericEpisodeName(...)` 判定为通用名称，则只显示 `第 N 集`，否则显示 `第 N 集 · 原始标题`。
- 当前 `isGenericEpisodeName` 只识别 `EpisodeN / EPN / EN / 第N集 / N`（其中 N 为阿拉伯数字），**没有识别 `第十集 / 第二十集` 这种中文数字通用名称**。
- `displayEpisodeTitle(...)` 又会在原始名称为空或被判为 generic 时使用 `fallbackEpisodeName` 生成 `第十集 / 第二十集`，因此卡片视觉上可能都是中文数字，而摘要是否追加名称却取决于 Emby 原始 `episode.name` 的具体格式。
- 从截图本身不能唯一判断第 20 集原始 name 是空、`第20集` 还是 `Episode20`；但不需要猜该值，源码已经足以证明不一致来自 generic-name classification，而不是 `selectedEpisodeID`、canonical order 或 playback 状态。

最小后续修正应只扩展 `isGenericEpisodeName` 的 exact-match candidate，把 `第\(chineseNumber(number))集` 也认作 generic。这样 `第十集 / 第二十集` 都只显示摘要 `第 10 集 / 第 20 集`；真正有剧情标题的 Episode（例如 `营救`）仍显示 `第 N 集 · 营救`。不需要修改排序、选择、播放或缓存 owner。

## Build identity collision history

- 首页轮播 `BUILD_TEST_INDEX.md` 已明确占用 **Build189 / OnePlayer 0.14.22** 作为 `Carousel native raw/coalesced-touch input` 候选，并已有 CI/IPA 证据。
- 本详情 follow-up 曾短暂以 0.14.22 / Build189 启动 Release CI；发现权威索引冲突后立即退休该详情身份，不分发、不用于真机/日志归因。
- 详情 follow-up 唯一有效身份是 **OnePlayer 0.14.23 / Build190**。

## Frozen / parallel boundaries

- Build182 detail Hero scroll isolation / persistent presentation cache保持 Frozen；不修改 `EmbyDetailPerformanceState.swift`。
- Build176 player episode-session replacement、Build178 canonical Emby episode ordering、Build173 PiP、MPV fast Seek、UnifiedTransport、Range/302/115 client-direct、Session cache、Emby Resume/progress 不变。
- 首页轮播 Active task owns Home carousel state/files；本任务不触碰 Home owner。
- Add Emby Active task范围为 AddServer / Session / startup routing；最终 merge 前再次检查 main 前进和共享 `AppIdentity`。

## Evidence level

- Build188：**Code written / CI passed / IPA produced / real-device tested / follow-up required / not stable**。
- Build190：**Code written / CI passed / IPA produced / real-device partially validated / naming follow-up required / not stable**。
- Build190 quick-range retain-selection fix：**real-device positive evidence YES**。
- Build190 default-entry selection：**acceptance evidence not yet complete**。
- Build190 full-picker return：**acceptance evidence not yet complete**。
- Accepted overall baseline：仍为 **Build184 / 0.14.17**。

## Next exact action

1. 若继续修复当前摘要不一致，只改 `isGenericEpisodeName` 的中文数字 generic exact-match，并补静态合同；不碰 selection/playback/order/cache。
2. 新候选出包前重新检查并行 Build 编号占用，不能直接假定 Build191 可用。
3. 后续真机继续验证：有 Resume / 无 Resume 的默认蓝框选择、完整 picker 播放后原位返回，以及真实标题 Episode 是否仍按 `第 N 集 · 标题` 展示。
