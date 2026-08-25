# DEV-home-carousel-drag-smoothness

## Status

**Active**

- **Work ID**：`DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords**：轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- **Task**：优化 OnePlayer 首页 V3 轮播图手动横向拖动，目标达到用户 EX 参考录屏同级别的丝滑、细腻和跟手，不出现起滑大跳、不跟手、卡顿、抖动、冻结后追帧或反向切换断点。
- **Acceptance**：手指轻微移动必须立即有细腻连续反馈；持续慢拖、快速拖、左右反向穿越中心必须连续；松手吸附自然；不得破坏首页纵向滚动、自动轮播、详情点击、媒体行或播放器/P0 合同。
- **Accepted integration baseline**：当前真实 accepted runtime baseline 仍为 OnePlayer 0.14.11 / Build178。轮播候选继承 Build176 player episode-selection/session contract 与 Build178 canonical Emby episode ordering。
- **Build179 result**：Code written / CI passed / IPA produced / **real-device rejected**。轻微拖动仍有死区，反向穿越中心会卡住后大跳。
- **Build180 implementation**：`DragGesture.minimumDistance = 0`；移除 4pt gate；横向 dominance 只用于第一次锁定，建立横向拖动后反向穿越中心不断流；移除 backdrop 前 8% delayed blend；保留单一 `V3HomeCarouselTransitionState` owner/local scope 与原 commit/cancel/auto-advance/blur 合同。
- **Build180 CI / artifact**：source `8d630a200cd1e0d9b06da90bc7d71e0fb4a7b6c5`；run `32845376285` success；artifact `9562183159`；IPA SHA-256 `9da61f301e610fd2dd8a20aafba22dd55fb415e609ac8b2fe8923407d73d40cc`；MinOS 15.0。
- **Build180 real-device result — PARTIAL / FAILED acceptance**：用户 2026-08-25 提供 `RPReplay_Final1787660867.mp4`。反向不松手左右切换已不再卡住，说明状态机修正有效；但起滑第一段位移仍明显过大，整体仍不够丝滑细腻，与 EX 有明显差距，因此 Build180 不可接受/冻结。
- **New video evidence**：Build180 新录屏 510×1108 / 30 fps / 5.5s。Hero 前景逐帧光流在约 1.13s、2.57s、4.50s 的每次起滑第一可见帧都出现约 14px 横向位移；EX 对应过渡的横向空间位移接近 0，主要是连续透明度混合。
- **Root-cause refinement after Build180**：剩余问题不再是 4/12pt 手势阈值或反向中心死区，而是视觉映射仍把 Hero 前景用 `progress × fullWidth` 做整屏横移。第一次系统可见 translation 会直接转换成同等像素前景位移，而 EX 的空间重心基本稳定。
- **Crossfade implementation**：保持 Build180 0pt/连续反向手势状态机不变；`carouselForegroundOpacity` 改为与 artwork/backdrop 相同的线性 progress crossfade；`carouselForegroundOffset` 固定为 0，移除 Hero 标题/Logo/元信息的整屏横向 travel。背景 artwork/backdrop progress、commit/cancel 阈值、release animation、auto-advance timing、详情点击与纵向滚动均不变。
- **Build identity correction**：本轮最初曾以轮播 `0.14.14 / Build182` 触发一次 CI，但并行 `DEV-detail-episode-page-optimization` 已在同一时间正式占用 **0.14.15 / Build182**。为遵守 Active task 唯一 Build 合同，轮播 Build182 identity 作废且不分发；同一轮播源码重新编号为 **OnePlayer 0.14.16 / Build183**。仓库搜索确认 Build183 当时未被其他任务占用。
- **Working branch**：`perf/home-carousel-drag-smoothness-build183`，从 Build180 workflow-restored head `452ba27a661b4427471a975de99bb30e5e59a469` 的轮播 follow-up 线继续。临时 CI helper 已恢复，workflow-restored branch head `4569dc4b0bb711328a50c5c074d8913329e9812c`。
- **Build183 CI**：dedicated standard MPV Release source `b7fc842ddfe245a42e68a7d80082e11e63f17938`；run **`32849750890`**；workflow conclusion **success**。通过：0pt/连续反向手势合同、foreground full-width travel removed、foreground linear crossfade、home/scroll/series-ordering checks、Build176/178/P0/Frozen zero-diff、Xcode 16.4 dependency resolution、Release device build、OnePlayer 0.14.16 (183) identity、MinOS 15.0、IPA packaging/upload。
- **Build183 artifact**：`OnePlayer-0.14.16-build183-home-carousel-crossfade`；artifact ID **`9563857302`**；artifact digest `sha256:aa9b28d147cf98aeaa03797d848e927a42928d8b44c8c25ef02c543179ef1352`；IPA `OnePlayer-0.14.16-build183-home-carousel-crossfade-unsigned.ipa`；IPA SHA-256 **`ad96332ea3ce0bab9eabd03cfe16e39fe5a3c10513eacb4c072f9f8cd0133e57`**；source zip SHA-256 `71ed60361b12b34249780e9ad1b37c1c02e77d49b137e0b27f875bd7383ec39b`。下载后 IPA/source checksum 再次校验 OK。
- **Files / state owner**：Build183 相对 Build180 的长期差异仅 `Sources/UI/EmbyHomeCarouselStateV3.swift`、`Sources/Core/AppIdentity.swift`、`scripts/check_home_immersive_carousel.py`、`docs/changelog/CHANGELOG_v0_14_16_build183.md`。`EmbyHomeCoreV3.swift` 与 owner/scope 沿用 Build179/180。
- **Frozen / inherited**：PlayerController、MPV fast Seek、PiP Build173、UnifiedTransport、Range/302/115 客户端直连、Session cache、Cache UI、Emby progress/Resume、episode selection/order、native navigation 均未改变。
- **Parallel conflict**：详情/剧集页任务当前拥有 Build182 / 0.14.15；其运行时范围是 detail presentation/cache，不占用 `EmbyHomeCarouselStateV3.swift` 或 carousel state owner。两个候选独立并行。
- **Validation state**：Build179 = rejected；Build180 = **real-device tested, partial improvement but rejected**；Build183 = **Code written / CI passed / IPA produced / Real-device pending / not stable**。
- **Next exact action**：用户在 iPhone 15 Pro Max / iOS 17.0 安装 Build183，与 EX 对照复测起滑第一帧细腻度、持续慢拖/快速拖、左右反向、取消/提交吸附。只有用户确认达到 EX 级别后才可接受/合并。
- **If Build183 still fails**：下一优先证据点才是 persistent full-screen 两张 `.blur(radius: 30)` layer 的 GPU/compositing 成本；不提前同时改 blur，以保证归因清晰。
- **Rejected / do-not-repeat**：不要恢复 4/12pt 起拖门槛；不要恢复每帧中心方向 gate；不要继续用 full-width foreground travel 作为 EX 手感目标；不要用 debounce/throttle 掩盖帧问题；不要复用其他 Active task 的 Build 编号；不要为首页轮播修改 Player/Transport/Cache。
