# DEV-home-carousel-drag-smoothness

## Status

**Active**

- **Work ID**：`DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords**：轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- **Task**：优化 OnePlayer 首页 V3 轮播图的手动横向拖动体验，使手指持续拖动期间的画面位移连续、跟手，不出现明显冻结、追帧、抖动、跳变或掉帧感，并以用户提供的 EX 录屏作为体验对照。
- **User intent / acceptance criteria**：用户 2026-08-25 提供 `op轮播图.mp4` 与 `ex轮播图.mp4` 真机录屏。OP 在手动拖动轮播图过程中可明显感受到卡顿/抖动；目标是达到 EX 相同级别的滑动丝滑程度。验收重点：1）手指持续移动时 Banner 位移连续并紧跟手指；2）不能出现明显“停一帧/几帧后突然追上”的感觉；3）不能有可感知抖动、跳变、掉帧感；4）松手后的完成/取消吸附仍自然；5）不得为此破坏首页纵向滚动、轮播自动切换、详情点击、媒体行或播放器/P0 合同。
- **Baseline**：任务于 2026-08-25 新建。base branch `main`；base commit `49f09c13887186eae5117f63deb08f7422248c24`。项目最新真机接受功能基线仍以 `PROJECT_STATE.md` 为准；本任务只触及首页轮播 UI，不以未真机接受的播放器选集候选作为运行时证明。
- **Working branch / PR / head commit**：branch `perf/home-carousel-drag-smoothness`；从 `main@49f09c13887186eae5117f63deb08f7422248c24` 创建；PR = none；当前产品源码尚未修改。
- **Build candidate**：未分配。分配前必须检查 `BUILD_TEST_INDEX.md` 与其他 Active checkpoint，禁止复用其他任务已占用的 Build / version / IPA candidate。
- **Evidence**：录屏逐帧对比显示 OP 手拖期间存在“持续移动 → 短暂停住 → 下一帧大幅追赶”的视觉节奏，而 EX 的位移更连续。当前真实源码已定位：`Sources/UI/EmbyHomeCarouselStateV3.swift` 的 `carouselDragGesture(width:)` 在 `DragGesture.onChanged` 中持续写顶层 `@State transitionProgress`；`Sources/UI/EmbyHomeCoreV3.swift` 将 `transitionProgress`、transition IDs、dragging 状态直接放在 `V3EmbyHomeView` 顶层，并且该 View 同时包含整个首页 ScrollView / rows / header / dock；`Sources/UI/EmbyHomeHeroV3.swift` 中同一个 progress 同时驱动 Hero 当前/目标大图 opacity、前景横移，以及 `persistentCarouselBackdrop` 两张全屏 `scaleEffect(1.12).blur(radius: 30)` 图片的交叉透明度。`carouselPreloadLayer` 还为所有轮播项创建 `EmbyCachedRemoteImage`。因此当前最强源码热点不是简单动画时长，而是高频 drag progress 对大范围 SwiftUI 树和多层大图合成的驱动成本。`EmbyCachedRemoteImage` 本身已使用后台解码 + decoded cache，但 `onImageLoaded` 会在 UI 接收图片时调用 `updateCarouselImageMetrics`，其中 `EmbyImageContrastAnalyzer.prefersLightForeground` 是同步 Core Image 分析；这可能造成图片首次到达时的额外主线程尖峰，但尚无证据证明它是持续拖动卡顿的主要原因。
- **Files / modules in scope**：已确认首要范围为 `Sources/UI/EmbyHomeCarouselStateV3.swift`、`Sources/UI/EmbyHomeHeroV3.swift`、`Sources/UI/EmbyHomeCoreV3.swift`；必要时读取 `Sources/UI/EmbySharedImageAndNavigation.swift` 和现有首页轮播检查脚本。只有证据证明需要时才修改其他文件。
- **State owner / shared dependencies**：首页轮播交互状态当前由 `V3EmbyHomeView` 顶层 `@State` 所有；Hero/Backdrop 只是该状态的渲染消费者。不得新增第二套互相校正的 carousel progress owner。若需要隔离高频交互状态，应明确保持单一 owner，并避免让高频 progress 无必要地驱动整个首页内容树。
- **Frozen / do-not-touch**：`PlayerController.swift`、MPV fast Seek、PiP Build173、UnifiedTransport、Range/302/115 客户端直连、Session cache、Cache UI、Emby 播放进度/Resume、native navigation 均不在本任务范围。不得引入时间→字节比例 Seek、retry/watchdog/fallback 或与首页轮播无关的重构。
- **Parallel conflicts checked against**：已检查 `DEV-player-episode-picker` 与 `DEV-nonstandard-episode-sorting`。前者范围在 Player 选集 UI/session，后者范围在 Emby 剧集排序数据链；当前均未占用 `EmbyHomeCarouselStateV3.swift` / `EmbyHomeHeroV3.swift` / `EmbyHomeCoreV3.swift` 或首页轮播状态 owner，因此本任务可以独立并行。若后续任一任务扩展到这些文件，必须重新评估并行安全。
- **Completed**：用户目标与真机录屏证据确认；当前 main/base/head 确认；独立 branch 创建；其他 Active 任务并行冲突检查完成；真实 carousel drag 定义、顶层状态 owner、Hero 与 persistent backdrop 渲染链、图片缓存/解码实现已读取；尚未修改产品代码。
- **Validation state**：Code written = no；CI passed = no；IPA produced = no；Real-device tested = no；Stable/frozen = no。
- **Pending**：继续确认现有 carousel 相关检查脚本与历史当前实现合同；基于真实源码选择最小、可验证的性能修正。优先验证高频 `transitionProgress` 是否能从整个首页树隔离，以及拖动期间是否有必要实时交叉混合全屏 blur backdrop。图片首次到达的同步 contrast 分析只在有进一步证据时处理，不先扩大范围。
- **Next exact action**：读取 `scripts/check_home_immersive_carousel.py` 和相关首页 UI/性能检查，确认当前轮播行为合同；随后在 `perf/home-carousel-drag-smoothness` 上实施最小结构性优化，目标是让手动 drag 的高频 progress 只驱动轮播必要层，避免不必要的大范围 SwiftUI invalidation / 重型全屏 blur 交叉合成，并保持现有自动轮播、点击与纵向滚动语义。
- **Rejected / do-not-repeat**：不要把问题简单归因于 `.animation` 时长或 spring 参数并盲调；不要加 debounce/throttle 让手势更新变少，因为目标是更跟手而不是少响应；不要引入 timer/watchdog/retry；不要为了性能改播放器/Transport/Cache；不要同时维护两个 carousel progress 状态；不要在无证据时重写整套首页或换成新架构。
- **Open questions / risks**：当前录屏能证明视觉不连续，但不能单独区分 SwiftUI 树 invalidation、GPU 大图 blur/opacity 合成、图片首次加载回调或其他主线程尖峰各自占比。第一版补丁必须基于现有调用链最强热点做最小改动，并通过 CI 后交给目标真机与 EX 并排复测；CI 不能代替真机丝滑度验收。
