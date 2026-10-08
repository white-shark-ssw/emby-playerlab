# DEV-meaningless-detail-routing

- **Status**: Active
- **Work ID**: `DEV-meaningless-detail-routing`
- **Routing aliases / keywords**: `优化无意义详情页` / `无意义详情页` / `Folder详情页` / `文件夹详情` / `detail routing`
- **Task**: 避免可浏览 Folder / CollectionFolder 被通用海报入口错误推入媒体详情页，改为进入现有文件夹子项浏览页。

## User intent / acceptance criteria

- 用户真机 Build303 日志中连续进入 3 个详情对象，第二个对象出现截图所示的空洞页面：只有标题、`Folder` 类型文字和详情页标准按钮，没有有意义的媒体内容。
- 可浏览 `Folder` / `CollectionFolder` 不应进入 `EmbyMediaDetailView`。
- 点击这类对象应复用现有 `V3LibraryFolderBrowserView`，继续展示其子项；嵌套文件夹仍可继续进入。
- `Movie` / `Series` 等真实媒体详情路径保持不变，`Episode` 的 series destination 特例保持不变。
- 不改播放器、Transport、Cache、Emby Session、详情页内部实现、Build303 已验收海报墙滚动合同。

## Baseline

- Accepted product baseline: OnePlayer `0.15.36 / Build303`。
- Runtime evidence: 用户提供的 Build303 真机日志，第二次详情加载无 `PlaybackInfo` 请求且最终 `images=0`；截图明确显示对象类型为 `Folder`。
- Base branch: `main`。
- Base commit before checkpoint creation: `a2720e55200a813bfe82a9280edaf8e6c483cefa`。
- Relevant source state: `EmbyPosterDetailDestination` 当前仅对 `Episode` 特判，其余统一进入 `EmbyMediaDetailView`；`EmbyServerBrowseV3.swift` 已存在 `v3LibraryIsBrowsableFolder` 与 `V3LibraryFolderBrowserView`。

## Working branch / PR / head commit

- Planned branch: `feat/meaningless-detail-routing`。
- PR: not created yet。
- Head commit: pending branch creation。

## Build candidate

- Reserved candidate: OnePlayer `0.15.37 / Build304`。
- Uniqueness check: `BUILD_TEST_INDEX.md`、当前 Active checkpoints 与仓库搜索未发现 Build304 / 0.15.37 占用。

## Evidence

- Build303 真机日志记录了 3 次详情生命周期；第二次对应 item `180310`，详情 model 进入 media 阶段后立即结束，没有发起 `PlaybackInfo`，Images/Similar 返回后仍无详情图片。
- 用户截图显示第二个页面的类型文案为 `Folder`，且页面没有有意义的媒体详情。
- 现有 Library V3 文件夹路径已经把 `Folder` / `CollectionFolder` 作为可浏览容器，并由 `V3LibraryFolderBrowserViewModel` 以 folder id 加载子项。
- `Tests/PosterWallRegression/LibraryAdapterTests.swift` 已覆盖 Folder/CollectionFolder 分类及 folder owner 子项加载语义。

## Files / modules in scope

- `Sources/UI/EmbySharedImageAndNavigation.swift`
- `Sources/UI/EmbyServerBrowseV3.swift`（仅暴露并复用现有 folder classification/browser，不改变其状态所有权）
- 必要的 regression guard / tests
- Candidate 身份及本任务项目资料

## State owner / shared dependencies

- 文件夹子项状态所有者继续是现有 `V3LibraryFolderBrowserViewModel`。
- 通用海报点击目标继续由 `EmbyPosterDetailDestination` 决定；这里只增加 Folder / CollectionFolder 路由分支。
- 不新增第二套 folder loader、缓存、导航状态或详情状态。

## Frozen / do-not-touch

- MPV / Player / UnifiedTransport / Cache / Emby Session / STRM→302→115/CDN P0 合同。
- Build303 已验收的 3 列海报墙滚动/分页行为。
- `EmbyMediaDetailView` 内部详情渲染、详情 still viewer / immersive 行为。
- 原生 NavigationStack push/pop 原则。
- iOS deployment target 15.0。

## Parallel conflicts checked against

- `DEV-aether-multi-engine-comparison`: Active；作用域为 Player/Transport/Aether，本任务不修改这些文件或状态所有者，无源码重叠。
- `DEV-search-page-optimization`: Completed；其 Build256 搜索基线保持受保护，本任务不修改 Search。
- 当前没有发现另一个 Active task 占用 `EmbySharedImageAndNavigation.swift` / Library folder routing / Build304。

## Completed

- 读取用户日志并确认 3 次详情访问中的第二次为无媒体信息的 Folder 详情。
- 读取真实定义、调用点、现有 folder browser 状态所有权及相关 regression tests。
- 确定最小方向：通用 destination 对 browsable folder 直接复用现有 folder browser，不修改详情页内部。
- 分配独立 candidate `0.15.37 / Build304`。

## Validation state

- Code written: no。
- CI passed: no。
- IPA produced: no。
- Real-device tested: Build303 仅复现问题；修复尚未真机验证。
- Stable / frozen: no。

## Pending

- 从最新 main 创建 `feat/meaningless-detail-routing`。
- 实现最小路由修改并处理现有 poster adapter regression guard 的有意例外。
- 运行/等待 CI，生成并核验 Build304 IPA candidate。
- 用户真机验证 Folder 点击进入子项浏览，而 Movie/Series/Episode 行为无回归。

## Next exact action

1. 创建 `feat/meaningless-detail-routing` branch。
2. 在真实源码上只增加 Folder / CollectionFolder destination 分支并复用现有 `V3LibraryFolderBrowserView`。
3. 更新 regression guard，提交 PR，推进 CI / IPA。

## Rejected / do-not-repeat

- 不在 `EmbyMediaDetailView` 内针对 Folder 堆叠隐藏按钮/空状态补丁；根因是 destination 类型路由错误。
- 不新增另一套文件夹 API loader 或导航状态。
- 不为未知类型做 speculative fallback/retry/timer。

## Open questions / risks

- `EmbySharedImageAndNavigation.swift` 被旧 Library adapter scope guard 明确视为 frozen file；本任务必须同步调整该 guard，仅允许这次有证据支持的 destination 变化，不能放宽其它保护范围。
