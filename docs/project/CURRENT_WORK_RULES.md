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

- **Task**：将 OnePlayer 完成通知策略从 important-completion-only 改为 every-final-reply。
- **User intent / acceptance criteria**：任何给用户的最终回答都必须触发 `white-shark-ssw/ChatGPT-Notify` PR #1；不再按任务重要性、回答长度或是否属于开发操作过滤。中间进度/工具过程不通知，每个用户轮次最多通知一次。
- **Baseline**：`docs/automation/CHATGPT_NOTIFY_RULES.md` 当前写明 `Default notification policy: important completion only`，并明确排除普通寒暄/简单问答/短澄清；`CHATGPT_PROJECT_INSTRUCTIONS.md` 也只要求“满足通知条件的重要任务”发送。
- **Evidence / reason**：用户实测发现普通回答没有触发通知，并明确要求移除该限制。
- **Files in scope**：`docs/automation/CHATGPT_NOTIFY_RULES.md`、`docs/project/CHATGPT_PROJECT_INSTRUCTIONS.md`、本 checkpoint。
- **Do-not-touch**：App 源码、任何开发 checkpoint、Build/CI/IPA、Player/Transport/Cache/Emby/PiP/Frozen 模块、通知中心 Bark workflow。
- **Completed**：已读取当前真实通知规则和 Project Instructions，确认过滤条件确实存在于 OnePlayer 项目规则层。
- **Validation state**：Rule update in progress；无产品代码变化。
- **Pending**：移除 important-only 条件，改成每轮最终回答固定通知；回读确认；恢复 checkpoint Idle；用本轮最终回答触发一次 OnePlayer 通知。
- **Next exact action**：更新 `docs/automation/CHATGPT_NOTIFY_RULES.md` 与 `docs/project/CHATGPT_PROJECT_INSTRUCTIONS.md`。
- **Rejected / do-not-repeat**：不再用“重要任务”“明显耗时”“简单问答不通知”等条件决定是否发送。
- **Open questions / risks**：每次最终回答都会产生一次 GitHub Actions run 与一条 Timeline 删除事件；通知正文仍不得包含 secrets / 高敏感信息。

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
