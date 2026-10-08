# 海报墙入口清单

_2026-10-06。DEV-poster-grid-smoothness；源码审计基线：main 408ccc865262673ab708c01b13f20328aeff8066。只登记当前路由与拟迁移范围，G01库内容页已实施P1/P2试点，其他宿主待迁移；Build299 G01重启/深处回顶/长帧有正向真机反馈，未覆盖项与其他宿主仍待验证。整体合同见 [POSTER_PRESENTATION_DESIGN.md](POSTER_PRESENTATION_DESIGN.md)，执行阶段/交付与新会话指令见 [POSTER_IMPLEMENTATION_PLAN.md](POSTER_IMPLEMENTATION_PLAN.md)。_

## 1. 清点口径

按“用户从哪里进入 → 当前真实目的页 → 内容变体/数据合同”登记。一个目的页的多个入口都要验证，但不复制多个展示实现。当前 App RootView/AppShellView 进入 EmbyServerRootViewV3；以下以这条可达产品路径为准。入口可达性为源码证据，不代表每个入口本轮都做过真机操作。

在已审计的当前 V3 海报路由中，EmbyPosterGrid 有 **9 个可达调用点**，覆盖多种 tab、收藏类型和递归文件夹；另有 1 个旧 V3EmbySearchView 调用点，未被当前根导航引用。不能把“调用点数量”当成“用户入口数量”。

## 2. 通用三列海报墙：逐入口迁移与验证

| 编号 | 用户入口 | 当前展示目的地 | 必须保留 |
|---|---|---|---|
| G01 | 首页“我的媒体”库卡片；首页各库最新区“更多” | V3LibraryBrowserView.nativeItemsTab → EmbyPosterWall（Build295试点） | 电影/节目/视频随库类型；library scope、排序、60 条分页、Library 快照 |
| G02 | 库页切换“预告片” | 同一 pagedPosterTab | 预告片类型过滤与原排序/分页 |
| G03 | 库页切换“合集” | 同一 pagedPosterTab | BoxSet 合集封面及原点击目的地；不推定存在另一个合集内部影片墙 |
| G04 | 库页切换“我的收藏” | 同一 pagedPosterTab | 当前库范围的收藏过滤；与 Dock 收藏页区分页面身份 |
| G05 | 库页切换“类别” | V3LibraryBrowserView.genresTab | 类别封面墙；点击进入类别结果，不直接进入影片详情 |
| G06 | 点击库内类别封面 | V3LibraryGenreGridView | library + genre.name 筛选、60 条分页 |
| G07 | 库页切换“文件夹” | V3LibraryFolderGrid | Folder/CollectionFolder 与影片混排；按真实类型选择目的地 |
| G08 | 点击文件夹，继续进入任意层级子文件夹 | V3LibraryFolderBrowserView → V3LibraryFolderGrid | parentId 查询；现有不分页合同；层级导航和逐页滚动状态 |
| G09 | Dock 收藏页：电影、剧集、集各区“更多” | V3FavoriteCategoryGridView 的 Movie/Series/Episode 变体 | 三种收藏查询分别登记；60 条分页，沿用 Episode 真实详情路由 |
| G10 | Dock 收藏页：演员区“更多” | 同一 FavoriteCategoryGridView 的 Person 变体 | 人物姓名/图片；点击人物作品页，不走影片详情 |
| G11 | 详情顶部类型/标签文字；详情下方“标签”区域 | EmbyDetailFilterResultsView | 两条入口路径，共用结果页；保留 filter.name / isGenre 的区别与 60 条分页 |
| G12 | 详情演职人员卡片；收藏演员预览卡片；演员收藏“更多”后的卡片 | EmbyPersonMediaView | 三条入口路径；真实 PersonId 筛选、60 条分页及缺少 PersonId 提示 |
| G13 | 输入关键词并提交；点击搜索历史，且当前仅选一个搜索服务器 | V3GlobalSearchServerGridView | term、来源服务器、18 条分页；两种发起路径共享目的页 |
| G14 | 多服务器搜索结果中，某服务器区的“更多” | 同一 V3GlobalSearchServerGridView | 使用结果区对应 client/server，而非当前首页服务器；保留查询词 |
| G15 | 打开搜索页的“推荐观看”，向下追加推荐 | V3EmbyGlobalSearchView.searchLanding → EmbyPosterSearchLanding / EmbyPosterWall | 网格本身纳入；现有初始 9 / 追加 6、随机推荐与排除已推荐 ID、6pt 横向边距、Search 生命周期 |

G01–G15 是入口登记编号，不是 15 套组件。演员、类别、文件夹需要明确内容变体；媒体、Episode、Person、genre、folder 的点击目标归页面适配器。

“角色搜索”在当前源码体现为点击演职人员进入 PersonId 作品页，未发现按角色名字单独查询的 Character API，不能擅自增加该业务语义。详情叶子结果页可以列入迁移，详情 Hero/播放/选集等冻结实现仍保留原范围。

## 3. 横向海报区：共享资源能力，使用对应布局适配

| 编号 | 当前展示区 | 接入边界 |
|---|---|---|
| H01 | 首页我的媒体入口、继续观看、各库最新行 | 分别保留库入口/横版继续观看/竖版影片样式；首页内容宿主按整体设计接入，保护已验收轮播与 Dock |
| H02 | 库页“建议”：继续观看、最新、各推荐分组、通用推荐 | 与主网格同样需要图片提前准备；当前没有独立“更多”目的页调用 |
| H03 | Dock 收藏页：电影/剧集/集/演员预览行 | 共享图片与预算，保留各区“更多”路由和人物点击目标 |
| H04 | 多服务器搜索结果的各服务器横向预览行 | 每个 section 保留实际来源 client；“更多”进入 G14 |
| H05 | 详情页“相似作品 / 更多类似”、演职人员横向行 | 关联审计项；不是通用三列结果页。详情已有冻结范围，不能凭本清单自动重构整个详情宿主 |

“推荐页面的更多观看”目前能定位到 G15 推荐观看网格、G14 搜索结果“更多”和 H02 库建议推荐行；未找到独立同名的“推荐更多”导航目的页。“更多类似”是 H05 的横向区标题，其卡片进入另一详情页，并非点击标题进入三列墙。实施时若源码新增目的页，按真实路由补项，不猜接口。

## 4. 不混入本轮通用海报墙的相关页面

- 详情“全部剧集” → EmbyEpisodePickerView：纵向剧集行、排序与快速跳转轨道，不是三列墙。
- 播放器选集浮层 → PlayerEpisodeSelectionOverlay：有播放状态与横向选集合同，不能由海报墙重构改写。
- 剧照查看器、详情标签胶囊网格、服务器选择网格、媒体库管理列表：图片或网格外观相近，但不属于影片海报结果墙。
- EmbyServerRootView / EmbyServerRootViewV2 / V3EmbySearchView：已审计根路由未引用的旧实现；保留历史代码，不能把其存在标成当前可达入口或顺手删除。

## 5. 每条入口的交付记录

G01当前覆盖已验收；G02–G08 Build300、G09–G14 Build301、G15 Build302已接入并通过各自实际源码回归及核验IPA。逐入口真机覆盖以以下矩阵和Build index为准，不能以共享组件或CI替代全路径验收。H01–H04/P6仍待推进。

每个适配器至少检查：首次无图时固定海报框 + 已有名称；磁盘暖缓存提前准备；详情 push/pop 返回后保持数据与位置；深处回顶时已准备首屏直接呈现；分页追加不改变旧项位置；排序/筛选/来源变化不收到旧回调；无更多、空结果、图片失败和已有内容下的追加失败。G08 还检查父子文件夹往返；G10/G12 检查人物目的地；G13/G14/H04 检查跨服务器相同 item.id；G15 检查追加推荐、关闭推荐和离开 Search 的既有生命周期。

图片缓存可共用，但不同结果页是否有重启后的元数据快照由原业务合同决定，不能把 Library 的 cached-first 恢复承诺自动扩展到搜索/人物结果。首屏图片需求与预取需求计入同一有限预算；搜索现有 recommendationPosterImages 的 pin 必须一并核查。

### 当前迁移进度（2026-10-08）

| 入口范围 | 计划阶段 | 产品接入 / 构建 / 真机 |
|---|---|---|
| G01 Library.items | P2 首个闭环 | 已接入 / Build299实际源码回归/Release/IPA通过 / 重启前后8013运动采样0 >=25ms；1560缓存apply1.66ms；深处返回与1560/1620回顶保留，用户无明显卡顿。本轮长帧调优结束，其他交互/资源/约2000与5000规模未全测 |
| G02–G08 Library其余入口 | P3 | 原生适配完成 / Build300 28+10+6 fresh回归、Release与IPA核验通过 / 新入口待真机验收 |
| G09–G15 其他三列墙 | P4；G15含搜索落地宿主 | 原生适配完成 / Build301叶与Build302落地宿主实际源码回归、Release/IPA通过 / 301日志类别过滤和搜索叶正向，其他路径及302真机待验证 |
| H01–H04 首页及其他横向行 | P5；必要宿主可在P4接入 | 未开始 / 未验证 / 未验证 |
| H05 冻结详情关联行 | 关联审计/保护回归 | 不自动纳入宿主改造；无本轮验证 |

更新进度时逐项注明实际覆盖范围，尤其G09的三种媒体与G10人物、G11两条路径、G12三条路径、G13输入/历史和G14不同服务器；不能只把阶段范围整体勾完。

## 6. 源码依据

- [RootView](../../Sources/App/RootView.swift)、[AppShellView](../../Sources/UI/AppShellView.swift)、[EmbyServerRootViewV3](../../Sources/UI/EmbyServerRootViewV3.swift)：当前根和 Dock 路由。
- [EmbyHomeCoreV3](../../Sources/UI/EmbyHomeCoreV3.swift)、[EmbyHomeRowsV3](../../Sources/UI/EmbyHomeRowsV3.swift)：库卡片、首页更多与横向行。
- [EmbyServerBrowseV3](../../Sources/UI/EmbyServerBrowseV3.swift)：128 / 175 / 546 / 627 / 813 五个当前网格调用点，以及库建议/文件夹递归/收藏预览；995 为旧搜索调用点。
- [EmbyMediaDetailView](../../Sources/UI/EmbyMediaDetailView.swift)：261 / 818 标签入口，550 人物入口，964 过滤结果网格，866 相似横向区标题。
- [EmbyPersonMediaView](../../Sources/UI/EmbyPersonMediaView.swift)：21 人物作品网格。
- [EmbySearchExperienceV3](../../Sources/UI/EmbySearchExperienceV3.swift)：449 推荐网格，480 多服务器更多，502 单服务器直接目的地，555 搜索结果网格。
- [EmbyEpisodePickerView](../../Sources/UI/EmbyEpisodePickerView.swift)、[PlayerEpisodeSelection](../../Sources/UI/PlayerEpisodeSelection.swift)、[EmbyDetailOverlayViews](../../Sources/UI/EmbyDetailOverlayViews.swift)：相关页面的实际布局边界。

以上行号只对应本清单的审计基线，不应作为后续源码不变的假设。

### G01 pilot state (2026-10-06)

perf/poster-wall-library-build295 / Draft PR292 / OnePlayer0.15.28 Build295：G01两条入口共用完整EmbyPosterWall宿主。8项生产cell/preparation/cache/model回归通过，18项Dock/轮播回归保留并核对真实依赖。Release CI成功，IPA独立核验完成；准确身份见BUILD_TEST_INDEX与当前checkpoint。首次无图、磁盘暖/内存暖、分页、~item2000回顶、暖重启、push/pop/侧滑返回及Dock均待真机验证；G02–G15/H01–H04未迁移。现有SwiftUI图片消费者共享prepare订阅，不代表这些滚动宿主已迁移。


## Build299 restart-before/after device evidence — Library long-frame iteration closed (2026-10-08 02:29 Asia/Shanghai)

User explicitly identifies the first attachment as before restarting and the second as after restarting, and reports: “目前没有可感知的明显卡顿”. Combined with measured Library evidence, the current G01 long-frame tuning iteration can close at unchanged OnePlayer0.15.32/299. This is scope-limited positive real-device feedback, not a statement of sustained presented120FPS, a causal controlled A/B improvement, explicit acceptance/merge of the entire poster reconstruction or validation of unmigrated hosts. Detail behavior remains user-tolerated and outside current tuning.

| Log | Captured span (UTC) | Library movement samples | Maximum interval | >=25 / >=33.3ms | Maximum acquired count |
|---|---|---:|---:|---:|---:|
| OnePlayer-App-1791397610.log (before restart) |18:25:47.664–18:26:48.725 (61.061s)|3753 in6 batches|16.6705000ms|0 /0|1560|
| OnePlayer-App-1791397728.log (after restart) |18:27:23.381–18:28:47.479 (84.098s)|4260 in6 batches|16.6703333ms|0 /0|1620|

First log1010 lines/SHA256 **070582e4da52bdf4a08e86f8c6779097c278dc951c37d920b5a0a93955ef9b3d**; second1281 lines/SHA256 **73decc91b3d36ea5c48a66f48942a9bf8ae10a9532472878de613866a1875970**. Created walls confirm0.15.32/299. Two new logs total **8013** movement intervals and no gap event; including the preceding5033 sample gives13046 intervals across19 batches/0 >=25/33.3ms, but these distinct captures are not one continuous controlled experiment. Before-restart batch p99 maximum8.3352501ms; after-restart p99 maximum16.6703333ms in a small51-sample batch, most other batches8.335ms. CADisplayLink movement-only coverage is not actual presented FPS or all rendering.

**Large cached-first entry is now observed:** after restart, original PagePersistentCache restores1560 items in238.44ms with main_thread=0. The native1560-record full application takes1.66ms, records1.2045417ms, native-submit0.0827083ms, cached membership0.0217083ms and first-screen demand0.3305417ms. This is real measured current-source work below8.33ms, not proof disk images were immediately presented or a controlled percentage gain over298. Its initial live query subsequently replaces cached data with first60 before native appearance, as the original cached-first/live-refresh policy requires; do not misreport that initial query as a same-model detail-pop reset.

Before restart28 applications/max logged1.75ms (complete work counter1.7853751ms); after restart29/max2.08ms (counter2.0953333ms). Records max0.6726667/1.2045417ms; configure max0.6378334/0.6308750ms; image-adopt0.2412082/0.2078334ms; controller-layout0.5912083/0.2010834ms; all recorded work stages0 >=8.33ms. Native-submit excludes deferred layout/rendering. Existing bounded shared image budgets/metadata geometry/suffix append/ordered persistence/native physics remain unchanged.

**Deep return and top evidence:** first log six native hide/reappear pairs retain exact offset/count/revision/replacement; second twelve pairs also retain them. Examples125298.33/1560 before restart and89860.00/1140 after restart. At18:26:47.661 return-top reports offset0/count1560/revision27; at18:28:47.479 offset0/count1620/revision28. No reset page query or item application is recorded at either top action, and item count/frontier remains present. Second top event is the last log line, so subsequent presented-image timing is not independently covered; no cancelled interactive-pop transition outcome, explicit sort/refresh, pressure/thermal or bitmap-network reuse proof is invented.

**Decision and handoff:** keep exact tested/package source **44cdd845f3e822dde0215d0a47f180fbb73544a8**, artifact11498169109/IPA SHA2565c8e5e8863389752444d1ead3fb901c281c9c7bdc9eb760d13dc6f42b78aebcf/MinOS15.0. Existing final CI37654986230 success and21 fresh poster+3 fresh native UI /10 retained exact-input detail tests /18 separate retained Dock/carousel evidence remain unchanged. No justified new runtime patch,300 allocation, CI rerun or IPA; documentation only. Resume GitHub facts before this update: mainf226c95474792ba22d428422c19edabaf6a6d17a; feature/PR292 ab92828515f26ef5bb09198f1cd7a7cdbca777e8, Draft/open/unmerged.

No repeat test is required merely to round1560/1620 up to2000 for this captured Library tuning decision. Planned~2000/5000-scale, resource-pressure/bitmap first-presented timing and uncovered interaction scenarios remain truthfully listed as broader P6 coverage, not marked passed or removed from the plan. G01 current long-frame tuning ends with positive device feedback; entire DEV-poster-grid-smoothness stays Active because P3 G02–G08, P4 G09–G15 and P5 H01–H04 are still unimplemented. Next planned implementation is the P3 Library adapter audit within original business/paging/type/navigation owners, after restoring scope beyond this Library-only tuning iteration. Do not merge/remove the checkpoint or call all hosts stable from these two logs. Protect accepted294/carousel293/Dock294/Search256/P0.

## Build300 P3 implementation milestone — 2026-10-08

Code written locally for G02–G08: per-query native adapters and persistent system links; genre own primary image/title-only card, mixed folder/media row heights and folder badge; original Episode/detail destination reused. Original Library query owner now publishes per-tab revision/replacement and distinguishes successful same-page reappearance from explicit tab switching.60/raw frontier/filter/sort and existing nonpaged child-folder API remain. Native G01 view/root/actions, Library suggestions, Favorites/Search suffix, detail/playback and image budgets protected. New adapters require production-source7 regression cases plus3 new native navigation UI cases; existing21 poster+3 native UI and10 detail tests remain applicable. Linux source/harness checks only at this milestone; no Swift/CI/IPA result yet.

Next exact action: commit these scoped production/test/checker changes, then exact-source macOS CI (28 poster/adapter units +6 native UI +10 detail;18 unchanged-input Dock/carousel evidence retained), Release/package, independent identity verification and file handoff. Source head is the implementation commit containing this milestone; resolve via feature branch before resuming.

## Build300 P3 verified IPA handoff — 2026-10-08

User explicitly accepted the current G01 Library performance and authorized the remaining poster plan. P3 G02–G08 is implemented on perf/poster-wall-library-build295 /Draft PR292 open/unmerged: Library trailers, collections, favorites, genre covers/results and mixed recursive folders use the shared native wall. Original library scope/types/filters/sort,60-item raw server frontier/dedup, nonpaged parent-folder API and type-specific system destinations preserved. Ordinary same-page successful reappearance retains metadata; explicit tab switching/refresh/sort keeps original reload/reset. Genre and folder own primary images/title-only/icon cards and tallest mixed-row geometry retained. Accepted G01 view/root, Library suggestions, Favorites/Search suffix, detail/cache/playback/P0, image preparation budgets and frozen Dock/carousel byte-protected.

**Exact tested/package source:** cfe1b84c816bae1c37b07e7ac007da972c0b3510 (runtime implementation fe87eae9eadb09f959194bd45a54aba81596229d; last correction document-only). Final CI control f9457201956df18c36e6fd63d5a30250a5abdea2, branch ci/build300-poster-library-adapters-20261008, workflow build300-poster-library-adapters.yml; run37671589976/job112964410869 independently confirmed **completed/success**. Fresh **28 poster/adapter units +10 detail/cache tests +6 native UI tests**, zero failures; prior18 Dock/carousel actual-source tests explicitly byte-guarded/retained, not rerun. Native UI includes G01 deep return, coordinator-confirmed cancelled pop, real inertia append, P3 three paged-tab deep returns, genre cover/results and recursive mixed folders. Terminal detail is a fixture; production detail destination is byte-protected. Full Release/package/identity/MinOS steps passed. First run37671394292 failed only document trailing blank lines before Swift tests; corrected, no passing or IPA claim for that run.

**Artifact:** OnePlayer-0.15.33-build300-poster-library-adapters, ID11506615484, ZIP SHA256 **0fc8414efa2196663eb88c377798057dc7977f8710c87ea72c09520069395255**, size22997853bytes. IPA OnePlayer-0.15.33-build300-poster-library-adapters-unsigned.ipa, **18752866bytes**, SHA256 **7ca5581668577888faeb0e88b2a229e13baf4c32673f697f3bdb5fb02a2944d0**. Source ZIP SHA256 **c0ac34e6a7bd9edb8126f2f3afb4fe046971265da84c7d6b6af9382e530a017f**; git archive comment matches exact source cfe1b84c. Independent download checks ZIP integrity, checksums, production/test byte comparisons, bundle **com.embyplayerlab.app**, version **0.15.33**, Build **300**, Info MinOS **15.0**, arm64 Mach-O MinOS **15.0.0**, runtime compatibility audit and CADisableMinimumFrameDurationOnPhone=true. Actual IPA file saved for direct handoff; unsigned/sign-install required. No temporary URL or upload path retained.

**State:** Code written /44 fresh regressions passed /Release CI passed /IPA produced+independently verified /P3 real-device testing pending /not whole-task Stable, frozen or merged. G01 accepted only within documented Build299 before/after-restart1560/1620 coverage; no300 FPS/long-frame gain claimed. Main changes in this cycle are documents only, not runtime synchronization.

**Next exact action:** runtime handoff for P3 (prioritize genre results, three paged tabs, mixed root and at least two folder levels; native pop/side-swipe return,refresh/sort and first/append/error states). Next development stage is P4 G09–G15: Favorites more Movie/Series/Episode/Person, detail filters/person works, direct/history/multi-server more Search and recommendations with correct landing host. P5 H01–H04 horizontal hosts follows; H05 remains protected audit-only. P6 broader~2000/5000/resource/pressure/background/uncovered interactions and final matrix remain. No Build301 identity allocated. Keep Aether235 isolated; resume current branch/PR/exact-source facts rather than assuming main is runtime baseline.

## Build300 P3 per-entry implementation and automated coverage

All rows use exactsource cfe1b84c /passing run37671589976 and verified0.15.33/300 IPA. Each new entry still awaits real-device testing; automation below does not establish performance acceptance.

| Entry | Native adapter / preserved contract | Actual-source automatic coverage |
|---|---|---|
| G02 Library trailers | pagedPosterTab → V3LibraryPosterPage /Trailer,library scope,60 paging | controlled raw frontier/dedup/type/scope unit; dedicated Trailer loop in deep native return UI |
| G03 Library collections | same adapter /BoxSet and original detail destination | BoxSet query/filter/frontier unit; superseded-sort/refresh unit; dedicated BoxSet native return loop |
| G04 Library favorites | same adapter /library expected types +IsFavorite | scope/filter/frontier unit; dedicated Library favorites native return loop; Dock Favorites suffix byte-protected |
| G05 Genre covers | genresTab → genre-card wall /own primary image,title only,genre-result destination | cover query/retry/reappearance unit; own-image/no-media-badge/reuse unit; cover→genre-result→cover native UI |
| G06 Genre results | V3LibraryGenreGridView → media wall /library+genre.name,SortName Ascending,60 paging | actual genre model query/raw dedup/failed-append+retry unit; scrolled detail-pop geometry/frontier UI |
| G07 Mixed folder root | foldersTab → mixed wall /Folder/CollectionFolder→child;media→unchanged detail destination | root parent query/reappearance unit; kind/mixed-row geometry unit; root media/detail and folder-child native UI |
| G08 Recursive folders | V3LibraryFolderBrowserView → mixed wall /exactparentId,nonpaged,one model/page | original folder owner parent/no-paging/return/failure unit; at least two child levels and terminal detail pop,parent/root returns UI |

Normal3-column card/year/progress/badge and native geometry cases remain in prior21 poster tests. No image budget change, P4/P5 migration or300 device long-frame claim is implied.

## Build301 partial P4 G09–G14 implementation — pending macOS validation

OnePlayer0.15.34 /Build301 /poster-results-adapters; same task/feature/Draft PR292. Shared EmbyPosterResultsPage owns one native vertical wall and one resident system selection/link; original models still own60 Favorites/Person/filter and18 Search paging, raw frontier, dedup and error policy. Explicit Person own-image/name-only and plain-media preferred-image/name/year-only variants preserve original fields/heights (24/40); standard media42 unchanged. Original missing PersonId message, Episode destination, actual selected server client/term and Dock clearance retained. No new pull-to-refresh on previously non-refreshable leaves. G01/P3 source, Favorites preview, Search root/direct/history/multi-server/recommendations and detail source outside the filter leaf are byte-guarded unchanged. P0/carousel/Dock/root Search lifetime/image budgets unchanged.

Production-source extraction/leaf scope guards passed on Linux; new9 query/frontier/variant/native units and2 table-driven native UI tests are written but not yet run (planned37 poster units +10 detail units +8 native UI;18 Dock/carousel retained exact-input evidence). Terminal detail is a fixture, production destination bytes protected. CI/Release/IPA and all301 real-device evidence pending. G15 recommendation single landing host and unbounded second pin removal explicitly pending, along with P5 and broad P6. No301 FPS/long-frame or stable claim.

| P4 entry | Build301 source state | Automated/device state |
| --- | --- | --- |
| G09 Movie/Series/Episode more | Native adapter; original60/types/Episode route | 60/types source and media native leaf tests/Release passed; device pending |
| G10 Person more | Native Person variant→original works page | Query and two-level native UI/Release passed; device pending |
| G11 genre/tag two original entry paths | Shared native filter leaf; name/isGenre60 unchanged | Both flags/native leaf/Release passed; entry paths frozen; device pending |
| G12 detail cast/favorite preview/Person more | Native Person works; originalPersonId60 | Entry constructors guarded; missingId/query/works native UI/Release passed; device pending |
| G13 direct/history | Shared native18 Search results | Initiating paths frozen; query/native leaf/Release passed; product entry/device pending |
| G14 multi-server more | Same native18 result leaf with actual section client/term | Section route frozen; cross-source/query identity and leaf/Release passed; multi-server device pending |
| G15 recommendation9/+6 | Unchanged, NOT migrated | Single landing host and second-pin removal pending |


## Build301 exact-source CI started

Product source **83a239dc259651755315d52e9028d159830d9960**, CI control **ff949150c67b183aefae761bf878c2b583a8af99**, branch ci/build301-poster-results-adapters-20261008, run **37679733748 /job112992327395**. Product-head lease, exact allowed diff/whitespace, P3/Dock/main detail/P4 leaf business/source guards and retained18 native input guards passed; macOS simulator preparation running.37 poster +10 detail +8 native UI/Release/package pending. No301 IPA/device claim yet. Next exact action: monitor this exact run, inspect real failed logs if needed, fix only proven errors, then continue through verified IPA handoff. Do not reuse300 IPA as301.


## Build301 P4 G09–G14 verified IPA handoff — 2026-10-08

**Exact product/test/package source:** 83a239dc259651755315d52e9028d159830d9960. CI controlff949150c67b183aefae761bf878c2b583a8af99, branch ci/build301-poster-results-adapters-20261008, run37679733748/job112992327395 independently confirmed completed/success. Fresh **37 poster/adapter units +10 detail/cache units +8 native UI tests /55 total /0 failures**;18 unchanged-input Dock/carousel regressions explicitly byte-guarded and retained, not rerun. Full Release/package/identity/embedded MinOS passed. Independent download verifies ZIP integrity, archive source comment, actual production/test bytes, checksums, bundle/version/build and arm64 LC minimum OS. No failed301 run or fabricated device evidence.

**Artifact:** OnePlayer-0.15.34-build301-poster-results-adapters, ID11509478670, ZIP23004275bytes, SHA256 **bd98c7ad2fda045042ca0682a2df2d1eb774de96297a8b4f55f5f50fbf145c4a**. IPA OnePlayer-0.15.34-build301-poster-results-adapters-unsigned.ipa, **18733102bytes**, SHA256 **b02bb528ef75898d34d403f44e720df0b424ae9505dcb9568540361807f731ac**. Source ZIP SHA256 **6dfaab9e3d33ddb4cbc52c811c3837ac186c6ede8639f20e7cece7afd15b1e01**. Bundlecom.embyplayerlab.app /version0.15.34 /Build301 /Info MinOS15.0 /arm64 MinOS15.0.0 /CADisableMinimumFrameDurationOnPhone=true. Actual IPA saved for direct file handoff; unsigned, sign-install required. No temporary URL or upload path retained. Closing commits change project documents only; exact packaged source stays83a239dc.

**Coverage:** G09 Movie/Series/Episode favorite more, G10 Person more, G11 genre/tag filter leaf, G12 person works, G13 direct/history full Search result leaf and G14 server-section more share native results adapter. Original60/18 providers, types/filter/PersonId/term/client, raw frontier/dedup/error policies unchanged. Native UI exercises deep returns across media/person/filter/search leaf variants and Person more→production works→fixture detail→both parents. Terminal detail is a fixture: production Episode→Series/detail destination bytes are protected, not claimed exercised through a real terminal detail in that harness. Original G11 two entry paths, G12 three entry paths, G13 direct/history and G14 section-client paths are source-guarded; full product entry/device scenarios remain pending. G01/P3, main detail outside filter leaf, Search root/recommendations/lifetime, Favorites previews, image budgets, Dock/carousel/P0 source unchanged.

**State and next action:** Code written /55 fresh regressions passed /Release CI passed /IPA produced+independently verified /301 real-device testing pending /not whole-task Stable, frozen or merged. G01 accepted only within documented299 scope. G15 is NOT migrated: Search history/recommendation/footer must join one vertical native host, preserve9/+6/random/exclusions/6pt and Dock destruction/re-entry, remove second unbounded image pin. P5 H01–H04 horizontal/Home follows; H05 detail horizontal remains audit-only. P6 broad2000/5000/pressure/background/resources and uncovered interaction/target-device matrix remain. No Build302 identity allocated. Resume current source/branch/PR and candidate collision before next implementation; keep Aether235 isolated. Handoff301 for Favorites/Person/filter/Search deep return/paging/actual Episode+server routes, then continue G15 rather than restarting accepted Library tuning. No301 FPS or long-frame improvement claimed.

## Build302 G15 implementation — pending macOS tests / IPA

2026-10-08: user prioritizes finishing the poster task; cross-route cache decoupling is deferred because it requires stable server identity propagation and existing disk-file compatibility, not a small local patch. Unique candidate OnePlayer0.15.35 /Build302 /poster-search-landing /iOS15.0; same feature/Draft PR292, accepted overall294 unchanged.

G15 now uses the shared native vertical wall with one reusable Search history/recommendation header, horizontal reusable history chips, and native loading/empty footer. Recommendations retain6pt horizontal padding, original pixel-request specification, poster/name/year/badges, and last-item-visible9/+6/random/exclusion contract. Existing model remains metadata/query owner; only presentation revision counters added. Resident detail link and original history/direct/multi-server routes, Search menu/keyboard and root/Dock lifetime are preserved. The unbounded recommendationPosterImages dictionary and detached parallel warm downloader are removed; disk/decoded/shared preparation remain sole image owners within existing4-task/prefetch12/first-screen24/decoded64+96MiB budgets. Default G01/P3/P4 geometry/refresh/load-ahead unchanged; shared wall header/inset options are opt-in.

Linux exact-source G15/business/root/preloader/protected-source guards, P4 adapters, demand/passive detail guards and actual-source extraction passed; git-based Dock/P3 guards await real CI checkout. Seven actual-source recommendation/query/header units and two native Search UI cases added (planned44 poster/adapter units+10 detail+10 native UI;18 retained Dock/carousel exact-input evidence). Search root/model/preloader/wall/header/Dock are actual production source; network/session boundary and terminal detail remain explicit fixtures. No302 macOS compilation/test/Release/IPA/device claim yet. Next: commit guarded scope, exact-source macOS CI, fix actual failures, complete Release/MinOS/package/independent IPA verification and direct file handoff. P5 H01–H04/P6 remain pending; H05 protected audit-only; task Active/unmerged/not Stable.

## Build302 exact-source CI started

Product source **dced392bbf2e3960539890121cf7d6e9d8f80e86**, control **b0eae8007acd160c158653cae84828bd4d2e98f2**, branch ci/build302-poster-search-landing-20261008, workflow build302-poster-search-landing.yml, dedicated **run37733627914 /job113168149767**. Product lease,23-path scope/whitespace, exact G15 business/root/preloader guards, original Dock/P3/P4/detail/demand/iOS15 guards and retained18 native input guard completed/success. Actual-source harness/simulator preparation running;44 poster+10 detail+10 native UI/Release/package/IPA/device pending. Legacy unrelated invalid workflow runs on this CI branch are not the dedicated302 run. Next: monitor this exact source/run, inspect real failure logs if needed, fix proven errors, finish Release and independently verified actual IPA. Cache migration deferred per user priority; P5/P6 remain pending.

## Build302 P4 G15 verified IPA handoff — 2026-10-08

**Product/test/package source:** dced392bbf2e3960539890121cf7d6e9d8f80e86. CI controlb0eae8007acd160c158653cae84828bd4d2e98f2, branch ci/build302-poster-search-landing-20261008, workflow build302-poster-search-landing.yml, dedicated **run37733627914 /job113168149767 completed/success**. Fresh44 poster/adapter/Search units +10 detail/cache units +10 native UI tests = **64/0 failures**. Original18 Dock/carousel exact-input source evidence retained/guarded, not rerun. Full Release, identity, embedded MinOS and packaging passed. Independent downloaded ZIP/source/IPA byte checks passed; no failed dedicated302 run or invented device evidence.

**Artifact:** OnePlayer-0.15.35-build302-poster-search-landing, ID11531248235, ZIP23005063bytes, SHA256 **7e038c9f6f3ce18c1bca85aa1673253816128508f6ab53f6c31b7fadc5f22343**. IPA OnePlayer-0.15.35-build302-poster-search-landing-unsigned.ipa, **18700220bytes**, SHA256 **4b8b559d8c570f91e2feaf0f08cb7f33bf75aa70aa6027f7e93bcfa668492af3**; source ZIP SHA256 **6b41257a76bc72e6d1b67337dd3af12d2ce25e46b3aa1b353b20f7440cff14fe**. Git archive comment matches exact product SHA; actual changed production/tests/checkers and protected301 source bytes independently compared. Bundlecom.embyplayerlab.app/version0.15.35/Build302/Info MinOS15.0/arm64 MinOS15.0.0/CADisableMinimumFrameDurationOnPhone=true. Actual unsigned IPA saved for direct file handoff; sign-install required. No temporary transfer URL or private upload path persisted. Closing updates are documents only, packaged source remainsdced392bbf2e3960539890121cf7d6e9d8f80e86.

**Scope and evidence:** P4 G09–G15 code is now complete. G15 history/recommendation title/grid/footer share one native vertical collection; reusable horizontal history chips retain actions,6pt grid insets, legacy requested pixel width and poster/name/year/play-state fields. Original9/+6/random/exclusions/duplicate/short/error/generation/query/history/server-selection/Dock lifecycle preserved. Removed unbounded recommendation UIImage dictionary and detached extra warm-download path; existing disk/decoded/preparation owners and4/12/24/64+96MiB budgets remain. Source guards protect G01/P3/P4 leaves, frozen detail/H05, original Search fields/menu/direct/history/multi-server routes/root actions, Home293/Dock294/P0. Seven new actual-source units and two native UI cases cover recommendations/append/deep native return/history clear/direct leaf/toggle and keyboard Dock. Production Search root/model/preloader/wall/header/Dock are compiled; network/session and terminal detail are explicit fixtures. Device302 result/presented FPS/first-presented bitmap timing are not measured.

**Cache priority and next action:** User requested cache decoupling only if simple, prioritizing the poster task. It requires stable server identity propagation plus legacy disk-data compatibility, so is explicitly deferred;302 retains existing route/URL keys and does not claim LAN/WAN cache sharing fixed. Task remains Active/Draft PR292 unmerged/not whole-task Stable/frozen. G01 tuning accepted only within recorded299/301 scope;301 partial positive logs do not prove every P3/P4 path. Hand off302 for actual Search landing cold/warm9/+6, deep detail/history return, clear/toggle/keyboard/Dock and Search exit/re-entry tests. Development next is **P5 H01–H04 native section/horizontal hosts**: retain Home Hero scroll bridge/refresh/top/Dock and293carousel, Library suggestion providers, Favorite media/Person destinations, multi-server actual client/term; P6 broad2000/5000/resource/pressure/background/uncovered matrix remains. H05 audit-only. Recheck fresh heads/PR/collision before allocating303; **no Build303 allocated**. Aether235 stays isolated, accepted overall294 unchanged.

## Build303 P5 candidate reservation — 2026-10-08

User explicitly requested continuous poster-task development;302 verified IPA already handed off,302 device result pending. Resume identity rechecked: feature/PR292 e0a14ab149331a2b3ad6e82442c2e57f73e6f3a1 Draft/open/unmerged; main efc6995a50850043f3cbbf3dc0a32ae4f5d6f828 docs-only, accepted overall294 runtime. Active Aether235 has separate Player/Transport scope; Search256 Completed. Build index and ci/build303 refs checked; reserve **OnePlayer0.15.36 /Build303 /poster-sections /iOS15.0** uniquely for this task.

P5 source audit confirms H01 Home, H02 Library suggestions, H03 Favorites root and H04 multi-server Search use SwiftUI vertical/horizontal trees. Planned scoped change: shared native vertical section host and reusable native horizontal rows, standard poster/person cells plus original landscape/library tile fields/specifications; native header/more callbacks return to original page navigation/model. Home mounts unchanged Hero interaction and existing high-frequency offset/refresh bridge in a finite top host, preserving293carousel/294Dock/refresh/top/safe-area. No per-card SwiftUI host or new metadata/API/cache owner. G01/P3/P4 leaves, main detail/H05/P0 and image4/12/24/64+96MiB budgets remain protected. Cache identity migration remains deferred.

No303 implementation/CI/IPA/device success yet. Next exact action: implement/test H01–H04 real-source section adapters, inspect fixed geometry/prefetch/return/query/source lifecycle, then one exact-source macOS Release/CI and verified actual303 IPA without an intermediate continue gate. P6 resource/scale/uncovered target-device validation remains pending; full task Active/not Stable/frozen/merged.
