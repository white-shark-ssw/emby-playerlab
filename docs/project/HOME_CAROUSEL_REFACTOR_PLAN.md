# 首页轮播需求复核与重构设计

> Latest controlling state (2026-10-06): **Completed / accepted / frozen at OnePlayer0.15.26/Build293**. User confirms testing has no remaining issue and authorizes closeout. Tested exactfa8ff44ff4a5384fd4603a64b33354f941764a8c; PR#289 merged atf0a737519801ff55f18e31f9bdcf5f83c9097c17. Native10/0, exact-source CI/IPA/MinOS15 verified. Build292120FPS is user-reported; no new numerical trace. Preserve resident pages, one UIKit/runtime authority, actual-position/opacity/base-color handoff, retained outgoing artwork and shared lower-edge floor. Other Frozen/P0 contracts preserved. Historical pending/unimplemented states below are superseded. Reopen only on new regression evidence.


> Current implementation status (2026-10-06): Build289/290 were implemented and device rejected. Build291 source dbeaa9d3472c85a5c238598da3aac41d8e49f43c corrects the proved transform/frame and Dock-extent violations; native regressions, exact-source CI and IPA verification passed, target-device acceptance pending. The earlier pre-implementation statements below are historical planning context. Live identity and next action: [acceptance record](BUILD_TEST_INDEX.md).


更新：2026-10-05。Work ID：`DEV-home-carousel-drag-smoothness`。

具体开发顺序、文件职责、阶段出口和交接验收见 [HOME_CAROUSEL_DEVELOPMENT_PLAN.md](HOME_CAROUSEL_DEVELOPMENT_PLAN.md)。本文件保留需求/源码/参考证据；历史候选中的开放选择以后面的已选方向及开发计划为准。

## 状态与证据

本文件是需求与实现边界设计，尚无重构代码、CI 或新 IPA。用户已同意先完整规划需求，再进行重构，并要求从设计上排除部分容易产生长帧的工作。用户明确选择：松手收尾动画期间再次横滑，应**立即接管，从当前可见位置继续**。

Build286 产品分支 `perf/home-carousel-progress-scope-build286`，PR #289，head `7e7b2ec944f5c0e74bc291e37683f1529e3d46b4`。Build288 精确源码 `ce565996e37dcb750117c9de4607b23b673edce3` 的 HomeCore / Hero / HeroScrollState / CarouselState / Interaction / ProgressPresentation / CadenceDiagnostics blobs 与 Build286 相同。用户确认该轮播仍滑动掉帧、无法持续达到期望的120帧、竞品体验差距大。这是定性真机结论，没有新的数值帧轨迹；不能推导“完全没有改善”。

真实代码已核对：`EmbyHomeCoreV3.swift`、`EmbyHomeHeroV3.swift`、三个轮播状态/交互/进度呈现文件、`EmbyHomeCarouselCadenceDiagnosticsV3.swift`、`EmbyHomeModelV3.swift`、`EmbySharedImageAndNavigation.swift`、`EmbyImageDiskCache.swift`、`DiagnosticsLogger.swift`。

## 需求与验收矩阵

| 领域 | 产品需求 | 当前依据 / 处理 |
|---|---|---|
| 方向与起步 | 横滑轮播、纵滑首页；慢拖细腻跟手，反向拖动连续 | 保留已验证的单 UIKit 获取方向/真实样本起步基础，不重跑猜测式手势优化 |
| 连续操作 | 收尾期间新横滑立即接管，当前位置连续，无先跳到终点 | 本轮用户明确确认；现有 `shouldBeginNativeCarouselDrag` 在 toID 非空且非 dragging 时拒绝新横滑，需要明确替换这一行为 |
| 分页 | 全宽前景页距，首尾循环；正常拖动>=0.28或同方向最近真实移动速度>=500pt/s提交 | 保留 Build241 产品合同；不猜竞品参数 |
| 松手 | 正常提交0.22s / 取消0.18s easeOut；持续高刷新请求覆盖收尾 | 保留未被推翻的行为；接管须停止旧动画并从实际可见状态转交，不能用已到终点的模型值跳变 |
| 自动轮播 | 保留激活条件、6s已落定间隔、0.62s easeInOut和单个已有调度来源 | 当前源码的行为；不得把“惯性期间暂停自动轮播”的旧退让方案当作根本解决 |
| 点击与导航 | 普通轻触进入当前项目详情；拖动/未落定抑制误触；系统拥有导航 | 保留真实入口和已有抑制语义；不创建第二导航 owner |
| 外观 | 图片渐变、全宽前景横移、logo/标题/评分/年份/类型/概述、明暗文字、渐变遮罩；最新用户允许下方底色衔接 | Hero与前景视觉、foreground compositing和白闪修正保留；全屏blur30不再强制，参见后续底色候选 |
| 首页联动 | 上下滚动时裁剪/拉伸/定位、沉浸背景、下拉刷新仍正常 | 原有Hero纵向几何合同；不让横向每次进度发布触发整页更新 |
| 数据 | Emby/HomeModel保持内容权威；保留设置、cached-first与live刷新 | 当前live轮播最多6项；内容/顺序/资源绑定只在接受内容变化时重算 |
| 图片 | 现有清晰Hero前/中/后3槽是历史基础；最新少量全页常驻候选需内存/首进验证 | 资源准备独立于运动；不降低清晰度；非就绪资源遵循现有异步占位，不等待网络阻塞手势 |
| 生命周期 | 离开首页停止轮播活动；返回/内容替换/取消可恢复正确状态 | 使用现有Home激活与内容生命周期；不新增watchdog/retry兜底 |
| 性能 | iPhone15ProMax/iOS17正常操作持续流畅，慢拖/快甩/反向/自动×纵向惯性均验收 | 真机验证才是结论；120Hz约8.33ms只是显示周期，回调频率不等于最终呈现 |
| 兼容及保护 | MinOS15；Player/MPV/PiP/Transport/Cache/EmbySession与客户端直连不受影响 | Frozen/P0保持；不提升最低系统版本 |

## 从设计上禁止进入运动路径的工作

“运动路径”包括手指拖动、松手收尾、自动切换，以及它们与首页纵向滚动重叠的时段。不能只把成本从手指跟随挪到收尾、自动轮播或滚动惯性期间。

| 工作 | 允许的阶段 / 边界 | 运动路径要求 |
|---|---|---|
| 内容集合构建、选邻页、查找URL、字符串格式化 | 接受内容/资源配置变化时建立绑定 | 不在每个进度回调重新遍历各媒体库和生成轮播列表；一次手势保留固定内容身份 |
| 文件IO、JSON、网络等待、图片缩放/解码 | 使用已有后台资源链；准备结果由轮播适配层消费 | 不同步等待、不在主线程补做；后台已解码不代表首次图层提交必然免费 |
| 明暗分析、尺寸/前景资料计算 | 图片身份/几何/外观变化时准备 | 不因hero/persistent/preload多个角色重复在运动回调计算；不能让结果更新使整页同步重建 |
| 视图/图层创建、销毁、布局和文字重排 | 内容/尺寸变化时准备有界槽位 | 单次运动只改已存在节点的位置/透明度；邻页轮换不能无界堆积，也不能在连续接管时集中重活 |
| 图层合成 | 建立稳定的遮罩、背景和前景合成关系 | 不动态堆叠快照、强制整页栅格化或每次进度制造额外离屏层；保留视觉效果后测render成本 |
| 图片回调发布 | 准备结果按现有item/URL身份验证，只更新相应资源槽 | 回调不改轮播选择、不启动自动动画、不让不可见角色扇出整树更新 |
| 日志与统计 | 已有后台日志落盘；阶段汇总和有界统计 | 不在逐帧回调格式化大量字符串/排序样本；保留播放诊断，不擅自更改共享logger |
| 动画完成 | 同一个过渡owner拥有取消、完成、接管 | 旧完成回调必须失效；不得靠固定延迟重新纠正新状态 |

后台任务的准备完成时间不能变成手势开始的等待条件。已加载资源及时展示；冷启动仍允许异步占位，具体占位策略不新增行为。在持续操作下也不能无限等待“空闲”：预准备的有界槽位和异步结果应支持连续循环，而不是用暂停自动轮播、积压更新或一次性排空工作来换短时指标。

## 当前源码事实，避免重复误诊

1. `EmbyCachedImageLoader` 已通过 `Task.detached(.utility)` 调用ImageIO thumbnail解码，并用 `kCGImageSourceShouldCacheImmediately`；磁盘缓存是独立actor。不能声称所有图片解码都在主线程，也不能无依据替换全局解码器。其UIImage回退路径和首次提交成本如需修改，应先取得具体证据。
2. `DiagnosticsLogger` 已有utility队列负责格式化/落盘。前台仍存在消息构造和有限入队，不等于日志写盘当前阻塞主线程。
3. Hero / persistent / preload各自调用 `updateCarouselImageMetrics`；其中同步做 `EmbyImageContrastAnalyzer.prefersLightForeground`，包含CoreImage average/render并可能更新Home的尺寸和颜色字典。不同角色拥有独立loader，回调有各自的去重范围。可据此设计单次资源准备/小范围发布，但旧Build212的1–3ms结果不支持把分析计算认定为目前主要根因。
4. 当前 `model.carouselItems` 是计算属性，会重新从媒体库内容构建集合；每次取邻页/当前项目等会再次访问。最多6个显示项不等于源集合构建完全没有成本。重构可在接受内容变化时生成只读呈现绑定，不建立第二内容权威。
5. Build286仍是UIKit输入→单个published progress→多个SwiftUI位移/透明度scope。不能从这个事实断言所有后代每次重新栅格化，也不能从简单SwiftUI probe达到120断言复杂真实树没有成本。
6. 当前完成/取消用 `asyncAfter`，完成检查主要是fromID/toID。新需求允许同一对页面被再次接管，单靠同一ID组合不能证明旧完成仍有效；新的单owner必须具有可靠取消/完成身份，防止旧动画落定新手势。这是接管新需求的确定性要求，不是新增防御式重试。

## 重构职责和候选呈现路径

- HomeModel继续拥有接受后的Emby内容和设置。
- 轮播唯一过渡owner拥有当前页、邻页、方向、progress、拖动/收尾/自动/取消和有效完成身份。没有第二套可独立前进的progress或当前页。
- 资源准备仅持有当前内容身份对应的图片、尺寸和前景资料；复用已有图片缓存，不建立另一个全局缓存/网络层。
- 呈现层消费同一owner和已经准备好的绑定。候选为稳定UIKit视图/图层层级，正常运动仅修改transform/position/opacity；低频内容更新继续和Home桥接。这是一条需要A/B验证的方案，不是已证明的根因修复。
- 接管顺序：读取当前可见状态→取消旧动画及其完成权限→把状态转交到同一owner→新手势从该状态继续。不把模型目标终点当成可见起点，不先跳到终点；不添加连续预测/插值来编造手指位置。
- 大面积模糊/遮罩/文字合成的GPU成本独立检查。不能用原生呈现替换后主线程变轻来宣称render hitch也消失。不默认预烘焙所有页面或新增全尺寸快照缓存；若需要派生背景，先证明瓶颈并核对视觉一致性、内存及已有缓存边界。

## 验证顺序与停止条件

1. 静态检查：只有内容变化能重建内容绑定；运动回调不得发起重活；接管后旧完成无法落定；无第二过渡owner；MinOS15和P0边界不变。
2. 使用真实图片、文字、最新已选的底色/渐变设计和Home内容验证整体；若需归因，再完成同包匹配A/B。简单参考图形仅作控制，不能替代真实轮播验收。
3. 真机覆盖：慢拖/反向/连续快甩、收尾立即接管、提交和取消、首尾循环、热/冷资源、首页离开返回、数据刷新、自动切换与纵向惯性重叠，以及持续使用。
4. 区分app更新/commit与render服务器/GPU；若可获取Instruments轨迹，优先用Animation Hitches分类。现有App日志只证明其实际记录阶段，CADisplayLink不能作为最终FPS权威。记录帧尾分布、资源提交/槽轮换/动画完成事件，不要求用户长时间手抄HUD。
5. CPU路径变轻但真实体验仍差时，继续定位render或首次提交边界，不叠加新timer/watchdog/插值。只有真机验收后才称Stable；CI/IPA只证明对应证据层级。

## 2026-10-05 后续需求：底色衔接与少量全页常驻候选

用户上传参考截图（IMG_8025.jpeg）：轮播图底部逐渐进入棕色底色，下方“我的媒体/继续观看”等区域沿用底色。截图只证明视觉参考，不能确定竞品内部是否真正使用纯色、模糊或采样颜色，也不能从单张FPS读数归因。

用户提出允许轮播与下方内容交界以下直接使用底色。这使前版“保留全屏blur30”不再是强制外观约束：新的候选设计为**Hero图片区+接缝渐变+下方单个不透明底色面**，不继续在列表背后铺两张整屏动态图片/模糊背景。Hero清晰图、前景横移和接缝连续保留。全局固定底色或每页预先提取底色尚未选定；若随页变化，颜色只在资源准备时计算，运动时可用单个填充面的颜色插值，不逐帧重新分析图片，不叠多张全屏背景。所有底部填充及渐变终点必须使用同一颜色定义，避免接缝或白闪。

性能判断：移除下方大面积动态图片/模糊合成能按设计减少对应工作，但不是已经证明的长帧根因或120FPS修复。旧Build269去blur仍约90FPS，不能重新承诺“只改底色即可解决”。Apple将commit和render阶段分开，必须用真实下方内容、纵向惯性与自动切换重叠验证。

用户另提出“假设5页预建叠放、4页opacity0”与切换实时创建的比较。本轮推荐：**对明确有界的小集合（当前产品最多6项），优先验证整页预建常驻**，组件含清晰图与前景；不是已经实施或真机通过。当前实现并非全页实时创建：Hero已常驻当前/前/后3页，前景已遍历全部轮播项。全页常驻候选进一步排除清晰Hero三槽轮换的挂载/资源绑定工作，代价是更高常驻内存与首次准备成本；已有3槽方向仍保留为有效历史基础，不能不测内存就宣称全页更优。

| 对比 | 有界全部预建常驻 | 切换期间实时创建 |
|---|---|---|
| 交互时工作 | 已准备节点仅改位移/透明度 | 可能同时构建、排版、资源绑定和首次提交 |
| 连续反向/甩动 | 邻页/循环页已有稳定身份 | 容易在新目标出现时夹带冷工作 |
| 内存与首次进入 | 较高，需要准备上限和实测 | 较低，但有操作时延风险 |
| 本轮建议 | 少量固定页的优先候选 | 避免作为高频切换路径 |

常驻不等于每页独立复制所有纹理，也不等于opacity0没有成本：
- 清晰背景、前景等角色复用同一准备好的图片引用；不为每页额外制造整屏快照或模糊纹理缓存。
- opacity0的组件仍持有图片/对象，并可能参与布局/依赖更新、接收异步回调；不指望alpha自动消除CPU工作或自动预热GPU资源。
- 只有当前/目标页消费运动更新；其余页不逐帧更新其内容/布局，不接受点击。所有节点保持稳定身份，不用if分支在每次运动时卸载再挂载。
- 前景仍全宽横移；图片按最终确认的视觉效果渐变。不能把所有内容都改成纯淡入淡出。
- 示例内存：假设单张解码图1400×2100×4字节≈11.2MiB，5张≈56MiB，仅为像素数据估算；实际还有logo、文字/合成/GPU资源等，不是本项目实测。
- 非就绪页按现有异步占位策略处理，不同步等完5张才允许交互；初始准备同样不能在主线程集中构建重活。
- 需要核对全页数、首进/返回的准备峰值、后台前台/内存压力和长时间循环。准备常驻不保证首次可见提交无成本。

本轮仅更新需求/方案，未改产品代码、未创建新Build。全页常驻与底色方案应作为可分辨的设计变更记录，后续匹配A/B避免同时更改手势/曲线导致归因丢失。

## 2026-10-05 EX交互视频参考：连续快切、按住往返与慢拖

来源：用户本轮上传 `RPReplay_Final1791200921.mp4`，Library ID `libfile_82a59af15df081918afb65bbe92beef2`。文件SHA256 `fca7a9571339065669abeec11ea6fd5f2309b12d2121f20037ab4d6f1a6335be`；ffprobe：510×1108、14.8s、30fps、444帧。已按0.5s总览及0.1s分段抽帧查看。文件为用户录制的竞品EX，不是OnePlayer真机测试基线，不归属Build286/288。不要用录屏或HUD证明最终120FPS，不从画面推断具体框架、常驻策略或曲线数值。

| 片段（近似） | 可见行为 | 对我们的设计意义 |
|---|---|---|
| 1.1–3.9s连续快切 | 页面连续进入后续项目；没有可见逐次停住等待或集中补跳；标题/logo/摘要横向更替，背景图叠合渐变 | 快甩应持续响应，不能积压一串等收尾后执行的换页命令；速度/方向和位移共同决定提交意图，但具体阈值仍沿用OnePlayer已验证500pt/s与0.28，不猜EX数值 |
| 4.8–9.5s按住往返 | `操控游戏`前景向一侧移动、邻页逐步混入，随后画面退回原页；方向改变时前景位移和图片混合可逆 | 拖动是一个可增加/减小的过渡进度，不在刚看到邻页时提前永久提交；反向跨过原点的目标身份须由唯一owner确定 |
| 10.5–11.7s较短切换 | 从操控游戏向玫瑰丛生，较短动作后出现完整目标页 | 快速动作可以以意图提交，不能只按“必须拖过半屏”来实现；录屏不能证明采样方式或确切释放边界 |
| 12.2–13.7s较慢切换 | 玫瑰丛生前景逐渐退出，操控游戏前景从另一侧进入；背景在原位置逐步混合，最后完整落定 | 手指运动阶段由真实进度驱动；松手再走提交或取消的短收尾，不在按住期间追加独立缓动追赶 |

核心视觉观察：同一作品背景的主体位置基本保持，跨页主要表现为图片混合；前景标题/logo、元数据和摘要则横向移动。在中间状态可见两页前景分别占据两侧。不能把“组件常驻”实现成整张背景和前景一起横推，也不能把前景只做alpha渐变。它们可以归属同一个item组件，但要允许不同的运动属性，共用同一过渡进度。

下方媒体卡片布局在切换期间保持，较大底色随页颜色变化。画面支持“渐变衔接+统一底色”的外观参考，但不证明竞品内部纯色/模糊/取色实现。

设计落实为：单一owner的idle→drag→settle；进度控制前景位移、背景混合和已准备底色；drag可逆且未落定不改当前页；settle完成才落定；settle遇新手势按本轮用户已明确选择立即接管当前可见状态。视频没有精确证明“EX在尚未结束的settle中如何接管”，后者是用户确认的OnePlayer需求，不应伪装成竞品源码事实。

本参考不授权改变既有松手0.22/0.18s曲线、不授权连续预测/插值、不证明全页常驻比3槽更快。它提供交互和视觉验收场景；资源常驻及底色方案仍待实现和真机验证。

## 2026-10-05 已选方向与下一实施步骤

用户认可常驻方案，并强调减少切换过程的实时创建成本；本轮将**当前有界轮播集合全页预建常驻**选为下一实现主方案，不再把每次切换创建新页当作默认路径。实际内容上限继续沿用HomeModel的6项，用户“5张”是示例，不改内容数量。此为设计选择，不是内存/流畅度已经真机验证的结论。

目标是：资源/内容改变时准备图像与前景；正常切换只让当前/目标节点参与位移和透明度变化；下方共用一个底色面。成本仍包含首次准备、首次提交、可见图层混合以及常驻内存，不能把系统理解成完全免费地换几张UIImage。所有图像角色复用已有资源，不新增整页快照缓存。

下一实施工作已经明确：
1. 核对并落实原生稳定呈现的桥接：保留首页外壳/导航/内容权威，轮播高频呈现不经由所有页的SwiftUI依赖更新；页面组件保持稳定身份，支持背景原位渐变与前景全宽横移分别应用。
2. 用同一过渡owner实现正常拖动、可逆移动、提交/取消与立即接管；收尾完成身份可靠取消，不用计时纠正。正常距离/方向速度阈值及既有收尾合同保留，立即接管是本轮明确新增需求。
3. 下方采用单个不透明底色与Hero渐变衔接。按提供的EX视频外观，推荐底色随作品变化并在资源准备阶段生成；这是可逆的默认设计选择，不逐帧分析图像。具体颜色算法及正常/反向接管时的连续颜色关系还需在源代码/API核对中确定。
4. 先完成这组有边界的真实内容重构，再执行静态/编译检查、唯一Build/候选分配、CI与IPA验证，交给目标真机覆盖慢拖、按住往返、连续快甩、立即接管、自动×纵向惯性以及常驻内存/首进。没有新代码或IPA前不把设计状态标为已实现。
5. 首个实现前核对PR#289/真实分支/head、其余Active任务和main最新源码；本任务串行取代旧性能候选，不另建并行同模块任务。不得将Build288详情冻结结论或其他任务代码顺带重构。

下一步是具体实现及测试候选，而不是继续要求用户收集六份旧会话或再次论证常驻原理。当前轮用户问的是实施顺序，本轮记录已选架构和可执行边界；尚未写产品代码。
## 尚需具体设计核对

- 立即接管时，跨越中点后的当前/目标页选择与反向目标规则，必须画出正常/提交/取消/再次接管的状态转换并对照真实行为。
- UIKit/CALayer如何保持Hero渐变/裁剪和foreground compositing效果；下方单个不透明底色按每页预先准备颜色的已选默认设计实施，核对反向/接管时的颜色连续性。
- 现有SwiftUI缓存图片组件如何把已准备资源交给原生呈现，避免改动Poster共享路径和重复loader；尚未设计新公共API。
- 内容刷新恰好发生在运动期间的接受边界，以及不就绪邻页的现有占位表现，需在具体实现前核对。
- 当前没有Xcode/Instruments真机执行轨迹；不虚构可直接在此Linux环境完成这些运行验证。

## 参考资料

- Apple: [Understanding hitches in your app](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app)
- Apple: [prepareForDisplay(completionHandler:)](https://developer.apple.com/documentation/uikit/uiimage/preparefordisplay(completionhandler:))
- Apple: [Demystify and eliminate hitches in the render phase](https://developer.apple.com/videos/play/tech-talks/10857/)

图片异步prepare API只是官方可选路径；现有解码已后台执行，本设计不因此自动加入另一次prepare或提高系统版本。

## Build293 accepted / carousel task completed — 2026-10-06 (Asia/Shanghai)

User's controlling target-device result: “目前测试没问题了，我认为轮播图重构这个任务可以验收通过进行收尾工作了”. This accepts the supplied **OnePlayer0.15.26 / Build293** carousel candidate, exact tested source **fa8ff44ff4a5384fd4603a64b33354f941764a8c**, on the project's iPhone15ProMax/iOS17.0 target. Build292 removal of long frames and stable120FPS remains user-reported performance evidence; Build293 has general explicit acceptance after flicker/color repair, without a new numerical frame trace.

- **DEV-home-carousel-drag-smoothness completed / carousel interaction and native presentation stable/frozen at Build293.**
- **PR#289 merged to main at f0a737519801ff55f18e31f9bdcf5f83c9097c17**. Merge preview preserves tested product bytes exactly; only authority/planning documents differ from tested source. No new code, Build, IPA or unnecessary retest generated for closeout.
- Native resident pages/resources stay prepared outside movement; one UIKit gesture/runtime transition authority; foreground uses full-width translation, artwork blends in place. Release takeover reads actual foreground position, every artwork opacity and base color before stopping animation; preserve contributing outgoing pages across committed same-direction rebasing and fade all outgoing pages through the new tail.
- Lower-edge sampled color plus artwork/contrast overlays ending by90% Hero height produce one solid Hero/content floor. Preserve accepted geometry/title/Dock, vertical scroll/stretch/refresh and native navigation. Do not restore transformed-frame writes, central-image hue mismatch, hidden contributing outgoing pages or opacity recomputation at acquisition.
- Preserve0.28/500pt/s,0.22/0.18/0.62s,6s auto, iOS15.0, Frozen/P0. No new blur, timer/watchdog, second progress owner or high-frequency full-tree SwiftUI.
- Validation: actual-source native **10 tests/0 failures**, Build292 negative **2 tests/22 expected assertions**; exact-source Release CI run/job **37345215494 /111882105262**, control **4a26035ab17e0cf61b3f647055a13a0c745c4280**, success. Verified artifact **11361570366**, digest **fe13e098eeb32b92b6e255784d0e742d7ffa2f5ac6225fcffe2daa1c61a87213**; IPA **8b57d565e0b7c93a12e43e65e3c2085350933097119ddf0b370f69d0df4f91bf**; sourceZIP **31b41a2ef631a99dbeb76926746fc87c5bff2c4e558ca0b193d2957aaaf447fc**. Info.plist+arm64 MinOS15.0, CADisableMinimumFrameDurationOnPhone=true.
- Evidence: **Code written /CI passed /IPA independently verified /real-device accepted /stable-frozen for carousel scope /merged to main**. Historical pending/rejected records above remain dated history and are superseded by this acceptance.
- Remove only this task's current checkpoint per DOCUMENTATION_POLICY; other task checkpoints unchanged. Reopen only with new concrete regression evidence; no remaining carousel test gate.
