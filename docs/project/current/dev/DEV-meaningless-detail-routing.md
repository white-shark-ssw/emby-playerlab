# DEV-meaningless-detail-routing

- **Status**: Active — Build304 IPA handoff ready; target-device validation pending
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
- Accepted Build303 exact product source used as CI guard: `0b5ce25bcec0a4d0240891913ad17114b02cf10e`。
- Relevant source state before this task: Library root native poster selection sent every item to `EmbyPosterDetailDestination`; `EmbyServerBrowseV3.swift` already owned `v3LibraryIsBrowsableFolder` and `V3LibraryFolderBrowserView`.

## Working branch / PR / tested source

- Working branch: `feat/meaningless-detail-routing`。
- PR: `#293` — `Route library Folder items to existing folder browser`，open / unmerged。
- Exact tested product source: `d5b36d98efcbe426d91a750735e2780c5b723576`。
- CI control branch: `ci/build304-meaningless-detail-routing-20261009`。
- Successful CI control head: `09934425748fc40837489f401e99a7563ce33abc`。
- The feature branch may advance with docs-only checkpoint updates after the tested product commit; runtime attribution remains the exact tested source above.

## Build candidate

- Candidate: OnePlayer `0.15.37 / Build304`。
- Dedicated successful run/job: `37828043577 / 113485873035`。
- Artifact: `OnePlayer-0.15.37-build304-meaningless-detail-routing`, ID `11573665346`, size `22969260` bytes, artifact digest `sha256:e658d08ec8d5f15d8296b195a341e720ff07bbbc03034ce9c7ea4092366323e5`。
- IPA: `OnePlayer-0.15.37-build304-meaningless-detail-routing-unsigned.ipa`, size `18659927` bytes, SHA-256 `6b2766d272836a6f0798b1b6a6a41081d28f32c80ef97999fc04601210b3f5e7`。
- Source ZIP SHA-256: `a6b6e0cd21d6bee9bbef33a95a857069a44d6d3458f011587630cabf669b4cfd`; archive comment is exact product source `d5b36d98efcbe426d91a750735e2780c5b723576`。
- Bundle: `com.embyplayerlab.app`; display name `OnePlayer`; packaged version/build `0.15.37 / 304`。
- App `MinimumOSVersion` and runtime Mach-O minOS both verified `15.0`。
- Uniqueness: Build304 / 0.15.37 remains assigned only to this task; parallel Aether task uses Build235 and does not overlap this UI route.

## Evidence

- Build303 真机日志记录了 3 次详情生命周期；第二次对应 item `180310`，详情 model 进入 media 阶段后立即结束，没有发起 `PlaybackInfo`，Images/Similar 返回后仍无详情图片。
- 用户截图显示第二个页面的类型文案为 `Folder`，且页面没有有意义的媒体详情。
- 现有 Library V3 文件夹路径已经把 `Folder` / `CollectionFolder` 作为可浏览容器，并由 `V3LibraryFolderBrowserViewModel` 以 folder id 加载子项。
- Build304 exact source changes Library root native poster destination only: `v3LibraryIsBrowsableFolder(item)` → existing `V3LibraryFolderBrowserView`; all other items remain on `EmbyPosterDetailDestination`。
- `EmbySharedImageAndNavigation.swift`, `EmbyMediaDetailView`, Player, Transport, Cache, Emby Session are not changed by the product candidate.
- Actual-source `PosterWallRegression` suite passed `53 tests / 0 failures`, including `LibraryAdapterTests` `7 / 0` plus retained poster/section/result/search regressions.
- Release generic-device build succeeded on Xcode 16.4; package validation, Info.plist identity and minOS audit all passed.
- Artifact ZIP, IPA checksum and source ZIP checksum were independently rechecked after download and match the CI checksum files/artifact digest.
- First Build304 control run `37827850287` failed before compilation because the CI guard compared against the wrong older Library baseline; only the CI control workflow baseline was corrected. Product source `d5b36d98...` was unchanged. Successful run is `37828043577`.

## Files / modules in scope

- `Sources/UI/EmbyServerBrowseV3.swift` — only the Library root native poster destination branch.
- `scripts/check_library_poster_adapters.py` — narrow regression-guard exception for that exact route substitution.
- `Sources/Core/AppIdentity.swift` — candidate version identity only.
- Candidate changelog / task checkpoint / CI control workflow.
- `Sources/UI/EmbySharedImageAndNavigation.swift` was inspected and explicitly guarded unchanged; it is not modified by Build304 product source.

## State owner / shared dependencies

- 文件夹子项状态所有者继续是现有 `V3LibraryFolderBrowserViewModel`。
- Library root poster selection stays system `NavigationLink` owned; its destination now routes browsable folders to the existing folder browser, while non-folder media keep `EmbyPosterDetailDestination`。
- 不新增第二套 folder loader、缓存、导航状态或详情状态。

## Frozen / do-not-touch

- MPV / Player / UnifiedTransport / Cache / Emby Session / STRM→302→115/CDN P0 合同。
- Build303 已验收的 3 列海报墙滚动/分页行为。
- `EmbyMediaDetailView` 内部详情渲染、详情 still viewer / immersive 行为。
- 原生 NavigationStack push/pop 原则。
- iOS deployment target 15.0。

## Parallel conflicts checked against

- `DEV-aether-multi-engine-comparison`: Active；作用域为 Player/Transport/Aether，本任务不修改这些文件或状态所有者；其当前 candidate 为 Build235，不与 Build304 冲突。
- `DEV-search-page-optimization`: Completed；其 Build256 搜索基线保持受保护，本任务不修改 Search。
- 当前没有发现另一个 Active task 占用 Library root folder routing / Build304 / 0.15.37。

## Completed

- 读取用户日志并确认 3 次详情访问中的第二次为无媒体信息的 Folder 详情。
- 读取真实定义、调用点、现有 folder browser 状态所有权及相关 regression tests。
- 确定并实现最小方向：仅 Library 根海报入口对 browsable folder 复用现有 folder browser，不修改详情页内部。
- 创建独立 branch / PR #293，并分配 candidate `0.15.37 / Build304`。
- 更新 Library adapter guard，只允许这次有证据支持的 root destination 替换；Frozen/P0 路径保持不变。
- Build304 actual-source regression、Release build、identity/minOS validation、IPA packaging/upload 全部成功。
- 下载 artifact 后独立核验 artifact digest、IPA SHA-256、source ZIP SHA-256、source commit comment、Info.plist identity 和 iOS 15.0 minOS。

## Validation state

- Code written: **yes**。
- CI passed: **yes — run `37828043577`, job `113485873035`**。
- IPA produced: **yes — artifact `11573665346`; IPA SHA-256 `6b2766d272836a6f0798b1b6a6a41081d28f32c80ef97999fc04601210b3f5e7`**。
- Real-device tested: **no for Build304**；Build303 only reproduces the original Folder problem。
- Stable / frozen: **no**。

## Pending

- 用户在 iPhone 15 Pro Max / iOS 17.0 安装 Build304，重点验证原截图对应 `Folder` 点击后直接进入子项浏览，不再出现空壳媒体详情。
- 同时抽查普通 `Movie` / `Series` 详情，以及 `Episode` 既有 series-destination 行为无回归。
- 收到真机结果后，再决定是否接受、合并 PR #293、更新长期项目资料并完成本任务；CI/IPA 成功不得提前描述成真机已解决。

## Next exact action

1. 交付已核验的 Build304 IPA 给用户。
2. 等待并记录 Build304 真机结果：Folder → 子项浏览；Movie/Series/Episode 原路径无回归。
3. 若真机通过，再完成 acceptance/merge/长期文档 closeout；若失败，以新日志/真机行为为最高优先级继续定位。

## Rejected / do-not-repeat

- 不在 `EmbyMediaDetailView` 内针对 Folder 堆叠隐藏按钮/空状态补丁；根因是 Library root destination 类型路由错误。
- 不新增另一套文件夹 API loader 或导航状态。
- 不为未知类型做 speculative fallback/retry/timer。
- 不把第一次 CI guard 失败误写成产品编译失败；它发生在 checkout/guard 阶段，产品 source 未改变。

## Open questions / risks

- Build304 目前只有 CI / IPA 证据；真正的 Folder 入口行为必须由目标真机验证。
- Library root 可能存在其它非 Folder 的特殊 Emby item type；本任务没有证据支持扩大路由分类，暂不做 speculative handling。
