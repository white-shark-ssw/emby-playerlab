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

- **Task**：接通播放器现有“选集”按钮：点击后从底部向上弹出横向剧集选择面板；设置中增加“自动加载下一集”选项，并基于现有播放结束/Emby 剧集数据设计正确的下一集切换逻辑。
- **User intent / acceptance criteria**：不新增或重复播放器“选集”按钮；复用当前真机已经存在但未生效的入口。点击后可横向浏览并切换同一剧集集数，交互样式参考用户提供截图的底部上弹面板；当前集有明确状态；自动加载下一集可在设置中开关，不能误把异常 EOF/提前结束当作正常剧终触发。
- **Baseline**：项目资料记录的最新功能基线为 OnePlayer 0.14.6 / Build173；PR #238；branch `fix/pip-seek-completion-return-simplify-0.14.6`；known head `4f7acf8da06ded00db735b07210983a0d2dd5be6`。但用户 2026-08-25 真机明确确认当前播放器已经存在“选集”按钮，而该 Build173 源码的当前 `PlayerBottomFunctionBar` 没有暴露 `.episodes`，因此当前真机安装包与已核对源码存在 UI 对应关系冲突，必须先确认当前安装版本/Build 后再落代码。
- **Evidence**：用户 2026-08-25 明确提出新功能需求并提供目标 UI 截图；随后明确纠正“目前已经有选集按钮，只是没有生效”。源码审计：`PlayerControlPanel` 已存在 `.episodes` 和占位页；较早 `fix/player-ui-v1-real-device` 源码也有真实“选集”按钮；Build173/main 当前 `PlayerBottomFunctionBar` 则只展示播放信息、音轨字幕、倍速和播放设置省略号。
- **Files / modules in scope**：待真实安装 Build 对齐后确认。已知相关定义包括 `Sources/UI/PlayerControlPanelViews.swift`、`PlayerScreen.swift`、`PlayerSettings.swift` / `PlayerSettingsView.swift`、`EmbyMediaDetailView.swift` / `EmbyEpisodePickerView.swift`、`EmbyAPIClient.seriesEpisodes()`、`PlayerController.handleEndEvent()`。
- **Frozen / do-not-touch**：MPV fast Seek；PiP Build173；UnifiedTransport/Range/302/115 客户端直连；Session cache 核心语义；系统导航所有权；不得引入时间→字节比例 Seek。
- **Completed**：已确认需求；已审计剧集数据来源、播放结束保护与设置持久化入口；已确认自然结束经过 `PrematureEOFGuard`，因此自动下一集可以只挂在非 premature 的正常结束结果上，不需要计时器；已确认现有 `.episodes` 面板目前只是未接数据的占位实现；已记录用户真机“按钮已存在”的最高优先级证据。
- **Validation state**：需求/源码审计完成；尚未 Code written。
- **Pending**：确认用户当前安装包版本号 + Build，定位完全对应源码；接通现有选集入口；实现横向底部面板、当前集定位和手动换集；增加自动下一集设置；实现自然结束后的下一集切换；静态回归检查；CI/IPA；真机验证。
- **Next exact action**：获得当前真机“关于 OnePlayer”中的版本号 + Build 后，读取对应 branch/commit 的 `PlayerControlPanelViews.swift` 与 `PlayerScreen.swift`，只在真实现有按钮调用链上接入 episode context，不新增第二个入口。
- **Rejected / do-not-repeat**：不得重复新增“选集”按钮；不得通过 duration/fileSize 或固定计时器猜测下一集；不得因为播放引擎发出单一 EOF 就无条件切下一集；不得为本功能重构冻结的 Transport/Seek/PiP。
- **Open questions / risks**：当前真机 UI 与 Build173 已核对源码不一致，必须先锁定真实安装 Build；需要确认现有播放入口如何携带 SeriesId/SeasonId/episode context；手动选集切换时 Emby progress/session 的停止与新播放启动必须沿用现有正式生命周期。

## Latest accepted functional baseline

- 项目资料：OnePlayer 0.14.6 / Build173
- 当前任务新增真机证据：播放器已经存在“选集”按钮，但未生效；真实安装 Build 待确认
- PiP 暂时冻结
- 后续功能开发应先确认实际 Build / PR / branch / commit，不默认以 `main` 作为最新功能测试基线

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
