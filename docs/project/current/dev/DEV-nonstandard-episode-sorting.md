# DEV-nonstandard-episode-sorting

## Status

**Active**

- **Work ID**：`DEV-nonstandard-episode-sorting`
- **Routing aliases / keywords**：非标准剧集排序 / 剧集排序 / 特殊剧集排序 / episode sorting
- **Task**：修复 OnePlayer 对非标准剧集的排序问题。当前已由真机截图、App 日志与 Emby 官方 TV episodes API 证据确认：问题不是标题自然排序或 UI 二次排序，而是 OnePlayer 使用通用 Items 查询并强制 `ParentIndexNumber,IndexNumber` 排序，绕过了 Emby TV series/season 自身的剧集顺序 authority。
- **User intent / acceptance criteria**：用户 2026-08-25 提供同一非标准剧集在 OnePlayer 与 EplayerX 的详情页/选集页真机截图，并明确确认 EplayerX 的顺序与 Emby 中的顺序一致、OnePlayer 当前顺序错误。修复后 OnePlayer 应服从 Emby 对该剧集的实际顺序；不得通过标题、文件名或自定义规则猜排序；标准剧集顺序不得回归；详情页、全部选集以及后续 Player 选集/自动下一集必须消费同一 canonical episode order。
- **Baseline**：任务于 2026-08-25 新建。working branch `fix/nonstandard-episode-sorting` 从 `main@f06c6cd68eb8b3ddcb802a1853c64437e4a5b04f` 创建。项目最新真机接受功能基线仍为 Build173 / OnePlayer 0.14.6；Build176 是另一独立任务 `DEV-player-episode-picker` 的 CI/IPA 候选，尚未真机接受。
- **Working branch / PR / head commit**：branch `fix/nonstandard-episode-sorting`；PR = none；产品源码尚未修改。本 checkpoint 首次创建时误落到 `main`，working branch 仍停在 base commit；后续产品修改必须明确写入 working branch，不得借用 main 或其他任务分支。
- **Build candidate**：未分配。当前另有独立 `DEV-home-carousel-drag-smoothness` Active 任务，也尚未分配 Build；分配前必须重新检查所有 Active checkpoint，禁止复用 Build176 或其他任务已占用身份。
- **Real-device evidence**：用户截图中，同一 Series 在 OnePlayer 第 1 季开头显示的内容顺序与 EplayerX/Emby 明显不同。OnePlayer App 日志对应 series `137597`：`episodesTotal=165`、`seasonsTotal=5`、季计数 `1=41,2=3,3=31,4=4,5=86`；SeasonId/ParentId 分组一致，说明季归属数据本身是完整的。关键证据为 `nilIndex=164`：165 个 Episode 中 164 个 `IndexNumber=nil`，因此当前强制按 `ParentIndexNumber,IndexNumber` 排序在该媒体上没有有效的集号排序信息。日志 `sampleFirst[0...4]` 与 OnePlayer 截图顶部 1～5 项完全对应，证明 UI 只是忠实显示 `seriesEpisodes()` 返回顺序，错误发生在共享数据请求/排序层。
- **Current OnePlayer source evidence**：`EmbyAPIClient.seriesEpisodes()` 当前分页调用通用 `/Users/{UserId}/Items`，参数包含 `ParentId={seriesId}&Recursive=true&IncludeItemTypes=Episode&SortBy=ParentIndexNumber,IndexNumber&SortOrder=Ascending`，返回后仅按 ID 去重且保持原顺序。详情页 `selectedSeasonEpisodes` 只按 SeasonId/ParentIndexNumber 过滤，不重排；`EmbyEpisodePickerView` 正序直接使用该数组，倒序仅 `reversed()`。因此 UI 不是排序 owner。
- **Emby API evidence**：当前 Emby REST API 明确提供 TV 专用 `GET /Shows/{Id}/Episodes`，可按 `SeasonId`/`Season` 过滤。Emby 官方旧服务端源码中，当未提供 SeasonId/Season 时，该 endpoint 直接执行 `series.GetEpisodes(user, dtoOptions)`；当提供 SeasonId 时执行 `season.GetEpisodes(user, dtoOptions)`，而不是把通用 Items 查询强制改成 `ParentIndexNumber,IndexNumber`。公开的官方 Emby for iOS 服务端日志也显示 iOS 客户端使用 `/Shows/{SeriesId}/Episodes?SeasonId=...` 获取剧集列表。该证据与用户确认的 EplayerX/Emby 顺序一致。
- **Root cause conclusion**：当前最强结论是 **OnePlayer 选择了错误的 episode-list authority**。`ParentIndexNumber` 对本样本仍可正确区分季，但绝大多数 `IndexNumber` 缺失；通用 Items API 在这些 nil 次级键下返回的顺序并不是 Emby TV 层认可的剧集展示顺序。不能通过给 nil IndexNumber 增加标题/日期/ID fallback 来“修复”，那仍然是在客户端猜 Emby 的顺序。
- **Minimal fix direction**：共享 `seriesEpisodes(seriesId:)` 应改为调用 Emby TV 专用 `/Shows/{seriesId}/Episodes`，携带 `UserId`、现有 Fields/Image/UserData 参数及分页参数，但**不主动提供 SortBy**，让 Emby series/season episode authority 决定 canonical 顺序。继续保留当前 ID 去重与分页，不新增 retry/fallback/timer/watchdog，也不改 UI 排序状态。该修改应位于 `Sources/Networking/EmbyAPIClient.swift`，不需要改 `LibraryItem`、SeasonId 分组逻辑或播放器核心。
- **Files / modules in scope**：已确认首要产品文件为 `Sources/Networking/EmbyAPIClient.swift`；验证脚本可新增专用 episode-ordering contract check。详情页/`EmbyEpisodePickerView` 当前只作为消费链验证，不应为了这个问题增加本地排序。未合并的 `DEV-player-episode-picker` 使用同一 `seriesEpisodes()` 结果，因此最终集成后必须复测 Player 选集显示与自动下一集顺序。
- **State owner / shared dependencies**：canonical episode order 应由 Emby TV API / Server series episode order 持有；OnePlayer 客户端只保持服务器返回顺序。SeasonId→Season.indexNumber 仍负责季归属兼容，但不成为集内排序 owner。
- **Frozen / do-not-touch**：`PlayerController.swift`、MPV fast Seek、PiP Build173、UnifiedTransport、Range/302/115 客户端直连、Session cache、Cache UI、MPV surface、Emby 播放进度/Resume 合同均不在本任务范围。不得引入时间→字节比例 Seek、timer/watchdog/retry/fallback。
- **Parallel conflicts checked against**：`DEV-player-episode-picker` 会消费 `seriesEpisodes()` 顺序，因此属于共享契约下游，但其 PR #249 没有修改 `EmbyAPIClient.swift`；本任务可独立修改共享数据 owner，之后该任务需要基于新顺序重新同步验证。新建的 `DEV-home-carousel-drag-smoothness` 只涉及首页轮播 UI 文件/状态 owner，与 `EmbyAPIClient.swift` 无文件或状态冲突。
- **Completed**：独立任务/branch 建立；真实 `seriesEpisodes`、`LibraryItem`、详情页/选集页调用点与去重行为已确认；用户真机对照截图与 App 日志已分析；Emby 当前 REST API 与官方服务端/官方 iOS 使用方式已交叉确认；根因与最小修改点已收敛。
- **Validation state**：Current wrong behavior = **real-device confirmed**；root-cause evidence = source/log/API confirmed；fix code written = no；CI passed = no；IPA produced = no；fixed behavior real-device tested = no；Stable/frozen = no。
- **Pending**：在 `fix/nonstandard-episode-sorting` 上只修改 `EmbyAPIClient.seriesEpisodes()` 使用 `/Shows/{Id}/Episodes` canonical order；增加最小 contract check；随后再分配独立 Build/Version、跑标准 MPV Release CI、产 IPA，并用当前 165 集异常 Series 与一个标准有 IndexNumber 的 Series 真机双向验证。
- **Next exact action**：在 working branch 写最小 API-path 修复，不做任何客户端猜排序；验证 HTTP 日志从 `/Users/.../Items?...SortBy=ParentIndexNumber,IndexNumber` 变为 `/Shows/{seriesId}/Episodes?...` 且不含强制 SortBy，然后进入 CI/IPA 阶段。
- **Rejected / do-not-repeat**：拒绝标题自然排序、文件名排序、DateCreated fallback、ID 排序、nil IndexNumber 人工补号、另一套客户端 sort state，以及任何“标准剧集走旧接口/异常剧集走新接口”的 speculative compatibility fallback。既然 canonical authority 已有 Emby TV endpoint，就不维护两套剧集顺序定义。
- **Open questions / risks**：修复后的真实顺序仍必须由目标 Emby Server + 真机确认，不能仅凭 API 文档宣称完成；同时要验证标准剧集不会因 endpoint 切换回归。未合并 Player episode picker/auto-next 最终需要重新同步此共享排序契约。
