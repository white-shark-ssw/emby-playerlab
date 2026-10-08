# DEV-meaningless-detail-routing

- **Status**: Completed — Build305 target-device accepted for the Folder/media-only Library-content issue; PR #293 pending merge
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

- Accepted overall baseline before this task: OnePlayer `0.15.36 / Build303`, exact product source `0b5ce25bcec0a4d0240891913ad17114b02cf10e`.
- Working branch: `feat/meaningless-detail-routing`.
- PR: `#293`, open / unmerged at the moment of this checkpoint.
- Build304 exact tested source: `d5b36d98efcbe426d91a750735e2780c5b723576`.
- Build304 CI run/job: `37828043577 / 113485873035`, success; artifact `11573665346`; IPA SHA-256 `6b2766d272836a6f0798b1b6a6a41081d28f32c80ef97999fc04601210b3f5e7`; MinOS 15.0.
- Build304 target-device log `OnePlayer-App-1791487069.log` proved the fresh Library root request for library `145113` was recursive but had no `IncludeItemTypes`, while selecting root Folder `180310` performed the existing non-recursive folder-child query and published exactly 2 child media items.
- Build305 target-device result on 2026-10-09 is now highest-priority evidence for this task: the user explicitly reports **“刚才的问题修复了”**. The former unwanted Folder/intermediate-page behavior is therefore accepted for the tested device path.

## Build304 result

- Product: OnePlayer `0.15.37 / Build304`.
- Code written ✅ / 53 tests 0 failures ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅.
- Device result: empty Folder detail shell is gone, but the unwanted Folder card remains and opens a 2-video intermediate folder page.
- Final UX: **rejected**. Stable/frozen: **no**.

## Build305 accepted result

- Product: OnePlayer `0.15.38 / Build305`.
- Exact product source: `3476a3d9a8976ef483bb9d9e2317d0d2e442f8bb`.
- Dedicated CI control: `ci/build305-meaningless-detail-routing-20261009` at `611ec8599ef1cddb21aaac08a69b504ba5b02a61`.
- CI run/job: `37832789044 / 113502123244` — success.
- Actual-source regression: 53 tests / 0 failures.
- Release generic-iOS build: success on Xcode 16.4.
- Artifact: `OnePlayer-0.15.38-build305-meaningless-detail-routing`, ID `11574533261`, digest `sha256:9ae178b9492534d0357bfcf3a7ddc8fcada49b1a49380019ef76dbc53b040b53`.
- IPA: `OnePlayer-0.15.38-build305-meaningless-detail-routing-unsigned.ipa`, SHA-256 `f843cd2ace20f9aa15f447c8d98e4935211a033b65e4493dd649fde30b9e53d4`.
- Source ZIP SHA-256: `a6ef12cff823c2d9b959635e079176cd1d18dc11ab535b3151c255bbf9a4ca11`; archive comment equals exact product SHA.
- Bundle identity independently verified: `com.embyplayerlab.app`, `0.15.38 / 305`, display name `OnePlayer`.
- Info.plist MinOS `15.0`; CI embedded Mach-O minimum-OS audit passed.
- Exact implementation is in `Sources/Networking/EmbyLibraryHubAPI.swift` rather than broad UI restructuring:
  - explicit `includeItemTypes` stays authoritative and unchanged;
  - when `libraryHubItemsPage` is `recursive == true` and the caller supplies an empty type scope, it uses `Movie,Series,Video`;
  - `libraryFolderChildren` continues to call the same API with `recursive: false`, so dedicated folder browsing remains unrestricted and unchanged.
- Build304 root Folder routing remains as a bounded safety path if an actual Folder legitimately reaches that root; `EmbyPosterDetailDestination` remains unchanged.
- Target-device acceptance: **yes for this task** — user reports the previously discussed problem is fixed on Build305.

## Separate newly reported issue — not attributed to this task

- In the same Build305 device session, the user reports a separate Home presentation problem: after opening a Home detail or entering a Library page and returning, already-loaded Home poster artwork visibly blanks/reloads.
- Exact source comparison from accepted Build303 (`0b5ce25b...`) to Build305 product (`3476a3d9...`) shows `EmbyPosterSections.swift`, `EmbyHomeCoreV3.swift` and the Home poster-presentation owner were **not changed by DEV-meaningless-detail-routing**; the product-source differences are AppIdentity, the Library networking normalization and the bounded Library Folder route plus task guards/docs.
- Therefore this checkpoint does **not** claim Build305 caused the Home return artwork behavior. It is routed to a separate development task with its own branch/Build and shared-poster Frozen-scope evidence.

## Files / modules in scope

- `Sources/UI/EmbyServerBrowseV3.swift` — Build304's already-tested root Folder destination branch only.
- `Sources/Networking/EmbyLibraryHubAPI.swift` — one exact recursive-empty-scope normalization for Library hub items.
- `scripts/check_library_poster_adapters.py` — exact source guard permitting only the Build304 route plus the Build305 query normalization; folder child semantics explicitly guarded.
- `Sources/Core/AppIdentity.swift` — `0.15.38` candidate identity.
- candidate changelog / checkpoint / CI control workflow.

## State owner / Frozen protection

- Library root selection remains system `NavigationLink` owned.
- Folder children remain solely owned by `V3LibraryFolderBrowserViewModel` and `libraryFolderChildren(parentId:)`.
- No second loader, retry, fallback, timer, watchdog, duplicate cache or navigation state.
- MPV, Player, UnifiedTransport, Session Cache, Emby Session, STRM→302→115/CDN, detail internals, native navigation ownership and iOS 15.0 deployment target remain protected and unchanged by this task.

## Validation state

- Build304: Code written ✅ / CI passed ✅ / IPA produced ✅ / real-device tested ✅ / final UX rejected ❌ / stable-frozen ❌.
- Build305: Code written ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device tested ✅ / reported Folder/media-only UX accepted ✅.
- Stable/frozen: task behavior accepted; durable project docs + PR merge still pending in this checkpoint.

## Completed

- Re-read the Build304 target-device log and confirmed the remaining failure was a fresh live unrestricted recursive Library root query, not a cache-only artifact.
- Inspected actual Build304 `libraryHubItemsPage` implementation and every source call site.
- Confirmed a conditional media-only default can be applied only to recursive empty-scope requests while leaving `recursive: false` folder browsing untouched.
- Implemented Build305 query normalization and version identity.
- Tightened the regression guard to require the exact networking substitution and reject any other Networking change.
- Build305 exact-source guard, 53-test regression suite, dependencies, Release build, identity/MinOS validation, packaging and artifact upload all passed.
- Independently downloaded and verified artifact digest, packaged checksums, IPA/source ZIP integrity, exact source archive comment, bundle identity/version/build and MinOS 15.0.
- Received target-device acceptance for the original Folder/media-only Library-content problem on 2026-10-09.

## Pending / Next exact action

1. Move the accepted Build305 conclusion into durable project state / build index / module status.
2. Reconcile PR #293 with latest `main`, merge the accepted task, then remove only this task checkpoint.
3. Continue the newly reported Home-return artwork issue only under its own task/branch; do not mix it into this completed Library-routing task.

## Rejected / do-not-repeat

- Build304 routing-only solution is insufficient for the stated UX.
- Do not hide Folder UI inside `EmbyMediaDetailView`; the root query is the evidence-backed owner of the unwanted card.
- Do not enumerate/flatten every Folder client-side; the existing recursive server query can return media directly when given the correct type scope.
- Do not globally force folder browsing to media-only; non-recursive folder queries are intentionally preserved.
- Do not add speculative fallback/retry/timer/watchdog or a second content owner.
