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

- **Task**：将 OnePlayer 接入统一 `white-shark-ssw/ChatGPT-Notify` Bark 完成通知中心。
- **User intent / acceptance criteria**：新的 OnePlayer 开发/规则会话在重要任务完整回答准备好后，自动触发 ChatGPT-Notify；通知正文短暂写入公共通知 PR 后立即擦除，并由通知中心 Action 推送后彻底删除。
- **Baseline**：OnePlayer `main` 当前规则入口为 `/AGENTS.md` + `docs/project/START_HERE.md`；通知中心固定为 `white-shark-ssw/ChatGPT-Notify` PR `#1`，协议 `BARK_NOTIFY_V1`，Bark group `ChatGPT-Notify`。
- **Evidence / reason**：用户已完成 Bark 真机推送、OpenAI 图标、分组、即时擦除与 Action 删除的链路验证，并明确要求 OnePlayer 接入。
- **Files in scope**：`AGENTS.md`、`docs/project/START_HERE.md`、`docs/automation/CHATGPT_NOTIFY_RULES.md`、必要的永久规则说明文件，以及本 checkpoint。
- **Do-not-touch**：App 源码、任何功能开发 checkpoint、Build/CI/IPA、Player/Transport/Cache/Emby/PiP/Frozen 模块。
- **Completed**：已读取当前 OnePlayer 规则入口、项目状态、模块状态、技术决策、Build 索引与文档政策；确认本任务属于 Rules 会话。
- **Validation state**：Rule integration in progress；未涉及产品代码或运行时验证。
- **Pending**：读取当前 ChatGPT Project Instructions；落盘通知规则；将新会话启动链路接入；复核实际文件；完成后恢复本 checkpoint 为 Idle。
- **Next exact action**：读取 `docs/project/CHATGPT_PROJECT_INSTRUCTIONS.md`，再按当前通知中心最新模板做最小接入。
- **Rejected / do-not-repeat**：不得把 Bark Key 写进 OnePlayer；不得把通知接入当成功能开发；不得修改 Active 功能任务或分配 Build。
- **Open questions / risks**：公共通知仓库的临时 payload 仍有极短公开窗口，因此通知正文不得包含 secrets / token / private URL / 高敏感信息。

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
