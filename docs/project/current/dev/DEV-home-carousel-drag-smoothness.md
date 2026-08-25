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
- **Dedicated CI source / run**：`79f74d438ed8eade5061d6f9b76df4ebdd66a344`；run **`32853247583` success**。
- **Artifact**：`OnePlayer-0.14.18-build185-home-carousel-axis-acquisition`；artifact ID `9565234614`；IPA SHA-256 `1f7ec2f6d09540b344ad10c36c438c4626bf40be3985d01b0d1b3404818e9b24`；MinOS 15.0。
- **Build185 real-device result — FAILED acceptance**：用户 2026-08-25 在 iPhone 15 Pro Max / iOS 17.0 提供两段对照录屏，第一段 `RPReplay_Final1787665181.mp4` 为 OnePlayer，第二段 `RPReplay_Final1787665268.mp4` 为 EX。用户明确报告：1）从手指按住到轮播第一次开始移动，OnePlayer 仍总有一段明显偏长的首段位移；2）持续拖动整体仍不及 EX 丝滑、细腻，体感近似“OnePlayer 像 60Hz、EX 像 120Hz”。因此 Build185 不接受、不稳定。
- **New recording format**：两段均为 510×1108 / 30 fps；OP 186 帧 / 6.20s，EX 193 帧 / 6.43s；视频时间轴本身稳定 30fps，不能仅凭录屏宣称真实 UI 就是 60Hz 或 120Hz。
- **Quantified first-motion evidence**：跟踪前景文字/元信息横向位置，OP 三次起滑第一帧可见位移约 **10px / 12px / 16px**；EX 三次约 **1px / 1px / 2px**。OP 第一段手势里，录屏触摸圆点已先横移约 **8px**，前景连续两帧仍保持原位，随后直接跳约 10px；支持“输入先动、视觉接管后追累计 translation”的现象。
- **Quantified drag granularity**：OP 非零逐帧前景位移中位数约 **3px**、P75 约 **4px**；EX 中位数约 **1px**、P75 约 **2px**。该数据与用户“EX 更细腻”的体感一致，但 30fps 录屏不能单独用于推断真实 display refresh rate。
- **ProMotion configuration evidence**：Build185 `Config/Info.plist` 已存在 `CADisableMinimumFrameDurationOnPhone = true`；仓库已有 `DisplayRefreshRateMonitor`，其 `CADisplayLink` 目标使用 `UIScreen.main.maximumFramesPerSecond`。目前没有证据表明 OnePlayer 只是漏开 >60Hz ProMotion 配置。
- **Source evidence after Build185**：第一次真正进入 horizontal transition 时会依次修改 `fromID / toID / progress / direction` 多个独立 `@Published` 字段，并先写一次 `progress = 0`，同一回调末尾再写真实 `progress`；该结构可能制造首次 transition invalidation，但不能仅凭源码区分 gesture delivery 延迟与 render/compositing 延迟。

## Build186 diagnostic candidate

- **Direction**：不再做 0.2pt/0.1pt 等阈值微调，也不改变既定 full-page foreground slide。Build186 从当前 accepted Build184 `main` 集成 Build185 carousel owner/0pt/axis/reversal/raw-progress 合同，并仅新增被动 drag cadence 诊断。
- **Branch**：`perf/home-carousel-drag-cadence-build186`；PR = none。
- **Build identity**：**OnePlayer 0.14.19 / Build186**。
- **Accepted base**：`main@dcd6cc6d01319e13ccb991967a190ae1f915053b`，继承 Build184 已接受的 detail performance/cache/visual hierarchy。
- **Product head before temporary CI helper**：`22434e79ca8476af326a3427d16fc0390c98e94d`。
- **Dedicated CI source / run**：`80d7b8b503d10bd8d10d62714afa9557a5988ab4`；run **`32858062142` success**。
- **Workflow-restored branch head**：`2ba1ad1f1d9e05b0fe8075226de3695a7b2a2b71`。
- **CI coverage**：Build185 carousel contracts、accepted Build184 integration、detail performance/visual hierarchy、series ordering、ProMotion opt-in、Xcode 16.4 Release device build、0.14.19 (186) identity、MinOS 15.0、IPA packaging/upload 全部通过。
- **Diagnostic behavior**：每次拖动记录首个 `onChanged` translation、axis lock translation、transition start translation、样本数、持续时间、平均 callback Hz、最大 callback gap、`UIScreen.main.maximumFramesPerSecond` 与 Low Power Mode 状态；拖动过程中不逐帧写日志，只在结束时写一条 `HomeCarouselDragTiming`，避免 logging 本身干扰手感。
- **Artifact**：`OnePlayer-0.14.19-build186-home-carousel-drag-timing`；artifact ID **`9567101523`**；artifact digest `sha256:9df143abb6935702e55516ce9ba042220080142c7dfb304b9e53d36548c4f3c7`。
- **IPA**：`OnePlayer-0.14.19-build186-home-carousel-drag-timing-unsigned.ipa`；下载后二次 SHA-256 = **`08cdf0398e024f8cc64dd75b2e6dfecab2b26833807feb810e280034b345f780`**，与 artifact 内校验文件一致。
- **Source ZIP SHA-256**：`47c9b3c1c0870e3c0be7615efc850f8ec32093ff8d653070339cb541c71b1ae2`，下载后二次校验一致。
- **Decision gate**：如果首个 `onChanged` 本身约 8–15pt，优先处理 SwiftUI DragGesture / vertical ScrollView 首次 delivery/arbitration；如果首样本约 0–1pt 且 callback cadence 足够高，但视觉仍晚/粗，则优先处理 transition state 原子提交和 Hero/persistent backdrop SwiftUI invalidation/compositing；只有 cadence 足够而画面仍低粒度，才进入两张 full-screen `.blur(radius: 30)` layer 的 GPU/compositing 检查。

## Frozen / inherited boundaries

- Build176 player episode-selection/session replacement、Build178 canonical episode ordering、Build173 PiP、MPV fast Seek、UnifiedTransport、Range/302/115 客户端直连、Session cache、Cache UI、Emby progress/Resume、native navigation 均不得因本任务变化。
- Build184 已接受的详情页性能/视觉改动属于当前 overall accepted runtime；Build186 已从当前 accepted `main` 集成，不再从旧 Build180/185 branch 整体状态出包。
- **Fallback policy explicitly allowed by user**：只有在保留既定容器平移交互继续验证后，若证据证明实在无法达到可接受丝滑度，才允许回到 Build183 类“foreground 固定、轮播主体 crossfade”的交互作为最终兜底。
- **Rejected / do-not-repeat**：不要恢复 4/12pt 起拖门槛；不要恢复 `1.08` 初始优势门槛；不要在已建立 horizontal drag 后重新进入中心方向 gate；不要用 debounce/throttle/补间动画掩盖跟手问题；不要擅自取消 foreground page travel；不要复用其他 Active task 的 Build 编号；不要为首页轮播修改 Player/Transport/Cache。

## Validation state

- Build179 = real-device rejected.
- Build180 = real-device partial improvement but rejected.
- Build183 = real-device feel somewhat finer but interaction regression, rejected.
- Build185 = **Code written / CI passed / IPA produced / real-device tested and rejected / not stable**.
- Build186 = **Code written / CI passed / IPA produced / not distributed for diagnosis / not stable**.
- Build187 = **Code written / CI passed / IPA produced / real-device tested / diagnostic gate confirmed / not stable**.
- Build189 = **Code written / CI passed / IPA produced / real-device pending / not stable**.


## Build187 final diagnostic package

- Build186 CI/IPA succeeded but was not distributed after confirming `HomeCarouselDragTiming` generic logging would not be included in the existing playback-log export.
- Build187 / OnePlayer 0.14.20 keeps Build186/Build185 drag behavior unchanged and routes only that summary through `DiagnosticsLogger.shared.playback(...)`.
- branch `perf/home-carousel-drag-cadence-build187`; CI source `6d562b2f5cf76be41cb0e763c8f3c50c4f0d724f`; restored head `468986492f639959f7f31129dadf5b49e781d37f`; run `32860057516` success.
- artifact `9567940931`; IPA SHA-256 `5fa04513919b5e2928ee2ca09cf45dddc79c91d64858971f571b423dbb2d50f8`; source ZIP SHA-256 `70ef0df0ef48c9be558674cfd892a39e9836780602992e482f2f0d806d24d40a`; MinOS 15.0.
- validation: **Code written / CI passed / IPA produced / real-device tested / diagnostic gate confirmed / not stable**.
- **Build187 real-device result — DIAGNOSIS CONFIRMED**：iPhone 15 Pro Max / iOS 17.0 真机导出日志显示每次触摸先出现 `first=0.00,0.00`，但第一次真正可用的 horizontal / axis-lock / transition 位移已经分别约为 **4.33pt / 8.00pt / 15.67pt / 11.00pt**；`lock` 与 `transition` 位移相同，说明 carousel 第一次能够建立横向 transition 时，手指位移已经累计了数点到十余点。日志同时确认 `maximumFramesPerSecond=120`、Low Power Mode = false。
- **Build187 conclusion**：0.5pt 阈值没有机会成为实际首段响应粒度；当前纵向 `ScrollView` 场景下 SwiftUI `DragGesture` 没有向 carousel 提供 0.5/1/2pt 级别的有效首段横向样本。停止继续做 0.2pt/0.1pt 等阈值微调，后续只针对输入采样层做最小替换。

## Build188 identity collision / Build189 native-touch candidate

- **Identity guard**：并行 Active `DEV-detail-episode-selection-navigation` 已正式占用 **OnePlayer 0.14.21 / Build188**，并已有独立成功 CI/IPA。因此此前 carousel native-touch 的 0.14.21 / Build188 包发生 Build 身份冲突，**不得分发、不得用于真机或日志归因**；其产品逻辑虽通过 CI，但该身份作废。
- **Valid carousel identity**：carousel native-touch 候选顺延为唯一的 **OnePlayer 0.14.22 / Build189**；GitHub 搜索及并行 checkpoint 核对时 Build189 未被其他 Active task 占用。
- **Architecture**：只替换手动拖动的输入采样层。新增 UIKit `UIGestureRecognizer` 从 `touchesMoved` 读取 `event.coalescedTouches(for:)`，第一次约 0.5pt 有效向量锁定横向/纵向；横向仍按 `abs(translation) / width` 一对一驱动既有 transition progress。recognizer 不 cancel/delay touches，并允许与纵向 ScrollView simultaneous recognition。
- **Release semantics unchanged**：原 SwiftUI `DragGesture(minimumDistance: 0)` 保留，继续使用原 `predictedEndTranslation.width`、0.28 progress / 0.48×width predicted commit 门槛以及原 complete/cancel settle；Logo、评分、年份、类型、剧情简介继续与所属轮播页整页横向平移。没有 debounce、throttle、插值、累计补偿、timer、watchdog、retry 或 fallback。
- **Branch**：`perf/home-carousel-native-touch-build189-from187`；PR = none。
- **Build identity**：**OnePlayer 0.14.22 / Build189**。
- **Product head before temporary CI helper**：`36bfd4c1600add86dccc0f9917eea28dc39173f4`。
- **Dedicated CI source / run**：`7ddb4453abdf671c936a7f42d72fb837d943cc73`；run **`32868634314` success**。
- **Workflow-restored branch head**：`c3b122f6f2934dc5c32c67e0fcae392a5c13cd14`。
- **Artifact**：`OnePlayer-0.14.22-build189-home-carousel-native-touch`；artifact ID **`9571260479`**；artifact digest `sha256:e33fdc0b4b185b3062e43ee3e506ff40399a8dbee8872c5344a1b7a4a9b65726`。
- **IPA**：`OnePlayer-0.14.22-build189-home-carousel-native-touch-unsigned.ipa`；下载后二次 SHA-256 = **`50c74bd43935a31ca3dda781c04a1113c2ce616c7da9e24e438cba78988c3a6d`**，与 artifact 内 `.sha256` 一致。Source ZIP SHA-256 = **`ae7b226aa20063700f3a0964714b2a89fe5e7c0eee4bf8b5cae371e432c791e4`**。
- **CI coverage**：native/coalesced touch、simultaneous ScrollView、原 page-slide/predicted release commit、Build183 fixed-foreground 拒绝合同、ProMotion opt-in、Build184 detail 与 P0/Frozen zero-diff、Xcode 16.4 Release、0.14.22 (189) identity、MinOS 15.0、IPA packaging/upload 均通过。
- **Evidence**：**Code written / CI passed / IPA produced / real-device pending / not stable**。
- **Next exact action**：安装 Build189，在 iPhone 15 Pro Max / iOS 17.0 重点验证极小起滑、慢短拖、正常/快速拖、按住左右反向穿越中心、Hero 区纵向滚动和详情点击。核心判据是第一段可见位移是否从“累计 4–16pt 后才动”变为立即、细粒度跟手。


## Build189 real-device release regression / Build190 candidate

- **Build189 real-device result — REJECTED**：用户安装 0.14.22 / Build189 后提供 `RPReplay_Final1787675510.mp4`（510×1108 / 30 fps / 9.07 s），明确报告“不能完整切换，滑到哪里就定格在那里”。录屏多次显示手动 progress 能随拖动到中间位置，但松手后没有 complete/cancel settle，页面停在两页之间。
- **Source evidence**：Build189 native recognizer 横向采样时进入 `.began/.changed`，而 complete/cancel 的唯一入口仍是 SwiftUI `carouselDragGesture(...).onEnded`，形成结束所有权竞争。
- **Build190 architecture**：native raw/coalesced sampler 保留，但横向时保持 passive；`canPrevent` / `canBePrevented` 均为 false，touch end/cancel 只令 sampler `.failed`。SwiftUI `DragGesture` 删除全部 per-frame `onChanged` progress 写入，只保留原 `onEnded`、`predictedEndTranslation`、0.28 / 0.48×width commit 与原 complete/cancel。移动 progress 单 owner = native；release settle 单 owner = SwiftUI。
- **Build / branch**：OnePlayer **0.14.23 / Build190**；`fix/home-carousel-native-release-build190`。
- **CI source / run**：`8effb767af988c9bb4e6230ffc8b1a7f664c2619`；run **`32873473886` success**；Release workflow restored at `817897ef6bd95d710657c3d12acc4d48ec8f2d39`.
- **Artifact**：`OnePlayer-0.14.23-build190-home-carousel-native-release`；ID `9573068806`；digest `sha256:355afc63f6b87251fce6c200af4796733bff8b947a27e71293e596745467437e`。IPA SHA-256 **`873abefa8c585ba577222a00d6feb99639bf3aa60861334d178eb8b4a26a24ba`**；source ZIP SHA-256 `e9491fbf27610421d46e1fd1325be1d8d86c6e6d7010adfd721ae542a34fd0cb`；MinOS 15.0。
- **Evidence**：Build189 = **real-device rejected / not stable**；Build190 = **Code written / CI passed / IPA produced / real-device pending / not stable**。
- **Next exact action**：真机先验证松手必定完整 commit/cancel，再重新比较极小起滑、慢拖、连续反向与 EX 的细腻度。
