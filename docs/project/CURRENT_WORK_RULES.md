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

- **Task**：细化“开发任务自主连续推进至可测试 Artifact/IPA”规则，并把 checkpoint 时机/写入频率纳入同一执行合同。
- **User intent / acceptance criteria**：任务明确且通过必要前置检查后，不因普通中间状态等待“继续”；只有用户决策/信息/权限/实机操作、真实冲突、证据不足、外部阻塞或当前环境能力不足才允许提前停；Artifact/IPA 交付前完成版本、Build、Candidate、源码与 Artifact 身份核验；checkpoint 必须尽早建立并仅在具有独立续接价值的实质里程碑滚动更新，优先顺带已有 GitHub 写节点，避免微步骤写放大。
- **Baseline**：`main@fd9c320d28bdf2388d9cae8d9a38bff7a57e15f5`；现有连续执行规则已存在于 `AGENTS.md`、`docs/project/CHATGPT_PROJECT_INSTRUCTIONS.md`、`.github/copilot-instructions.md`，但缺少本轮新增的证据不足/实机操作停点和 checkpoint 写入节奏约束。
- **Evidence / reason**：用户明确要求替换上一轮规则文本并补充 checkpoint 生存性要求。
- **Files in scope**：`AGENTS.md`、`docs/project/CHATGPT_PROJECT_INSTRUCTIONS.md`、`docs/project/DOCUMENTATION_POLICY.md`、`.github/copilot-instructions.md`、本 checkpoint。
- **Do-not-touch**：任何 App 源码、功能开发 checkpoint、Build233 或其他 Active 开发任务状态。
- **Completed**：已确认最新 main 与现有规则真实文本；已确认本次应修改连续执行合同和 checkpoint 文档治理合同。
- **Validation state**：Rule refinement in progress。
- **Pending**：写入永久规则文件；核验净 diff；恢复本 checkpoint 为 Idle。
- **Next exact action**：替换 `AGENTS.md` 的 continuous-execution 条款并强化 Documentation/checkpoint 条款，然后同步 ChatGPT/Copilot/Documentation Policy。
- **Rejected / do-not-repeat**：不得把 checkpoint 当停工门槛；不得为了每个微小步骤单独制造 GitHub 写；不得把连续推进理解为可以在证据不足时强行改代码或强行出包。
- **Open questions / risks**：并行开发会话正在推进 main，写规则时必须基于每个文件的当前 blob SHA，避免覆盖并行源码变化。

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
