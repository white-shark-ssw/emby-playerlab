# DEV-home-carousel-drag-smoothness

## Status

**Active**

- **Work ID**：`DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords**：轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- **Task**：优化 OnePlayer 首页 V3 轮播图手动横向拖动，目标达到用户 EX 参考录屏同级别的丝滑、细腻和跟手，不出现起滑大跳、不跟手、卡顿、抖动、冻结后追帧或反向切换断点。
- **Acceptance**：手指轻微移动必须立即有细腻连续反馈；持续慢拖、快速拖、左右反向穿越中心必须连续；Logo、评分、年份、类型、剧情简介等前景内容必须继续作为轮播页内容随页面横向平移；松手吸附自然；不得破坏首页纵向滚动、自动轮播、详情点击、媒体行或播放器/P0 合同。
- **Accepted integration baseline**：当前真实 accepted runtime baseline 仍为 OnePlayer 0.14.11 / Build178。轮播候选继承 Build176 player episode-selection/session contract 与 Build178 canonical Emby episode ordering。

## Real-device evidence trail

- **Build179**：Code written / CI passed / IPA produced / **real-device rejected**。轻微拖动仍有死区，反向穿越中心会卡住后大跳。
- **Build180 implementation**：`DragGesture.minimumDistance = 0`；移除 4pt gate；横向 dominance 只用于第一次进入拖动，建立横向拖动后反向穿越中心不断流；移除 backdrop 前 8% delayed blend；保留单一 `V3HomeCarouselTransitionState` owner/local scope 与原 commit/cancel/auto-advance/blur 合同。
- **Build180 real-device result — PARTIAL / FAILED**：用户确认按住不松手左右反向已不再卡住，说明方向反转状态机修正有效；但起滑第一段位移仍明显过大，整体仍不够细腻丝滑，与 EX 有明显差距，因此不可接受/冻结。
- **Build183 experiment**：为验证“空间位移是否是粗糙感来源”，曾将 foreground full-width travel 改为 linear crossfade、`carouselForegroundOffset = 0`。CI/IPA 成功。
- **Build183 real-device result — PARTIAL FEEL IMPROVEMENT / INTERACTION REGRESSION / REJECTED**：用户明确反馈手感“好像比之前细腻了一些”，但同时指出 Logo、评分、年份、类型、剧情简介被固定在屏幕上，原本已经确定的“随轮播页一起横向切换”交互被未经允许改变。用户无法在交互方式改变的前提下做有效 EX 手感比较。Build183 因交互回归不能作为正式方向。
- **Evidence correction after Build183**：此前根据 30fps 录屏光流推导“full-width foreground travel 应被取消”的结论被用户最新真机交互要求推翻。用户最新真机结果优先级更高。前景横向平移是既定交互合同，不能为了表面更顺而擅自取消。

## Build185 current candidate

- **Root-cause refinement**：Build180 虽已 `minimumDistance = 0`，但第一次建立横向拖动前仍要求 `abs(horizontal) > abs(vertical) * 1.08`。手指起滑时如果混入少量纵向噪声，轮播会先完全不动；达到 1.08 倍优势后，当前已累计的完整 `translation.width` 会一次性映射为 `progress × width` 的 foreground offset，直接形成“先不动 → 一下跳出去”的体验。该门槛比取消既定 foreground travel 更符合用户最新真机反馈。
- **Implementation**：Build185 从 Build180 clean carousel line 继续，恢复并锁定原 foreground slide contract；新增非渲染态 `V3HomeCarouselDragAxis` / `dragAxis`，`DragGesture(minimumDistance: 0)` 保持不变；第一次有效位移达到 **0.5pt** 时按 `abs(horizontal) >= abs(vertical)` 一次性锁定 horizontal / vertical。horizontal 锁定后使用原始 `translation.width` 连续驱动 progress，左右反向穿越中心不断流；vertical 锁定后整次触摸不让 carousel 接管，保护首页纵向 ScrollView。`onEnded` 清空 axis。没有 debounce、throttle、插值、累计补偿、timer、watchdog、retry 或 fallback。
- **Established slide contract restored**：`carouselForegroundOpacity` 在 transition 中保持 from/to 均可见；`carouselForegroundOffset` 恢复 Build180 公式：from = `-direction * progress * width`，to = `direction * (1 - progress) * width`。Logo/评分/年份/类型/剧情简介继续与所属轮播页一起平移。
- **Unchanged**：artwork/backdrop raw blend、commit threshold `0.28`、predicted threshold `0.48 × width`、0.22/0.18s complete/cancel settle、6s auto-advance、0.62s auto transition、详情点击、persistent `.blur(radius: 30)`、首页纵向滚动、Build179 local state owner/scope 均未改变。
- **Working branch**：`perf/home-carousel-drag-smoothness-build185`；PR = none。
- **Build identity**：**OnePlayer 0.14.18 / Build185**。详情页并行任务已经占用并产出 0.14.17 / Build184，因此轮播内部 Build184 CI 虽成功但因 identity 冲突作废、不分发；Build185 是当前唯一有效轮播编号。
- **Product head before temporary CI helper**：`1297d740795dec868368e80119c562e4932abc9e`。
- **Dedicated CI source / run**：`79f74d438ed8eade5061d6f9b76df4ebdd66a344`；run **`32853247583` success**。
- **Workflow-restored branch head**：`7e7918c83fce16ada9863956179dc971f79ebe28`。
- **CI coverage**：0pt drag delivery、0.5pt one-time axis acquisition、old 1.08 gate removed、old 4pt gate removed、Build180 raw artwork progress、foreground full-width slide restored、Build183 fixed/crossfade regression forbidden、existing commit/cancel/auto/blur contracts、home/scroll/series-ordering checks、Build176/178/P0/Frozen zero-diff、Xcode 16.4 dependency resolution、Release device build、OnePlayer 0.14.18 (185) identity、iOS 15.0 MinOS、IPA packaging/upload 全部通过。
- **Artifact**：`OnePlayer-0.14.18-build185-home-carousel-axis-acquisition`；artifact ID **`9565234614`**；artifact digest `sha256:9799657b332469f65ec117eb7d28eb524ba22f4f5a8887a4a057ad7775164e8d`。
- **IPA**：`OnePlayer-0.14.18-build185-home-carousel-axis-acquisition-unsigned.ipa`；下载后二次 SHA-256 = **`1f7ec2f6d09540b344ad10c36c438c4626bf40be3985d01b0d1b3404818e9b24`**，与 artifact 内校验文件一致。
- **Source ZIP SHA-256**：`a67c6ad7515ae363ba8bf05ffaee6ef830f1c706762e4517485ec9d93e7c5925`，下载后二次校验一致。
- **Compatibility**：CI MinOS = iOS 15.0；目标真机仍为 iPhone 15 Pro Max / iOS 17.0。
- **Long-term product diff vs Build180 clean head**：仅 `Sources/UI/EmbyHomeCarouselStateV3.swift`、`Sources/Core/AppIdentity.swift`、`scripts/check_home_immersive_carousel.py`、`docs/changelog/CHANGELOG_v0_14_18_build185.md`。`EmbyHomeHeroV3.swift` 未改，既有前景布局/调用点原样保留。
- **Frozen / inherited**：PlayerController、MPV fast Seek、PiP Build173、UnifiedTransport、Range/302/115 客户端直连、Session cache、Cache UI、Emby progress/Resume、episode selection/order、native navigation 均未改变。
- **Parallel conflict**：详情页任务拥有并行 Build184 / 0.14.17，运行时范围为 `EmbyMediaDetailView` 等 detail UI，不占用 `EmbyHomeCarouselStateV3.swift` / carousel state owner。Build185 当前无已知编号冲突。
- **Validation state**：Build179 = rejected；Build180 = real-device partial improvement but rejected；Build183 = **real-device tested, feel somewhat finer but interaction regression, rejected**；Build185 = **Code written / CI passed / IPA produced / Real-device pending / not stable**。
- **Next exact action**：用户在 iPhone 15 Pro Max / iOS 17.0 安装 Build185，与 EX 对照重点复测：1）起滑极小位移是否立即、细腻跟随；2）Logo/评分/年份/类型/剧情简介是否仍随所属轮播页一起横移；3）按住不松手左右反向是否继续无卡点；4）纵向首页滚动是否不被误抢；5）慢拖/快拖/取消/提交吸附整体是否达到 EX 手感。
- **Fallback policy explicitly allowed by user**：只有在保留既定容器平移交互继续验证后，若证据证明实在无法达到可接受丝滑度，才允许回到 Build183 类“foreground 固定、轮播主体 crossfade”的交互作为最终兜底。不得在未证明传统平移方案不可行前擅自切换交互方式。
- **If Build185 still fails while slide semantics must remain**：下一步先根据真机现象确认是首次事件/锁轴问题还是持续帧率问题；只有持续拖动仍有掉帧证据时才检查 persistent full-screen 两张 `.blur(radius: 30)` layer 的 GPU/compositing 成本，不提前同时改 blur。
- **Rejected / do-not-repeat**：不要恢复 4/12pt 起拖门槛；不要恢复 `1.08` 初始优势门槛；不要在已建立 horizontal drag 后重新进入中心方向 gate；不要用 debounce/throttle/补间动画掩盖跟手问题；不要擅自取消 foreground page travel；不要复用其他 Active task 的 Build 编号；不要为首页轮播修改 Player/Transport/Cache。
