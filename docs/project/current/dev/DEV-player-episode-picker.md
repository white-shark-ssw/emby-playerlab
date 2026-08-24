# DEV-player-episode-picker

## Status

**Active**

- **Work ID**：`DEV-player-episode-picker`
- **Task**：新增播放器“选集”功能：播放器底部增加选集入口，点击后从底部向上弹出横向剧集面板；播放设置增加“自动加载下一集”，并用可信自然结束触发下一集。
- **User intent / acceptance criteria**：当前 Build173 播放器没有选集按钮；新增入口。横向浏览并切换同一剧集，样式参考用户截图；当前集明确显示“正在播放”；自动下一集可开关；异常 EOF / 提前结束不得误触发下一集。
- **Baseline**：用户 2026-08-25 真机确认当前安装为 OnePlayer 0.14.6 / Build173。功能基线 PR #238；branch `fix/pip-seek-completion-return-simplify-0.14.6`；head `4f7acf8da06ded00db735b07210983a0d2dd5be6`。
- **Working branch / PR / head commit**：branch `feat/player-episode-picker-0.14.7`；draft PR #249；Build174 candidate source commit `2d4c4cae7deac930e040ca7579b462d9952ce60d`。
- **Build candidate**：OnePlayer 0.14.7 / Build174。专用标准 MPV Release CI run `32776020154` 完整通过；artifact `OnePlayer-0.14.7-build174-episode-picker` 已上传。该 source commit 与恢复 CI helper 后的产品代码相同，差异仅为临时 workflow 恢复。
- **Evidence**：`PlayerControlPanel` 原有 `.episodes` 枚举被接入底部栏；新增 `PlayerEpisodeCoordinator` 复用 `libraryItem` / `seriesEpisodes` / `playbackInfo` / `resolvePlaybackSource`；`seriesEpisodes()` 使用 `ParentIndexNumber,IndexNumber` 升序；`PlayerScreen` 以外层全屏 host + keyed `PlayerSessionScreen` 替换整个 source-owned 播放会话；自动下一集在 UI 边界再次使用同一纯 `PrematureEOFGuard.evaluate`，只有 non-premature 的可信自然结束才允许切下一集。
- **Files / modules in scope**：`Sources/Core/AppIdentity.swift`、`Sources/UI/PlayerControlPanelViews.swift`、新增 `Sources/UI/PlayerEpisodeSelection.swift`、`Sources/UI/PlayerScreen.swift`、`Sources/UI/PlayerSettings.swift`、`Sources/UI/PlayerSettingsView.swift`、`docs/changelog/CHANGELOG_v0_14_7_build174.md`。
- **State owner / shared dependencies**：完整播放器 source-owned session 切换由外层 `PlayerScreen` host 管理；复用现有 Emby source resolution；依赖现有 premature-EOF 判定合同，不新增第二套播放结束权威。
- **Frozen / do-not-touch**：`PlayerController.swift`、MPV fast Seek、PiP Build173、UnifiedTransport/Range/302/115 客户端直连、Session cache、Cache UI、MPV surface 均未进入最终产品 diff；没有时间→字节比例 Seek；没有为选集新增 timer/watchdog/retry。
- **Parallel conflicts checked against**：迁移到多任务 checkpoint 时没有创建第二个功能任务；后续任何新并行任务若触及 `PlayerScreen`、播放 session 生命周期、`PlayerSettings*` 或相同状态所有者，必须先显式判定冲突，不能盲目并行。
- **Completed**：Code written；版本标识更新到 0.14.7；选集按钮与横向底部面板；当前集状态与自动定位；手动换集；全屏 host 内完整旧会话 stop + 新会话创建；自动下一集设置（Build174 candidate 默认开启）；可信自然结束 gate；Build174 专用契约检查；Xcode 16.4 Release 编译；App 身份校验；MinOS 15.0 校验；IPA/source artifact 生成。临时占用的 `build-mdk-lab.yml` 已恢复到 Build173 基线内容，最终产品 diff 不包含 CI helper。
- **Validation state**：**Code written = yes；CI passed = yes（run 32776020154）；IPA produced = yes；Real-device tested = no；Stable/frozen = no。** 两条历史通用 PR workflow 仍因自身硬编码旧版本合同失败，这些失败发生在标准 Build174 编译之外，不能解释为本次 Swift 编译失败。
- **Pending**：用户安装 Build174 真机验证：1）剧集播放时出现选集按钮；2）面板上弹/横向滚动/当前集居中与“正在播放”；3）手动切集不退出播放器、不闪回竖屏；4）Resume/Emby 进度正确；5）自然播完自动下一集；6）关闭自动下一集后停在本集结束；7）异常短片/提前 EOF 不跳集；8）S1 最后一集可进入 S2 第一集；9）电影/普通 Video 不显示选集按钮。
- **Next exact action**：获取并安装 Build174 artifact，在 iPhone 15 Pro Max / iOS 17.0 做上述真机矩阵；根据真机结果只修有证据的问题。
- **Rejected / do-not-repeat**：此前“Build173 已有选集按钮”已由用户更正；不得在现有 `PlayerController` 内原地替换 source；不得预解析/长期缓存下一集 115/CDN 临时直链；不得用单一引擎 EOF 无条件切集；不得为本功能重构冻结 Transport/Seek/PiP；不得为让旧通用 CI 变绿而修改与本功能无关的历史校验器。
- **Open questions / risks**：横向面板尺寸/材质/卡片间距需真机视觉确认；换集时旧 SwiftUI session 的消失与新 session 的建立是否完全无旋转闪屏需真机确认；自动下一集默认开启是否符合最终产品偏好由本轮真机体验决定。
