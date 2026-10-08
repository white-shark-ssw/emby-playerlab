# DEV-meaningless-detail-routing

- **Status**: Active — Build304 target-device rejected for the original UX goal; Build305 candidate in progress
- **Work ID**: `DEV-meaningless-detail-routing`
- **Routing aliases / keywords**: `优化无意义详情页` / `无意义详情页` / `Folder详情页` / `文件夹详情` / `detail routing`
- **Task**: 让 Library 正常内容页只展示媒体对象；Folder / CollectionFolder 留在现有文件夹浏览路径，不再以“电影内容卡”形式制造无意义详情/中间层。

## User intent / acceptance criteria

- Build303 原问题：Library 根海报墙中的 item `180310` 以 `Folder` 进入通用媒体详情，形成只有标题/Folder/按钮的空壳详情。
- Build304 不再进入空壳详情，但用户真机确认点击同一张卡后进入了该 Folder，并看到其中两个视频；用户明确指出这仍不是目标体验。
- 对单文件夹多视频、电影类内容库，正常 `.items` 内容页应展示递归媒体对象，而不是把承载它们的 Folder 当作内容卡。
- `.folders` tab / nested folder browser 继续保留真实 Folder 浏览语义。
- 普通 Movie / Series / Video 仍走原有详情路径；Episode 既有特例、Player/Transport/Cache/Emby/P0、Build303 海报墙滚动合同保持不变。

## Baseline / new target-device evidence

- Accepted overall baseline remains OnePlayer `0.15.36 / Build303`, exact source `0b5ce25bcec0a4d0240891913ad17114b02cf10e`.
- Build304 exact tested source `d5b36d98efcbe426d91a750735e2780c5b723576`; CI `37828043577 / 113485873035`; artifact `11573665346`; IPA SHA-256 `6b2766d272836a6f0798b1b6a6a41081d28f32c80ef97999fc04601210b3f5e7`; MinOS 15.0.
- Build304 target-device log `OnePlayer-App-1791487069.log` is now higher-priority evidence and rejects the original routing-only fix as sufficient.
- In that log, the live root request for library `145113` is `Recursive=true` but has **no `IncludeItemTypes`**; after the server response the root still contains 60 cards (`same_ids=1`).
- Tapping the problematic root card then issues `ParentId=180310&Recursive=false&...` and the folder browser publishes exactly **2** child items. Those two child items `180312` and `180313` each open normal detail and issue `PlaybackInfo` requests.
- Therefore the remaining problem is the Library `.items` query admitting Folder rows when the view's `collectionType` is nil/unrecognized; it is not a detail renderer bug and not a folder-child loader bug.

## Working branch / PR

- Branch: `feat/meaningless-detail-routing`.
- PR: `#293` — open / unmerged.
- Main currently differs from the feature line only by this task's earlier docs checkpoint; product/runtime baseline remains Build303 plus this task's scoped changes.

## Build candidates

### Build304 — rejected for final UX

- OnePlayer `0.15.37 / Build304`.
- Code written ✅ / 53 tests 0 failures ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅.
- Target-device result: empty media-detail shell is gone, but the unwanted Folder card remains and opens a 2-video folder browser. **Not accepted / not stable / not frozen.**

### Build305 — current candidate

- Reserved: OnePlayer `0.15.38 / Build305`.
- Repository search shows no existing Build305 allocation; parallel Aether remains Build235.
- Product change: in `V3LibraryBrowserViewModel.expectedItemTypes`, unknown/nil collection type now uses the existing mixed-media scope `[Movie, Series, Video]` instead of unrestricted `[]`.
- Existing recognized scopes remain unchanged: movies→Movie, tvshows→Series, homevideos→Video, mixed→Movie/Series/Video.
- Existing recursive root query remains unchanged; therefore media nested under folders stays discoverable, while Folder itself no longer belongs in the normal content result set. The dedicated `.folders` path remains the folder owner.
- Build304's root Folder routing remains as a bounded safety path for any actual Folder card that legitimately reaches that root; no global detail destination is changed.

## Files / modules in scope

- `Sources/UI/EmbyServerBrowseV3.swift` — Build304 root Folder route + Build305 unknown/nil content-type media-only fallback.
- `scripts/check_library_poster_adapters.py` — exact normalization/guard for only those two intended deviations from accepted Build303.
- `Sources/Core/AppIdentity.swift` — candidate identity `0.15.38`.
- candidate changelog / task checkpoint / CI control workflow.

## State owner / Frozen protection

- Library root system `NavigationLink` remains the selection/push owner.
- `V3LibraryFolderBrowserViewModel` remains the sole folder-child owner and still uses `libraryFolderChildren(parentId:)`.
- No second loader, retry, fallback, timer, watchdog, cache or navigation state is added.
- Do not touch MPV, Player, UnifiedTransport, Session Cache, Emby Session, STRM→302→115/CDN, detail internals, native navigation ownership, or iOS 15.0 deployment target.

## Validation state

- Build304: Code written ✅ / CI passed ✅ / IPA produced ✅ / real-device tested ✅ / final UX rejected ❌ / stable-frozen ❌.
- Build305: Code written ✅ / CI pending / IPA pending / real-device pending / stable-frozen ❌.

## Completed

- Re-read Build304 target-device log and confirmed the root problem is a fresh live unrestricted Library `.items` query, not stale cache-only behavior.
- Confirmed `expectedItemTypes` already maps `mixed` to Movie/Series/Video but default/nil to unrestricted `[]`.
- Implemented the minimal Build305 correction: default/nil now reuses Movie/Series/Video media scope; recognized library types are unchanged.
- Tightened the Library guard so only Build304's root Folder route and Build305's exact default media-scope substitution are allowed against accepted Build303 source.
- Reserved `0.15.38 / Build305`; no Build305 collision found.

## Pending / Next exact action

1. Finish syncing the feature branch with current main docs identity without changing product runtime.
2. Run the narrow actual-source Library/poster regression guard and Release CI for exact Build305 product source.
3. Package and independently verify Build305 IPA, bundle/version/build identity and MinOS 15.0.
4. Hand Build305 to the user. Target-device acceptance criterion: the former `180310` Folder card must disappear from the normal content page; its two child videos should be represented as media content rather than requiring a Folder intermediate page. `.folders` tab must still be able to browse folders.

## Rejected / do-not-repeat

- Build304 routing-only solution is insufficient for the stated UX even though it removed the empty detail shell.
- Do not hide Folder UI inside `EmbyMediaDetailView`; the fresh root query is the current evidence-backed owner of the unwanted card.
- Do not query every root Folder to inspect/flatten children client-side; the existing recursive media query can already request the correct media types directly.
- Do not add speculative fallback/retry/timer/watchdog or a second folder/content state owner.
