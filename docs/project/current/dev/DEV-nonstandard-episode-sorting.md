# DEV-nonstandard-episode-sorting

## Status

**Active**

- **Work ID**：`DEV-nonstandard-episode-sorting`
- **Routing aliases / keywords**：非标准剧集排序 / 剧集排序 / 特殊剧集排序 / episode sorting
- **Task**：修复 OnePlayer 对非标准剧集的排序问题。先确认真实 Emby 返回字段、当前排序定义与所有调用点，再基于实际失败样本做最小排序修正；不得猜测非标准剧集命名或编号规则。
- **User intent / acceptance criteria**：非标准剧集在 OnePlayer 中应按用户实际媒体元数据形成正确、稳定的剧集顺序；不得破坏标准 `ParentIndexNumber / IndexNumber` 剧集排序，也不得为修复排序顺带改播放器、Transport、Cache、PiP、Seek 或媒体传输链路。具体异常样本与期望顺序等待本任务源码/数据证据确认后记录。
- **Baseline**：任务于 2026-08-25 新建。base branch `main`；base commit `f06c6cd68eb8b3ddcb802a1853c64437e4a5b04f`。项目最新真机接受功能基线仍为 Build173 / OnePlayer 0.14.6；Build176 是另一独立任务 `DEV-player-episode-picker` 的 CI/IPA 候选，尚未真机接受。
- **Working branch / PR / head commit**：branch `fix/nonstandard-episode-sorting`；从 `main@f06c6cd68eb8b3ddcb802a1853c64437e4a5b04f` 创建；PR = none；当前产品源码尚未修改。
- **Build candidate**：未分配。分配前必须检查 `BUILD_TEST_INDEX.md` 与其他 Active checkpoint，禁止复用 Build176 或其他任务已占用身份。
- **Evidence**：现有 `DEV-player-episode-picker` checkpoint 记录其 `seriesEpisodes()` 消费结果按 `ParentIndexNumber,IndexNumber` 升序；PR #249 的 changed files 为 `AppIdentity.swift`、`PlayerControlPanelViews.swift`、`PlayerEpisodeSelection.swift`、`PlayerScreen.swift`、`PlayerSettings.swift`、`PlayerSettingsView.swift` 与 Build174-176 changelog，未显示它修改共享排序 API 定义。`PlayerEpisodeSelection.swift` 直接调用 `client.seriesEpisodes(seriesId:)` 并按返回数组决定选集列表与自动下一集，因此本任务若修改共享 `seriesEpisodes` 排序契约，会影响该未合并功能的消费结果。
- **Files / modules in scope**：尚未最终确定。首要检查真实 `seriesEpisodes` 定义、`LibraryItem` 剧集编号字段、详情页/剧集列表排序调用点及相关测试。只有证据确认后才登记并修改具体源码文件。
- **State owner / shared dependencies**：剧集元数据与排序结果的 owner 预计位于 Emby API / Library 数据层，但必须以真实源码确认。播放器选集任务是排序结果消费者，不应在本任务中修改其 UI/session owner。
- **Frozen / do-not-touch**：`PlayerController.swift`、MPV fast Seek、PiP Build173、UnifiedTransport、Range/302/115 客户端直连、Session cache、Cache UI、MPV surface、Emby 播放进度/Resume 合同均不在本任务范围。不得引入时间→字节比例 Seek、timer/watchdog/retry/fallback。
- **Parallel conflicts checked against**：已检查当前唯一其他 Active checkpoint `DEV-player-episode-picker`。该任务消费 `seriesEpisodes()` 的顺序并用其决定选集显示/自动下一集，但其 PR #249 当前未修改排序 API 定义文件。当前允许独立推进“源码定位/证据收集”；如果本任务最终需要修改与 PR #249 相同源码文件、同一状态 owner，或依赖其未合并代码，则必须停止并改为串行/stacked 处理，不得静默并行。
- **Completed**：任务身份确认；独立 branch `fix/nonstandard-episode-sorting` 已从 `main@f06c6cd...` 创建；并行任务初步冲突检查完成；尚未修改产品代码。
- **Validation state**：Code written = no；CI passed = no；IPA produced = no；Real-device tested = no；Stable/frozen = no。
- **Pending**：定位真实 `seriesEpisodes` 定义与调用点；确认 `LibraryItem` 可用排序字段；查清非标准剧集当前实际错误表现与数据形态；判断是否存在标准/特殊剧集混排、缺失 IndexNumber、重复编号或字符串标题参与排序等具体失败模式；随后只做有证据支持的最小修复。
- **Next exact action**：在 `fix/nonstandard-episode-sorting` 对应基线源码中读取 `seriesEpisodes`、`LibraryItem` 定义及所有排序调用点，确认排序 owner 与现行请求参数/本地排序行为；在证据不足前不写补丁。
- **Rejected / do-not-repeat**：不要仅凭“非标准剧集”字样猜测按文件名、标题自然排序或自行定义季/集规则；不要把播放器选集 UI 当作排序 owner；不要复制一套独立排序状态；不要为了兼容未知情况加入 fallback/retry；不要触碰 Frozen 播放/传输模块。
- **Open questions / risks**：用户的具体非标准剧集样本及其 Emby 元数据尚未记录；真实排序 owner 尚待源码确认。共享 `seriesEpisodes()` 结果会被未合并的 `DEV-player-episode-picker` 消费，若修复发生在共享数据层，需要在该任务最终合并/测试前重新同步并验证自动下一集顺序。
