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

- **Task**：新增播放器内“选集”功能：点击后从底部向上弹出横向剧集选择面板；设置中增加“自动加载下一集”选项，并基于现有播放结束/Emby 剧集数据设计正确的下一集切换逻辑。
- **User intent / acceptance criteria**：播放器内可快速横向浏览并切换同一剧集的集数；交互样式参考用户提供截图的底部上弹面板；当前集有明确状态；自动加载下一集可在设置中开关，不能误把异常 EOF/提前结束当作正常剧终触发。
- **Baseline**：OnePlayer 0.14.6 / Build173；PR #238；branch `fix/pip-seek-completion-return-simplify-0.14.6`；known head `4f7acf8da06ded00db735b07210983a0d2dd5be6`。
- **Evidence**：用户 2026-08-25 明确提出新功能需求并提供目标 UI 截图；当前开发槽此前为 Idle。
- **Files / modules in scope**：待源码审计确认，优先检查现有 PlayerScreen/PlayerController、Emby episode/series 数据模型与 API、播放结束事件、PlayerSettings 持久化和现有详情页选集实现。
- **Frozen / do-not-touch**：MPV fast Seek；PiP Build173；UnifiedTransport/Range/302/115 客户端直连；Session cache 核心语义；系统导航所有权；不得引入时间→字节比例 Seek。
- **Completed**：已确认开发会话路由和 Build173 功能基线；已建立本任务 checkpoint。
- **Validation state**：需求/基线已确认；尚未 Code written。
- **Pending**：审计真实剧集数据来源、播放器状态所有权与播放结束语义；确定自动下一集触发条件；实现 UI/设置/切换；静态回归检查；CI/IPA；真机验证。
- **Next exact action**：读取 Build173 分支中的播放器 UI、PlayerController、剧集详情/选集、Emby API/模型、播放结束处理与 PlayerSettings 真实定义和调用点，形成最小实现范围后再改代码。
- **Rejected / do-not-repeat**：不得通过 duration/fileSize 或固定计时器猜测下一集；不得因为播放引擎发出单一 EOF 就无条件切下一集；不得为本功能重构冻结的 Transport/Seek/PiP。
- **Open questions / risks**：需要确认现有播放入口是否已携带 SeriesId/SeasonId/episode context；异常短片/提前 EOF 与正常自然播完必须区分；手动选集切换时 Emby progress/session 的停止与新播放启动必须沿用现有正式生命周期。

## Latest accepted functional baseline

- OnePlayer 0.14.6 / Build173
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
