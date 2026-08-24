# OnePlayer Documentation Policy

## Purpose

`docs/project/` 是 OnePlayer 日常开发的权威接手层。v1-v19 长会话导出只作为历史证据，不作为每次开发必须重新读取的资料。

## 新会话入口

任何新的 OnePlayer 开发会话，首先读取：

1. `START_HERE.md`
2. `PROJECT_STATE.md`
3. `MODULE_STATUS.md`
4. `TECHNICAL_DECISIONS.md`
5. `BUILD_TEST_INDEX.md`

然后再读取当前任务相关源码、PR、branch 和日志。

只有当前资料不足以解释历史争议时，才查询 `docs/history/chat-exports/`。

## Required documents

- `START_HERE.md` — 新会话最短入口。
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

如果一次工作只做资料阅读、纯讨论或没有产生新项目结论，可以不制造无意义更新。

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
