# OnePlayer Current Work — Development

这是**功能开发专用**的跨会话滚动 checkpoint。它与规则维护槽独立，不能被规则会话覆盖或重置。

适用范围：

- 功能开发；
- Bug 修复；
- 日志 / 真机问题排查；
- Player / PiP / Transport / Cache / Emby / Navigation / Compatibility 等实现工作；
- CI / IPA / Build 验证。

## Status

**Active**

- **Task**：新增播放器“选集”功能：在 Build173 现有底部功能栏增加选集入口，点击后从底部向上弹出横向剧集选择面板；设置中增加“自动加载下一集”选项，并基于现有播放结束/Emby 剧集数据实现正确的下一集切换逻辑。
- **User intent / acceptance criteria**：播放器当前只有字幕等按钮，没有选集按钮；新增一个选集入口。点击后可横向浏览并切换同一剧集集数，交互样式参考用户提供截图的底部上弹面板；当前集有明确“正在播放”状态；自动加载下一集可在设置中开关，不能误把异常 EOF/提前结束当作正常剧终触发。
- **Baseline**：用户 2026-08-25 真机确认当前安装为 OnePlayer 0.14.6 / Build173，并更正此前“已有选集按钮”的说法——当前存在的是字幕按钮，确实没有选集按钮。对应功能基线：PR #238；branch `fix/pip-seek-completion-return-simplify-0.14.6`；known head `4f7acf8da06ded00db735b07210983a0d2dd5be6`。本任务开发 branch：`feat/player-episode-picker-0.14.7`，从该 Build173 分支创建。
- **Evidence**：用户 2026-08-25 提供目标 UI 截图并明确要求选集横向上弹面板；随后真机确认版本为 `0.14.6 (173)`，并最终更正当前播放器并无选集按钮。源码审计：`PlayerControlPanel` 已存在 `.episodes` 枚举和占位页，但 `PlayerBottomFunctionBar` 当前只展示播放信息、音轨字幕、倍速和播放设置；`EmbyAPIClient.seriesEpisodes()` 已按 `ParentIndexNumber,IndexNumber` 升序提供整部剧集；详情页已有成熟的播放源解析逻辑；`PlayerController.handleEndEvent()` 先经过 `PrematureEOFGuard`，可作为可信自然结束边界。
- **Files / modules in scope**：`Sources/UI/PlayerControlPanelViews.swift`、`PlayerScreen.swift`、`PlayerSettings.swift` / `PlayerSettingsView.swift`、新增播放器剧集上下文/面板文件；`Sources/Player/PlayerController.swift` 仅允许增加“可信自然结束”信号，不改变 EOF 恢复算法；必要时更新 `AppIdentity.swift` 版本标识。Emby API 复用现有 `libraryItem` / `seriesEpisodes` / `playbackInfo` / `resolvePlaybackSource`，不新增媒体代理链。
- **Frozen / do-not-touch**：MPV fast Seek；PiP Build173；UnifiedTransport/Range/302/115 客户端直连；Session cache 核心语义；系统导航所有权；不得引入时间→字节比例 Seek。
- **Completed**：需求与真实 Build 已对齐；已确认当前没有选集按钮；已创建 `feat/player-episode-picker-0.14.7`；已审计剧集数据来源、播放源解析、设置持久化、PlayerController/Transport 状态所有权和自然结束保护。架构决定：换集不允许在同一个 `PlayerController` 内原地替换 source，因为其 `PlaybackOrchestrator` / `PlaybackTransportContext` 都绑定当前媒体源；应由全屏播放器宿主持有当前 source，每次换集完整停止旧播放会话并创建新会话，同时保持全屏播放器容器不退出。自动下一集只在 `PrematureEOFGuard` 判定为非 premature 的可信自然结束后触发；不预取 115 媒体直链，不加 timer/watchdog，只预取/复用剧集元数据。
- **Validation state**：真实基线已确认；开发分支已创建；尚未 Code written。
- **Pending**：实现播放器全屏宿主的会话替换；新增选集按钮；实现横向底部面板、当前集定位和手动换集；增加自动下一集设置；接入可信自然结束信号；静态回归检查；CI/IPA；真机验证。
- **Next exact action**：在 `feat/player-episode-picker-0.14.7` 落第一版最小实现；先新增播放器剧集 coordinator/overlay，再接 `PlayerScreen` 会话替换和 `PlayerController` trusted natural-end signal，最后跑 CI。
- **Rejected / do-not-repeat**：此前“当前真机已经存在选集按钮”的判断已由用户更正，禁止继续沿用；不得通过 duration/fileSize 或固定计时器猜测下一集；不得因为播放引擎发出单一 EOF 就无条件切下一集；不得把下一集 115/CDN 临时直链提前长时间解析并缓存；不得为本功能重构冻结的 Transport/Seek/PiP。
- **Open questions / risks**：横向面板视觉细节需等待真机确认；换集时需要避免旧 `PlayerScreen` onDisappear 触发主界面竖屏恢复造成闪屏；自动下一集默认值与真机交互可在首版验证后按用户反馈调整。

## Latest accepted functional baseline

- OnePlayer 0.14.6 / Build173
- PR #238
- branch `fix/pip-seek-completion-return-simplify-0.14.6`
- task branch `feat/player-episode-picker-0.14.7`
- 用户真机确认：当前播放器没有选集按钮，只有字幕等现有功能按钮
- PiP 暂时冻结
- 后续功能开发不默认以 `main` 作为最新功能测试基线

## Active task template

进入可能持续多个步骤的开发任务后，应尽早改为 `Active`，并滚动维护：

- **Task**：当前功能任务的一句话目标
- **User intent / acceptance criteria**：怎样算完成
- **Baseline**：Build / version / branch / PR / commit
- **Evidence**：日志、真机结果、源码事实或明确需求
- **Files / modules in scope**：允许修改的真实范围
- **Frozen / do-not-touch**：不得顺手修改的区域
- **Completed**：已经完成且有证据的步骤
- **Validation state**：Code written / CI passed / IPA produced / Real-device tested / Stable/frozen
- **Pending**：尚未完成的步骤
- **Next exact action**：新会话接手后的第一项具体动作
- **Rejected / do-not-repeat**：本任务中已被证据否定的路线
- **Open questions / risks**：仍未解决的问题

## Proactive checkpoint rule

无法可靠预知会话上限，因此不能等“快到上限”才保存。

只要任务目标明确并已有可用基线/工作方向，就建立第一个 `Active` checkpoint；之后在真实基线确认、第一版有效代码、CI/IPA、真机结果、方案转向等重要节点刷新。

不需要为每个小编辑更新。

## Completion rule

任务完成后：

1. 将长期结论同步到 `PROJECT_STATE.md` / `MODULE_STATUS.md` / `TECHNICAL_DECISIONS.md` / `BUILD_TEST_INDEX.md`；
2. 仅将本文件恢复为 `Idle`；
3. 不得改动或重置 `CURRENT_WORK_RULES.md`。
