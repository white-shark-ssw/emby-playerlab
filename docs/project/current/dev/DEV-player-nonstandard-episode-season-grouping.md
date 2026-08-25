# DEV-player-nonstandard-episode-season-grouping

## Status

**Active**

- **Work ID**：`DEV-player-nonstandard-episode-season-grouping`
- **Routing aliases / keywords**：播放器非标准选集 / 播放器选集漏集 / SeasonId 选集 / 非标准剧集播放器 / player episode grouping
- **Task**：修复播放器内选集对非标准 Emby 剧集的季分组遗漏，并完成超大剧集列表的打开性能优化；播放器与详情页消费同一组 canonical episodes + seasons 数据并使用同一 SeasonId 优先季归属语义。

## Acceptance criteria

1. 非标准 Series 在详情页 980 集正常时，播放器选集也必须显示完整剧集。
2. 播放器与详情页共同使用 `seriesEpisodes(seriesId:) + seriesSeasons(seriesId:)`。
3. 季归属优先 Episode `SeasonId -> Season.id/indexNumber`；只有映射不可用时才回退 `ParentIndexNumber`。
4. 保持 Build178 `/Shows/{SeriesId}/Episodes` canonical server order；不新增标题/文件名/日期/ID/人工集号排序。
5. 超大列表打开时不得因为一次性实例化全部剧集卡片而出现数秒主线程卡顿；保持完整数据，不通过截断集数或人工分页规避。
6. 当前选集 UI、点击切集、source-owned session replacement、可信自然结束 auto-next 不变。
7. PlayerController / MPV / PiP / UnifiedTransport / Cache / Range/302/115 / Resume-progress 不变；MinOS 15.0。

## Root-cause evidence

2026-08-26 用户目标机日志：

- `episodesTotal=980`, `seasonsTotal=1`, `selectedCount=980`, `unmatched=0`；
- `parentIndex={nil=979,1=1}`；
- `seasonId={152156=980}`；
- 播放器 `[EpisodeContext] episodes loaded ... count=980`。

因此 API/分页已经拿到全部 980 集；旧播放器 UI 仅按 `ParentIndexNumber` 分季/过滤，最终只显示唯一一集 `parentIndexNumber=1`。详情页 SeasonId 分组正确。

Build194 真机进一步确认：SeasonId-first 修复后同一非标准 Series 已能在播放器选集中正常显示完整剧集；新的问题是点击“选集”后会卡住数秒。当前源码的横向容器是 `ScrollView(.horizontal) + HStack + ForEach(displayedEpisodes)`，每个 child 又包含远程缩略图、标题和两行简介，因此 980 集会在面板出现时建立整条复杂 `HStack`。该结构是当前性能问题的直接源码证据。

## Baseline / identity

- Accepted overall runtime：**OnePlayer 0.14.24 / Build191**，已通过 PR #257 合并 main。
- Working branch：`fix/player-nonstandard-episode-season-grouping`。
- Draft PR：**#258**。
- Product SeasonId fix commit：`bf095264ed61640d6b6840a7fc1d57624fc390f0`。
- Build194：**OnePlayer 0.14.27 / Build194**。
- Build194 dedicated CI run：**32879897997 — success**。
- Build194 artifact：`OnePlayer-0.14.27-build194-player-seasonid-grouping`，ID **9575488345**。
- CI-produced IPA SHA-256：`21ebddfff348efd8a48e82381183f711135dfb054ff6d83d80c54364d5813ad1`。
- TrollStore-friendly rewrap SHA-256：`e8d969cbdcab42c05e847f1ef16492ea870f62273d65c4bcb5eafbb77f2d55ae`。
- Next candidate reserved：**OnePlayer 0.14.28 / Build195**，purpose = lazy player episode row / large-list open performance。

## Implementation

Current product scope remains one file:

- `Sources/UI/PlayerEpisodeSelection.swift`

Build194 PlayerEpisodeCoordinator loads both canonical episodes and real Season items. Overlay season numbers/current season/membership use SeasonId-first mapping equivalent to detail semantics, with ParentIndexNumber fallback. `nextPlaybackSource()` still indexes the full canonical `episodes` array.

Build195 performance direction is intentionally minimal: replace only the episode scroller's eager `HStack` with `LazyHStack`, so only visible/near-visible card/image views are instantiated while the full canonical episode array remains available for scrolling, selection and auto-next.

Validation script:

- `scripts/check_player_episode_season_grouping.py`

The dedicated contract reproduces the supplied 980-item shape (979 nil ParentIndexNumber, one ParentIndexNumber=1, all one SeasonId) and requires all 980 to remain visible through SeasonId grouping. Build195 will extend the static contract to require the lazy horizontal episode row and reject reintroduction of the eager episode-card `HStack`.

## Frozen / parallel boundaries

No changes to PlayerController, MPV Seek, PiP, Transport, Cache, EmbyAPIClient, detail page, full episode picker, Range/302/115 client-direct, Resume/progress or Build178 canonical ordering.

Build192 Add/Edit Emby and carousel work remain independent; no file/state overlap.

## Validation state

- Build194 code written：**YES**。
- Build194 static contract：**PASS**。
- Build194 standard MPV Release CI：**PASS** — Xcode 16.4, 0.14.27 (194), MinOS 15.0, Frozen/P0 checks all passed。
- Build194 IPA produced：**YES**。
- Build194 TrollStore-friendly rewrap installation：**PASS on target device**。
- Build194 SeasonId grouping runtime：**POSITIVE** — user confirms the 980-episode Series now displays correctly in the player picker。
- Build194 large-list performance：**FAILED / follow-up required** — opening the picker blocks for several seconds with 980 episodes。
- Build194 Stable：**NO**。
- Build195：reserved; code/CI/IPA pending。

## Next exact action

1. In `PlayerEpisodeSelection.swift`, change only the episode row from eager `HStack` to `LazyHStack`; do not add pagination, timers, retries or item-count caps.
2. Keep fixed 174-point card geometry and existing ScrollViewReader/current-episode positioning contract.
3. Extend the task static contract to require the lazy row while preserving SeasonId grouping and full canonical auto-next.
4. Build **OnePlayer 0.14.28 / Build195** with dedicated Xcode 16.4 standard MPV Release CI and MinOS 15.0.
5. Target-device retest the same 980-episode Series: picker should appear promptly, all episodes remain reachable, current episode auto-position/selection works, and horizontal scrolling loads cards on demand without changing order.
6. Also spot-check a normal Series before considering PR #258 stable/mergeable.

## Rejected / do-not-repeat

- Do not sort episodes by title/file/date/ID/artificial number.
- Do not treat nil ParentIndexNumber as a non-episode.
- Do not make auto-next use the UI-filtered list.
- Do not modify detail-page files merely to create an abstraction.
- Do not fix 980-item opening latency by truncating the episode list, changing canonical order, manual pagination, debounce, timer, retry or watchdog.
- Do not treat CI/IPA or installability as proof of runtime performance acceptance.
