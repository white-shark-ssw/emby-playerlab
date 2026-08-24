# OnePlayer Current Work Router

`CURRENT_WORK.md` 只负责**跨会话工作槽路由**，不保存具体任务正文。

OnePlayer 允许以下两个工作槽同时独立存在：

- `CURRENT_WORK_DEV.md` — 功能开发 / Bug / 日志 / 真机 / 架构实现 / CI / IPA
- `CURRENT_WORK_RULES.md` — 项目规则 / 文档治理 / AI 协作机制

两个槽可以同时为 `Active`，互不覆盖、互不重置。

## Explicit routing phrases

以下短口令具有明确、最高优先级的路由含义：

- `当前为规则会话` → `CURRENT_WORK_RULES.md`
- `当前为开发会话` → `CURRENT_WORK_DEV.md`
- `当前为功能会话` → `CURRENT_WORK_DEV.md`

语义等价的明确表达同样有效，例如“当前会话用于维护修改项目规则”“继续 OnePlayer 功能开发”。

## Session routing

新会话读取本文件后，只能根据**用户当前消息中足够明确的会话用途**选择工作槽：

1. 明确属于项目规则、Project Instructions、`AGENTS.md`、`START_HERE.md`、Skill、AI 协作或文档治理 → `CURRENT_WORK_RULES.md`。
2. 明确属于功能开发、Bug、播放日志、真机问题、架构实现、Build / CI / IPA → `CURRENT_WORK_DEV.md`。
3. 工作槽当前是 `Active` 或 `Idle` **不能单独作为会话类型判断依据**。即使只有一个槽为 `Active`，也不得仅凭这一点自动选择。
4. 如果用户只说“继续 OnePlayer”“接着做”等，而当前消息无法可靠判断属于规则会话还是开发/功能会话，必须明确告知用户“当前会话类型无法确定”，并让用户选择“规则会话”或“开发/功能会话”。
5. 在用户完成选择前：不得把任何槽设为 `Active`，不得修改、覆盖、清空或合并任一槽，也不得擅自开始其中一个任务。
6. 不得根据模型猜测、旧聊天主题、哪个槽最近更新、哪个槽为 `Active`、任务看起来更紧急等因素替用户做选择。

## Isolation rule

- 开发会话只更新 `CURRENT_WORK_DEV.md`，不得覆盖或重置 `CURRENT_WORK_RULES.md`。
- 规则维护会话只更新 `CURRENT_WORK_RULES.md`，不得覆盖或重置 `CURRENT_WORK_DEV.md`。
- 一个槽完成时只将该槽恢复为 `Idle`。
- 长期项目结论仍写入对应的 `PROJECT_STATE.md` / `MODULE_STATUS.md` / `TECHNICAL_DECISIONS.md` / `BUILD_TEST_INDEX.md` 或永久规则文件。

## Proactive checkpoint rule

两个工作槽都必须采用前置 checkpoint：无法可靠预知 ChatGPT 会话/上下文上限，因此不能等到“快满了”才保存。

**只有在会话类型已经明确路由后**，进入多步骤任务时才允许把对应槽设为 `Active`。只要目标和可用基线/工作方向已经明确，就应尽早建立 checkpoint；之后在有独立续接价值的里程碑滚动刷新。

目标是：任一会话突然达到上限时，新会话通过明确声明自己的用途进入对应槽，再从该槽的 `Next exact action` 继续，而不依赖旧聊天导出。
