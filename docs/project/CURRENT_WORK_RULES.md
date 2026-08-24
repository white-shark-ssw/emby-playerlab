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
- **Baseline**：`main`，当前已有规则/开发双会话路由和单一 `CURRENT_WORK_DEV.md`。
- **Evidence / reason**：单一 `CURRENT_WORK_DEV.md` 只能安全承载一个 Active 功能任务；多个并行开发会话会争用同一 checkpoint。
- **Files in scope**：`AGENTS.md`、`docs/project/CURRENT_WORK.md`、`docs/project/CURRENT_WORK_DEV.md`、`docs/project/DOCUMENTATION_POLICY.md`、新增开发任务 checkpoint 目录说明、本规则 checkpoint。
- **Do-not-touch**：App 源码、Player / PiP / Transport / Cache 等功能实现；不扩展规则并行机制到当前没有需求的其他类别。
- **Completed**：已确定采用“开发路由器 + 每功能独立 checkpoint + 每功能独立 branch/PR”，不采用固定 DEV1/DEV2/DEV3 槽。
- **Validation state**：Rule checkpoint documented
- **Pending**：定义任务选择/创建规则、并行冲突规则、合并前同步规则；写入永久规则；检查 diff；合并 PR；恢复本槽 Idle。
- **Next exact action**：创建规则分支，并把 `CURRENT_WORK_DEV.md` 改为多任务开发路由器，新增 `docs/project/current/dev/README.md` 作为独立任务 checkpoint 规范。
- **Rejected / do-not-repeat**：多个开发会话共享同一个可写 `CURRENT_WORK_DEV.md`；固定数量 `CURRENT_WORK_DEV_1/2/3` 槽；根据 Active/最近更新自动猜具体功能任务。
- **Open questions / risks**：并行任务若触碰同一文件、同一状态所有者或 Frozen 核心，需要序列化或先处理冲突，不能盲目并行。

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
