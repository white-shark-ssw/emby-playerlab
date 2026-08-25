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
- 当前旧播放器代码的 `seasonNumbers` 只取 `episodes.compactMap(\.parentIndexNumber)`，`displayedEpisodes` 又按 `parentIndexNumber == season` 过滤，因此只剩唯一一集 `parentIndexNumber=1`。
- 详情页通过 `seriesSeasons` + `SeasonId` 映射正确得到同季 980 集。

结论：这是播放器选集季分组遗漏，不是 Emby API 少返回、分页失败或 canonical order 问题。

## Baseline / identity

- Latest **accepted overall runtime baseline** remains OnePlayer **0.14.17 / Build184** merged to `main` at `5bf00bb0f48d0b640bcbea740d4c17c9f8e7be8f`.
- **Integration base used by this task**：`main@39576a908cc7d1d12e16e4e4721844143f7d3ffb`。
- Identity guard discovered that this current main tree already contains the active detail Build191 product source (`AppIdentity.sourceVersion = 0.14.24`, `EmbyMediaDetailView.swift`, `EmbyEpisodePickerView.swift`) even though Build191 is still real-device pending and does not replace accepted Build184.
- `main@39576a9` is a descendant of detail workflow-restored head `516f5cf6e8832af083d3c2605e365cb1dcb7119a`; compare reports no remaining file diff to that Build191 head. Therefore this bug was observed and is being fixed on the same Build191-style integration tree shown in the user's screenshot.
- This task is explicitly **stacked/dependent on the current Build191 detail integration identity**, but its product diff is file-disjoint from the detail task. Build194 validation does not imply Build191 acceptance.
- Working branch：`fix/player-nonstandard-episode-season-grouping`。
- Branch base：`39576a908cc7d1d12e16e4e4721844143f7d3ffb`。
- Current branch head：`2eade5b3b691a77e79345c1b4d8ed18340db6b93`。
- PR：none。
- Build candidate：**OnePlayer 0.14.27 / Build194**。
- Target artifact：`OnePlayer-0.14.27-build194-player-seasonid-grouping`。

## Files / modules in scope

Product change:

- `Sources/UI/PlayerEpisodeSelection.swift` — PlayerEpisodeCoordinator now loads real Season list; overlay season numbers/current season/filtering use SeasonId-first semantics matching detail behavior.

Validation:

- `scripts/check_player_episode_season_grouping.py` — guards the exact SeasonId-first/ParentIndex fallback contract and simulates the supplied 980-episode metadata shape.

Existing shared API reused unchanged:

- `Sources/Networking/EmbyAPIClient.swift` — existing `seriesEpisodes(seriesId:)` and `seriesSeasons(seriesId:)` are the common data source; no networking change required.

## State owner / shared dependencies

- PlayerEpisodeCoordinator remains the player-picker metadata owner.
- EmbyAPIClient remains the canonical network/API owner.
- Episode array order remains Build178 server-order authority.
- `nextPlaybackSource()` still indexes the full canonical `episodes` array, not the season-filtered UI list.
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

- `DEV-detail-episode-selection-navigation` owns active Build191 changes in `EmbyMediaDetailView.swift` / `EmbyEpisodePickerView.swift`. This task does **not** modify those files. It consumes the same `seriesEpisodes + seriesSeasons` API data and mirrors the already-working SeasonId-first membership semantics in player-only code. Because the integration base already contains Build191 source, this task is stacked for testing/merge identity even though source ownership is disjoint.
- `DEV-add-emby-page-optimization` owns Build192 and AddServer/Session/startup files; no file/state overlap.
- `DEV-home-carousel-drag-smoothness` owns Build193 and Home carousel state/files; no file/state overlap.
- Build194 is reserved uniquely for this task after 191/192/193.

## Completed

- User explicitly approved creating this as a new independent task and approved using the same episode/season data semantics as detail.
- Root cause established from current source + target-device logs.
- Independent branch created.
- Product fix commit `bf095264ed61640d6b6840a7fc1d57624fc390f0`.
- Contract test commit / current head `2eade5b3b691a77e79345c1b4d8ed18340db6b93`.
- Product diff from branch base is limited to `PlayerEpisodeSelection.swift`; test script is the only additional task file.
- Player now waits for both canonical episode data and real Season items, then publishes them together; season-fetch failure only logs and retains the existing ParentIndexNumber fallback, matching detail's safe fallback direction without adding retry/timer behavior.
- Overlay derives explicit season numbers from real Season items when available; current season and membership map Episode.SeasonId to Season.id/indexNumber first, then fall back to ParentIndexNumber.

## Validation state

- Code written：**YES**。
- Static contract script written：**YES**，execution in dedicated CI pending。
- Frozen/P0 product diff：current compare shows only `Sources/UI/PlayerEpisodeSelection.swift` modified; no PlayerController/MPV/PiP/Transport/Cache changes.
- CI passed：NO。
- IPA produced：NO。
- Real-device tested：NO for Build194。
- Stable / frozen：NO。

## Pending

- Create Draft PR after rechecking current main advancement and stacked Build191 identity.
- Run `scripts/check_player_episode_season_grouping.py` in dedicated Build194 Release CI.
- Compile standard MPV Release with Xcode 16.4, iOS 15.0 MinOS and Build194 identity.
- User real-device validation on the supplied 980-episode non-standard Series and at least one normal standard Series.
- Final merge must re-evaluate Build191 detail task state because this task's integration base includes Build191 product source.

## Next exact action

1. Recheck current main / other Active checkpoint Build identities before PR/CI.
2. Create Draft PR for the player-only bug fix.
3. Run dedicated Build194 standard MPV Release CI with contracts proving: SeasonId-first player grouping, Build178 server order untouched, auto-next still uses full canonical episodes, Frozen/P0 files unchanged, MinOS 15.0.
4. Produce Build194 IPA for target-device verification.

## Rejected / do-not-repeat

- Do not sort non-standard episodes by title/file/date/ID or synthesize artificial ordering.
- Do not treat nil ParentIndexNumber as “not a real episode”.
- Do not change auto-next to use the UI-filtered `displayedEpisodes`; it must keep canonical full-series order.
- Do not refactor `EmbyMediaDetailView.swift` while the independent detail Build191 task is active merely to create an abstraction.
- Do not describe Build194 success as Build191 detail acceptance.
- Do not add timer/retry/watchdog/fallback for a deterministic metadata grouping bug.
