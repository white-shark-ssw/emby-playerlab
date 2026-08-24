# OnePlayer Parallel Development Checkpoints

本目录只保存**当前仍在进行中的功能开发任务 checkpoint**。每个并行功能拥有一个独立文件；这里不是长期历史档案。

## Task identity

每个功能任务必须有稳定且唯一的 Work ID：

`DEV-<short-slug>`

示例：

- `DEV-player-episode-picker`
- `DEV-airplay-controls`
- `DEV-cache-settings`

对应 checkpoint：

`docs/project/current/dev/<Work-ID>.md`

Work ID 一旦用于 branch / PR / checkpoint，不应在任务中途随意改名。

每个任务还必须维护：

- **Routing aliases / keywords**：2-6 个稳定、自然、能明确代表任务的功能名称；优先包含用户日常会直接说出的中文短语。

例如详情页任务可以登记：

`详情页优化 / 详情页 / 媒体详情 / detail page`

别名用于**选择已有 Active 任务**，不是自动创建新任务的依据。

## Selecting an existing task

用户不必输入完整 Work ID。可以直接输入功能名，例如：

- `详情页优化`
- `选集功能`
- `AirPlay 控制`

自动选择已有 Active 任务时，匹配优先级为：

1. 精确 Work ID；
2. 明确 Task 名称；
3. 明确 `Routing aliases / keywords`；
4. 唯一且可解释的强关键词匹配。

只有恰好一个 Active checkpoint 构成强匹配时，才允许自动续接。

如果多个任务都匹配、只有模糊语义相关、无法指出具体命中的任务字段，或输入既可能表示旧任务也可能表示新任务，则必须列出候选让用户选择。

**不得因为当前只有一个 Active 任务就自动选择它。** Active 状态不是用户意图。

没有唯一强匹配时，也不得擅自新建任务；必须先让用户确认是继续已有任务还是新建功能。

## New task rule

新建任务的明确表达包括：

- `当前为功能会话，新任务：<功能名>`
- `当前为开发会话，新任务：<功能名>`
- 其他明确表示“新建/新增一个独立功能任务”的等价说法。

在具体功能任务没有被明确选定前，不得创建新 checkpoint、不得修改任何已有 checkpoint、不得创建或切换到某个功能 branch。

## One task = one checkpoint + one branch

每个 Active 功能必须同时满足：

1. 一个独立 checkpoint 文件；
2. 一个独立开发 branch；
3. 一个独立 PR（进入可评审/测试阶段后）；
4. checkpoint 中记录真实 base / branch / PR / commit；
5. 一个独立 Build / version candidate 身份（分配测试基线后）；
6. 一组稳定的 `Routing aliases / keywords`；
7. 一个功能会话只维护自己的 checkpoint，不得覆盖其他功能任务。

两个 Active 功能任务绝不能共用同一个开发 branch。

checkpoint 是跨会话控制面状态，应保持在 GitHub 可被新会话发现的位置；产品代码仍只在对应功能 branch / PR 中开发。

## Resume identity guard

任务被选中后，**不能因为名称匹配成功就立刻写代码**。先执行身份核对：

1. 读取 checkpoint 的 `Working branch / PR / head commit`；
2. 确认真实 GitHub branch 与 checkpoint 一致；
3. 已有 PR 时确认 PR head/branch 属于这个 Work ID；
4. 已有 Build/version candidate 时确认编号、版本和 IPA candidate 名称仍属于该任务；
5. 扫描其他 Active checkpoint，确认没有共用 branch、Build 编号或同名 IPA candidate；
6. 发现 checkpoint 与 GitHub 当前事实冲突时，停止并向用户说明，不得自行猜测哪个记录应该被覆盖。

identity guard 通过后，才按该任务的 `Next exact action` 继续。

## Parallel-safety preflight

创建新的并行功能任务前，必须读取本目录其他 Active checkpoint，并比较：

- Files / modules in scope；
- State owner；
- Frozen / do-not-touch；
- 依赖关系；
- 预计修改的共享基础设施。

可以并行的典型情况：两个任务修改相互独立的 UI / 服务模块，并且没有共享状态所有者。

如果两个任务可能同时修改以下任一项，不得静默并行：

- 同一源码文件；
- 同一核心状态所有者；
- 同一 Frozen 模块或 P0 合同；
- Player / PiP / UnifiedTransport / Cache 等共享核心路径；
- 一个任务依赖另一个尚未合并的代码。

此时必须明确告诉用户存在并行冲突风险。优先选择串行完成；如果确实需要依赖开发，则必须明确记录为 stacked/dependent work，而不能假装两个任务独立。

## Baseline and merge discipline

每个任务开始时独立记录自己的真实功能基线，不能因为另一个并行任务更新了 `main` 就自动改变当前任务的测试证据。

另一个 PR 合并后，当前任务在最终 CI / IPA / merge 前必须重新检查目标分支：

1. 目标 branch 是否前进；
2. 是否出现文件/状态所有者/依赖重叠；
3. 是否需要同步/rebase/merge 最新目标；
4. 同步后原有 CI 是否仍然代表当前代码。

如果基线发生实质变化，必须重新执行受影响验证；旧 CI 不得直接当作新基线通过证据。

## Build / version candidate uniqueness

并行功能在分配测试 Build / version candidate 前，必须检查：

- `docs/project/BUILD_TEST_INDEX.md`；
- 本目录其他 Active checkpoint；
- 已存在的 CI / IPA candidate。

不同并行任务不得使用同一个 Build 编号或同名 IPA candidate。发现编号已被占用时，使用下一个未占用编号，并在自己的 checkpoint 中记录。

一个 Build candidate 写入 Active checkpoint 后视为该任务已占用。除非该任务明确放弃/完成并同步状态，否则其他任务不得复用该编号。

Build 编号只表示测试基线身份，不改变“CI passed / IPA produced / Real-device tested / Stable”证据分级规则。

## Checkpoint template

每个任务文件至少包含：

- **Status**：Active
- **Work ID**
- **Routing aliases / keywords**
- **Task**
- **User intent / acceptance criteria**
- **Baseline**：version / Build / base branch / base commit
- **Working branch / PR / head commit**
- **Build candidate**（如已分配）
- **Evidence**
- **Files / modules in scope**
- **State owner / shared dependencies**
- **Frozen / do-not-touch**
- **Parallel conflicts checked against**
- **Completed**
- **Validation state**
- **Pending**
- **Next exact action**
- **Rejected / do-not-repeat**
- **Open questions / risks**

## Completion

任务完成后：

1. 将长期有效结论同步到 `PROJECT_STATE.md` / `MODULE_STATUS.md` / `TECHNICAL_DECISIONS.md` / `BUILD_TEST_INDEX.md`；
2. 确认 PR / Build / 真机证据已经正确记录；
3. 删除该任务的 `docs/project/current/dev/<Work-ID>.md`；
4. 不修改其他 Active 功能任务 checkpoint；
5. 不把已完成任务无限保留在本目录，历史由 Git / PR / Build index 承担。
