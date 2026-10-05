# 首页轮播模块开发计划

> Current implementation status (2026-10-06): Build289/290 were implemented and device rejected. Build291 source dbeaa9d3472c85a5c238598da3aac41d8e49f43c corrects the proved transform/frame and Dock-extent violations; native regressions, exact-source CI and IPA verification passed, target-device acceptance pending. The earlier pre-implementation statements below are historical planning context. Live identity and next action: [task checkpoint](current/dev/DEV-home-carousel-drag-smoothness.md).


更新：2026-10-05。唯一任务：`DEV-home-carousel-drag-smoothness`。

本文件供其他开发会话直接执行。需求/源码依据见 [需求与设计](HOME_CAROUSEL_REFACTOR_PLAN.md)，实时进度与分支身份见 [任务 checkpoint](current/dev/DEV-home-carousel-drag-smoothness.md)。本轮只整理计划；没有重构代码、新 Build、CI 或 IPA。

## 1. 目标与已确定范围

针对 Build286/288 仍掉帧的问题，做一次范围明确的轮播呈现重构：内容准备与运动分离，最多6页全部预建常驻，单一过渡权威，背景原位混合、前景全宽横移，Hero底部渐变衔接到下方单个不透明底色，并支持收尾期间立即接管。

这一方案按设计排除切换时的页面创建和部分大面积背景合成工作；它不是已经证明的120FPS修复。最终验收必须使用真实内容与目标真机，不能仅看简单测试图形、CI或DisplayLink回调频率。

| 已确认合同 | 实现要求 |
|---|---|
| 页面常驻 | 沿用HomeModel最多6项；5张是用户举例。全部稳定节点预建，隐藏页不参与逐次运动更新，图片引用共享 |
| 拖动 | 保留一个UIKit手势owner、方向获取与真实样本起步；慢拖、按住反向连续跟手，不追加预测位置 |
| 前景与背景 | 标题/logo/元数据/概述按全宽页距横移；图片主体留在原位渐变。二者共用一个权威进度 |
| 提交与取消 | 正常拖动进度>=0.28，或同方向最近真实移动速度>=500pt/s；提交0.22s、取消0.18s easeOut |
| 即时接管 | 收尾或自动动画中再次横滑，停止旧动画，从当前可见位置继续；不等待旧收尾，不先跳终点 |
| 底色 | 单个下方底色面。采用每项预先准备底色、随同一过渡变化的默认设计；Hero渐变终点与下方填充保持一致 |
| 自动轮播 | 保留已有激活条件、落定后6s间隔与0.62s easeInOut；沿用单一已有调度源，不靠暂停纵向惯性规避问题 |
| 首页与导航 | 保留纵向滚动、Hero裁剪/拉伸、刷新、轻触详情和拖动误触抑制；系统导航owner保持 |
| 兼容 | iPhone15ProMax/iOS17.0验收；优先保持MinOS15.0；保留最高刷新请求覆盖收尾 |

## 2. 接手与源码基线

先读根 `AGENTS.md`、`START_HERE.md`、通知规则、`CURRENT_WORK.md`、`CURRENT_WORK_DEV.md` 以及项目状态/模块/技术决策/Build索引，再读本任务 checkpoint 与本计划。

截至本计划写入前，GitHub身份核对如下；开发前必须重新核对，不能把本表当作永久实时状态。

| 身份 | 当前记录 |
|---|---|
| 行为基础 | 已合并Build241；其中三槽Hero与全屏blur是历史呈现，按本次新设计替换 |
| 控制源码 | Build286 / OnePlayer0.15.19，`7e7b2ec944f5c0e74bc291e37683f1529e3d46b4` |
| 产品分支/PR | `perf/home-carousel-progress-scope-build286`，Draft PR#289，open/unmerged，head与上项一致 |
| main | `b786dbf5ee9fc118fe9c3ed166154758438cae43`；当前计划写入将继续推进文档，main不自动等于最新测试运行时 |
| 后续真机证据 | Build288源码`ce565996e37dcb750117c9de4607b23b673edce3`的Home运行时与286一致，用户报告仍不足 |
| 新候选 | 尚未分配；不要把文档提交当新产品源码或假定下一个可用编号 |

以286运行时为串行实现基础，重新核对main包含的已接受变化和其他任务重叠后继续本任务。优先续用本任务现有分支/PR；若技术上确需串行替换分支，明确记录新基线、head、旧PR处置，不留下两个同时声称权威的轮播开发线。身份不符按仓库规则停止报告，不擅自覆盖。

并行边界：Poster任务当前Build283，分支`perf/poster-grid-offmain-persistence-build280`；Aether任务Build235，分支`feat/aether-multi-engine-comparison`；Search已完成。接手时重读全部Active checkpoint。本轮没有分配新Build；分配前检查Build索引、所有Active候选及CI/IPA事实，不能仅凭最大数字加一。

详情导航Build288的接受/冻结与轮播不足是不同结论。不要继承被拒绝的Build287行为或借此重开详情、Poster、Player。不需要默认阅读六份老会话；只有新实现确实缺证据时定向补查。

## 3. 文件与职责边界

先核对实际定义与调用方，再选最终文件划分。下面新模块职责是设计要求，不是已存在的API名称。

| 文件/范围 | 允许修改或核对的职责 |
|---|---|
| `Sources/UI/EmbyHomeCoreV3.swift` | Home桥接、激活/纵向几何/低频内容接受、单底色接入；不重构下面列表 |
| `Sources/UI/EmbyHomeCarouselInteractionV3.swift` | 保留真实输入基础；取消收尾时拒绝新横滑的旧合同，转交唯一过渡owner |
| `Sources/UI/EmbyHomeCarouselStateV3.swift` | 统一拖动/自动/收尾/接管状态与有效完成身份，取消旧延迟完成权威 |
| `Sources/UI/EmbyHomeHeroV3.swift` | 接入稳定呈现；保留前景资料、清晰图、遮罩/文字可读性及白闪修正效果 |
| `Sources/UI/EmbyHomeCarouselProgressPresentationV3.swift` | 替换旧高频SwiftUI分发；迁移完成后删除不再使用的包装，不保留双实现兜底 |
| `Sources/UI/EmbyHomeModelV3.swift` | 内容来源/最多6项保持；只在必要时增加低频呈现绑定边界，不建立第二内容权威 |
| 新轮播专属呈现/准备文件（按需要） | 稳定UIKit/CALayer容器与有界资源绑定；一个职责只有一个owner，不建通用框架 |
| `EmbySharedImageAndNavigation.swift`、图片缓存 | 先只读，核对私有loader/UIImage复用和生命周期。共享文件确需改时先核对Poster冲突，优先串行最小修改 |
| 轮播诊断文件 | 只保留必要有界事件/阶段统计；不添加高频字符串输出或新的驱动DisplayLink |
| `Sources/Core/AppIdentity.swift`及实际构建配置 | 仅在唯一候选分配/打包时更新，保持版本/Build/MinOS一致 |

排除Player/MPV/PiP/UnifiedTransport/播放Cache/EmbySession、STRM→302→115/CDN、海报网格架构、详情导航架构与广泛格式整理。已有解码和日志落盘在后台，不能编造主线程IO根因来替换共享基础设施。

## 4. 实施顺序与阶段出口

### A. 实现前审计

1. 执行身份/并行冲突核对，确认串行基线。记录本次开发真正采用的源commit。
2. 列出当前owner、调用方和图片/内容发布入口；核对UIKit桥接、原生动画取消/完成、presentation读取、遮罩/裁剪、刷新率API与MinOS。
3. 定义唯一owner的idle、dragging、settling、auto和取消/内容替换转换；明确已提交当前页与过渡中可见页的区别。
4. 核对内容更新/几何改变/离开首页的现有行为，选确定性的接受边界。正常更新不让每个move重建集合；不可让持续拖动造成无界排队。

出口：本任务 checkpoint 记录基线、职责、涉及文件与尚有真实阻塞。没有证据支持的额外改动不进入实现。

### B. 唯一过渡owner与即时接管

1. 继续保留一个UIKit输入owner，将当前页、活动页对、方向、进度、拖动/动画状态及完成身份收敛到一个权威。Home只消费低频已接受内容/已提交选择，不独立维护可前进的第二套进度。
2. 普通drag使用真实位移，保持原起步和0.28/500判定。按住往返减少/增加同一连续进度，跨原点或页边界时连续转交邻页，不能按“进度过半”提前永久提交。
3. 立即接管必须读取当前实际可见前景位置，关联回同一过渡进度，并捕获一致背景混合/底色；随后撤销旧动画完成权限与动画，将可见状态作为新拖动起点。不能读取已经设为终点的model属性代替可见状态。
4. 同一from/to组合可以再次出现，旧完成回调仍必须失效。为具体接管需求使用动画/过渡身份，不靠新增定时器、延迟纠正、重试或比较页ID猜完成。
5. 原生动画的model/presentation是一个owner的呈现关系，不是两套业务选择。完成只落定一次；tap、自动调度、最高刷新生命周期由这个结果驱动。
6. 保留正常提交/取消时长和视觉曲线；自动动画用已有0.62s合同。移除被替代的`asyncAfter`落定路径，不保留两套完成owner。

出口：真实输入与动画打断连续，无旧回调落定新拖动；语义测试覆盖同页对重复接管、提交/取消/自动中打断与反向。初始短过渡的剩余时长等未改变合同不要顺手重新调参。

### C. 内容与资源准备、全部页面常驻

1. 在接受内容变化时准备最多6项的稳定ID/顺序、URL、标题/logo/元数据/概述、几何和资源绑定。HomeModel仍是内容权威，绑定只是当前接受内容的只读呈现资料。
2. 创建一次有界页面节点；正常切换不增删节点、不创建loader、不重新排文字。仅当前/目标页更新运动属性；其他页不可点击且不接收高频观察更新。
3. 复用现有后台下载/磁盘/解码与UIImage缓存引用。不要每个背景/前景/隐藏预加载角色各自重复准备同一资源，不新增全尺寸快照、模糊纹理或全局缓存。
4. 图片身份/尺寸变化时准备对比度、底色、适配几何；耗时分析离开主线程，最终只更新匹配ID/URL的相应槽位。资源完成不改变页选择或启动动画。
5. 冷资源沿用已有异步占位，不等待所有页下载/解码后才能拖动。原生节点创建需在主线程完成，但不同时挤入同步解码/分析/批量重排。
6. 删除已被明确替代的隐藏1×1 preload角色，前提是新资源owner确实覆盖其职责；保证取消、离开、返回和内容刷新不会泄漏加载任务或常驻页。

出口：热资源连续切换没有页面/loader创建、列表构建或文字布局；准备数量有界，冷资源不阻塞操作。记录首进/返回/首次显现/峰值内存，不能把alpha0等同GPU预热或零成本。

### D. 稳定原生呈现与单底色

1. 保留SwiftUI Home外壳、内容与系统导航；轮播使用稳定UIKit/CALayer呈现容器。具体API必须从源码/官方兼容性核对后采用，不凭设计文档发明接口。
2. 正常运动只改当前/目标已有前景的transform/position和已有图片的opacity，统一进度派生。保持图片原位、前景全宽横移；不把整个item一起横推。
3. 保留前景合成稳定与白闪修正效果。UIKit迁移不要求字面保留SwiftUI的`.compositingGroup()`，但需验证等价画面；不能随意用整页栅格化/快照代替。
4. 将列表背后的整屏动态blur图片层替换为一个不透明底色面；Hero范围保留清晰图和接缝渐变，底色与渐变终点共用定义，正向/反向/接管时连续一致。
5. 底色仅资源准备时提取；运动只按权威进度混合已准备颜色。没有逐帧图像分析，没有多层整屏背景交叉淡入。
6. 保留纵向拉伸/裁剪和自动×纵向惯性重叠。横向进度不向Home根及全部隐藏页面逐次发布；纵向必要几何更新也只触达相应容器。
7. 移除失去职责的旧progress scope/旧背景/旧完成驱动；不要让新旧轮播并存或新增产品开关长期兜底。

出口：真实内容画面满足参考、节点身份稳定，运动路径无准备重活；CPU优化与GPU/首次提交成本分别验证。不能承诺改为UIKit就自动120FPS。

### E. 必要验证与唯一测试候选

1. 审查diff、P0/Frozen、MinOS/API、单owner与所有高频调用方。静态检查不代替编译。
2. 做少量有意义的状态测试：正常/反向阈值、提交/取消打断、同页对旧完成失效、自动打断、内容删除当前/目标后的合法状态、0/1/2/6项、离开/返回。优先现有测试设施，不另造庞大测试框架。
3. 检查缓存热/冷、过期资源回调、页面数量、任务生命周期和实际内存。低影响外观改动不写镜像实现的测试。
4. 到可测试整体后再分配唯一Build/version/candidate，更新checkpoint/Build索引/AppIdentity/构建身份；不为每个小编辑消耗一次Actions出包。
5. 按仓库实际workflow完成Release编译、PR/CI/IPA。最终CI前重新核对main推进及重叠；实质同步后重跑受影响检查。
6. 独立取回并验证Artifact/源ZIP/IPA：源head/分支/PR、version/Build/candidate、artifact ID/digest、IPA与源ZIP SHA256、bundle、Info.plist、MinOS、压缩包完整性。查明实际工具能力，不能伪造本环境Xcode或真机结果。

出口：身份已核验的真实内容测试IPA；记录Code written / CI passed / IPA produced，交用户实机验收。正常开发应连续到此，不因中间commit、PR或checkpoint完成就等“继续”。

## 5. 实机验收表

设备：iPhone15ProMax/iOS17.0。先热资源且不录屏测真实呈现，再单独用录屏核对外观。EX视频是14.8s/30fps参考，不是120FPS证明或EX源码证据。

| 场景 | 必须核对 |
|---|---|
| 慢拖、短距离松手 | 跟手细腻、正确取消/提交、前景全宽与背景固定混合一致 |
| 按住左右往返 | 进度可逆、过原点连续、目标及底色正确，无提前永久选页 |
| 快速连续切换/首尾循环 | 无等待收尾、积压补跳、节点重建、重复loader与白闪 |
| 收尾/自动期间再次横滑 | 从可见位置立即接管；同方向及反方向均无跳终点，旧完成失效 |
| 自动×首页纵向惯性 | 不卡顿，不通过暂停自动或禁用惯性掩盖；Hero裁剪/拉伸正确 |
| 冷图、首次显示、内容刷新 | 不阻塞输入、不显示错误item资源、无集中主线程准备或无界待处理列表 |
| 轻触详情/返回、纵向手势/刷新 | 导航动画及系统返回合同保持，拖动误触被抑制，首页恢复正确 |
| 首进/返回/持续循环/前后台 | 常驻数量与内存有界，无持续增长，首次资源提交成本可定位 |

记录可见体验与可取得的帧尾/阶段证据，优先Animation Hitches区分app commit与render/GPU。120Hz约8.33ms是显示周期，不是所有阶段合计的简单硬阈值；CADisplayLink次数不能当最终FPS。不要恢复长期手抄HUD协议，不比较不同启动会话的合成TREE读数来归因。

先验证重构整体是否达到产品目标；若仍有长帧，再围绕真实事件做一次有控制的匹配对比，不叠加预测、插值、watchdog或拆掉更多视觉组件。用户实机通过之前保持Active；只有明确接受才称Stable/frozen。

## 6. 每个里程碑必须留下的交接信息

只更新本任务checkpoint，不另建同模块Active任务：已完成阶段、实际分支/head/PR、已分配候选、代码/CI/IPA/实机各自状态、实际失败证据、Pending、Next exact action。重要设计或真机结论同步需求设计/技术决策/模块/项目状态；IPA节点同步Build索引。

禁止重复路线：输入采样/标准Pan单独替换、DisplayLink帧锁、单独去blur、削减前景至3页、仅进度观察范围缩小，都不足以解释既有目标机结果；不重新声称“SwiftUI天生只能90”或“常驻/原生必然解决”。旧实验只用于限制推论，不将其失败当作本次新整体设计已失败。

给新会话的续接指令：

`/dev 继续 DEV-home-carousel-drag-smoothness，按 docs/project/HOME_CAROUSEL_DEVELOPMENT_PLAN.md 执行开发，先核对当前任务身份与源码，再连续推进到身份核验后的测试IPA。`
