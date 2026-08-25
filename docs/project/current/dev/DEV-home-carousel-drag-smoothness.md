# DEV-home-carousel-drag-smoothness

## Status

**Active**

- **Work ID**：`DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords**：轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- **Task**：优化 OnePlayer 首页 V3 轮播图手动横向拖动，目标达到用户 EX 参考录屏同级别的丝滑、细腻和跟手，不出现起滑大跳、不跟手、卡顿、抖动、冻结后追帧或反向切换断点。
- **Acceptance**：手指轻微移动必须立即有细腻连续反馈；持续慢拖、快速拖、左右反向穿越中心必须连续；Logo、评分、年份、类型、剧情简介等前景内容必须继续作为轮播页内容随页面横向平移；松手吸附自然；不得破坏首页纵向滚动、自动轮播、详情点击、媒体行或播放器/P0 合同。
- **Accepted integration baseline**：当前真实 accepted runtime baseline 已推进到 **OnePlayer 0.14.17 / Build184** 并在 `main`。后续 carousel 包必须从当前 accepted `main` 集成，不能再用旧 carousel 分支整体状态替代 accepted Build184。

## Real-device evidence trail

- **Build179**：Code written / CI passed / IPA produced / **real-device rejected**。轻微拖动仍有死区，反向穿越中心会卡住后大跳。
- **Build180 implementation**：`DragGesture.minimumDistance = 0`；移除 4pt gate；横向 dominance 只用于第一次进入拖动，建立横向拖动后反向穿越中心不断流；移除 backdrop 前 8% delayed blend；保留单一 `V3HomeCarouselTransitionState` owner/local scope 与原 commit/cancel/auto-advance/blur 合同。
- **Build180 real-device result — PARTIAL / FAILED**：用户确认按住不松手左右反向已不再卡住，说明方向反转状态机修正有效；但起滑第一段位移仍明显过大，整体仍不够细腻丝滑，与 EX 有明显差距，因此不可接受/冻结。
- **Build183 experiment**：为验证“空间位移是否是粗糙感来源”，曾将 foreground full-width travel 改为 linear crossfade、`carouselForegroundOffset = 0`。CI/IPA 成功。
- **Build183 real-device result — PARTIAL FEEL IMPROVEMENT / INTERACTION REGRESSION / REJECTED**：用户明确反馈手感“好像比之前细腻了一些”，但同时指出 Logo、评分、年份、类型、剧情简介被固定在屏幕上，原本已经确定的“随轮播页一起横向切换”交互被未经允许改变。Build183 因交互回归不能作为正式方向。
- **Evidence correction after Build183**：用户最新真机交互要求优先。foreground 横向平移是既定交互合同，不能为了表面更顺而擅自取消。只有传统平移方案被证据证明无法达到可接受丝滑度时，用户才允许 Build183 类 foreground 固定/crossfade 作为最终兜底。

## Build185 implementation and result

- **Implementation**：Build185 从 Build180 clean carousel line 继续，恢复并锁定原 foreground slide contract；保留 `DragGesture(minimumDistance: 0)`；新增非渲染态 `V3HomeCarouselDragAxis / dragAxis`，第一次有效位移达到 **0.5pt** 时按 `abs(horizontal) >= abs(vertical)` 一次性锁定 horizontal / vertical。horizontal 锁定后使用原始 `translation.width` 连续驱动 progress，左右反向穿越中心不断流；vertical 锁定后整次触摸不让 carousel 接管，保护首页纵向 ScrollView。没有 debounce、throttle、插值、累计补偿、timer、watchdog、retry 或 fallback。
- **Established slide contract**：`carouselForegroundOpacity` 在 transition 中保持 from/to 均可见；`carouselForegroundOffset` 使用原 Build180 公式：from = `-direction * progress * width`，to = `direction * (1 - progress) * width`。Logo/评分/年份/类型/剧情简介继续与所属轮播页一起平移。
- **Unchanged**：artwork/backdrop raw blend、commit threshold `0.28`、predicted threshold `0.48 × width`、0.22/0.18s complete/cancel settle、6s auto-advance、0.62s auto transition、详情点击、persistent `.blur(radius: 30)`、首页纵向滚动、Build179 local state owner/scope 均未改变。
- **Working branch**：`perf/home-carousel-drag-smoothness-build185`；PR = none。
- **Build identity**：OnePlayer **0.14.18 / Build185**。
- **Product head before temporary CI helper**：`1297d740795dec868368e80119c562e4932abc9e`。
- **Dedicated CI source / run**：`79f74d438ed8eade5061d6f9b76df4ebdd66a344`；run **`32853247583` success**。
- **Workflow-restored branch head**：`7e7918c83fce16ada9863956179dc971f79ebe28`。
- **Artifact**：`OnePlayer-0.14.18-build185-home-carousel-axis-acquisition`；artifact ID `9565234614`；IPA SHA-256 `1f7ec2f6d09540b344ad10c36c438c4626bf40be3985d01b0d1b3404818e9b24`；MinOS 15.0。
- **Build185 real-device result — FAILED acceptance**：用户 2026-08-25 在 iPhone 15 Pro Max / iOS 17.0 再次提供两段对照录屏，第一段 `RPReplay_Final1787665181.mp4` 为 OnePlayer，第二段 `RPReplay_Final1787665268.mp4` 为 EX。用户明确报告：1）从手指按住到轮播第一次开始移动，OnePlayer 仍总有一段明显偏长的首段位移；2）持续拖动整体仍不及 EX 丝滑、细腻，体感近似“OnePlayer 像 60Hz、EX 像 120Hz”。因此 Build185 不接受、不稳定。
- **New recording format**：两段均为 510×1108 / 30 fps；OP 186 帧 / 6.20s，EX 193 帧 / 6.43s；视频时间轴本身是稳定 30fps，不能仅凭录屏宣称真实 UI 就是 60Hz 或 120Hz。
- **Quantified first-motion evidence**：跟踪前景文字/元信息的横向位置，OP 三次起滑第一帧可见位移约 **10px / 12px / 16px**；EX 三次约 **1px / 1px / 2px**。OP 第一段手势里，系统录屏触摸圆点已先横移约 **8px**，前景连续两帧仍保持原位，随后直接跳约 10px；这支持“输入先动、视觉接管后追累计 translation”的现象。
- **Quantified drag granularity**：在三段可比拖动区间内，OP 非零逐帧前景位移中位数约 **3px**、P75 约 **4px**；EX 中位数约 **1px**、P75 约 **2px**。该数据与用户“EX 更细腻”的体感一致，但由于录屏只有 30fps，不能单独用于推断真实 display refresh rate。
- **ProMotion configuration evidence**：Build185 `Config/Info.plist` 已存在 `CADisableMinimumFrameDurationOnPhone = true`；仓库已有 `DisplayRefreshRateMonitor`，其 `CADisplayLink` 目标使用 `UIScreen.main.maximumFramesPerSecond`。因此目前没有证据表明 OnePlayer 只是漏开了 >60Hz ProMotion 配置。
- **Source evidence after Build185**：当前 `DragGesture.onChanged` 第一次真正进入 horizontal transition 时，会依次修改 `fromID / toID / progress / direction` 四个独立 `@Published` 字段，并先写一次 `progress = 0`，随后同一回调再写真实 `progress`；该结构会在首次接管制造多次 transition invalidation，但目前尚不能仅凭源码证明“两帧视觉延迟”究竟来自 SwiftUI/ScrollView gesture delivery，还是 transition/view rendering。

## Next exact action

- **Do not continue threshold tuning**：Build185 已证明把 1.08 gate 改成 0.5pt 一次性锁轴仍不足以达到 EX；不再尝试 0.2pt/0.1pt 等无证据数字微调。
- **Build186 direction**：先做行为保持的诊断候选，基于当前 accepted `main@Build184` 集成 Build185 carousel contract，而不是继续沿旧 carousel 整体 branch。只增加轻量 drag cadence 采样：记录首次 `onChanged` translation、axis lock 时 translation、样本数/持续时间、平均 callback Hz、最大样本间隔；每次手势只在结束时写一条日志，避免逐帧 logging 干扰性能。
- **Decision gate**：如果 Build186 日志显示第一个 `onChanged` 本身就已经是约 8–15pt，优先处理 SwiftUI DragGesture / vertical ScrollView 的首次 gesture delivery/arbitration；如果首样本已接近 0–1pt 且 callback cadence 足够高，但视觉仍晚/粗，则优先处理 transition state 原子提交与 Hero/persistent backdrop 的 SwiftUI invalidation/compositing 成本。
- **Only after cadence evidence**：若持续拖动 callback cadence 足够而画面仍表现出明显低刷新粒度，才进入 persistent full-screen 两张 `.blur(radius: 30)` layer / Hero render scope 的 GPU/compositing 检查；不提前同时改 blur。

## Frozen / inherited boundaries

- Build176 player episode-selection/session replacement、Build178 canonical episode ordering、Build173 PiP、MPV fast Seek、UnifiedTransport、Range/302/115 客户端直连、Session cache、Cache UI、Emby progress/Resume、native navigation 均不得因本任务变化。
- Build184 已接受的详情页性能/视觉改动属于当前 overall accepted runtime；下一 carousel 候选必须继承，不能从旧 Build180/185 branch 整体状态出包。
- **Fallback policy explicitly allowed by user**：只有在保留既定容器平移交互继续验证后，若证据证明实在无法达到可接受丝滑度，才允许回到 Build183 类“foreground 固定、轮播主体 crossfade”的交互作为最终兜底。
- **Rejected / do-not-repeat**：不要恢复 4/12pt 起拖门槛；不要恢复 `1.08` 初始优势门槛；不要在已建立 horizontal drag 后重新进入中心方向 gate；不要用 debounce/throttle/补间动画掩盖跟手问题；不要擅自取消 foreground page travel；不要复用其他 Active task 的 Build 编号；不要为首页轮播修改 Player/Transport/Cache。

## Validation state

- Build179 = real-device rejected.
- Build180 = real-device partial improvement but rejected.
- Build183 = real-device feel somewhat finer but interaction regression, rejected.
- Build185 = **Code written / CI passed / IPA produced / real-device tested and rejected / not stable**.
- Build186 = not yet created; diagnostic direction defined by current real-device evidence.
