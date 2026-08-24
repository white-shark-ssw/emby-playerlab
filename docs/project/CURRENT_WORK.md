# OnePlayer Current Work Router

`CURRENT_WORK.md` 现在只负责**跨会话工作槽路由**，不再保存具体任务正文。

OnePlayer 允许以下两个工作槽同时独立存在：

- `CURRENT_WORK_DEV.md` — 功能开发 / Bug / 日志 / 真机 / 架构实现 / CI / IPA
- `CURRENT_WORK_RULES.md` — 项目规则 / 文档治理 / AI 协作机制

两个槽可以同时为 `Active`，互不覆盖、互不重置。

## Session routing

新会话读取本文件后，根据用户当前会话意图选择工作槽：

1. 用户明确说“当前会话用于维护修改项目规则”“规则维护”“修改项目指令”“维护 AGENTS / START_HERE / Skill / 文档治理”等，选择 `CURRENT_WORK_RULES.md`。
2. 用户要继续功能开发、修 Bug、分析播放日志、真机问题、Build / CI / IPA 等，选择 `CURRENT_WORK_DEV.md`。
3. 用户只说“继续 OnePlayer”且只有一个槽为 `Active`，续接唯一的 Active 槽。
4. 如果两个槽都为 `Active`，但用户没有说明当前会话属于哪一类，不得把两个任务合并或互相覆盖；先明确展示两个 Active 槽，再让用户选择要续接的槽。

## Isolation rule

- 开发会话只更新 `CURRENT_WORK_DEV.md`，不得覆盖或重置 `CURRENT_WORK_RULES.md`。
- 规则维护会话只更新 `CURRENT_WORK_RULES.md`，不得覆盖或重置 `CURRENT_WORK_DEV.md`。
- 一个槽完成时只将该槽恢复为 `Idle`。
- 长期项目结论仍写入对应的 `PROJECT_STATE.md` / `MODULE_STATUS.md` / `TECHNICAL_DECISIONS.md` / `BUILD_TEST_INDEX.md` 或永久规则文件。

## Proactive checkpoint rule

两个工作槽都必须采用前置 checkpoint：无法可靠预知 ChatGPT 会话/上下文上限，因此不能等到“快满了”才保存。

进入多步骤任务后，只要目标和可用基线/工作方向已经明确，就应尽早把对应槽设为 `Active`；之后在有独立续接价值的里程碑滚动刷新。

目标是：任一会话突然达到上限时，新会话只需声明自己的用途，就能从对应槽的 `Next exact action` 继续，而不依赖旧聊天导出。
