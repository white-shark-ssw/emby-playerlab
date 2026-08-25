# DEV-player-nonstandard-episode-season-grouping

## Status

**Active**

- **Work ID**：`DEV-player-nonstandard-episode-season-grouping`
- **Routing aliases / keywords**：播放器非标准选集 / 播放器选集漏集 / SeasonId 选集 / 非标准剧集播放器 / player episode grouping
- **Task**：修复播放器内选集对非标准 Emby 剧集的季分组遗漏，使播放器与详情页消费同一组 canonical episodes + seasons 数据，并使用同一 SeasonId 优先的季归属语义。

## User intent / acceptance criteria

1. 用户给出的非标准 Series 在详情页显示 980 集正常，但播放器选集只显示 1 集；播放器必须显示完整可用剧集。
2. 播放器与详情页使用同一 Emby 数据来源：`seriesEpisodes(seriesId:)` + `seriesSeasons(seriesId:)`。
3. 季归属优先以 Episode `SeasonId` 对照真实 Season item 的 `id/indexNumber`；只有无法建立该映射时才退回 `ParentIndexNumber`。
4. 保持 Build178 canonical episode order：继续按 `/Shows/{SeriesId}/Episodes` 返回顺序展示，不新增标题、文件名、日期、ID、人工集号排序。
5. 当前 Season picker UI、横向卡片、点击切集、完整 source-owned session replacement、可信自然结束 auto-next 均不改变。
6. 不修改 PlayerController / MPV Seek / PiP / UnifiedTransport / Cache / Range/302/115 client-direct / Emby Resume/progress。
7. Deployment Target 保持 iOS 15.0。

## Real-device / log evidence

2026-08-26 用户在 iPhone 15 Pro Max / iOS 17.0 提供截图和日志：

- 详情页 `EpisodeDiagnostic`: `episodesTotal=980`, `seasonsTotal=1`, `selectedSeason=1`, `selectedCount=980`, `unmatched=0`。
- `parentIndex={nil=979,1=1}`。
- `seasonId={152156=980}`，即 980 集全部属于同一个真实 SeasonId。
- `seasonIndex={1=1}`，真实 Season item 的 indexNumber 为 1。
- 播放器 `[EpisodeContext] episodes loaded ... count=980`，证明播放器网络/分页已拿到全部 980 集。
- 当前 `PlayerEpisodeSelection.swift` 的 `seasonNumbers` 只取 `episodes.compactMap(\.parentIndexNumber)`，`displayedEpisodes` 又按 `parentIndexNumber == season` 过滤，因此只剩唯一一集 `parentIndexNumber=1`。
- 详情页当前已通过 `seriesSeasons` + `SeasonId` 映射正确得到同季 980 集。

结论：这是播放器选集季分组遗漏，不是 Emby API 少返回、分页失败或 canonical order 问题。

## Baseline / identity

- Accepted runtime baseline：OnePlayer **0.14.17 / Build184**，已合并 `main`。
- Main at task creation：`39576a908cc7d1d12e16e4e4721844143f7d3ffb`；该提交仅记录并行 Build192 文档候选，产品运行时代码仍继承 Build184。
- Working branch：`fix/player-nonstandard-episode-season-grouping`。
- Branch base：`39576a908cc7d1d12e16e4e4721844143f7d3ffb`。
- PR：none。
- Build candidate：**OnePlayer 0.14.27 / Build194**。
- Target artifact：`OnePlayer-0.14.27-build194-player-seasonid-grouping`。

## Files / modules in scope

Primary expected product change:

- `Sources/UI/PlayerEpisodeSelection.swift` — PlayerEpisodeCoordinator 加载真实 Season 列表；overlay 季号/过滤改为与详情页一致的 SeasonId 优先语义。

Existing shared API reused without speculative changes unless real compile/runtime evidence requires it:

- `Sources/Networking/EmbyAPIClient.swift` — 已存在 `seriesEpisodes(seriesId:)` 与 `seriesSeasons(seriesId:)`，默认不改。

Validation/changelog/docs may be added on this task branch or main according to project policy.

## State owner / shared dependencies

- PlayerEpisodeCoordinator remains the player-picker metadata owner.
- EmbyAPIClient remains the canonical network/API owner.
- Episode array order remains Build178 server-order authority.
- No new playback source/session owner is introduced.
- No new timer/retry/watchdog/cache is introduced.

## Frozen / do-not-touch

- `Sources/Player/PlayerController.swift`
- MPV fast Seek / Player engine core
- PiP Build173 architecture
- UnifiedTransport / Range / Cache
- STRM -> 302 -> 115/CDN client-direct contract; NAS never relays media bytes
- Emby progress/Resume
- Build182 detail scroll/cache owner
- Build184 accepted detail visual hierarchy
- Home carousel owner
- Add/Edit Emby SessionStore owner

## Parallel conflicts checked against

- `DEV-detail-episode-selection-navigation` owns active Build191 work in `EmbyMediaDetailView.swift`; this new task **will not modify that file**. It mirrors the already accepted/current detail data semantics by consuming the same `seriesEpisodes + seriesSeasons` API data and SeasonId-first membership rules in player code.
- `DEV-add-emby-page-optimization` owns Build192 and AddServer/Session/startup files; no overlap.
- `DEV-home-carousel-drag-smoothness` owns Build193 and Home carousel state/files; no overlap.
- Build194 is the next unoccupied candidate after 191/192/193.

## Completed

- User explicitly approved creating this as a new independent task.
- Root cause established from current main source + target-device logs.
- Independent branch created from current main.
- Build194 identity reserved.

## Validation state

- Code written：NO.
- CI passed：NO.
- IPA produced：NO.
- Real-device tested：NO.
- Stable / frozen：NO.

## Pending

- Implement Season list loading in PlayerEpisodeCoordinator without changing playback/session lifecycle.
- Replace player picker `ParentIndexNumber`-only grouping with SeasonId-first grouping equivalent to detail semantics.
- Add diagnostics/contracts covering the exact 980-episode shape: one SeasonId, mostly nil ParentIndexNumber.
- Build/IPA Build194 after code review and target-branch conflict recheck.
- User real-device validation on the supplied non-standard 980-episode Series plus a normal standard Series.

## Next exact action

1. Re-read current branch `PlayerEpisodeSelection.swift` and exact detail season-membership implementation.
2. Make the smallest player-only change: load `seriesSeasons`, preserve canonical `episodes` order, derive seasonNumbers from explicit seasons when available, and test membership by SeasonId first with ParentIndexNumber fallback.
3. Ensure manual switching and auto-next continue to consume the unfiltered canonical `episodes` array.
4. Run static diff check proving Frozen/P0 files unchanged before creating PR/CI candidate.

## Rejected / do-not-repeat

- Do not sort non-standard episodes by title/file/date/ID or synthesize artificial ordering.
- Do not treat nil ParentIndexNumber as “not a real episode”.
- Do not change auto-next to use the UI-filtered `displayedEpisodes`; it must keep canonical full-series order.
- Do not refactor `EmbyMediaDetailView.swift` while the independent detail Build191 task is active merely to create an abstraction.
- Do not add timer/retry/watchdog/fallback for a deterministic metadata grouping bug.
