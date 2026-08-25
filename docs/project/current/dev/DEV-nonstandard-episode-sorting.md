# DEV-nonstandard-episode-sorting

## Status

**Active**

- **Work ID**：`DEV-nonstandard-episode-sorting`
- **Routing aliases / keywords**：非标准剧集排序 / 剧集排序 / 特殊剧集排序 / episode sorting
- **Task**：修复 OnePlayer 对非标准剧集的排序问题。真机截图、App 日志与 Emby TV episodes API 证据已确认：问题不是标题自然排序或 UI 二次排序，而是 OnePlayer 使用通用 Items 查询并强制 `ParentIndexNumber,IndexNumber`，绕过了 Emby TV series episode order authority。
- **User intent / acceptance criteria**：用户 2026-08-25 提供同一非标准剧集在 OnePlayer 与 EplayerX 的详情页/选集页截图，并明确确认 EplayerX 顺序与 Emby 一致、OnePlayer 当前错误。修复后 OnePlayer 应服从 Emby 实际剧集顺序；不得按标题/文件名/日期/ID 猜排序；标准剧集不得回归；详情页、全部选集、Player 选集与自动下一集必须消费同一 canonical order。
- **Canonical baseline**：当前 real-device accepted / merged functional baseline 为 **OnePlayer 0.14.9 / Build176**，canonical branch `main`。本任务最终已纠正为从 `main@7c4f36864b367270c862305f385f27bf7eb057b4` 直接派生；该 main head 只在 Build176 merge 后补写项目资料，产品树仍为已接受 Build176。此前从旧 main / 历史 feature branch 起步的中间提交均不作为 Build178 测试基线。
- **Working branch / PR / product head**：branch `fix/nonstandard-episode-sorting`；draft PR **#254**，base=`main`；Build178 产品 commit `e27e40c15ff76101267b749d52622f56fc02f3eb`。相对 `main@7c4f368...` 只有 `Sources/Core/AppIdentity.swift`、`Sources/Networking/EmbyAPIClient.swift`、`scripts/check_series_episode_ordering.py`、`docs/changelog/CHANGELOG_v0_14_11_build178.md` 四个文件差异；自检已剔除一次旧 blob 带入的无关 `imageURL()` 可选链变化。
- **Build candidate**：**OnePlayer 0.14.11 / Build178** 已分配；artifact identity `OnePlayer-0.14.11-build178-episode-ordering`。独立首页轮播任务已保留 **0.14.10 / Build177**，本任务不得复用 Build177。
- **Real-device evidence / root cause**：series `137597` 日志：`episodesTotal=165`、`seasonsTotal=5`、季计数 `1=41,2=3,3=31,4=4,5=86`，SeasonId/ParentId 分组一致；`nilIndex=164`，即 165 集中 164 集 `IndexNumber=nil`。`sampleFirst[0...4]` 与 OnePlayer 截图顶部项目完全对应，证明错误顺序来自共享 `seriesEpisodes()` 结果而不是 UI。旧实现调用 `/Users/{UserId}/Items` 并强制 `ParentIndexNumber,IndexNumber`；Emby 专用 `GET /Shows/{Id}/Episodes` 直接使用 series/season episode authority。
- **Implemented minimal fix**：`seriesEpisodes(seriesId:)` 改用 `Shows/{seriesId}/Episodes`，携带 `UserId`、既有 browse fields/image/user-data、`StartIndex`/`Limit` 分页；不发送 `SortBy`/`SortOrder`，保留服务器顺序、原分页终止条件和 ID-preserving `deduplicated(all)`。没有标题/文件名/DateCreated/ID fallback，没有人工补号，没有 retry/timer/watchdog，没有修改 UI、Player、Transport、Cache 或 Resume。
- **Contract check**：`scripts/check_series_episode_ordering.py` 固定检查 TV episodes path、UserId/分页、禁止 `SortBy` / `ParentIndexNumber,IndexNumber` / 旧 `libraryItems(parentId:seriesId...)`，并保持 iOS 15.0 Deployment Target。
- **Parallel / downstream**：Build176 player episode selector/auto-next 已成为 accepted main baseline，本任务从该产品树直接派生。Player 选集与自动下一集是共享 canonical order 的下游消费者，但本任务没有修改 `PlayerEpisodeSelection.swift` / `PlayerScreen.swift` / Player session owner。首页轮播 Build177 与本任务无文件/状态 owner 冲突。
- **Frozen / do-not-touch**：PlayerController、MPV fast Seek、PiP、UnifiedTransport、Range/302/115 客户端直连、Session cache、Cache UI、Emby progress/resume 均未修改。
- **CI baseline**：临时 dedicated standard MPV Release helper commit `db9aa2498fba5c6b092bfec2427042859e32b26a`，run **32836693548**，Build178 contract step 已通过，当前仍在 CI 中；该 helper 构建后必须恢复为 `main` 原有 `Build MDK Lab IPA` workflow，不属于最终产品差异。
- **Validation state**：Current wrong behavior = **real-device confirmed**；root-cause evidence = source/log/API confirmed；**Code written = yes**；Build178 contract preflight = passed；full CI passed = **not yet**；IPA produced = no；fixed behavior real-device tested = no；Stable/frozen = no。
- **Pending**：等待 dedicated Build178 Xcode 16.4 Release compile、0.14.11 (178) app identity、iOS 15.0 MinOS、IPA packaging/artifact upload；随后恢复临时 workflow 并记录 post-restore head。真机必须同时验证当前 165 集异常 Series 和至少一个 IndexNumber 正常的标准 Series；HTTP 日志应显示 `/Shows/137597/Episodes?...` 且无强制 SortBy。
- **Next exact action**：完成 run 32836693548；若成功，验证 artifact 与 source SHA 后恢复 CI helper，同步 `BUILD_TEST_INDEX.md` / 本 checkpoint 的 CI/IPA 证据，再交付 Build178 真机验证。CI/IPA 成功不得描述为排序已真机解决。
- **Rejected / do-not-repeat**：标题自然排序、文件名排序、DateCreated/ID fallback、nil IndexNumber 人工补号、客户端第二套 sort state、旧/新接口 speculative fallback；也不要把旧 generic Validate Source 的历史版本硬编码问题当成本 Build178 产品失败。
