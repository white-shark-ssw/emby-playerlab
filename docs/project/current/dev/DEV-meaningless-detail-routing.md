# DEV-meaningless-detail-routing

- **Status**: Active — Build304 target-device rejected for final UX; Build305 candidate in progress
- **Work ID**: `DEV-meaningless-detail-routing`
- **Routing aliases / keywords**: `优化无意义详情页` / `无意义详情页` / `Folder详情页` / `文件夹详情` / `detail routing`
- **Task**: 让 Library 正常内容页只展示媒体对象；Folder / CollectionFolder 保留在现有文件夹浏览路径，不再作为普通电影内容卡制造无意义详情/中间层。

## User intent / acceptance criteria

- Build303 原问题：Library 根海报墙中的 item `180310` 以 `Folder` 进入通用媒体详情，形成只有标题、`Folder` 和详情按钮的空壳详情。
- Build304 把该对象改为进入已有 Folder browser；用户真机确认空壳详情消失，但点击同一张卡会进入该 Folder，并看到其中 2 个视频。用户明确指出这仍不是目标体验。
- 对“单文件夹多视频”这类电影库结构，正常 `.items` 内容页应直接来自递归媒体查询，不应把承载媒体的 Folder 当作内容卡。
- `.folders` tab / nested folder browser 继续保留真实 Folder 浏览语义。
- Movie / Series / Video 正常详情、Episode 特例、Build303 海报墙滚动合同、Player/Transport/Cache/Emby/P0 全部保持不变。

## Baseline / runtime evidence

- Accepted overall baseline: OnePlayer `0.15.36 / Build303`, exact product source `0b5ce25bcec0a4d0240891913ad17114b02cf10e`.
- Working branch: `feat/meaningless-detail-routing`.
- PR: `#293`, open / unmerged.
- Build304 exact tested source: `d5b36d98efcbe426d91a750735e2780c5b723576`.
- Build304 CI run/job: `37828043577 / 113485873035`, success; artifact `11573665346`; IPA SHA-256 `6b2766d272836a6f0798b1b6a6a41081d28f32c80ef97999fc04601210b3f5e7`; MinOS 15.0.
- Build304 target-device log `OnePlayer-App-1791487069.log` is now the highest-priority evidence for this task.
- The fresh Library root request for library `145113` is recursive but contains no `IncludeItemTypes`, and the live response republishes the same 60 root cards. This proves the unwanted Folder is not merely stale presentation cache.
- Selecting root Folder `180310` then performs the existing non-recursive folder-child query and publishes exactly 2 children. Those child media items open normal details and request PlaybackInfo.
- Therefore Build304 routing-only behavior is insufficient: the remaining owner is the recursive Library content query when its caller supplies no item-type scope.

## Build304 result

- Product: OnePlayer `0.15.37 / Build304`.
- Code written ✅ / 53 tests 0 failures ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅.
- Device result: empty Folder detail shell is gone, but the unwanted Folder card remains and opens a 2-video intermediate folder page.
- Final UX: **rejected**. Stable/frozen: **no**.

## Build305 candidate

- Reserved product: OnePlayer `0.15.38 / Build305`.
- Build305 collision check: no existing Build305 allocation found; parallel Aether task remains Build235.
- Exact implementation direction is now in `Sources/Networking/EmbyLibraryHubAPI.swift` rather than broad UI restructuring:
  - explicit `includeItemTypes` stays authoritative and unchanged;
  - when `libraryHubItemsPage` is `recursive == true` and the caller supplies an empty type scope, it uses `Movie,Series,Video`;
  - `libraryFolderChildren` continues to call the same API with `recursive: false`, so dedicated folder browsing remains unrestricted and unchanged.
- This is supported by complete call-site inspection of the Build304 source: the only recursive `libraryHubItemsPage` call that can arrive with an empty type list is the normal Library root `.items` path; genre paths pass explicit types, while folder children are non-recursive.
- Build304 root Folder routing remains as a bounded safety path if an actual Folder legitimately reaches that root; `EmbyPosterDetailDestination` remains unchanged.

## Files / modules in scope

- `Sources/UI/EmbyServerBrowseV3.swift` — Build304's already-tested root Folder destination branch only; no new Build305 UI change.
- `Sources/Networking/EmbyLibraryHubAPI.swift` — one exact recursive-empty-scope normalization for Library hub items.
- `scripts/check_library_poster_adapters.py` — exact source guard permitting only the Build304 route plus the Build305 query normalization; folder child semantics explicitly guarded.
- `Sources/Core/AppIdentity.swift` — `0.15.38` candidate identity.
- candidate changelog / checkpoint / CI control workflow.

## State owner / Frozen protection

- Library root selection remains system `NavigationLink` owned.
- Folder children remain solely owned by `V3LibraryFolderBrowserViewModel` and `libraryFolderChildren(parentId:)`.
- No second loader, retry, fallback, timer, watchdog, duplicate cache or navigation state.
- Do not touch MPV, Player, UnifiedTransport, Session Cache, Emby Session, STRM→302→115/CDN, detail internals, native navigation ownership, or iOS 15.0 deployment target.

## Validation state

- Build304: Code written ✅ / CI passed ✅ / IPA produced ✅ / real-device tested ✅ / final UX rejected ❌ / stable-frozen ❌.
- Build305: Code written ✅ / CI pending / IPA pending / real-device pending / stable-frozen ❌.

## Completed

- Re-read the Build304 target-device log and confirmed the new failure is a fresh live unrestricted recursive Library root query, not a cache-only artifact.
- Inspected actual Build304 `libraryHubItemsPage` implementation and every source call site.
- Confirmed a conditional media-only default can be applied only to recursive empty-scope requests while leaving `recursive: false` folder browsing untouched.
- Implemented Build305 query normalization and version identity.
- Tightened the regression guard to require the exact networking substitution and reject any other Networking change.
- Added Build305 changelog.

## Pending / Next exact action

1. Run Build305 exact-source regression/Release CI and fix only evidence-backed failures.
2. Package and independently verify Build305 IPA, source identity, bundle version/build and MinOS 15.0.
3. Hand Build305 to the user for target-device validation.
4. Target-device acceptance: the former `180310` Folder card must disappear from the normal content page; its contained media should remain discoverable by the recursive media query; the dedicated Folder tab must still browse folders normally.

## Rejected / do-not-repeat

- Build304 routing-only solution is insufficient for the stated UX.
- Do not hide Folder UI inside `EmbyMediaDetailView`; the root query is the evidence-backed owner of the unwanted card.
- Do not enumerate/flatten every Folder client-side; the existing recursive server query can return media directly when given the correct type scope.
- Do not globally force folder browsing to media-only; non-recursive folder queries are intentionally preserved.
- Do not add speculative fallback/retry/timer/watchdog or a second content owner.
