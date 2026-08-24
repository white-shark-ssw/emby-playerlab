# OnePlayer Current Work — Development

这是**功能开发专用**的跨会话滚动 checkpoint。它与规则维护槽独立，不能被规则会话覆盖或重置。

适用范围：

- 功能开发；
- Bug 修复；
- 日志 / 真机问题排查；
- Player / PiP / Transport / Cache / Emby / Navigation / Compatibility 等实现工作；
- CI / IPA / Build 验证。

## Status

**Idle**

当前没有正在进行中的功能开发任务。

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
