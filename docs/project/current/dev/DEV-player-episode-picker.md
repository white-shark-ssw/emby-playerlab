# DEV-player-episode-picker

## Status

**Active**

- **Work ID**：`DEV-player-episode-picker`
- **Task**：新增播放器“选集”功能：播放器底部增加选集入口，展开横向剧集选择；支持季选择；播放设置增加“自动加载下一集”，并用可信自然结束触发下一集。
- **User intent / acceptance criteria**：当前 Build173 播放器没有选集按钮；新增入口。2026-08-25 用户在 Build174 真机第一版基础上提供 EX 录屏与 OnePlayer 详情页截图，要求选集 UI / 选季 / 交互按录屏重做，同时明确 **OnePlayer 现有底栏按钮布局保持当前位置不变**，不要照搬 EX 在打开选集后让按钮行随剧集容器上移。选集内容直接叠在播放器控制层上，不再使用 Build174 灰色大 Sheet；删除右上角关闭按钮，点击选集内容上方的播放器空白区关闭；删除“选集 + 剧名”标题块。内容使用播放器正常横屏 safe-area 起点，避开刘海 / Dynamic Island 侧边。顶部只保留“第N季⌄”季入口；点击显示轻量季菜单、当前季带勾，选别季只原地筛选列表而不切播放。卡片信息层级按详情页横向剧集卡：174×98 横图；一行剧集标题（例如“第一集”）；最多两行 Emby Overview。当前集保留白色边框和“正在播放”。异常 EOF / 提前结束不得误触发自动下一集。
- **Baseline**：用户 2026-08-25 真机确认当前安装为 OnePlayer 0.14.6 / Build173。功能基线 PR #238；branch `fix/pip-seek-completion-return-simplify-0.14.6`；head `4f7acf8da06ded00db735b07210983a0d2dd5be6`。
- **Working branch / PR / head commit**：branch `feat/player-episode-picker-0.14.7`；draft PR #249。Build174 candidate source commit `2d4c4cae7deac930e040ca7579b462d9952ce60d`；Build175 UI refinement code commit begins at `a66cacf7ca22590dc45edf7765e5343195300633` and version/changelog commits follow on the same branch.
- **Build candidates**：Build174 = OnePlayer 0.14.7 / Build174，CI run `32776020154` passed，artifact `OnePlayer-0.14.7-build174-episode-picker`，用户已安装并提供第一版 UI 真机反馈。Build175 = OnePlayer 0.14.8 / Build175，作为 EX-style UI refinement 候选；专用标准 MPV Release workflow 已触发，CI / IPA 当前待结果。
- **Evidence**：`PlayerControlPanel` 原有 `.episodes` 枚举接入底部栏；`PlayerEpisodeCoordinator` 复用 `libraryItem` / `seriesEpisodes` / `playbackInfo` / `resolvePlaybackSource`；`seriesEpisodes()` 使用 `ParentIndexNumber,IndexNumber` 升序；`PlayerScreen` 用外层全屏 host + keyed `PlayerSessionScreen` 替换完整 source-owned 播放会话；自动下一集只接受现有 `PrematureEOFGuard` 的 non-premature 自然结束。详情页真实 `EmbyMediaDetailView` 横向卡片使用 174×98 图片和 `displayEpisodeTitle` 信息层级；`LibraryItem` 已有 `overview`、`parentIndexNumber`、`indexNumber`，无需新增剧集模型。用户 EX 录屏确认季菜单为播放器控制层中的轻量菜单，选择季后同一横向条原地换季。
- **Files / modules in scope**：`Sources/Core/AppIdentity.swift`、`Sources/UI/PlayerControlPanelViews.swift`、`Sources/UI/PlayerEpisodeSelection.swift`、`Sources/UI/PlayerScreen.swift`、`Sources/UI/PlayerSettings.swift`、`Sources/UI/PlayerSettingsView.swift`、Build174/175 changelog。Build175 UI refinement 实际产品代码优先只改 `PlayerEpisodeSelection.swift` + 版本标识/changelog。
- **State owner / shared dependencies**：完整播放器 source-owned session 切换由外层 `PlayerScreen` host 管理；季筛选只是现有 `episodes` 元数据的 UI 状态，不是新的播放会话 owner。选季不解析媒体源；只有用户点集或可信自然结束才解析目标集播放源。
- **Frozen / do-not-touch**：`PlayerController.swift`、MPV fast Seek、PiP Build173、UnifiedTransport/Range/302/115 客户端直连、Session cache、Cache UI、MPV surface；不得引入时间→字节比例 Seek、timer/watchdog/retry。
- **Parallel conflicts checked against**：`docs/project/current/dev/` 当前只有本任务一个 Active checkpoint，因此 Build175 未与其他并行功能候选冲突。若后续新增任务触及 `PlayerScreen` / session lifecycle / `PlayerSettings*`，必须重新判定并行冲突。
- **Completed**：Build174 功能链和 IPA；用户真机打开第一版面板并提供明确改版证据。Build175 已完成代码改动：保留底栏按钮布局不动；删除大材质 Sheet、标题块和 X；仅播放器上方空白区负责关闭；自然使用横屏 safe-area；按 `parentIndexNumber` 加 `第N季` Menu，当前季自动选择，选季仅筛选浏览；卡片改为 174×98 + 一行标题 + 两行 overview；当前集白框/“正在播放”保留。`AppIdentity.sourceVersion` 已更新到 0.14.8，Build175 changelog 已添加。
- **Validation state**：Build174：Code written = yes；CI passed = yes；IPA produced = yes；Real-device tested = partial；Stable/frozen = no。Build175：**Code written = yes；CI passed = pending；IPA produced = pending；Real-device tested = no；Stable/frozen = no。**
- **Pending**：等待 Build175 标准 MPV Release CI；若通过则恢复临时 CI helper、下载 IPA 并给用户真机测试。真机重点：1）底栏按钮位置和 Build174 一样未上移；2）无灰色大 Sheet / 无 X / 无“选集+剧名”；3）空白区关闭；4）safe-area 左起点；5）季菜单与勾选；6）切季不切播放；7）标题+两行简介；8）当前集定位；9）手动换集；10）Resume/Emby 进度；11）自然结束自动下一集；12）关闭自动下一集；13）异常 EOF 不跳集；14）跨季；15）普通电影不显示按钮。
- **Next exact action**：读取 Build175 workflow run 结果；若编译失败只按真实错误修；若成功则恢复 `.github/workflows/build-mdk-lab.yml` 到原 MDK Lab 内容，固定 artifact 并交付 Build175 IPA。
- **Rejected / do-not-repeat**：Build174 的灰色大 Sheet、右上角 X、“选集/剧名”标题已被用户否定；不要把 EX 的“按钮跟随剧集容器上移”照搬到 OnePlayer；不得在现有 `PlayerController` 内原地替换 source；不得预解析/长期缓存下一集 115/CDN 临时直链；不得单凭引擎 EOF 无条件切集；不得为旧通用 CI 改历史校验器。
- **Open questions / risks**：Build175 季菜单精确宽度/圆角/字号、透明叠层在不同片源亮度下的可读性，以及卡片纵向高度需要下一轮真机视觉确认；自动下一集默认开启是否保留仍待完整体验确认。
