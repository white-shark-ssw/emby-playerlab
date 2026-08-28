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

- **Task**：细化自主连续开发 checkpoint 规则，增加非原子 GitHub 写链的批量 checkpoint 判定。
- **User intent / acceptance criteria**：开发任务通过必要前置检查后继续自主推进到可测试 Artifact/IPA 身份核验；checkpoint 尽早建立且只记录独立续接价值里程碑；blob → tree → commit → ref 等非原子 GitHub 写链只在产生可复用持久身份且 `Next exact action` 实质改变时批量记录一次，禁止按微操作逐条写 checkpoint。
- **Baseline**：`main@762eb3fc5041cd088034794eb49582bdafc9ab93`；现有连续执行/checkpoint 规则已存在于 `AGENTS.md`、`CHATGPT_PROJECT_INSTRUCTIONS.md`、`DOCUMENTATION_POLICY.md`、`current/dev/README.md`、Copilot instructions。
- **Evidence / reason**：用户明确要求上一版规则增加非原子 GitHub 写链的 checkpoint 批处理约束，以兼顾突然中断恢复能力和执行效率。
- **Files in scope**：`AGENTS.md`、`docs/project/CHATGPT_PROJECT_INSTRUCTIONS.md`、`docs/project/DOCUMENTATION_POLICY.md`、`docs/project/current/dev/README.md`、`.github/copilot-instructions.md`、本 Rules checkpoint。
- **Do-not-touch**：App 源码、Build233/其他功能任务 checkpoint、Frozen/P0 模块、功能 branch/PR/CI/IPA。
- **Completed**：已确认最新 main、会话路由、通知规则、MODULE_STATUS 与现有连续执行/checkpoint 条款；已建立本次 Rules checkpoint。
- **Validation state**：Rule refinement in progress; no App/runtime change.
- **Pending**：同步永久规则文件；核验最终 diff/主线身份；恢复 Rules checkpoint 为 Idle。
- **Next exact action**：将非原子 GitHub 写链批量 checkpoint 判定同步到永久规则入口，并保持现有 Artifact/IPA/Runtime 交付和证据边界不变。
- **Rejected / do-not-repeat**：不得为 blob/tree/commit/ref 每个微操作单独写 checkpoint；不得把 checkpoint 推迟到 CI/出包/最终结论；不得因普通中间状态等待用户“继续”。
- **Open questions / risks**：并行开发可能继续推进 `main`；最终核验需区分本规则会话净变更与并行功能会话变更。

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
