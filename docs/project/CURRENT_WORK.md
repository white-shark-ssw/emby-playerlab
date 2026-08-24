# OnePlayer Current Work

这是用于跨会话续接的**短期滚动状态文件**。它只保存当前正在进行的一件工作，不作为长期历史记录。

它同时适用于：

- 多步骤源码开发；
- 日志/真机问题排查；
- 架构调整；
- 规则、文档治理与 AI 协作机制调整。

## Status

**Idle**

当前没有正在进行中的跨会话任务。

## Latest accepted functional baseline

- OnePlayer 0.14.6 / Build173
- PiP 暂时冻结
- 后续功能开发应先确认实际 Build / PR / branch / commit，不默认以 `main` 作为最新功能测试基线

## Active task template

当进入可能持续多个步骤的任务时，应尽早将本文件改为 `Active`，而不是等会话快结束时才建立交接。

只维护以下内容：

- **Task**：当前任务的一句话目标
- **User intent / acceptance criteria**：用户真正要求什么、怎样算完成
- **Baseline**：对应 Build / version / branch / PR / commit；规则任务可写当前规则文件/commit
- **Evidence**：当前日志、真机结果、源码事实、明确需求或已确认规则
- **Files / modules in scope**：允许修改的真实范围
- **Frozen / do-not-touch**：本任务明确不能顺手修改的区域
- **Completed**：已经完成并有证据的步骤
- **Validation state**：Code written / CI passed / IPA produced / Real-device tested / Stable/frozen；规则任务可注明 Rule documented / merged
- **Pending**：尚未完成的步骤
- **Next exact action**：新会话接手后的第一项具体动作
- **Open questions / risks**：仍未被证据解决的问题

## Proactive checkpoint rule

无法可靠预知 ChatGPT 会话或上下文上限，因此**禁止把交接保存推迟到“快到上限”时**。

对多步骤任务：

1. 一旦任务目标明确，并且已经有可用的真实基线或工作方向，就建立第一个 `Active` checkpoint；
2. 已确认真实 Build / PR / branch / commit 后刷新；
3. 形成第一版有效代码、规则决定或文档修改后刷新；
4. CI / IPA 状态变化后刷新；
5. 用户提供新的真机结果后刷新；
6. 原假设被证伪、方案转向或范围发生重要变化后刷新；
7. 其他足以改变新会话下一步动作的重要里程碑后刷新。

不依赖用户提醒，也不依赖用户判断会话还剩多少容量。

不需要为每个小编辑更新，避免制造噪音。目标是：**无论在哪一个普通节点突然被会话上限切断，GitHub 中最近一次 checkpoint 都足以让新会话继续。**

## Completion rule

任务完成后：

1. 把长期有效结论写入 `PROJECT_STATE.md` / `MODULE_STATUS.md` / `TECHNICAL_DECISIONS.md` / `BUILD_TEST_INDEX.md` 或对应的永久规则文件；
2. 将本文件恢复为 `Idle`；
3. 不把历史过程无限追加到这里。

新会话看到 `Active` 时，应优先按 `Next exact action` 续接，不要无理由从头重复已经完成的分析。
