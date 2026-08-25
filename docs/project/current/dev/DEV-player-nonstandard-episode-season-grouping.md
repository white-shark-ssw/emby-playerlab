# DEV-player-nonstandard-episode-season-grouping

## Status

**Active**

- **Work ID**：`DEV-player-nonstandard-episode-season-grouping`
- **Routing aliases / keywords**：播放器非标准选集 / 播放器选集漏集 / SeasonId 选集 / 非标准剧集播放器 / player episode grouping
- **Task**：修复播放器内选集对非标准 Emby 剧集的季分组遗漏，使播放器与详情页消费同一组 canonical episodes + seasons 数据，并使用同一 SeasonId 优先的季归属语义。

## Acceptance criteria

1. 非标准 Series 在详情页 980 集正常时，播放器选集也必须显示完整剧集。
2. 播放器与详情页共同使用 `seriesEpisodes(seriesId:) + seriesSeasons(seriesId:)`。
3. 季归属优先 Episode `SeasonId -> Season.id/indexNumber`；只有映射不可用时才回退 `ParentIndexNumber`。
4. 保持 Build178 `/Shows/{SeriesId}/Episodes` canonical server order；不新增标题/文件名/日期/ID/人工集号排序。
5. 当前选集 UI、点击切集、source-owned session replacement、可信自然结束 auto-next 不变。
6. PlayerController / MPV / PiP / UnifiedTransport / Cache / Range/302/115 / Resume-progress 不变；MinOS 15.0。

## Root-cause evidence

2026-08-26 用户目标机日志：

- `episodesTotal=980`, `seasonsTotal=1`, `selectedCount=980`, `unmatched=0`；
- `parentIndex={nil=979,1=1}`；
- `seasonId={152156=980}`；
- 播放器 `[EpisodeContext] episodes loaded ... count=980`。

因此 API/分页已经拿到全部 980 集；旧播放器 UI 仅按 `ParentIndexNumber` 分季/过滤，最终只显示唯一一集 `parentIndexNumber=1`。详情页 SeasonId 分组正确。

## Baseline / identity

- Accepted overall runtime：**OnePlayer 0.14.24 / Build191**，已通过 PR #257 合并 main。
- Working branch：`fix/player-nonstandard-episode-season-grouping`。
- Draft PR：**#258**。
- Product fix commit：`bf095264ed61640d6b6840a7fc1d57624fc390f0`。
- Build candidate：**OnePlayer 0.14.27 / Build194**。
- Dedicated CI run：**32879897997 — success**。
- Artifact：`OnePlayer-0.14.27-build194-player-seasonid-grouping`，ID **9575488345**。
- CI-produced IPA SHA-256：`21ebddfff348efd8a48e82381183f711135dfb054ff6d83d80c54364d5813ad1`。

## Implementation

Only product file changed:

- `Sources/UI/PlayerEpisodeSelection.swift`

PlayerEpisodeCoordinator now loads both canonical episodes and real Season items. Overlay season numbers/current season/membership use SeasonId-first mapping equivalent to detail semantics, with ParentIndexNumber fallback. `nextPlaybackSource()` still indexes the full canonical `episodes` array.

Validation script:

- `scripts/check_player_episode_season_grouping.py`

The dedicated contract reproduces the supplied 980-item shape (979 nil ParentIndexNumber, one ParentIndexNumber=1, all one SeasonId) and requires all 980 to remain visible through SeasonId grouping.

## Frozen / parallel boundaries

No changes to PlayerController, MPV Seek, PiP, Transport, Cache, EmbyAPIClient, detail page, full episode picker, Range/302/115 client-direct, Resume/progress or Build178 canonical ordering.

Build192 Add/Edit Emby and carousel work remain independent; no file/state overlap.

## Validation state

- Code written：**YES**。
- Static contract：**PASS**。
- Standard MPV Release CI：**PASS** — Xcode 16.4, 0.14.27 (194), MinOS 15.0, Frozen/P0 checks all passed。
- IPA produced：**YES**。
- Runtime real-device tested：**NO**。
- Stable：**NO**。

### 2026-08-26 installation result

User attempted to install the first distributed Build194 IPA through TrollStore and received **Parse Error 302: `Unable to locate Info.plist inside app bundle.`** Runtime validation therefore did not start.

Local inspection of the CI artifact shows:

- archive contains exactly `Payload/OnePlayer.app/Info.plist`;
- plist parses successfully as OnePlayer **0.14.27 (194)** / MinOS 15.0;
- ZIP integrity test passes;
- original archive places the main `Info.plist` near the end of the ZIP (entry 90 of 91).

Therefore current evidence does **not** prove a product-code or compiled-app Info.plist defect. A distribution/transfer/archive-read issue remains plausible. Do not count the failed install as runtime feature rejection.

A packaging-only TrollStore-friendly rewrap was produced from the same CI IPA content, moving `Payload/OnePlayer.app/Info.plist` and the main executable to the beginning of the archive without changing their file bytes. Rewrap SHA-256: `e8d969cbdcab42c05e847f1ef16492ea870f62273d65c4bcb5eafbb77f2d55ae`. This rewrap is pending target-device install.

## Next exact action

1. User installs the TrollStore-friendly Build194 rewrap.
2. If install succeeds, test the supplied 980-episode Series and at least one normal Series.
3. Confirm player picker shows all 980 episodes, season selection remains correct, manual switch works, and normal-series behavior is unchanged.
4. Only after target-device runtime acceptance update Build194 to real-device accepted/stable and consider PR #258 merge.
5. If TrollStore still returns 302 on the rewrap, obtain the exact downloaded file size/hash if practical and investigate transfer/package parsing before changing product code.

## Rejected / do-not-repeat

- Do not sort episodes by title/file/date/ID/artificial number.
- Do not treat nil ParentIndexNumber as a non-episode.
- Do not make auto-next use the UI-filtered list.
- Do not modify detail-page files merely to create an abstraction.
- Do not add timer/retry/watchdog/fallback for this deterministic metadata bug.
- Do not treat CI/IPA or installability as proof of runtime fix.