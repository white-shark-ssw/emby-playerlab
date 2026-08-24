# OnePlayer Documentation Policy

## Purpose

`docs/project/` 是 OnePlayer 日常开发的权威接手层。v1-v19 长会话导出只作为历史证据，不作为每次开发必须重新读取的资料。

## 新会话入口

任何新的 OnePlayer 会话，首先读取：

1. `START_HERE.md`
2. `CURRENT_WORK.md`
3. 根据用户当前消息中明确的会话用途进入规则会话或开发/功能会话
4. `PROJECT_STATE.md`
5. `MODULE_STATUS.md`
6. `TECHNICAL_DECISIONS.md`
7. `BUILD_TEST_INDEX.md`

然后再读取当前任务相关源码、PR、branch、日志或规则文件。

### 会话类型路由

- `当前为规则会话` → `CURRENT_WORK_RULES.md`
- `当前为开发会话` / `当前为功能会话` → `CURRENT_WORK_DEV.md`
- 语义明确的规则维护表达 → 规则会话
- 语义明确的功能开发、Bug、日志、真机、架构实现、CI / IPA 表达 → 开发/功能会话
- 直接说一个明确功能名（例如“详情页优化”）也可以同时表达“开发/功能会话 + 具体功能任务”，但只有唯一强匹配已有 Active checkpoint 时才允许自动续接。

如果用户当前消息不足以可靠判断属于规则会话还是开发/功能会话，必须明确告知用户并让用户选择。

在用户选择前：不得根据 Active 状态、最近更新时间、旧聊天主题、任务紧急程度或模型猜测自动选择；不得激活、修改、覆盖或清空任何工作 checkpoint；不得擅自开始某个任务。

## 开发会话支持多个并行功能

`CURRENT_WORK_DEV.md` 是**开发任务路由器**，不保存单个 Active 功能正文。

每个当前功能任务拥有独立 checkpoint：

`docs/project/current/dev/<Work-ID>.md`

任务模板和并行约束见：

`docs/project/current/dev/README.md`

### 直接使用功能名称续接

每个 Active 功能 checkpoint 应维护 `Routing aliases / keywords`，包括用户日常可能直接说出的短功能名。

用户直接输入“详情页优化”“选集功能”等名称时，按以下顺序选择已有任务：

1. 精确 Work ID；
2. 明确 Task 名称；
3. 明确 `Routing aliases / keywords`；
4. 唯一、可解释的强关键词匹配。

只有恰好一个 Active checkpoint 强匹配时才能自动续接。

如果多个任务都匹配、只有模糊语义相关、无法指出具体命中字段，或既可能表示继续旧任务又可能表示新任务，则必须展示候选并让用户选择。

即使只有一个 Active 功能，也不能仅凭 Active 状态自动选择；没有唯一匹配时也不能自动创建新任务。

具体任务未明确前，不得创建/修改功能 checkpoint，不得创建、切换或复用功能 branch，不得开始代码修改。

### Resume identity guard

已有任务被选中后，开始代码修改前必须核对：

- checkpoint 记录的 working branch / PR / head commit；
- GitHub 当前真实 branch / PR 身份；
- 已分配的 Build / version / IPA candidate；
- 其他 Active checkpoint 是否占用了同一 branch、Build 编号或同名 IPA candidate。

出现不一致或重复占用时必须停止并告诉用户，不能自行猜测哪个记录应该被覆盖。

## Required documents

- `START_HERE.md` — 新会话最短入口。
- `CURRENT_WORK.md` — 规则/开发会话类型路由。
- `CURRENT_WORK_DEV.md` — 多功能开发任务路由器。
- `current/dev/README.md` — 独立功能 checkpoint 模板、名称路由与并行规则。
- `current/dev/<Work-ID>.md` — 每个正在进行功能自己的短期 checkpoint；完成后删除。
- `CURRENT_WORK_RULES.md` — 规则 / 文档治理的滚动 checkpoint。
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

## 多功能并行开发隔离

允许多个功能开发会话同时 Active，但必须满足：

1. 每个功能有唯一 Work ID；
2. 每个功能有独立 `current/dev/<Work-ID>.md`；
3. 每个功能有独立开发 branch；
4. 进入评审/测试阶段后使用独立 PR；
5. 每个功能会话只维护自己的 checkpoint；
6. 两个 Active 功能不得共用同一个开发 branch；
7. 每个任务维护稳定的 `Routing aliases / keywords`；
8. 已分配的 Build/version/IPA candidate 在任务 Active 期间保持唯一占用。

### 并行前冲突检查

创建新的并行功能任务前，必须读取其他 Active 功能 checkpoint，比较：

- Files / modules in scope；
- State owner；
- Frozen / do-not-touch；
- 共享基础设施；
- 未合并依赖。

如果两个任务可能修改同一源码文件、同一核心状态所有者、同一 Frozen/P0 路径，或一个任务依赖另一个尚未合并的代码，不得静默并行。必须明确告诉用户存在冲突风险；优先串行。如果确实需要依赖开发，则明确记录 stacked/dependent work。

Git 最终能否自动合并，不代表架构状态所有权适合并行修改。

### Build / version candidate

分配测试 Build / version candidate 前必须检查：

- `BUILD_TEST_INDEX.md`；
- `current/dev/` 其他 Active checkpoint；
- 已存在 CI / IPA candidate。

并行任务不得复用同一 Build 编号或同名 IPA candidate。Build candidate 写入 Active checkpoint 后视为该任务占用，除非任务明确完成/放弃并同步状态，否则其他任务不得复用。

### 合并前重新同步

另一个并行 PR 可能先合并，因此当前任务在最终 CI / IPA / merge 前必须重新检查目标 branch 是否前进，以及是否新增文件、状态所有者或依赖重叠。

如果同步最新目标后代码发生实质变化，必须重新执行受影响验证；旧 CI 不代表同步后代码已经通过。

## 会话中断与 checkpoint

会话上限不可预测，所以不得把交接建立在“用户提前提醒”或“快到上限再保存”之上。

- 规则任务使用 `CURRENT_WORK_RULES.md`。
- 每个功能任务使用自己的 `current/dev/<Work-ID>.md`。
- 规则任务与多个功能任务可以同时 Active。

只有会话类型和具体功能任务（若为开发会话）已经明确后，才允许建立对应 checkpoint。

只要任务目标和可用真实基线/工作方向明确，就应尽早建立第一个 checkpoint；随后在有独立续接价值的节点刷新，例如：

1. 已确认真实 Build / PR / branch / commit 或规则基线；
2. 已形成第一版有效代码、规则决定或文档修改；
3. CI / IPA 状态发生变化；
4. 用户提供新的真机结果；
5. 原假设被证伪或方向发生重要变化；
6. 其他足以影响新会话 `Next exact action` 的重要里程碑。

不要求每个小编辑都提交一次。最近一次 checkpoint 必须足以回答：现在做什么、真实基线、已完成什么、证据等级、还缺什么、下一步是什么、哪些路线不要重复。

功能任务完成后，将长期有效结论转入项目状态文件，并只删除自己的 `current/dev/<Work-ID>.md`；不得影响其他 Active 功能。规则任务完成后写入永久规则文件，并只将 `CURRENT_WORK_RULES.md` 恢复为 Idle。

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
