# 海报墙重构开发计划

_2026-10-06。DEV-poster-grid-smoothness 已按用户授权执行：P0完成，P1/P2 Library.items试点已实现并通过生产源码回归；Release/IPA已独立核验，真机验收待完成。P3–P6保留原阶段门槛。_

## 1. 接手入口与资料分工

先读根 AGENTS.md、docs/project/START_HERE.md、CURRENT_WORK.md / CURRENT_WORK_DEV.md，以及 PROJECT_STATE / MODULE_STATUS / TECHNICAL_DECISIONS / BUILD_TEST_INDEX / DOCUMENTATION_POLICY；选择现有 [DEV-poster-grid-smoothness](current/dev/DEV-poster-grid-smoothness.md)，不要新建重叠任务。

然后按顺序读：
1. [POSTER_PRESENTATION_DESIGN.md](POSTER_PRESENTATION_DESIGN.md)：状态所有权和体验合同，特别是 2A / 6A。
2. 本计划：实施顺序、检查与交付条件。
3. [POSTER_ENTRY_INDEX.md](POSTER_ENTRY_INDEX.md)：G01–G15 / H01–H05 真实入口、内容变体和覆盖状态。

checkpoint 保存当前身份/完成项/待办；本计划不是另一个 checkpoint。实施授权以新会话用户指令为准；当前用户已授权按计划开发；应按仓库纪律连续推进到P2可测试 IPA，不在普通代码/提交/CI中间节点停等“继续”。

## 2. 基线、历史代码与身份迁移

| 身份 | 当前已核实状态 | 实施用途 |
|---|---|---|
| 计划制定时文档 main | df4c7bf3cd4b8de51f392e9af930d12c42c26219 | 本计划审计基线；代码仍为已验收整体 Build294，接手时重新核对 head |
| 已验收整体产品 | OnePlayer0.15.27 / Build294，ca60a034d68d451bc0f93f5681465398131d54c5 | 保护最新 Dock 与继承的 Build293 轮播 |
| 历史 Poster 候选 | OnePlayer0.15.16 / Build283，39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6 | 分支 perf/poster-grid-offmain-persistence-build280；Draft PR#282 仍 open/unmerged，base 为 diag/poster-grid-persistence-frame-tail-build278 |
| 其他当前任务 | Aether Active：feat/aether-multi-engine-comparison，Build235；Search checkpoint Completed，Build256 合同保留 | 不复用它们的分支、候选或状态；海报不接入 Player/Transport/Aether |

本轮重新核对 PR#282 与真实分支 head 一致；没有修改其身份。实施时已重新查询最新索引、Active checkpoint、PR/CI候选并分配独立 perf/poster-wall-library-build295 / PR292 / OnePlayer0.15.28 / Build295。历史身份保持不变。

实施基线采用接手时最新且包含已验收 Build294 的产品源码。在同一 Work ID 下明确记录从旧实验分支迁往最新基线的原因、新 branch/base/head/PR 和旧身份保留关系；记录新事实后才推进。发现真实身份冲突先解决，不悄悄改成猜测值。不直接合并历史 PR stack，也不覆盖新 Home/Dock 文件。

从 Build280/283 提取有证据的后台有序 Library 持久化，以及原生网格导航链接持续挂载的激活合同。旧原生 cell 仍有 UIHostingController<AnyView>，不能作为最终轻量 cell 原样照搬；旧交互侧滑返回仍需在新候选明确验收。

用户此次停顿/视觉逆向尚无安装 Build/时间线。可依据明确重构要求和源码问题实施；缺少原报告 Build 限制的是“当前根因已证实”的归因。A/B使用明确记录的整体基线与新候选；不能将未知安装状态推定为283或294。

## 3. 开工前逐项核对的真实源码

| 范围 | 文件 / 定义 | 核对重点 |
|---|---|---|
| 网格与业务 | EmbyPosterGrid.swift；EmbyServerBrowseV3.swift | 网格尺寸、Library七tab、60分页、folder不分页、收藏四类型、选中/排序所有者 |
| 现有图片能力 | EmbySharedImageAndNavigation.swift；EmbyImageDiskCache.swift；EmbyServerSharedV3.swift | decoded pool64项/96MiB；已有后台ImageIO；私有loader/decoder访问范围、取消与真实URL/key |
| 页面快照 | EmbyPagePersistentCache.swift；Library/Favorites model初始化与persistSnapshot调用 | 当前 Library/Favorites 同步快照恢复；Library同步完整快照写出，cached-first/write-through顺序 |
| 首页 | EmbyHomeCoreV3 / RowsV3 / ModelV3、HeroScrollState / ScrollOffsetObserver / RefreshControlStylerV3 | 元数据恢复时机、单一纵向偏移、Hero footprint、刷新/回顶、已有轮播资源 |
| 搜索 | EmbySearchExperienceV3 / RecommendationPreloader | 单服务器/多服务器路径、18/9+6、现有recommendationPosterImages、离开Dock重置 |
| 详情叶子与人物 | EmbyMediaDetailView中的FilterResults；EmbyPersonMediaView | 仅迁移叶子结果；genre/tag与PersonId；不改详情Hero/播放 |
| 外围 | ServerDock、SharedImageAndNavigation中的PosterDetailLink及Episode目的地 | 安全区/键盘/内容避让、系统push/pop、Episode→Series等真实路由 |
| 验证与打包 | Tests/ServerDockRegression、scripts/check_server_dock_refactor.py、实际选用workflow/project.yml | 测试使用真实源码；旧严格文本checker的适用范围；实际候选版本和MinOS |

缓存准备职责可能需要从现有private loader/decoder提取可复用能力；先确认访问范围再修改，不另写同功能解码器。磁盘缓存继续只有原actor；播放 Session Cache 是另一个冻结范围，不在本计划中。

## 4. 必须在实现前确定的展示合同

这些是建议职责，不是声称已有同名类型/API。具体文件命名由实施会话按源码组织确定，新增范围须有实际消费者。

| 合同 | 唯一所有者 / 输入输出 |
|---|---|
| 业务数据、分页与持久化 | 现有页面model。包括query、sort、nextStartIndex、hasMore、去重和请求代次 |
| 展示适配 | 页面将已加载item映射为来源明确的稳定ID、显示字段、图片规格、内容类型和结构变化；不复制业务分页 |
| 完整滚动宿主 | 原生collection/controller持有滚动、固定几何、cell复用、预取、图片目标项呈现；通过轻量宿主接回SwiftUI页面 |
| 图片准备协调 | 一套共享in-flight、消费者订阅、优先级及有限并发；复用现有decoded/disk池，不另设缓存权威 |
| 首屏资源需求 | 所属页面持有有限prepared引用，计入共享预算；远处滚动不清掉首屏，页面需求结束时释放 |
| 选择和导航 | 页面适配器将点击交给既有路由；系统负责push/pop，单一selection/link所有者 |

item身份需包括真实来源；页面身份包括用户/服务器或实际route scope、query/filter/tab/sort。图片请求还区分真实tag、imageType/index、请求URL和像素规格。沿用现有缓存key/route合同，不顺手做稳定服务器ID缓存迁移。

事件分为首次内容、追加item、真实字段更新、结构替换与图片完成。图片完成不得发布整个业务数组或应用全列表snapshot。普通字段变化只更新受影响item；追加不重建旧item。全量结构更新只用于真实刷新/筛选等事件，避免每次滚动或SwiftUI update扫描5000项。异步结果同时校验页面代次与当前cell绑定请求，不仅比较数组下标。

UIKit创建/复用/布局在主线程；文件读取、图片解码、JSON对象构造/序列化在明确后台执行上下文。写了async/actor并不证明CPU重活离开MainActor；实际记录执行线程。图库任务并发有界，不为每个影片长期保留Task。

## 5. 补充的生命周期与异常合同

| 场景 | 实施要求 |
|---|---|
| 首次图下载未完成 | 最终尺寸灰色海报框 + 已有片名/真实字段；图到达只替换图，不改卡片高度 |
| 磁盘暖、内存冷 | 导航/快照恢复后尽早表达首屏需求，后台读取/解码；不主线程读图，不等待整库准备 |
| 缓存元数据恢复 | 已发现Library/Favorites初始化同步读盘/解析；P1必须测恢复耗时，并在原model/cache所有权内规划后台恢复与发布顺序。先缓存后实时刷新，避免异步旧快照覆盖新数据。不能为了异步化先清空已显示数据 |
| 同页详情返回 | 原业务model/列表内容与位置继续有效；重新绑定不会重新下载已缓存图。页面暂时遮挡与真正销毁分开处理 |
| 深处回顶 | 不fetch第一页、不refresh、不重置分页、不整页loading；首屏prepared图直接消费，当前位置需求随后更新 |
| 刷新/排序/查询变化 | 保留原业务语义；确需换序时更新结构/首屏集合，旧代次数据与图片不得覆盖新状态 |
| 图片tag或缓存清理 | tag/规格变化走新的真实请求身份；现有清理入口影响正确图片需求。不新增轮询或缓存有效期制度 |
| 快速离屏/反向/共享图 | 撤掉无消费者的预取；一个订阅取消不终止其他可见消费者仍需要的任务。可见绑定即使无预取也能正常加载 |
| 缺图/请求失败 | 保留片名与固定框；保留现有失败语义，不造自动重试链。追加失败不能清掉已有列表 |
| 内存压力/后台恢复 | 先释放可丢弃资源，回前台提前重建当前需求；与正常暖缓存验收分开记录。不声称内存被系统回收后仍绝对零占位 |
| 首屏与页面堆栈 | 当前浏览页及明确需要即时返回的页保留需求，按整体预算限制；不能所有历史查询各自永久pin首屏 |
| 退出Search/切换用户来源 | 沿用已验收生命周期并释放所属订阅；已完成缓存仍可复用，但旧回调不能更新新页面 |

当前NSCache64项/96MiB是建议起始配置，不是App硬上限。实际峰值要包含可见图、首屏强引用、in-flight临时缓冲和轮播资源，按图片对象去重，避免同一图多个引用重复估算，也不能漏掉缓存外引用。窗口从可见区+有限邻近区开始测，不随访问影片数增长。

暖重启直接显示的重点是元数据和首屏图的真实准备时机。只增加更大缓存、预热未知全库、拖延导航动画或加等待所有海报的门禁，都不能替代此合同。搜索/人物结果没有Library的既有快照合同，不自动添加跨进程查询恢复。

## 6. 单一滚动宿主与用户交互

通用三列页接入的是完整纵向宿主，不能在旧纵向ScrollView里再塞一个可纵向滚动的collection。库tab条/系统标题工具栏仍由原页面管理；列表标题、初始/追加loading、空态/错误/footer属于同一个滚动内容布局或原来的固定区域。

G15推荐网格嵌在搜索落地页内：搜索历史、推荐标题/网格/footer组成一个纵向展示宿主；不能只把网格片段换成原生内滚动列表。H03收藏根与H04多服务器结果根同理，通过section适配组织内容，搜索输入框、键盘/Dock生命周期仍由原页面负责。

状态栏回顶只交给当前最上层可见页面的主纵向滚动视图。横向行关闭scrollsToTop；隐藏但常驻的Home、被push遮挡的列表也要按既有活跃/导航生命周期关闭竞争响应，恢复可见时再启用。无需新增全局滚动管理器。

保留原生拖动/惯性/bounce及侧滑返回。原生cell点击要验证：拖动后松手不误开详情，多指操作不多开，正常单次点击保持系统入口动画；沿用真实点击/导航合同，不机械复制SwiftUI专用触摸桥或新增超时补偿器。Home竖向拖动、横向行拖动、轮播拖动和导航返回分别保有原来的权威。

颜色、圆角、名称/年份、角标、进度、左右/行间距、文字截断保持真实原样。宽度/方向/字体环境发生真实布局变化时才重算并更新图片规格；图片到达不触发尺寸失效。访问性标签、焦点与实际可点击区域不得因原生化丢失。

## 7. 分阶段开发与通过条件

P0已完成；P1/P2代码和生产源码自动回归已完成，Release/IPA核验已完成，目标机A/B待完成。P3–P6未开始。以下阶段门槛仍有效；自动验证不代替真机性能验收。

| 阶段 | 范围和产物 | 进入下一阶段前的条件 |
|---|---|---|
| P0 基线/隔离 | 固定最新产品基线，记录同Work ID的新分支身份及历史提取范围；确认入口/真实字段和依赖 | 无身份或源码冲突；已有轮播/Dock/缓存/Search/P0保护边界清楚 |
| P1 已验证修正与恢复路径 | 最小移植有序后台Library快照构建/写盘；核查cached-first恢复读盘/解析时机与顺序；为原生适配保留常驻导航激活合同 | 后台证据、写入有序、刷新失败保留缓存、缓存frontier恢复；无旧快照覆盖新状态。相关冻结合同不变 |
| P2 Library.items最小闭环 | 完整原生网格+原生cell+共享图片准备/订阅+首屏需求+目标项更新+模型分页事件 | 实际源码测试、iOS15编译、冷图/磁盘暖/内存暖/分页/回顶/导航可测；形成首个身份核验IPA，交目标机A/B |
| P3 其余Library适配 | G02–G08：预告/合集/库收藏/类别封面与结果/递归文件夹 | 共用核心；60分页和不分页区别正确；类型/路由/父子返回正确 |
| P4 所有其他三列入口 | G09–G15：收藏四类型、详情过滤、人物、搜索直接/历史/更多、推荐。G15同时接正确搜索落地滚动宿主 | 分页/来源/生命周期无改写；去掉推荐无上限第二图片pin；每条入口有接入和测试记录 |
| P5 首页及其余横向区 | H01–H04使用section/横向适配，首页接现有Hero bridge/刷新/回顶/Dock | 单一纵向宿主和高频桥；首屏/横向预取可靠；Build293轮播和Build294Dock回归通过 |
| P6 最终候选与验收 | 合并最新目标影响核查、真实源码测试、唯一版本Build、exact-source Release CI/IPA | 包/源码/Artifact/MinOS身份齐全；完整真机矩阵完成后才标稳定，仍未验证项明确列出 |

P2是有意的小范围真机比较：原生容器历史上不是单独充分条件，不能未检查真实尾部就批量复制。新会话按授权推进到P2可测试IPA后，因需要用户真机结果才正常交接；若用户明确要求一次推进更大范围，记录尚未验收的风险与范围，不把未测P2说成已通过。后续各阶段可合并合理候选，避免每个小改动都启动Actions。

H05冻结详情横向区只作为资源/回归关联审计；本轮不自动改其宿主。旧V1/V2/旧Search、选集、剧照和服务器网格不纳入产品替换。任何扩大范围都需真实需求和明确记录。

## 8. 有意义的自动验证

新增最小测试覆盖共享合同，使用实际生产逻辑和可控异步完成顺序，避免复制一套算法再测试副本：
- cell A→B复用后，A延迟图不能贴到B；同item改tag/规格后旧图不能覆盖；跨服务器相同item.id隔离。
- 可见/预取请求合并，取消一个订阅后另一个仍能完成；无消费者任务释放；窗口/首屏及in-flight数量不随5000个已访问item增长。
- 图片完成只更新对应绑定，不触发数据/结构重载；同ID同字段无重新配置，追加保持旧ID/几何与业务frontier。
- 有序快照写出、过期恢复结果不能覆盖新数据、失败不覆盖上一有效快照；以真实生产cache/model边界验证。
- 原生几何和内容类型、点击目的地合同；首屏集合随真实布局/query更新，深处回顶不触发model reload。

这些测试不证明120FPS。其余功能用窄范围源码/构建检查和目标机矩阵验证。现有Tests/ServerDockRegression的轮播/Dock生产源码测试继续运行；其stub不代替完整首页集成测试。

旧scripts/check_server_dock_refactor.py包含某些页面文本必须完全等于旧Dock转换结果的假设。合法海报改动后先核对适用范围：保留Dock真实几何/状态断言和冻结源码保护，针对海报允许改动补明确边界，不能将预期旧页面完全不变的脚本机械当新功能失败，也不能删除/放宽所有断言换取通过。Build283专用checker当前不在main，不能声称已经在最新基线运行。

## 9. 真机矩阵与性能判定

目标 iPhone15ProMax / iOS17.0，正常120Hz环境、录屏关闭时采性能；录屏只辅助视觉定位。记录实际候选Build/source、缓存状态、热/低电量状态和样本时长。比较同一库、排序、数据规模与操作；不把冷网络与内存暖数据混比。

| 场景 | 必须观察的结果 |
|---|---|
| 首次无图、固定数据滑动 | 框+片名立即稳定出现；普通拖动/惯性/快速反向无抖动、误点 |
| 磁盘暖/内存冷、内存暖往返 | 不重复网络获取；不明显闪占位；旧cell不显示错图 |
| 60→多页追加与同规模固定数据 | 分别定位插入、持久化与固有显示尾部；追加不跳位置、失败不清已有数据 |
| 约第2000项→状态栏/产品回顶 | 首屏已准备图直接呈现，不重拉第一页、不整页loading、不人工offset补偿 |
| 暖磁盘强退重启→库/首页 | 元数据与首屏准备连续，无明显重新加载断点；记录cache恢复/读图/解码/首次呈现时间 |
| 详情push/pop、侧滑返回及多级文件夹 | 系统入口动画正常、返回位置/数据保留；快速滚动不误触，人物/Episode目的地正确 |
| 刷新/排序/tab/query/tag/服务器切换 | 不贴旧图、不串数据、不改变既有查询重置和分页规则 |
| Home纵横混合与轮播交互 | Hero位置/拉伸/共用底色/刷新/回顶不变，快速轮播接管无闪烁，横向行无手势冲突 |
| Dock/Search键盘与切页 | Dock位置和内容避让不变；推荐9/+6、详情返回保留、离开Search重置不变 |
| 长时间往返、内存压力、后台恢复 | 资源无持续增长，释放与恢复有证据；压力场景单独列结果，不隐藏正常暖缓存不达标 |

5000是规模验收：使用真实大库或明确注明的固定元数据fixture，已加载约2000项才测试回顶。不为制造测试入口改成全5000空槽/随机范围加载。若真机库规模不足，明确记录大规模项待测；小库通过不能替代。

收集p50/p95/p99/max及>=16.7/25/33.3ms事件数/频率，按120Hz约8.33ms帧预算分析；平均display-link Hz不是已呈现FPS。用有界诊断/signpost关联cell prepare/configure/layout、decode/adopt、插入事务、JSON/写盘及必要的Animation Hitches证据；不逐帧字符串刷日志造成测量长帧。

内区contentOffset停顿/反向与bounds、手指实际方向、bounce、refresh、程序回顶分别标识。静止时零位移正常；需要排查的是运动过程异常中断。即便offset单调，也可能是提交/渲染缺帧，不能靠强行修offset掩盖。

通过标准：目标场景无可感知抖动/加载断点；稳定维持目标刷新率的证据与长帧尾部改善一致；无可复现由本任务cell/adopt/分页/持久化造成的显著长帧；保护功能与资源预算通过。定量结果必须如实报告，不设未经测量的“所有帧绝不超8.33ms”承诺；相关可复现>=25/33.3ms事件须定位，未解决不得写“彻底解决”。

## 10. 交付、回退和新会话状态记录

每个候选保留唯一version/Build/candidate、产品source/base/head、PR、CI control/source/run/job、Artifact id/digest、IPA与源码包SHA、Bundle/Info.plist/Mach-O MinOS。使用实际存在的构建能力做exact-source guard；旧workflow文件名/内部历史版本字符串不是新候选身份，不原样拿旧包替代。最终交付前查询目标branch推进与冲突并重验受影响范围。

提交以阶段拆分，使Library核心、其他适配、Home集成可独立审查和回退；不增双实现运行时开关或隐藏fallback。回退只撤销本任务造成的对应阶段变更，保留已验收轮播/Dock及其他任务代码；不能重置main到旧Build283。合并前保持原生导航与缓存合同；有真实回归先定位所属阶段。

checkpoint每个有独立续接价值的里程碑更新：
- 已完成/验证/待办与当前阶段；逐入口状态，不靠“共享组件已完成”总括。
- 新branch/PR/base/head与候选身份；已核实的CI/包记录，用户真机原话和日志范围。
- 窗口/并发/驻留实测参数及为何选择；尚未满足的暖启动/回顶/长帧项目。
- Next exact action指向下一项具体实现、构建或用户真机测试。
同步PROJECT_STATE/MODULE_STATUS/TECHNICAL_DECISIONS；有新构建才更新BUILD_TEST_INDEX。没有代码、CI、真机结果时不制造完成标记。全部范围验收后才收尾该任务，保留未测项目不能写全局稳定。

## 11. 可复制的新会话启动指令

```text
当前为开发会话，仓库 white-shark-ssw/emby-playerlab，继续 DEV-poster-grid-smoothness。
读取仓库 AGENTS.md、START_HERE 和当前权威状态，再读取该任务 checkpoint、
POSTER_PRESENTATION_DESIGN.md、POSTER_IMPLEMENTATION_PLAN.md、POSTER_ENTRY_INDEX.md。
按计划执行海报墙重构，先完成 Library.items 最小闭环并连续推进到可测试 IPA。
以最新已验收整体基线开发，明确记录旧 Build283 分支身份迁移，
保护 Build293 轮播、Build294 Dock、Search/页面缓存、原生导航和 iOS15/P0。
首屏准备、暖缓存重启和约第2000项回顶必须作为验收合同。
不要新建重叠任务，不要只换容器，不要在普通中间节点等待“继续”。
```

## Current execution — 2026-10-06

P0身份迁移完成；P1后台Library恢复/有序持久化和P2 Library.items完整原生宿主/固定cell/共享准备/首屏需求/目标项更新已实现。8项生产海报回归和18项Dock/轮播回归通过并按依赖逐字核对保留；准确源码、CI和交付身份由当前任务checkpoint及BUILD_TEST_INDEX记录。P2可测试IPA已交付并独立核验，目标机验收待完成；P3–P6和其余入口未开始。Build294仍为已验收整体基线。

## Build296 /0.15.29 — Library inactive-refresh inertia correction and bounded tail diagnostics (2026-10-07 Asia/Shanghai)

- Task DEV-poster-grid-smoothness; G01 Library.items only; same perf/poster-wall-library-build295 /Draft PR292. Product exact source **bfa5b56ee1e5737cf0fff9a2b7234505e8469dfb**; baseline03d1bad260666c3f38ae3913d6828f393690673e (accepted overall294/Dock294, inherited carousel293). Main changes before final packaging were project documents only.
- User feedback2026-10-06 23:04: refactor relatively successful, FPS maintains a high level; asks to improve long frames. Qualitative positive Build295 result, not full P2 acceptance or presented120FPS measurement.
- Actual native fast-swipe/controlled metadata test reproduced on iOS18.5: deceleration stays1 through append; inactive endRefreshing synchronously triggers deceleration-end0. Source5187b590e51770f05fd393709cbd66ddddc589b6, run37488102803/job112353349125. Actual count120, content expanded, offset did not jump. This is simulator causal evidence, not independent proof of the earlier video's iOS17 timing/root cause.
- Small owner fix: call existing endRefreshing only when loading finishes AND UIRefreshControl.isRefreshing is true. Real pull-refresh completion preserved. No inertia/offset/footer/page-size/load-ahead/image-budget changes, placeholder-total slots, timers or retries.
- Bound diagnostics:64 numeric frames, including first stationary frame after motion; native drag/deceleration endpoints; count/revision/loading/footer/geometry/legal boundary; append begin/completion; real refresh; model request/response/publication/persistence/finish. Wall4096/model2048 event caps. No per-frame strings. SourceVersion/package Build logged at wall creation; no new source URL/user ID traces.
- Exact-source CI **[run37490702186](https://github.com/white-shark-ssw/emby-playerlab/actions/runs/37490702186) /job112362875963 success**; control **b904829dc6e24186e35c5cc595bf2d71893094f3**, branch ci/build296-poster-wall-motion-20261006, workflow .github/workflows/build296-poster-wall-motion.yml. **12 actual production-source units/0 failures +1 real native-gesture UI test/0 failures**. Actual18 native Dock/carousel tests remain byte-guarded against source20d52f7706d9abf914facf50359df8ccb336fd09/run37474393518/job112306217313; original logs retained. Not described as rerun.
- Release compile, scope/whitespace/Frozen guards, package identity and MinOS audit passed. Artifact **[OnePlayer-0.15.29-build296-poster-wall-motion-diagnostics](https://github.com/white-shark-ssw/emby-playerlab/actions/runs/37490702186/artifacts/11425443691)**, ID **11425443691**, ZIP digest/downloaded SHA256 **efcbbf9ac1de1cd175ba0603e4dcc7f156a4adc46a8cd79ba42caaaac7cfdabd**.
- IPA `OnePlayer-0.15.29-build296-poster-wall-motion-diagnostics-unsigned.ipa`, **18724844 bytes**, SHA256 **c9379f6a592feece2a158f9ee8bf2a29bd60f28409b5c607b0ac56fc4639af1d**. Exact source ZIP SHA256 **d4fc1ab9015750870e013da09cfbc8cf82b7be73d95c6322dcf912c2a68c959b**; git archive comment equals package source.
- Independent verification: ZIP integrity/checksums, bundle **com.embyplayerlab.app**, version **0.15.29**, Build **296**, Info MinOS **15.0**, arm64 Mach-O MinOS **15.0.0**, CADisableMinimumFrameDurationOnPhone=true; embedded compatibility audit **OK**. Downloadable IPA saved separately; no temporary signed URL in project docs.
- Earlier CI: initial named/latest simulator destination failed before tests, corrected to actual iOS18.5 UDID; native UI failures exposed the cause; first refresh/control-request unit fixture failures were corrected by empty unit-host isolation, actual window attachment and bounded10s test-only boundary wait. Same-source run37490079849 was cancelled after12 unit passes when a duplicate same-control push run appeared; final run above completed the entire pipeline. No failed/cancelled run is claimed as success.
- **Code written /12+1 regressions passed /exact-source Release CI passed /IPA independently verified /Build296 target-device pending /task Active /not stable /not merged.** P2 awaits iPhone15ProMax/iOS17 initial-load inertia and long-frame log/video, plus remaining cache/navigation/deep return-top matrix. G02–G15/H01–H04 unstarted and gated; accepted overall baseline294 remains. Protect293carousel/294Dock/Search256/P0.
