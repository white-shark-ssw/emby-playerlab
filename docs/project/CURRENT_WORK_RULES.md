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

- **Task**：新增“开发任务通过前置检查后必须自主连续推进到可测试 IPA/Artifact 身份核验完成”的执行规则。
- **User intent / acceptance criteria**：任务已经明确且前置检查通过后，除非必须由用户决策/提供信息、出现真实冲突或外部阻塞，否则 AI 不得停在代码完成、检查、提交、CI、出包准备或 checkpoint 等中间状态等待用户说“继续”；应在当前执行能力允许范围内持续推进，直到可测试 IPA/Artifact 已生成并完成 Build/branch/commit/artifact/包身份核验，再交给用户真机测试。
- **Baseline**：`main` at `e6e8443c207caf4ed93e47e5d8c9b5dc987519b0`; repository rules currently live primarily in `AGENTS.md`, `docs/project/CHATGPT_PROJECT_INSTRUCTIONS.md`, and `.github/copilot-instructions.md`.
- **Evidence / reason**：用户在当前规则会话中明确要求新增该长期规则。
- **Files in scope**：`AGENTS.md`, `docs/project/CHATGPT_PROJECT_INSTRUCTIONS.md`, `.github/copilot-instructions.md`, `docs/project/CURRENT_WORK_RULES.md`.
- **Do-not-touch**：App 源码、任何功能开发 checkpoint、Player/Transport/Cache/Emby/PiP/Frozen/P0 运行时合同。
- **Completed**：已完成规则归属、当前 `main` 身份、现有执行/验证/checkpoint 规则与 Frozen 模块核对。
- **Validation state**：Rule decision confirmed; permanent rule edits pending.
- **Pending**：写入永久规则文件；核验 GitHub 最终内容；恢复本文件为 Idle。
- **Next exact action**：把连续执行条款写入 `AGENTS.md`，并同步 ChatGPT/Copilot 规则入口。
- **Rejected / do-not-repeat**：不得把 checkpoint、commit、CI passed 或 IPA packaging preparation 当作默认等待用户“继续”的交接点。
- **Open questions / risks**：无；规则不得越过真实用户决策、冲突、权限/基础设施阻塞，也不得把 IPA 生成误称为真机通过。

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
