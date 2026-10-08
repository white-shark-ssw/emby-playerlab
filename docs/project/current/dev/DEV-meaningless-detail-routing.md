# DEV-meaningless-detail-routing

- **Status**: Active
- **Work ID**: `DEV-meaningless-detail-routing`
- **Routing aliases / keywords**: `优化无意义详情页` / `无意义详情页` / `Folder详情页` / `文件夹详情` / `detail routing`
- **Task**: 避免 Library 根海报墙中的可浏览 `Folder` / `CollectionFolder` 被推入媒体详情页，改为复用现有文件夹子项浏览页。

## User intent / acceptance criteria

- 用户真机 Build303 日志中连续进入 3 个详情对象，第二个对象出现截图所示的空洞页面：只有标题、`Folder` 类型文字和详情页标准按钮，没有有意义的媒体内容。
- Library 根海报墙点击可浏览 `Folder` / `CollectionFolder` 时不应进入 `EmbyMediaDetailView`。
- 这类对象应复用现有 `V3LibraryFolderBrowserView` 展示其子项；嵌套文件夹仍沿既有 folder browser 继续进入。
- `Movie` / `Series` 等真实媒体继续走现有 `EmbyPosterDetailDestination`，`Episode` 的 series destination 特例保持不变。
- 不改播放器、Transport、Cache、Emby Session、详情页内部实现、Build303 已验收海报墙滚动合同。

## Baseline

- Accepted product baseline: OnePlayer `0.15.36 / Build303`。
- Runtime evidence: 用户提供的 Build303 真机日志，第二次详情加载无 `PlaybackInfo` 请求且最终 `images=0`；截图明确显示对象类型为 `Folder`。
- Base branch: `main`。
- Main before task checkpoint: `a2720e55200a813bfe82a9280edaf8e6c483cefa`。
- Task branch base after checkpoint creation: `28f50007bfeb9b20e4b42bc8ea0458c5eb925962`。
- Relevant source state: Library 根 `nativePosterNavigationLink` 原先把所有 `nativePosterSelection` 直接交给 `EmbyPosterDetailDestination`；同文件已经有 `v3LibraryIsBrowsableFolder`、`V3LibraryFolderBrowserView` 与 folder child owner。

## Working branch / PR / head commit

- Branch: `feat/meaningless-detail-routing`。
- PR: `#293` — `Route library Folder items to existing folder browser`。
- Current implementation head: `3053e99579ea013916d48d3fe41bd3e17e30f2a1`。

## Build candidate

- Reserved candidate: OnePlayer `0.15.37 / Build304`。
- Uniqueness check: `BUILD_TEST_INDEX.md`、其他 Active checkpoints 与仓库搜索未发现 Build304 / 0.15.37 占用。

## Evidence

- Build303 真机日志记录了 3 次详情生命周期；第二次对应 item `180310`，详情 model 进入 media 阶段后立即结束，没有发起 `PlaybackInfo`，Images/Similar 返回后仍无详情图片。
- 用户截图显示第二个页面的类型文案为 `Folder`，且页面没有有意义的媒体详情。
- 真实源码确认问题入口是 Library 根原生海报墙：`nativePosterNavigationLink` 原先不区分 `Folder`，而 `.folders` tab / nested folder path 已正确复用 `V3LibraryFolderBrowserView`。
- `Tests/PosterWallRegression/LibraryAdapterTests.swift` 已覆盖 `Folder` / `CollectionFolder` 分类与 folder owner 子项加载语义。
- 实现 diff 从 task branch base 到首个路由 commit 只有 `Sources/UI/EmbyServerBrowseV3.swift` 4 additions / 2 deletions；没有改动共享详情 destination 或 P0 模块。

## Files / modules in scope

- `Sources/UI/EmbyServerBrowseV3.swift` — 仅 Library 根 `nativePosterNavigationLink` 的 Folder destination 分支。
- `scripts/check_library_poster_adapters.py` — 只允许上述精确路由例外，其余 accepted root/navigation guard 保持冻结。
- `Sources/Core/AppIdentity.swift` — Build304 candidate source version `0.15.37`。
- 本任务 checkpoint / candidate 文档。

## State owner / shared dependencies

- Library 根原生海报墙仍由现有 `nativePosterSelection` / system `NavigationLink` 拥有选择与 push 状态。
- 文件夹子项继续由现有 `V3LibraryFolderBrowserViewModel` 拥有，并继续调用 `libraryFolderChildren(parentId: folder.id)`。
- 非 Folder 媒体继续进入现有 `EmbyPosterDetailDestination`；没有新增第二套 detail destination、folder loader、缓存或导航状态。

## Frozen / do-not-touch

- MPV / Player / UnifiedTransport / Cache / Emby Session / STRM→302→115/CDN P0 合同。
- Build303 已验收的 3 列海报墙滚动/分页行为。
- `EmbySharedImageAndNavigation.swift` / `EmbyPosterDetailDestination`。
- `EmbyMediaDetailView` 内部详情渲染、详情 still viewer / immersive 行为。
- 原生 system navigation push/pop 原则。
- iOS deployment target 15.0。

## Parallel conflicts checked against

- `DEV-aether-multi-engine-comparison`: Active；作用域为 Player/Transport/Aether，本任务不修改这些文件或状态所有者，无源码重叠。
- `DEV-search-page-optimization`: Completed；其 Build256 搜索基线保持受保护，本任务不修改 Search。
- 未发现另一个 Active task 占用 Library root folder routing 或 Build304。

## Completed

- 读取用户日志并确认 3 次详情访问中的第二次是无媒体信息的 `Folder` 详情。
- 读取真实定义、调用点、root selection owner、现有 folder browser owner 与 regression tests。
- 在 `feat/meaningless-detail-routing` 上完成最小路由修改：Library 根选中 `Folder` / `CollectionFolder` 时复用 `V3LibraryFolderBrowserView`，其它 item 行为不变。
- 更新 `check_library_poster_adapters.py`：先断言精确的新 Folder route，再仅把这一精确片段归一化后继续执行原 accepted-root 对比，避免放宽其它冻结范围。
- `AppIdentity.sourceVersion` 更新为 `0.15.37`，保留 iOS 15.0 与其它产品合同。
- 创建 PR #293。

## Validation state

- Code written: **yes** — implementation head `3053e99579ea013916d48d3fe41bd3e17e30f2a1`。
- CI passed: pending。
- IPA produced: no。
- Real-device tested: Build303 仅复现问题；Build304 修复尚未真机验证。
- Stable / frozen: no。

## Pending

- 核验 PR #293 exact diff 并等待/修复 PR CI。
- CI 通过后记录 Build304 candidate 的 CI 证据；若当前 GitHub 能力有合法 Build304 package 路径则继续出 IPA，否则明确停在 CI 证据层。
- 用户真机验证：原截图 Folder 点击后进入子项浏览；Movie/Series/Episode 详情行为无回归；嵌套 Folder 继续可浏览。

## Next exact action

1. 核验 PR #293 仅包含 root Folder route、精确 regression guard 与 candidate identity 三类预期变化。
2. 检查 PR CI；失败则按真实日志最小修复，成功则更新 checkpoint / project evidence。
3. 在不制造临时 speculative build infrastructure 的前提下继续到可获得的最高 package 证据层，然后交付真机测试。

## Rejected / do-not-repeat

- 不修改 `EmbyPosterDetailDestination` 做全局 Folder 特判：当前证据已经定位到 Library 根 native selection，而且其它入口并未证明有同类问题。
- 不在 `EmbyMediaDetailView` 内针对 Folder 堆叠隐藏按钮/空状态补丁；这里是 destination 类型路由错误，不是详情内部展示问题。
- 不新增另一套文件夹 API loader、导航状态、fallback、retry、timer 或 watchdog。

## Open questions / risks

- 当前真机证据只证明 Library 根这一入口存在问题；不要把修复范围未经证据扩大到 Search/Home/Favorites 等所有通用详情入口。
- 旧 Library adapter guard 把 root navigation 视为 accepted 范围；本任务通过精确字符串归一化只允许这一个已确认的 Folder route 变化，不能进一步放宽。
