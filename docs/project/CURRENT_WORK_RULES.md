# OnePlayer Current Work — Rules

这是**规则 / 文档治理专用**的跨会话滚动 checkpoint。它与功能开发槽独立，不能被开发会话覆盖或重置。

适用范围：

- ChatGPT Project Instructions；
- `AGENTS.md`；
- `START_HERE.md`；
- `DOCUMENTATION_POLICY.md`；
- AI Coding Rules / Copilot Instructions / Skills；
- 项目接手、证据分级、Frozen、会话续接等协作机制。

## Status

**Active**

- **Task**：固化会话路由短口令，并规定无法判断会话类型时必须让用户选择，禁止擅自路由或激活工作槽。
- **User intent / acceptance criteria**：支持“当前为规则会话”“当前为开发会话”“当前为功能会话”；若语义不足以判断属于哪个槽，必须明确告知用户并让用户选择，任何槽都保持原状态。
- **Baseline**：`main`，双工作槽机制已由 PR #246 建立。
- **Evidence / reason**：功能开发与规则维护可能同时存在；错误猜测会导致错误槽被设为 Active 或覆盖真实 checkpoint。
- **Files in scope**：`AGENTS.md`、`docs/project/CURRENT_WORK.md`、`docs/project/DOCUMENTATION_POLICY.md`、本规则 checkpoint。
- **Do-not-touch**：App 源码、`CURRENT_WORK_DEV.md`、Player / PiP / Transport / Cache 等功能实现。
- **Completed**：已确认“无法判断时必须询问用户，禁止默认选择”是硬规则。
- **Validation state**：Rule checkpoint documented
- **Pending**：写入永久路由规则、检查 diff、合并 PR、将本槽恢复为 `Idle`。
- **Next exact action**：更新 `CURRENT_WORK.md` 与 `AGENTS.md`，加入短口令和 ambiguity-stop 规则。
- **Rejected / do-not-repeat**：根据 Active 状态、历史会话或模型猜测自动选槽；在语义不明确时擅自将任一槽设为 `Active`。
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
3. 不得改动或重置 `CURRENT_WORK_DEV.md`。
