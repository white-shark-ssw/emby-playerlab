# DEV-home-carousel-drag-smoothness

## Status

**Active**

- **Work ID**：`DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords**：轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- **Task**：优化 OnePlayer 首页 V3 轮播图的手动横向拖动体验，目标是达到用户 EX 参考录屏同级别的丝滑、细腻和跟手，不出现起滑大跳、不跟手、卡顿、抖动、冻结后追帧或反向切换断点。
- **Acceptance**：手指轻微移动时必须立即产生细腻连续的视觉反馈；持续慢拖、快速拖、左右反向穿越中心都必须连续；松手完成/取消吸附自然；不得破坏首页纵向滚动、自动轮播、详情点击、媒体行或播放器/P0 合同。
- **Accepted integration baseline**：当前真实 accepted runtime baseline 仍为 OnePlayer 0.14.11 / Build178。Build179/180/182 轮播测试线继承 Build176 player episode-selection/session contract 与 Build178 canonical Emby episode ordering。
- **Build179 result**：Code written / CI passed / IPA produced / **real-device rejected**。用户真机确认轻微拖动有死区，反向穿过中心会卡住后大跳。
- **Build180 implementation**：将 `DragGesture.minimumDistance` 改为 0，移除 4pt gate；横向 dominance 只用于第一次锁定，建立横向拖动后反向穿越中心不断流；移除 backdrop 前 8% delayed blend。保留 Build179 单一 `V3HomeCarouselTransitionState` owner/local scope、commit/cancel 阈值、settle 动画、自动轮播和 blur 设计。
- **Build180 CI / artifact**：source `8d630a200cd1e0d9b06da90bc7d71e0fb4a7b6c5`；run `32845376285` success；artifact `9562183159`；IPA SHA-256 `9da61f301e610fd2dd8a20aafba22dd55fb415e609ac8b2fe8923407d73d40cc`；MinOS 15.0。
- **Build180 real-device result — PARTIAL / FAILED acceptance**：用户 2026-08-25 提供 `RPReplay_Final1787660867.mp4`。反向不松手左右切换已不再卡住，说明 Build180 状态机修正有效；但用户仍明确报告起滑第一段位移过大、整体不够细腻丝滑，与 EX 手感仍有明显差距，因此 Build180 不能接受或冻结。
- **New video evidence**：Build180 新录屏 510×1108 / 30 fps / 5.5s。对 Hero 前景区域做逐帧光流测量，在约 1.13s、2.57s、4.50s 的每次起滑第一可见帧都出现约 14px 横向位移；EX 参考录屏对应过渡的横向空间位移接近 0，主要表现为连续透明度混合。这解释了即使 progress 已从 0pt 开始接收，OnePlayer 仍会给人“起滑一下就窜一段”的粗糙感。
- **Root-cause refinement after Build180**：剩余问题不再是 4/12pt 手势阈值或反向中心死区，而是视觉映射仍把 Hero 前景用 `progress × fullWidth` 做整屏横移。30fps 采样下第一次系统可见 translation 会直接转换成同等像素前景位移；EX 的空间重心基本稳定，因此手感更细腻。
- **Build182 candidate**：并行 `DEV-detail-episode-page-optimization` 已预留 Build181，因此本任务下一候选为 **OnePlayer 0.14.14 / Build182**，branch `perf/home-carousel-drag-smoothness-build182`，从 Build180 workflow-restored head `452ba27a661b4427471a975de99bb30e5e59a469` 创建。
- **Build182 implementation**：保持 Build180 0pt/连续反向手势状态机不变；`carouselForegroundOpacity` 改为与 artwork/backdrop 相同的线性 progress crossfade；`carouselForegroundOffset` 固定为 0，移除 Hero 标题/Logo/元信息的整屏横向 travel。背景 artwork/backdrop progress、commit/cancel 阈值、release animation、auto-advance timing、详情点击与纵向滚动均不变。
- **Why this is minimal**：只改变已被新录屏直接否定的 foreground spatial mapping；不改图片下载/解码、不改 full-screen blur、不换 Carousel 架构、不引入 debounce/throttle/timer/watchdog/retry/fallback。
- **Files / state owner**：Build182 新增长期产品差异相对 Build180 仅 `Sources/UI/EmbyHomeCarouselStateV3.swift`、`Sources/Core/AppIdentity.swift`、`scripts/check_home_immersive_carousel.py`、`docs/changelog/CHANGELOG_v0_14_14_build182.md`。`EmbyHomeCoreV3.swift` 与 owner/scope 沿用 Build179/180。
- **Frozen / inherited**：PlayerController、MPV fast Seek、PiP Build173、UnifiedTransport、Range/302/115 客户端直连、Session cache、Cache UI、Emby progress/Resume、episode selection/order、native navigation 均不得因本任务变化。
- **Parallel conflict**：详情/剧集页优化任务占用 Build181，当前 checkpoint 记录的运行时范围仍不与 `EmbyHomeCarouselStateV3.swift` / carousel state owner 重叠；如其后续扩展到共享首页状态，必须重新检查。
- **Validation state**：Build179 = rejected；Build180 = **real-device tested, partial improvement but rejected**；Build182 = **Code written = yes / CI passed = no / IPA produced = no / Real-device tested = no / Stable = no**。
- **Next exact action**：为 Build182 跑 dedicated standard MPV Release CI，锁定 Build180/Build178 inherited contracts、Xcode 16.4 Release、0.14.14 (182)、MinOS 15.0 和 IPA；成功后发用户 iPhone 15 Pro Max / iOS 17.0 与 EX 对照复测起滑第一帧细腻度和持续拖动流畅度。
- **If Build182 still fails**：只有在 crossfade 仍不能达到 EX 后，下一优先证据点才是 persistent full-screen 两张 `.blur(radius: 30)` layer 的 GPU/compositing 成本；不提前同时改 blur，以保证归因清晰。
- **Rejected / do-not-repeat**：不要恢复 4/12pt 起拖门槛；不要恢复每帧中心方向 gate；不要继续用 full-width foreground travel 作为 EX 手感目标；不要用 debounce/throttle 掩盖帧问题；不要为首页轮播修改 Player/Transport/Cache。
