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

## New task rule

进入开发/功能会话后，必须先确定用户是在：

- 继续一个已有功能任务；或
- 新建一个功能任务。

推荐明确表达：

- `当前为功能会话，新任务：<功能名>`
- `当前为功能会话，继续 DEV-<slug>`
- `当前为开发会话，继续 <明确任务名>`

如果用户只说“当前为功能会话”，但没有说明要继续哪个功能或是否新建任务，则读取本目录当前任务后让用户选择。即使当前只有一个 Active 功能，也不能仅凭这一点认定用户一定要继续它。

在具体功能任务没有被明确选定前，不得创建新 checkpoint、不得修改任何已有 checkpoint、不得创建或切换到某个功能 branch。

## One task = one checkpoint + one branch

每个 Active 功能必须同时满足：

1. 一个独立 checkpoint 文件；
2. 一个独立开发 branch；
3. 一个独立 PR（进入可评审/测试阶段后）；
4. checkpoint 中记录真实 base / branch / PR / commit；
5. 一个功能会话只维护自己的 checkpoint，不得覆盖其他功能任务。

两个 Active 功能任务绝不能共用同一个开发 branch。

checkpoint 是跨会话控制面状态，应保持在 GitHub 可被新会话发现的位置；产品代码仍只在对应功能 branch / PR 中开发。

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

Build 编号只表示测试基线身份，不改变“CI passed / IPA produced / Real-device tested / Stable”证据分级规则。

## Checkpoint template

每个任务文件至少包含：

- **Status**：Active
- **Work ID**
- **Task**
- **User intent / acceptance criteria**
- **Baseline**：version / Build / base branch / base commit
- **Working branch / PR / head commit**
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
