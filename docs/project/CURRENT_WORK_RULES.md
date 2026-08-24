# OnePlayer Current Work — Rules

这是**规则 / 文档治理专用**的跨会话滚动 checkpoint。它与功能开发工作独立，不能被开发会话覆盖或重置。

适用范围：

- ChatGPT Project Instructions；
- `AGENTS.md`；
- `START_HERE.md`；
- `DOCUMENTATION_POLICY.md`；
- AI Coding Rules / Copilot Instructions / Skills；
- 项目接手、证据分级、Frozen、会话续接等协作机制。

## Status

**Active**

- **Task**：设计并固化 OnePlayer 多功能会话并行开发机制。
- **User intent / acceptance criteria**：允许同时打开多个功能开发会话；每个功能必须有独立 checkpoint、branch/PR，不得互相覆盖；无法判断具体功能任务时必须让用户选择，不能猜测。
- **Baseline**：branch `docs/parallel-feature-work`，基于 `main` commit `21a86451e700ff265e153aedb95486bd6914c78d`。
- **Evidence / reason**：实际发现 `CURRENT_WORK_DEV.md` 已被另一个“播放器选集/自动下一集”功能任务占用并处于 Active，Build174 candidate 已 CI/IPA、等待真机；这证明单一开发槽无法安全支持并行功能会话。
- **Files in scope**：`AGENTS.md`、`docs/project/CURRENT_WORK.md`、`docs/project/CURRENT_WORK_DEV.md`、`docs/project/DOCUMENTATION_POLICY.md`、`docs/project/current/dev/README.md`、现有选集任务迁移 checkpoint、本规则 checkpoint。
- **Do-not-touch**：App 源码、Player / PiP / Transport / Cache 等功能实现；不改变选集功能代码或其 Build174 证据。
- **Completed**：已建立“开发路由器 + 每功能独立 checkpoint + 每功能独立 branch/PR”模型；已定义任务选择/新建规则；已定义同文件/同状态所有者/Frozen/依赖冲突 guard；已定义唯一 Build/version candidate 规则和合并前同步/重验规则；已将现有选集任务完整迁移为 `DEV-player-episode-picker`；已检查分支相对 main 仅修改 6 个规则/文档文件，无 App 源码。
- **Validation state**：Rule documented on branch；existing active dev checkpoint preserved
- **Pending**：创建并合并规则 PR；合并后确认 main 的选集 checkpoint 与开发路由器；将本规则槽恢复为 `Idle`。
- **Next exact action**：创建 PR，确认可合并后 squash merge；随后只重置 `CURRENT_WORK_RULES.md`，不得删除 `DEV-player-episode-picker`。
- **Rejected / do-not-repeat**：多个开发会话共享同一个可写 `CURRENT_WORK_DEV.md`；固定数量 DEV1/DEV2/DEV3 槽；根据 Active/最近更新自动猜具体功能任务；两个 Active 功能共用 branch；把 Git mergeability 当成状态所有权并行安全证明。
- **Open questions / risks**：无规则层未解决问题；具体并行任务仍需每次做范围冲突检查。

## Permanent rule sources

长期有效规则以以下文件为准：

- `/AGENTS.md`
- `docs/project/CHATGPT_PROJECT_INSTRUCTIONS.md`
- `docs/project/START_HERE.md`
- `docs/project/DOCUMENTATION_POLICY.md`
- `.github/copilot-instructions.md`
- `.github/skills/`

## Active task template

进入可能持续多个步骤的规则维护任务后，应尽早改为 `Active`，并滚动维护：

- **Task**：当前规则调整的一句话目标
- **User intent / acceptance criteria**：用户真正希望约束或改善什么
- **Baseline**：当前规则文件 / branch / PR / commit
- **Evidence / reason**：触发规则修改的实际问题或已确认需求
- **Files in scope**：允许修改的规则/文档文件
- **Do-not-touch**：当前不应修改的 App 源码或无关规则
- **Completed**：已经确认并写入的规则决定
- **Validation state**：Rule drafted / documented / PR opened / merged
- **Pending**：尚未完成的规则问题
- **Next exact action**：新规则会话接手后的第一项具体动作
- **Rejected / do-not-repeat**：已否决的规则设计
- **Open questions / risks**：尚未解决的问题

## Proactive checkpoint rule

无法可靠预知会话上限，因此不能等“快到上限”才保存。

只要规则问题和基本方向已经明确，就建立第一个 `Active` checkpoint；之后在形成规则决定、修改永久规则文件、创建/合并 PR、方案转向等重要节点刷新。

不需要为每个小讨论更新。

## Completion rule

任务完成后：

1. 将最终规则写入对应永久规则文件；
2. 仅将本文件恢复为 `Idle`；
3. 不得改动或重置开发任务 checkpoint。
