# OnePlayer Current Work — Development Router

`CURRENT_WORK_DEV.md` 现在只负责**功能开发任务路由**，不再保存某一个具体功能的 Active 正文。

OnePlayer 允许同时存在多个独立功能任务。每个任务的 checkpoint 位于：

`docs/project/current/dev/<Work-ID>.md`

规则与模板见：

`docs/project/current/dev/README.md`

## Development task routing

进入开发/功能会话后，必须先确定当前会话对应哪个具体功能任务。

推荐明确表达：

- `当前为功能会话，新任务：<功能名>`
- `当前为开发会话，新任务：<功能名>`
- `当前为功能会话，继续 DEV-<slug>`
- `当前为开发会话，继续 <明确任务名>`

如果用户只说“当前为功能会话”或“当前为开发会话”，但没有说明具体任务：

1. 读取 `docs/project/current/dev/` 当前 Active checkpoint；
2. 明确告诉用户现有 Active 功能任务；
3. 让用户选择继续哪个任务，或明确说要新建任务；
4. 即使当前只有一个 Active 功能，也不能仅凭它存在就自动认定用户要继续该任务。

在具体任务明确前：

- 不得创建新的功能 checkpoint；
- 不得修改任何已有功能 checkpoint；
- 不得创建、切换或复用某个功能 branch；
- 不得擅自开始代码修改。

## Parallel development model

每个 Active 功能任务必须拥有：

- 独立 Work ID；
- 独立 `docs/project/current/dev/<Work-ID>.md`；
- 独立开发 branch；
- 独立 PR（进入评审/测试阶段后）；
- 独立 Build / version candidate 身份。

多个功能任务可以同时 Active，但任何一个会话只能维护自己已明确选定的任务 checkpoint。

两个 Active 功能任务绝不能共用同一个开发 branch，也不得把多个任务的 checkpoint 合并成一个文件。

## Parallel conflict guard

新建并行功能任务前，必须读取其他 Active 功能 checkpoint，比较 Files / modules in scope、State owner、Frozen 区域和依赖关系。

如果可能同时修改同一源码文件、同一状态所有者、同一 Frozen/P0 核心路径，或者新任务依赖另一个尚未合并的功能，不得静默并行。必须明确告诉用户冲突风险；优先串行，或明确记录为 stacked/dependent work。

不要因为“Git 可以之后解决冲突”就忽略架构状态所有权冲突。

## Build / version candidate

并行任务分配 Build / version candidate 前，必须检查：

- `BUILD_TEST_INDEX.md`；
- `docs/project/current/dev/` 其他 Active checkpoint；
- 已存在的 CI / IPA candidate。

不同 Active 功能任务不得复用同一 Build 编号或同名 IPA candidate。

## Merge / validation

并行期间另一个 PR 可能先合并。当前任务在最终 CI / IPA / merge 前必须重新检查目标 branch 是否已经前进，以及是否出现新的源码、状态所有者或依赖重叠。

若同步最新目标后代码发生实质变化，必须重新执行受影响验证。旧 CI 不能直接当作同步后的当前代码证据。

## Current known active tasks

不要在本文件手工维护动态任务清单。以 `docs/project/current/dev/` 目录中的实际任务 checkpoint 为准，避免多个并行会话争用同一索引文件。

当前从旧单槽迁移出的任务：

- `DEV-player-episode-picker` — checkpoint 已迁移至 `docs/project/current/dev/DEV-player-episode-picker.md`。

## Completion

任务完成后：

1. 将长期有效结论同步到 `PROJECT_STATE.md` / `MODULE_STATUS.md` / `TECHNICAL_DECISIONS.md` / `BUILD_TEST_INDEX.md`；
2. 删除本任务自己的 `docs/project/current/dev/<Work-ID>.md`；
3. 不修改其他 Active 功能任务 checkpoint；
4. 历史由 Git / PR / Build index 承担，不把已完成任务无限留在 current 目录。
