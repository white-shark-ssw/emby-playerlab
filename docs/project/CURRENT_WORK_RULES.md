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

- **Task**：把“每个最终回答必须触发 ChatGPT-Notify”提升为 OnePlayer `AGENTS.md` 的直接强制规则。
- **User intent / acceptance criteria**：不再依赖“重要任务”判断，也不只通过 START_HERE 间接加载；新 OnePlayer 会话读取第一份仓库规则时即可看到每轮最终回答都必须通知。
- **Baseline**：`docs/automation/CHATGPT_NOTIFY_RULES.md` 与 `docs/project/CHATGPT_PROJECT_INSTRUCTIONS.md` 已是 every-final-reply；`AGENTS.md` 尚无通知条款。
- **Evidence / reason**：用户实测发现并行/既有会话存在不触发情况；当前通知链路本身可正常推送。
- **Files in scope**：`AGENTS.md`、本 checkpoint；必要时只校正通知规则入口文字。
- **Do-not-touch**：App 源码、任何功能开发 checkpoint、Build/CI/IPA、Player/Transport/Cache/Emby/PiP/Frozen 模块。
- **Completed**：确认 `AGENTS.md` 当前没有完成通知直接规则；现有详细通知规则已经是 every final reply。
- **Validation state**：Rule change in progress。
- **Pending**：在 `AGENTS.md` 增加最高可见度的强制通知条款；回读；恢复 checkpoint Idle；以本轮最终回答做实际通知。
- **Next exact action**：更新 `AGENTS.md`。
- **Rejected / do-not-repeat**：不得再用 important/耗时/代码修改作为是否通知的过滤条件。
- **Open questions / risks**：仓库规则更新无法自动注入已经打开且不会重新读取仓库规则的旧会话；这些会话需要一次性重新读取启动规则。

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
