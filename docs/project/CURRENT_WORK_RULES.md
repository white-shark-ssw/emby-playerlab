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

- **Task**：为并行功能开发增加“直接说功能名即可安全续接”的唯一匹配路由，并加强 branch / Build candidate 防串线检查。
- **User intent / acceptance criteria**：用户可直接说“详情页优化”等功能名称；若它与一个 Active 功能任务唯一且强匹配，应自动选择该任务；若存在多个可能匹配、匹配不足或无法确认，则必须让用户选择，不能猜。自动续接前还要确认任务自己的 branch / PR / Build candidate 没有与其他 Active 任务冲突或串线。
- **Baseline**：`main`，PR #250 已建立多功能并行 checkpoint 模型；现有 Active 任务 `DEV-player-episode-picker` 独立保存。
- **Evidence / reason**：用户希望减少每次输入完整 Work ID 的负担，同时最担心多个并行会话造成代码分支冲突或版本号/Build candidate 混乱。
- **Files in scope**：`AGENTS.md`、`docs/project/CURRENT_WORK_DEV.md`、`docs/project/current/dev/README.md`、`docs/project/DOCUMENTATION_POLICY.md`、本规则 checkpoint；必要时仅补充现有 checkpoint 的 routing aliases，不修改其产品代码或测试证据。
- **Do-not-touch**：App 源码、任何功能 branch 产品实现、Player/PiP/Transport/Cache 等功能代码。
- **Completed**：已确认采用显式 `Routing aliases / keywords` + 唯一强匹配自动路由；不采用仅凭模型模糊语义或“唯一 Active”自动选择。
- **Validation state**：Rule checkpoint documented
- **Pending**：写入永久路由规则；增加续接前 branch/PR/Build identity guard；检查 diff；合并 PR；恢复本槽 Idle。
- **Next exact action**：创建规则分支，更新开发路由器、并行 checkpoint 模板和 AGENTS.md。
- **Rejected / do-not-repeat**：只因为一个任务是唯一 Active 就自动进入；多个候选时按模型偏好挑一个；自动把没有唯一匹配的功能名当作新任务并创建 checkpoint；未核对 branch/Build identity 就开始写代码。
- **Open questions / risks**：无。

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
3. 不得改动、删除或重置任何仍在进行中的功能任务 checkpoint。
