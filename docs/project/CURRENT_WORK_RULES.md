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
- **Baseline**：规则修改从 `main@fd9c320d28bdf2388d9cae8d9a38bff7a57e15f5` 开始；并行功能开发允许继续推进 main，本任务不修改其源码/checkpoint。
- **Evidence / reason**：用户明确要求替换上一轮规则文本并补充 checkpoint 生存性要求。
- **Files in scope**：`AGENTS.md`、`docs/project/CHATGPT_PROJECT_INSTRUCTIONS.md`、`docs/project/DOCUMENTATION_POLICY.md`、`.github/copilot-instructions.md`、本 checkpoint。
- **Do-not-touch**：任何 App 源码、功能开发 checkpoint、Build233 或其他 Active 开发任务状态。
- **Completed**：`AGENTS.md` 已加入用户决策/信息/权限/实机操作、真实冲突、证据不足、外部阻塞/环境能力不足停点，并把 commit/push、PR、CI、checkpoint、准备出包定义为普通中间状态；交付点改为可测试 Artifact/IPA 完成 version/Build/Candidate/source/Artifact/package/MinOS 身份核验后进入 Runtime/实机测试。`CHATGPT_PROJECT_INSTRUCTIONS.md`、`DOCUMENTATION_POLICY.md`、Copilot Instructions 已同步；checkpoint 规则已明确尽早建立、实质里程碑滚动、优先顺带已有 GitHub 写节点和“最多丢失一个小的有效里程碑”的目标节奏。
- **Validation state**：Permanent rules written; final repository/diff verification pending。
- **Pending**：核验当前 main、四个永久规则文件实际文本与净 diff；确认没有功能源码/checkpoint 被本规则任务修改；恢复本 checkpoint 为 Idle。
- **Next exact action**：读取当前 main 和修改后的关键规则片段，比较本任务基线与当前 head 的文件范围并区分并行开发变化；若规则范围正确，恢复 Rules checkpoint 为 Idle。
- **Rejected / do-not-repeat**：不得把 checkpoint 当停工门槛；不得为了每个微小步骤单独制造 GitHub 写；不得把连续推进理解为可以在证据不足时强行改代码或强行出包；不得为了减少 GitHub 写而跨越多个独立续接里程碑不更新 checkpoint。
- **Open questions / risks**：并行开发会话可能继续推进 main，最终核验必须识别并行提交，不能把其源码变化归因于本规则任务。

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
