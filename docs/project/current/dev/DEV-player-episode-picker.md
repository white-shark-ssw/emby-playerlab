# DEV-player-episode-picker

## Status

**Active**

- **Work ID**：`DEV-player-episode-picker`
- **Task**：新增播放器“选集”功能：播放器底部增加选集入口，点击后从底部向上展开横向剧集面板；支持季选择；播放设置增加“自动加载下一集”，并用可信自然结束触发下一集。
- **User intent / acceptance criteria**：当前 Build173 播放器没有选集按钮；新增入口。2026-08-25 用户在 Build174 第一版真机基础上提供目标录屏与详情页截图，要求播放器选集 UI / 选季 / 交互尽量完整复刻该录屏：面板从播放器下方区域展开，背景覆盖全宽，但内容起始位置遵循横屏刘海屏 safe-area；点击播放器上方空白区关闭面板，因此删除当前右上角关闭按钮；删除 Build174 面板左上角“选集 + 剧名”标题块。剧集区顶部只保留类似录屏的“第 N 季⌄”季选择入口；点击后出现轻量季菜单，当前季带勾，选择其他季后原地切换横向剧集列表，不再打开第二层全屏/大弹窗。横向剧集卡片视觉和信息层级改为复用详情页“即将播放”横向集容器语义：缩略图；下方第一行显示剧集标题（例如“第一集”）；再显示最多两行剧情/内容简介。当前集仍以明确边框/“正在播放”覆盖状态标识。自动下一集可开关；异常 EOF / 提前结束不得误触发下一集。
- **Baseline**：用户 2026-08-25 真机确认当前安装为 OnePlayer 0.14.6 / Build173。功能基线 PR #238；branch `fix/pip-seek-completion-return-simplify-0.14.6`；head `4f7acf8da06ded00db735b07210983a0d2dd5be6`。
- **Working branch / PR / head commit**：branch `feat/player-episode-picker-0.14.7`；draft PR #249；Build174 candidate source commit `2d4c4cae7deac930e040ca7579b462d9952ce60d`。
- **Build candidate**：OnePlayer 0.14.7 / Build174。专用标准 MPV Release CI run `32776020154` 完整通过；artifact `OnePlayer-0.14.7-build174-episode-picker` 已上传。该 source commit 与恢复 CI helper 后的产品代码相同，差异仅为临时 workflow 恢复。Build174 已由用户安装并提供真机 UI 截图；当前证据只确认第一版选集面板能显示，不能据此宣称整个选集功能已验收。
- **Evidence**：`PlayerControlPanel` 原有 `.episodes` 枚举被接入底部栏；新增 `PlayerEpisodeCoordinator` 复用 `libraryItem` / `seriesEpisodes` / `playbackInfo` / `resolvePlaybackSource`；`seriesEpisodes()` 使用 `ParentIndexNumber,IndexNumber` 升序；`PlayerScreen` 以外层全屏 host + keyed `PlayerSessionScreen` 替换整个 source-owned 播放会话；自动下一集在 UI 边界再次使用同一纯 `PrematureEOFGuard.evaluate`，只有 non-premature 的可信自然结束才允许切下一集。用户目标录屏约 9.1 秒、横屏 1108×510：播放器控制层显示后点击“选集”在底部展开面板；面板中以“第1季⌄”作为唯一顶部选择控件；点击季入口出现小型季菜单（当前季带勾）；选择第2季后原地替换为 S2 横向卡片；面板外播放器区域可直接关闭面板。用户详情页截图确认目标卡片正文为“剧集标题 + 两行简介”结构。
- **Files / modules in scope**：`Sources/Core/AppIdentity.swift`、`Sources/UI/PlayerControlPanelViews.swift`、新增 `Sources/UI/PlayerEpisodeSelection.swift`、`Sources/UI/PlayerScreen.swift`、`Sources/UI/PlayerSettings.swift`、`Sources/UI/PlayerSettingsView.swift`、`docs/changelog/CHANGELOG_v0_14_7_build174.md`。下一版 UI 精修应优先限制在 `PlayerEpisodeSelection.swift`，只有现有 coordinator 缺少 season grouping / overview 数据暴露时才最小调整相关调用点。
- **State owner / shared dependencies**：完整播放器 source-owned session 切换由外层 `PlayerScreen` host 管理；复用现有 Emby source resolution；依赖现有 premature-EOF 判定合同，不新增第二套播放结束权威。季选择只是现有 `episodes` 元数据的 UI 分组/筛选状态，不得成为新的播放会话所有者。
- **Frozen / do-not-touch**：`PlayerController.swift`、MPV fast Seek、PiP Build173、UnifiedTransport/Range/302/115 客户端直连、Session cache、Cache UI、MPV surface 均未进入最终产品 diff；没有时间→字节比例 Seek；没有为选集新增 timer/watchdog/retry。
- **Parallel conflicts checked against**：迁移到多任务 checkpoint 时没有创建第二个功能任务；后续任何新并行任务若触及 `PlayerScreen`、播放 session 生命周期、`PlayerSettings*` 或相同状态所有者，必须先显式判定冲突，不能盲目并行。
- **Completed**：Code written；版本标识更新到 0.14.7；选集按钮与第一版横向底部面板；当前集状态与自动定位；手动换集；全屏 host 内完整旧会话 stop + 新会话创建；自动下一集设置（Build174 candidate 默认开启）；可信自然结束 gate；Build174 专用契约检查；Xcode 16.4 Release 编译；App 身份校验；MinOS 15.0 校验；IPA/source artifact 生成。临时占用的 `build-mdk-lab.yml` 已恢复到 Build173 基线内容，最终产品 diff 不包含 CI helper。用户已在真机打开 Build174 面板并提供 UI 调整目标。
- **Validation state**：**Code written = yes；CI passed = yes（run 32776020154）；IPA produced = yes；Real-device tested = partial（第一版 UI 已真机显示并获得明确改版反馈）；Stable/frozen = no。** 两条历史通用 PR workflow 仍因自身硬编码旧版本合同失败，这些失败发生在标准 Build174 编译之外，不能解释为本次 Swift 编译失败。
- **Pending**：先按用户录屏重做 Build174 面板 UI：1）删除 X；2）删除左上角“选集/剧名”；3）safe-area 对齐面板内容起点；4）新增“第N季⌄”与轻量季菜单；5）季切换原地刷新横向列表；6）卡片正文改为剧集标题 + 最多两行 overview；7）保持当前集“正在播放”状态。之后重新 CI/IPA，并继续真机验证手动切集、Resume/Emby 进度、自然结束自动下一集、关闭自动下一集、异常 EOF 不跳集、跨季自动下一集、电影不显示按钮。
- **Next exact action**：先反查 `LibraryItem` 的 overview 字段与详情页“即将播放”卡片的真实 View/排版定义，再只在有证据的范围内重构 `PlayerEpisodeSelection.swift` 的 UI 和 season grouping；不改播放会话/Transport 核心。
- **Rejected / do-not-repeat**：此前“Build173 已有选集按钮”已由用户更正；Build174 第一版带“选集/剧名”头部和右上角 X 的大面板布局已被用户否定，不要继续保留；不得在现有 `PlayerController` 内原地替换 source；不得预解析/长期缓存下一集 115/CDN 临时直链；不得用单一引擎 EOF 无条件切集；不得为本功能重构冻结 Transport/Seek/PiP；不得为让旧通用 CI 变绿而修改与本功能无关的历史校验器。
- **Open questions / risks**：季菜单的精确宽度/圆角/字号、卡片尺寸与录屏的像素级差异需下一版真机确认；选季状态应默认定位当前播放集所属季，手动切到别季后仅改变浏览筛选，直到用户实际点选某集才切换播放；自动下一集默认开启是否符合最终产品偏好仍待本轮完整真机体验决定。
