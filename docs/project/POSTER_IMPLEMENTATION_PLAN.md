# 海报墙重构开发计划

_2026-10-08。P0完成，P1/P2 Library.items试点已实现并通过生产源码回归；Build299 Release/IPA已核验。重启前后/1560缓存全应用/1560与1620深处回顶有正向真机日志及用户无明显卡顿反馈，本轮G01长帧调优结束；未覆盖的大规模/交互/资源项目仍列入P6，其他宿主未迁移，P3–P6保留阶段门槛。_

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

P0已完成；P1/P2代码和生产源码自动回归已完成，Release/IPA核验已完成，目标机A/B待完成。用户已验收当前G01覆盖并授权继续；P3 G02–G08原生适配、实际源码回归、Release/IPA独立核验已完成，新入口待真机验证。P4 G09–G14已完成代码/55项新回归/Release及核验IPA，真机待验证；G15/P5/P6仍待推进。以下阶段门槛仍有效；自动验证不代替真机性能验收。

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

## Build301 partial P4 G09–G14 implementation — pending macOS validation

OnePlayer0.15.34 /Build301 /poster-results-adapters; same task/feature/Draft PR292. Shared EmbyPosterResultsPage owns one native vertical wall and one resident system selection/link; original models still own60 Favorites/Person/filter and18 Search paging, raw frontier, dedup and error policy. Explicit Person own-image/name-only and plain-media preferred-image/name/year-only variants preserve original fields/heights (24/40); standard media42 unchanged. Original missing PersonId message, Episode destination, actual selected server client/term and Dock clearance retained. No new pull-to-refresh on previously non-refreshable leaves. G01/P3 source, Favorites preview, Search root/direct/history/multi-server/recommendations and detail source outside the filter leaf are byte-guarded unchanged. P0/carousel/Dock/root Search lifetime/image budgets unchanged.

Production-source extraction/leaf scope guards passed on Linux; new9 query/frontier/variant/native units and2 table-driven native UI tests are written but not yet run (planned37 poster units +10 detail units +8 native UI;18 Dock/carousel retained exact-input evidence). Terminal detail is a fixture, production destination bytes protected. CI/Release/IPA and all301 real-device evidence pending. G15 recommendation single landing host and unbounded second pin removal explicitly pending, along with P5 and broad P6. No301 FPS/long-frame or stable claim.


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

## Build303 P5 implementation — macOS validation pending

H01–H04 now use shared EmbyPosterSections native vertical host and reusable native horizontal rows. Standard EmbyPosterCell is unchanged; person own-image/name-only, landscape212x120/subtitle/progress and library164x92/title variants preserve existing URL widths440/person-scale/650/480 and page source. Home Hero remains unchanged in one finite top host; original offset/owned-refresh coordinators attach directly to native vertical collection, original hero-height/tracking clamp/top0.2/Dock clearance kept. Existing page-owned native links retain Library/media/Person/more/server-term destinations; Favorites previews still cap20. Metadata/model/API/provider/cache source unchanged. Horizontal offsets are keyed by section+route/user, same publications do not reload cards; images adopt per binding. Page-wide prefetch12, shared firstScreen24/tasks4/decoded64+96MiB retained. Bounded diagnostic frames/cell/apply costs are observers only, not presented FPS.

Linux P5 scope guard, demand URL/detail guards, Python extraction/compilation passed. Eight actual-native unit cases and two native UI cases written (planned52poster+10detail+12UI+18freshDock/carousel=92); full app compilation and tests await macOS. Generic section UI uses fixed metadata/explicit Hero visual fixture; Favorites root/model and Search/Library production adapters compile. No303 CI/IPA/device/performance pass claim yet. Next: exact-source CI with unchanged293/294 source protection, Release/iOS15/identity/package; retrieve/independently verify actual IPA and hand off. P6/302-device/cache decoupling limits remain.

## Build303 exact-source CI in progress

Product source **1fdca1f8f2765bd1660330945e167dedecf5e418**, CI control **69121d5b5156745b91e86299f86ce1916e1ac8c0**, branch ci/build303-poster-sections-20261008, workflow build303-poster-sections.yml, dedicated run **37751337210** /job113225034414 in progress. Source scope20paths. Planned92 fresh tests (52+10+12+18); source compilation/tests/Release/IPA success not yet claimed. Next action: inspect this job's actual completed steps/logs, correct only proven failures, then verify the actual303 source/IPA/Artifact/MinOS and hand off. Main documentation only; feature/runtime not merged.302 device/P6/cache identity limitations unchanged.

## Build303 native unit milestone — 80 fresh regressions passed

Dedicated run37751337210/job113225034414 on control69121d5b5156745b91e86299f86ce1916e1ac8c0 against exact product1fdca1f8f2765bd1660330945e167dedecf5e418: source/scope/whitespace/iOS15 guards passed; fresh18 production Dock/carousel +10 detail/cache +52 poster/adapter/Search/P5 units completed/success (80 total). Includes original variants/specs/source identity, same publication/geometry/request-memo/native return, row reuse/offset/latest callback, query replacement, shared12prefetch cap, first-screen/task cap, actual Home offset/owned-refresh coordinators and wide-cell stale-image binding. Twelve native UI tests in progress; full Release/package/IPA/device not yet passed. Continue this actual job through UI/Release/identity/package and verified file handoff.

## Build303 all92 fresh regressions passed; Release/package next

Run37751337210/job113225034414 completed all test steps successfully on exact product1fdca1f8f2765bd1660330945e167dedecf5e418 /control69121d5b5156745b91e86299f86ce1916e1ac8c0:52poster/adapter/Search/P5 +10detail/cache +12native UI +18freshDock/carousel =92,0failures. New native UI cases cover reusable vertical/horizontal mixed layout, deep native detail return and product top command; actual Favorites root preview→detail,Movie more→grid and Person→works. Original ten Library/P3/P4/Search/native inertia/pop cases rerun. Section UI's Hero visual is explicitly fixed fixture; Home production root/model/Carousel source awaits full app Release and actual device coverage, not implied by fixture. Full original Home viewport/nativeCarousel and bridge sources remain byte-guarded; actual offset/owned-refresh coordinators passed native units. Release/dependencies in progress; no actual303 IPA yet. Continue directly through Release, package and independent source/Artifact/IPA/MinOS identity check.

## Build303 refresh completion correction — final-source validation pending

First source1fdca1f8f2765bd1660330945e167dedecf5e418/control69121d5b5156745b91e86299f86ce1916e1ac8c0/run37751337210/job113225034414 completed92 tests and full Release/package successfully, but is NOT the delivery candidate. Source review found normal Home/Library suggestions' initial-spinner-only flags could prematurely finish refresh with existing metadata. Native section refresh now ends only from the original page async task completion (normal Home/suggestions/Favorites); immersive Home still uses the unchanged owned-refresh coordinator. Added actual native completion unit and physical pull UI regression. Source fixed locally; final macOS validation pending. Planned final84 fresh cases:53poster+10detail+18Dock/carousel+3P5UI. Earlier10 unchanged Library/P3/P4/Search native UI cases retained from the first source, guarded by unchanged original test body and runtime scope/source checks; not94 freshly rerun. Same reserved303/0.15.36, no304. No first candidate IPA handed off, no device acceptance/performance claim. Continue exact-source Release/package and independent actual IPA check.

## Build303 corrected exact-source run started

Final corrected product **0b5ce25bcec0a4d0240891913ad17114b02cf10e**, control **30c558e7984c682f22e92e13a3d6104ea27b7579**, run **37754814214** on ci/build303-poster-sections-20261008. First92-pass/Release source1fdca1f8f2765bd1660330945e167dedecf5e418 is superseded before delivery for refresh completion; its ten unchanged original UI tests retained with full raw log and exact original test/helper/source guards. Final planned84 fresh (53poster+10detail+18Dock/carousel+3P5UI); no final-source pass or actual IPA claim yet. Next inspect actual job, correct concrete failure, complete Release/identity/iOS15/package and independently verify/save actual final303 IPA. Main remains documentation-only; PR292 Draft/open/unmerged, accepted294, P6/device/cache limits unchanged.

## Build303 final-source native unit milestone — 81 fresh passed

Final source0b5ce25bcec0a4d0240891913ad17114b02cf10e/control30c558e7984c682f22e92e13a3d6104ea27b7579/run37754814214/job113236645278: exact source/scope/retained-input/iOS15 guards,18freshDock/carousel+10detail/cache+53poster/adapter/Search/P5 units completed/success (81fresh). New existing-content refresh completion unit passes. Three selected P5 native UI cases in progress; original ten unrelated UI cases retain raw first-run evidence and exact test/helper/source guards, not rerun. Full Release/identity/MinOS/package/actualIPA verification pending. Next: continue this exact run through UI and package, recover local execution connection for downloaded actual IPA verification and file handoff; no first-source IPA delivery or device/Stable/merge claim.
