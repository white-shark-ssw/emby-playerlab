# OnePlayer Current Work

这是用于跨会话续接的**短期滚动状态文件**。它只保存当前正在进行的一件工作，不作为长期历史记录。

## Status

**Idle**

当前没有正在进行中的源码开发任务。

## Latest accepted functional baseline

- OnePlayer 0.14.6 / Build173
- PiP 暂时冻结
- 后续功能开发应先确认实际 Build / PR / branch / commit，不默认以 `main` 作为最新功能测试基线

## Active task template

当进入新开发任务时，将本文件改为 `Active`，并只维护以下内容：

- **Task**：当前任务的一句话目标
- **User intent / acceptance criteria**：用户真正要求什么、怎样算完成
- **Baseline**：对应 Build / version / branch / PR / commit
- **Evidence**：当前日志、真机结果、源码事实或明确需求
- **Files / modules in scope**：允许修改的真实范围
- **Frozen / do-not-touch**：本任务明确不能顺手修改的区域
- **Completed**：已经完成并有证据的步骤
- **Validation state**：Code written / CI passed / IPA produced / Real-device tested / Stable/frozen
- **Pending**：尚未完成的步骤
- **Next exact action**：新会话接手后的第一项具体动作
- **Open questions / risks**：仍未被证据解决的问题

## Checkpoint rule

长任务不要等到会话结束才写交接。出现以下节点时，应主动刷新本文件：

1. 已确认真实测试基线和实现方向；
2. 形成第一版有效代码修改；
3. CI / IPA 状态发生变化；
4. 用户提供新的真机结果；
5. 发现原假设错误、方案需要转向；
6. 当前会话可能被中断前的任一重要里程碑。

不需要为每个小编辑更新，避免制造噪音。

## Completion rule

任务完成后：

1. 把长期有效结论写入 `PROJECT_STATE.md` / `MODULE_STATUS.md` / `TECHNICAL_DECISIONS.md` / `BUILD_TEST_INDEX.md`；
2. 将本文件恢复为 `Idle`；
3. 不把历史过程无限追加到这里。

新会话看到 `Active` 时，应优先按 `Next exact action` 续接，不要无理由从头重复已经完成的分析。
