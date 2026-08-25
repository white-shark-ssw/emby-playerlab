# DEV-nonstandard-episode-sorting

## Status

**Active**

- **Work ID**：`DEV-nonstandard-episode-sorting`
- **Routing aliases / keywords**：非标准剧集排序 / 剧集排序 / 特殊剧集排序 / episode sorting
- **Task**：修复 OnePlayer 对非标准剧集的排序问题。当前已由真机截图、App 日志与 Emby 官方 TV episodes API 证据确认：问题不是标题自然排序或 UI 二次排序，而是 OnePlayer 使用通用 Items 查询并强制 `ParentIndexNumber,IndexNumber` 排序，绕过了 Emby TV series/season 自身的剧集顺序 authority。
- **User intent / acceptance criteria**：用户 2026-08-25 提供同一非标准剧集在 OnePlayer 与 EplayerX 的详情页/选集页真机截图，并明确确认 EplayerX 的顺序与 Emby 中的顺序一致、OnePlayer 当前顺序错误。修复后 OnePlayer 应服从 Emby 对该剧集的实际顺序；不得通过标题、文件名或自定义规则猜排序；标准剧集顺序不得回归；详情页、全部选集以及后续 Player 选集/自动下一集必须消费同一 canonical episode order。
- **Baseline**：working branch `fix/nonstandard-episode-sorting` 从 `main@f06c6cd68eb8b3ddcb802a1853c64437e4a5b04f` 创建。项目最新真机接受功能基线仍为 Build173 / OnePlayer 0.14.6；Build176 是独立 `DEV-player-episode-picker` CI/IPA 候选，尚未真机接受。
- **Working branch / PR / head commit**：branch `fix/nonstandard-episode-sorting`；PR = none；当前 checkpoint head `195a57c8331ac2301377dcac8b33b4670ceae989`，implementation head `f301e3147c2a276a4b9c20e65c4a4197bca928cc`。
- **Build candidate**：未分配；当前另有独立 `DEV-home-carousel-drag-smoothness` Active 任务，同样需独立 Build 身份。禁止复用 Build176 或其他任务已占用身份。
- **Real-device evidence**：同一 Series 在 OnePlayer 第 1 季开头顺序与 EplayerX/Emby 明显不同。App 日志对应 series `137597`：`episodesTotal=165`、`seasonsTotal=5`、季计数 `1=41,2=3,3=31,4=4,5=86`；SeasonId/ParentId 分组一致。关键证据为 `nilIndex=164`：165 个 Episode 中 164 个 `IndexNumber=nil`。日志 `sampleFirst[0...4]` 与 OnePlayer 截图顶部 1～5 项完全对应，证明 UI 只是显示 `seriesEpisodes()` 返回顺序，错误发生在共享数据请求/排序层。
- **Source / API conclusion**：旧实现的 `EmbyAPIClient.seriesEpisodes()` 分页调用通用 `/Users/{UserId}/Items` 并强制 `ParentIndexNumber,IndexNumber`。Emby REST API 提供 `GET /Shows/{Id}/Episodes`；官方服务端源码在无 SeasonId/Season 时直接执行 `series.GetEpisodes(user, dtoOptions)`，有 SeasonId 时执行 `season.GetEpisodes(user, dtoOptions)`。公开官方 Emby for iOS 服务端日志也使用 `/Shows/{SeriesId}/Episodes?SeasonId=...`。因此 canonical episode order 应由 Emby TV API/Server 持有。
- **Implemented minimal fix**：working branch commit `a32acde490683f0c558e807f2f560c2c86aaecde` 只修改 `Sources/Networking/EmbyAPIClient.swift` 的 `seriesEpisodes(seriesId:)`：改用 `Shows/{seriesId}/Episodes`，显式带 `UserId`、既有 browse fields/image/user-data、`StartIndex`/`Limit` 分页；不再传 `SortBy`/`SortOrder`，不再走 `libraryItems(parentId:seriesId...)`。保留现有分页终止条件和 ID-preserving `deduplicated(all)`。没有新增 fallback/retry/timer/watchdog，没有改 UI/Player/Transport/Cache/Resume。
- **Contract check**：working branch commit `f301e3147c2a276a4b9c20e65c4a4197bca928cc` 新增 `scripts/check_series_episode_ordering.py`，静态检查 `seriesEpisodes` 必须使用 `/Shows/{seriesId}/Episodes`、携带 UserId/分页、不得含 `SortBy`、`ParentIndexNumber,IndexNumber` 或旧 `libraryItems(parentId: seriesId...)`，并保持 iOS 15.0 deployment target。
- **Files / modules in scope**：产品文件仅 `Sources/Networking/EmbyAPIClient.swift`；新增验证脚本 `scripts/check_series_episode_ordering.py`。详情页和全部选集页不做本地排序修改。
- **State owner / shared dependencies**：canonical episode order 由 Emby TV API / Server series episode order 持有；OnePlayer 只保持服务器返回顺序。SeasonId→Season.indexNumber 继续负责季归属兼容，不成为集内排序 owner。
- **Parallel conflicts checked against**：`DEV-player-episode-picker` 是共享顺序下游消费者，最终需同步复测；其 PR #249 未改 `EmbyAPIClient.swift`。`DEV-home-carousel-drag-smoothness` 只涉及首页轮播 UI，与本任务无文件/状态冲突。
- **Frozen / do-not-touch**：PlayerController、MPV fast Seek、PiP、UnifiedTransport、Range/302/115、cache、Emby progress/resume 均未修改。
- **Completed**：独立任务/branch 建立；真实 `seriesEpisodes`、`LibraryItem`、详情页/选集页调用点与去重行为已确认；用户真机对照截图与 App 日志已分析；Emby 当前 REST API 与官方服务端/官方 iOS 使用方式已交叉确认；最小 API-path 修复及 contract check 已写入 working branch。
- **Validation state**：Current wrong behavior = **real-device confirmed**；root-cause evidence = source/log/API confirmed；**Code written = yes**；CI passed = no；IPA produced = no；fixed behavior real-device tested = no；Stable/frozen = no。
- **Pending**：重新检查 Active task 的 Build 占用后，为本任务分配独立 version/build；运行 ordering contract check + 现有相关 checks + 标准 MPV Release CI，产独立 IPA；真机必须同时验证当前 165 集异常 Series 和至少一个 IndexNumber 正常的标准 Series。HTTP 日志应显示 `/Shows/137597/Episodes?...` 且无强制 SortBy。
- **Next exact action**：分配独立 Build/Version 并进入 CI/IPA；CI 成功只能标记 CI/IPA，不得宣称排序已真机修复。
- **Rejected / do-not-repeat**：标题自然排序、文件名排序、DateCreated/ID fallback、nil IndexNumber 人工补号、客户端第二套排序状态、旧/新接口 speculative fallback。
- **Open questions / risks**：修复后的真实顺序仍必须由目标 Emby Server + 真机确认，不能仅凭 API 文档宣称完成；同时要验证标准剧集不会因 endpoint 切换回归。未合并 Player episode picker/auto-next 最终需要重新同步此共享排序契约。
