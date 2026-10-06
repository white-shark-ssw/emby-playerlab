# 海报墙入口清单

_2026-10-06。DEV-poster-grid-smoothness；源码审计基线：main 408ccc865262673ab708c01b13f20328aeff8066。只登记当前路由与拟迁移范围，G01库内容页已实施P1/P2试点，其他宿主待迁移；本轮真机验收待完成。整体合同见 [POSTER_PRESENTATION_DESIGN.md](POSTER_PRESENTATION_DESIGN.md)，执行阶段/交付与新会话指令见 [POSTER_IMPLEMENTATION_PLAN.md](POSTER_IMPLEMENTATION_PLAN.md)。_

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
| G15 | 打开搜索页的“推荐观看”，向下追加推荐 | V3EmbyGlobalSearchView.recommendationsSection | 网格本身纳入；现有初始 9 / 追加 6、随机推荐与排除已推荐 ID、6pt 横向边距、Search 生命周期 |

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

实施后逐行填写“已接入 / 构建验证 / 真机验证 / 待验证”；G01已写入Build295独立试点，8项生产海报回归/18项Dock轮播回归通过、Release CI/IPA已独立核验、真机待验收；G02–G15仍待迁移。共享核心完成不等于全部入口完成。

每个适配器至少检查：首次无图时固定海报框 + 已有名称；磁盘暖缓存提前准备；详情 push/pop 返回后保持数据与位置；深处回顶时已准备首屏直接呈现；分页追加不改变旧项位置；排序/筛选/来源变化不收到旧回调；无更多、空结果、图片失败和已有内容下的追加失败。G08 还检查父子文件夹往返；G10/G12 检查人物目的地；G13/G14/H04 检查跨服务器相同 item.id；G15 检查追加推荐、关闭推荐和离开 Search 的既有生命周期。

图片缓存可共用，但不同结果页是否有重启后的元数据快照由原业务合同决定，不能把 Library 的 cached-first 恢复承诺自动扩展到搜索/人物结果。首屏图片需求与预取需求计入同一有限预算；搜索现有 recommendationPosterImages 的 pin 必须一并核查。

### 当前迁移进度（2026-10-06）

| 入口范围 | 计划阶段 | 产品接入 / 构建 / 真机 |
|---|---|---|
| G01 Library.items | P2 首个闭环 | 已接入 / 自动回归/Release/IPA通过 / 未验证 |
| G02–G08 Library其余入口 | P3 | 未开始 / 未验证 / 未验证 |
| G09–G15 其他三列墙 | P4；G15含搜索落地宿主 | 未开始 / 未验证 / 未验证 |
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
