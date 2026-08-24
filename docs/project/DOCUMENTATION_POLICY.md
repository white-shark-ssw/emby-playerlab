# OnePlayer Documentation Policy

## Purpose

`docs/project/` 是 OnePlayer 日常开发的权威接手层。v1-v19 长会话导出只作为历史证据，不作为每次开发必须重新读取的资料。

## 新会话入口

任何新的 OnePlayer 会话，首先读取：

1. `START_HERE.md`
2. `CURRENT_WORK.md`
3. 根据用户当前消息中明确的会话用途读取 `CURRENT_WORK_DEV.md` 或 `CURRENT_WORK_RULES.md`
4. `PROJECT_STATE.md`
5. `MODULE_STATUS.md`
6. `TECHNICAL_DECISIONS.md`
7. `BUILD_TEST_INDEX.md`

然后再读取当前任务相关源码、PR、branch、日志或规则文件。

工作槽路由：

- `当前为规则会话` → `CURRENT_WORK_RULES.md`
- `当前为开发会话` / `当前为功能会话` → `CURRENT_WORK_DEV.md`
- 语义明确的规则维护表达 → `CURRENT_WORK_RULES.md`
- 语义明确的功能开发、Bug、日志、真机、架构实现、CI / IPA 表达 → `CURRENT_WORK_DEV.md`

### 路由不确定时的硬规则

如果用户当前消息不足以可靠判断属于规则会话还是开发/功能会话，必须明确告知用户当前会话类型无法确定，并让用户选择。

在用户选择前：

- 不得根据哪个槽为 `Active`、哪个槽最近更新、旧聊天主题、任务紧急程度或模型猜测自动选择；
- 即使只有一个槽为 `Active`，也不得仅凭该状态自动路由；
- 不得把任何槽设为 `Active`；
- 不得修改、覆盖、清空或合并任一槽；
- 不得擅自开始某个槽中的任务。

只有会话类型明确后，才读取并操作对应工作槽。如果所选工作槽为 `Active`，新会话应优先按其中记录的真实基线、已完成步骤和 `Next exact action` 续接，不要无理由从头重复已经完成的分析。

只有当前资料不足以解释历史争议时，才查询 `docs/history/chat-exports/`。

## Required documents

- `START_HERE.md` — 新会话最短入口。
- `CURRENT_WORK.md` — 工作槽路由，不保存具体任务正文。
- `CURRENT_WORK_DEV.md` — 功能开发的跨会话滚动 checkpoint。
- `CURRENT_WORK_RULES.md` — 规则 / 文档治理的跨会话滚动 checkpoint。
- `PROJECT_STATE.md` — 项目**现在是什么**。
- `TECHNICAL_DECISIONS.md` — 已验证的重要技术决策和否决路线。
- `BUILD_TEST_INDEX.md` — 重要 Build / CI / IPA / 真机节点。
- `MODULE_STATUS.md` — 模块状态、冻结区、已知问题与下一步。

## 主动更新规则

每次重要开发迭代，必须在**同一轮工作**中主动更新相关项目文档。不要等待用户另行要求整理。

重要迭代包括：

- 新测试 IPA 改变运行行为；
- 真机结果确认或否定假设；
- Player / Transport / Cache / Emby / PiP / Navigation / Compatibility 架构变化；
- 依赖或最低 iOS 变化；
- 一个方向被冻结、放弃或替换；
- 当前功能测试基线发生变化。

规则 / 文档治理会话形成新的长期规则后，同样应在同一轮写入对应永久规则文件。

如果一次工作只做资料阅读、纯讨论或没有产生新项目结论，可以不制造无意义更新。

## 会话中断与双工作槽

会话上限不可预测，所以不得把交接建立在“用户提前提醒”或“快到上限再保存”之上。

OnePlayer 使用两个相互隔离的滚动工作槽：

- `CURRENT_WORK_DEV.md`
- `CURRENT_WORK_RULES.md`

两个槽可以同时为 `Active`。任何会话只维护与自身用途匹配的槽，不得覆盖、清空或合并另一个槽。

**只有在会话类型已经明确后**，进入多步骤任务时才允许把对应槽设为 `Active`。只要任务目标已经明确，并且已经形成可用的真实基线或工作方向，就应尽早建立第一个 checkpoint。

随后在有独立续接价值的节点主动刷新，例如：

1. 已确认真实 Build / PR / branch / commit 或规则基线；
2. 已形成第一版有效代码、规则决定或文档修改；
3. CI / IPA 状态发生变化；
4. 用户提供新的真机结果；
5. 原假设被证伪或方向发生重要变化；
6. 其他足以影响新会话 `Next exact action` 的重要里程碑。

不要求每个小编辑都提交一次。目标不是记录完整过程，而是让最近一次 checkpoint 始终足以回答：

- 现在在做什么；
- 对应哪个真实基线；
- 已经完成什么；
- 当前证据等级是什么；
- 还缺什么；
- 新会话第一步具体做什么；
- 哪些已验证路线不要重复尝试。

因此，即使开发会话和规则维护会话同时存在，并且其中任一个在没有预警的情况下突然达到上限，新会话也可以通过**明确声明自己的用途**进入对应工作槽继续。若没有明确声明且语义不足以判断，必须先让用户选择，不能猜。

任务完成后，把长期有效结论转入对应的项目状态文件或永久规则文件，然后**只将当前槽恢复为 `Idle`**。不得影响另一个槽。

## Evidence levels

绝不能混淆：

1. **Code written** — 代码存在。
2. **CI passed** — 编译/验证通过。
3. **IPA produced** — 安装包已生成。
4. **Real-device tested** — 用户已在目标真机测试。
5. **Stable / frozen** — 用户与项目正式接受为当前合同。

CI 成功或 IPA 存在，不等于运行时问题已经解决。

## Compatibility contract

- Target device: iPhone 15 Pro Max.
- Required real-device OS: iOS 17.0.
- Deployment Target 优先保持 iOS 15.0。
- 只有明确 API/依赖原因才能提高最低版本，并且必须先说明。
- Deployment Target 任何情况下不得高于 iOS 17.0。
- 不为了 UI 便利提高最低系统。

## History handling

v1-v19 原始会话已经归档在：

`docs/history/chat-exports/`

资料冲突时优先级：

1. 用户最新真机结果；
2. 当前真实源码 / 当前测试 branch；
3. CI / IPA 证据；
4. 当前 `docs/project/` 状态；
5. 历史聊天计划或旧结论。

旧导出中“准备修复”不代表已经实现。
