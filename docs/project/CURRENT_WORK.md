# OnePlayer Current Work Router

`CURRENT_WORK.md` 只负责**跨会话类型路由**，不保存具体任务正文。

OnePlayer 当前有两类工作：

- `CURRENT_WORK_DEV.md` — 开发/功能任务路由器；其下允许多个独立功能任务同时 Active
- `CURRENT_WORK_RULES.md` — 项目规则 / 文档治理 / AI 协作机制 checkpoint

规则维护与多个功能开发任务可以同时存在，互不覆盖、互不重置。

## Explicit routing phrases

以下短口令具有明确、最高优先级的会话类型含义：

- `当前为规则会话` → `CURRENT_WORK_RULES.md`
- `当前为开发会话` → `CURRENT_WORK_DEV.md`
- `当前为功能会话` → `CURRENT_WORK_DEV.md`

语义等价的明确表达同样有效。

## Session routing

新会话只能根据**用户当前消息中足够明确的会话用途**选择规则或开发类型：

1. 明确属于项目规则、Project Instructions、`AGENTS.md`、`START_HERE.md`、Skill、AI 协作或文档治理 → 规则会话。
2. 明确属于功能开发、Bug、播放日志、真机问题、架构实现、Build / CI / IPA → 开发/功能会话。
3. 如果当前消息无法可靠判断属于哪类会话，必须明确告知用户并让用户选择；不得猜测或激活任何任务。
4. 不得根据旧聊天主题、Active 状态、最近更新时间、紧急程度或模型偏好替用户选择。

## Development task routing

路由为开发/功能会话后，还必须进一步确认**具体功能任务**。

功能任务 checkpoint 位于：

`docs/project/current/dev/<Work-ID>.md`

具体规则见：

- `CURRENT_WORK_DEV.md`
- `docs/project/current/dev/README.md`

如果用户只明确了“这是功能/开发会话”，但没有说明继续哪个功能还是新建任务，则必须读取当前 Active 功能 checkpoint 并让用户选择。即使只有一个 Active 功能，也不能仅凭其存在自动认定要继续它。

在具体功能任务确定前，不得创建/修改功能 checkpoint，不得创建、切换或复用功能 branch，也不得开始代码修改。

## Isolation rule

- 规则会话只维护 `CURRENT_WORK_RULES.md` 和永久规则文件，不得修改任何功能任务 checkpoint。
- 每个功能会话只维护自己明确选定的 `docs/project/current/dev/<Work-ID>.md` 和对应 branch/PR。
- 一个功能任务不得覆盖、清空、合并或重置另一个功能任务 checkpoint。
- 两个 Active 功能任务不得共用同一个开发 branch。
- 长期项目结论仍写入对应的 `PROJECT_STATE.md` / `MODULE_STATUS.md` / `TECHNICAL_DECISIONS.md` / `BUILD_TEST_INDEX.md` 或永久规则文件。

## Parallel development guard

多个功能任务可以并行，但新建任务前必须比较其他 Active 任务的文件范围、状态所有者、Frozen 区域和依赖。

如果两个任务会修改同一文件、同一状态所有者、同一 Frozen/P0 核心路径，或一个依赖另一个未合并代码，不得静默并行；必须明确告诉用户风险，并优先串行或明确记录 stacked/dependent work。

并行任务的 Build / version candidate 也必须唯一，不能共享同一个 Build 编号或同名 IPA candidate。

## Proactive checkpoint rule

无法可靠预知 ChatGPT 会话/上下文上限，因此不能等到“快满了”才保存。

只有在会话类型和具体功能任务（若为开发会话）都明确后，进入多步骤任务时才允许建立对应 checkpoint。只要目标和可用基线/工作方向明确，就应尽早保存；之后在有独立续接价值的里程碑滚动刷新。

目标是：任何一个并行会话突然达到上限时，新会话通过明确声明会话类型和具体任务，就能从该任务的 `Next exact action` 继续，而不依赖旧聊天导出。
