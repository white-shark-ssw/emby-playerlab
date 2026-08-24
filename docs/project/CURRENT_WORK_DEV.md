# OnePlayer Current Work — Development Router

`CURRENT_WORK_DEV.md` 只负责**功能开发任务路由**，不保存某一个具体功能的 Active 正文。

OnePlayer 允许同时存在多个独立功能任务。每个任务的 checkpoint 位于：

`docs/project/current/dev/<Work-ID>.md`

规则与模板见：

`docs/project/current/dev/README.md`

## Development task routing

进入开发/功能会话后，必须先确定当前会话对应哪个具体功能任务。

用户不必每次输入完整 Work ID。以下表达都有效：

- `当前为功能会话，新任务：<功能名>`
- `当前为开发会话，新任务：<功能名>`
- `当前为功能会话，继续 DEV-<slug>`
- `当前为开发会话，继续 <明确任务名>`
- 直接输入明确功能名，例如 `详情页优化`、`选集功能`。

### Direct feature-name routing

每个 Active 功能 checkpoint 应维护 `Routing aliases / keywords`，记录少量稳定、自然、能代表该任务的中文/英文功能名。

用户直接说功能名时，按以下优先级匹配当前 Active checkpoint：

1. 精确 Work ID；
2. 明确 Task 名称；
3. 明确 `Routing aliases / keywords`；
4. 与上述字段存在唯一、可解释的强关键词匹配。

只有**恰好一个** Active checkpoint 构成强匹配时，才允许自动选择该任务并继续。

不得仅凭模型模糊语义、最近聊天主题、最近更新时间、唯一 Active 状态或任务看起来更相关就自动选择。

如果出现以下任一情况，必须展示候选并让用户选择：

- 两个或以上 Active 任务都匹配；
- 只有弱语义相关，无法指出具体命中的 Work ID / Task / alias；
- 用户输入既可能是继续旧任务，也可能是新建相近任务；
- 没有 Active checkpoint 能形成唯一强匹配。

没有唯一匹配时，不得擅自创建新任务。必须先问用户是继续哪个已有任务，还是新建任务。

如果用户只说“当前为功能会话”或“当前为开发会话”，但没有给出可唯一匹配的具体任务，也必须列出当前 Active 功能让用户选择。即使当前只有一个 Active 功能，也不能仅凭 Active 状态认定用户要继续它。

在具体任务明确前：

- 不得创建新的功能 checkpoint；
- 不得修改任何已有功能 checkpoint；
- 不得创建、切换或复用某个功能 branch；
- 不得擅自开始代码修改。

## Resume identity guard

无论任务是通过 Work ID、功能名称还是 alias 自动选中，**开始代码修改前必须重新核对任务身份**：

1. 读取该任务 checkpoint 中的 `Working branch / PR / head commit`；
2. 确认当前真实开发 branch 与 checkpoint 一致；
3. 如果已有 PR，确认 PR head 与 branch 身份一致；
4. 如果已有 Build / version candidate，确认编号和 IPA candidate 名称仍只属于该任务；
5. 检查其他 Active checkpoint，确认没有共用同一开发 branch、同一 Build 编号或同名 IPA candidate；
6. 若记录与 GitHub 当前事实不一致，先停止开发并向用户说明冲突，不得自行“修正”到某个猜测状态。

只有 identity guard 通过后，才能按该任务的 `Next exact action` 继续。

## Parallel development model

每个 Active 功能任务必须拥有：

- 独立 Work ID；
- 独立 `docs/project/current/dev/<Work-ID>.md`；
- 独立开发 branch；
- 独立 PR（进入评审/测试阶段后）；
- 独立 Build / version candidate 身份；
- 稳定的 `Routing aliases / keywords`。

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

Build candidate 一旦写入某个 Active checkpoint，就视为该任务占用，除非该任务明确放弃/完成并同步更新项目资料。不得因为另一个任务“更快完成”而偷偷复用该编号。

## Merge / validation

并行期间另一个 PR 可能先合并。当前任务在最终 CI / IPA / merge 前必须重新检查目标 branch 是否已经前进，以及是否出现新的源码、状态所有者或依赖重叠。

若同步最新目标后代码发生实质变化，必须重新执行受影响验证。旧 CI 不能直接当作同步后的当前代码证据。

## Current known active tasks

不要在本文件手工维护动态任务清单。以 `docs/project/current/dev/` 目录中的实际任务 checkpoint 为准，避免多个并行会话争用同一索引文件。

## Completion

任务完成后：

1. 将长期有效结论同步到 `PROJECT_STATE.md` / `MODULE_STATUS.md` / `TECHNICAL_DECISIONS.md` / `BUILD_TEST_INDEX.md`；
2. 删除本任务自己的 `docs/project/current/dev/<Work-ID>.md`；
3. 不修改其他 Active 功能任务 checkpoint；
4. 历史由 Git / PR / Build index 承担，不把已完成任务无限留在 current 目录。
