# DEV-home-carousel-drag-smoothness

## Status

**Active — Build198 real-device tested: lifecycle/settle behavior good, minimum drag still too coarse vs EX; Build200 EX-blend candidate code written and CI starting**

- **Work ID**：`DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords**：轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- **Task**：优化 OnePlayer 首页 V3 轮播图手动横向拖动，目标达到用户 EX 参考录屏同级别的丝滑、细腻和跟手，不出现起滑大跳、不跟手、卡顿、抖动、冻结后追帧或松手停在中间态。
- **Evidence sync**：2026-08-27 +08:00。
- **Current instruction**：保留 Build198 已通过真机验证的单一 UIKit 输入 owner，不再修改手势阈值/生命周期。Build200 只验证 EX 型固定空间 + progress-driven foreground blend 是否能改善最小拖动的视觉细腻度。

## Acceptance contract

1. 手指极小横向移动必须立即、细腻、连续反馈；不得先积累一段位移后突然追上。
2. 慢拖、快速拖、按住左右反向穿越中心必须连续。
3. Build198 已证明完整 page-slide 在生命周期正确后仍比 EX 粗；因此 Build200 获准把 Logo、评分、年份、类型、剧情简介改为**固定空间 + interactive linear crossfade**，直接复用现有 `transitionProgress`，不新增第二套进度状态。
4. 松手必须可靠 complete 或 cancel，绝不能冻结在两页中间。
5. Hero 区纵向滑动必须继续交给首页 `ScrollView`；详情点击正常；自动轮播正常。
6. 不得影响 Player / MPV / PiP / Transport / Cache / Emby Session / STRM→302→115/CDN client-direct 等 P0/Frozen 合同。
7. 不得用 interpolation / timer / watchdog / retry / debounce / throttle 来掩盖输入粒度或渲染问题。

## Current identities

- **Accepted overall runtime baseline**：OnePlayer **0.14.32 / Build199**，已真机接受并合并到 `main`。
- Build198 historical candidate：**OnePlayer 0.14.31 / Build198**。
- Build198 successful CI / IPA source：`a569155d443433a5f4769dfe506fec6ab9bdd0e6`。
- Build198 durable cleanup head：`c769f2c4c05fffdb36e90d78d8baddec5e0e7c21`；tested-source → cleanup-head 只有临时 CI helper 删除，产品源码不变。
- **Current carousel candidate**：OnePlayer **0.14.33 / Build200**。
- **Working branch**：`perf/home-carousel-ex-blend-build200`。
- Build200 base：Build198 durable product head `c769f2c4c05fffdb36e90d78d8baddec5e0e7c21`。
- Build200 current CI source：`4d3afe36768b7749d9d0bd0081725f3d947b2099`。
- PR：none。

## Why this architecture exists

### Build185 / Build187 — pure SwiftUI input is too coarse at drag start

- Build185 restored full-page foreground slide but target-device recordings still showed first visible page movement around **10 / 12 / 16 px** versus EX around **1 / 1 / 2 px**.
- Build187 diagnostics proved first useful SwiftUI horizontal/axis-lock samples were already about **4.33pt / 8.00pt / 15.67pt / 11.00pt**.
- Same device reported maxFPS=120 and Low Power Mode off; continuing tiny SwiftUI threshold tuning was not evidence-supported.

### Build189 / Build193 — split move/end ownership is rejected

- Build189 used native movement while SwiftUI still owned release; target device could freeze between pages after release.
- Build193 kept SwiftUI as release owner and reproduced the same freeze.
- Movement and release must not live on separate hit-test/input owners. Do not restore this architecture or patch it with timer/watchdog/reconciliation.

### Build198 — single UIKit lifecycle owner is retained

Target structure:

`one UIKit interaction surface → one complete begin/move/end/cancel owner → one carousel transition state → SwiftUI render`

Build198 behavior:

- `Sources/UI/EmbyHomeCarouselInteractionV3.swift` is the single native lifecycle owner.
- First meaningful raw motion uses about **0.5pt** only for axis acquisition.
- Vertical acquisition fails the carousel recognizer so Home `UIScrollView` remains authoritative; horizontal acquisition owns the gesture through end/cancel.
- Rendering publishes only the latest actual touch position once per UIEvent; coalesced touches are not replayed into multiple state publications.
- Predicted touch is used only for release prediction, not to render ahead of the finger.
- Commit/cancel semantics remain progress **0.28**, predicted-distance gate **0.48 × width**, and the existing settle durations.
- High-frequency transition ownership remains local to `V3HomeCarouselTransitionState`.

### Build198 target-device result — 2026-08-27

User result on the verified Build198 IPA:

- **minimum/subtle drag smoothness: rejected** — “最小丝滑还是没变化，比较大，细腻程度还是感觉比 EX 差了一些”；
- **other tested behavior: okay** — no new complaint about release/cancel, committed settle, repeated reversal, vertical Hero scroll, detail tap or auto-advance.

Conclusion:

- Stage 1 successfully removed the split-owner lifecycle failure mode and is now the retained input foundation.
- Stage 1 did **not** make the minimum visible page-slide fine enough.
- Do **not** change the UIKit recognizer, 0.5pt axis acquisition, release prediction, 0.28 commit threshold, 0.48-width gate, or settle ownership in response to this result.
- The remaining problem is the visual mapping: a small normalized progress mapped to `progress × fullWidth` produces visible multi-point spatial movement even when input ownership is correct.

Evidence level:

**Build198 = Code written ✅ / CI passed ✅ / IPA produced + verified ✅ / real-device tested ✅ / lifecycle & other tested behavior acceptable / minimum smoothness rejected / not stable.**

## EX visual evidence and Build200 decision

EX reference review previously showed outgoing/incoming Hero content remains effectively spatially fixed while blend weight changes continuously. With a roughly 510pt Hero width, even 1% normalized page-slide progress becomes about 5pt of spatial movement; the same progress expressed as opacity blend does not create that large spatial jump.

Build183 had already demonstrated the fixed-foreground crossfade direction can feel finer, but it was rejected then because changing page-slide semantics was premature. Build198 has now satisfied the prerequisite: the correct single-owner lifecycle is stable in the user's real-device test, yet the minimum page-slide still feels coarser than EX. Therefore the previously conditional EX-style fallback is now evidence-supported and authorized for Build200.

## Build200 — fixed-spatial foreground + linear blend

Build200 is intentionally a **visual-mapping-only** delta on top of Build198:

- version/build becomes **0.14.33 / 200**;
- `carouselForegroundOpacity(for:)` now uses the same clamped `transitionProgress` blend as the backdrop:
  - outgoing = `1 - blend`;
  - incoming = `blend`;
- `carouselForegroundOffset(for:width:)` returns `0`, so Logo/rating/year/type/overview no longer translate by full Hero width during an interactive transition;
- backdrop behavior is structurally unchanged because it already used progress-driven crossfade;
- `EmbyHomeCarouselInteractionV3.swift` is unchanged;
- `EmbyHomeHeroV3.swift` and `EmbyHomeCoreV3.swift` are unchanged;
- gesture axis arbitration, tap routing, vertical scrolling, thresholds, predicted-release behavior, settle durations and auto-advance are unchanged.

Build200 delta from Build198 durable head before CI helper:

- `Sources/Core/AppIdentity.swift`
- `Sources/UI/EmbyHomeCarouselStateV3.swift`
- `docs/changelog/CHANGELOG_v0_14_33_build200.md`
- `scripts/check_home_carousel_single_owner.py`

The runtime/product change is only `AppIdentity.swift` + `EmbyHomeCarouselStateV3.swift`. No Player / MPV / PiP / UnifiedTransport / Cache / Emby Session path is touched.

## Build198 CI / packaging evidence

- Workflow：`Build198 Carousel Single Owner IPA`
- Successful run：`32987054824`
- Job：`98235720724`
- Source：`a569155d443433a5f4769dfe506fec6ab9bdd0e6`
- Result：success through source contract, diff/Frozen guard, Xcode 16.4, icon generation, dependency resolution, Release build, built-app validation, MinOS validation, IPA/source packaging and artifact upload.

Verified Build198 artifact:

- Artifact：`OnePlayer-0.14.31-build198-home-carousel-single-owner`
- Artifact ID：`9613342337`
- Artifact digest：`sha256:4597f6b9bcdd74a44441632f72c5c4b9127aab03e3dad7e38478c552cae773f3`
- IPA：`OnePlayer-0.14.31-build198-home-carousel-single-owner-unsigned.ipa`
- IPA SHA-256：`9432928b31898c0c3f05e7e0affb6949c23339a37edd8f14c1d47343ff31f3d8`
- Source ZIP SHA-256：`00e3fd353c487d185469a2bd9679031cc8a3da9829b310281d8e638c10cd046d`
- Bundle：`com.embyplayerlab.app`
- Version/build：`0.14.31 / 198`
- `MinimumOSVersion` / executable minOS：`15.0`

## Build200 CI / packaging state

- Feature CI source：`4d3afe36768b7749d9d0bd0081725f3d947b2099`.
- A scoped Build200 workflow was added on the feature branch.
- Because GitHub Actions event registration has recently been delayed, a one-shot `main` CI helper was also created to checkout **exactly** `4d3afe36768b7749d9d0bd0081725f3d947b2099`; it must be deleted after the Build200 run is captured.
- Required gates: Build200 contract script, exact Build198→Build200 delta/Frozen guard, Xcode 16.4 Release build, app identity `0.14.33 (200)`, MinOS `15.0`, IPA ZIP verification, source snapshot and artifact upload.
- Until those gates actually pass, Build200 remains **Code written only; CI/IPA not yet claimed**.

## Build200 target-device validation — next exact action after IPA

1. Tiny initial horizontal drag: compare minimum visible change directly against Build198 and EX.
2. Slow micro-drag around center: check whether opacity progression feels continuous rather than producing a spatial jump.
3. Small drag + release: must cancel completely.
4. Committed drag / fast flick: must complete completely.
5. Hold and reverse through center repeatedly: no pause/freeze/catch-up.
6. Vertical drag on Hero, detail tap and auto-advance must remain unchanged from Build198.
7. Compare portrait and landscape subjective `drag / visual continuity / settle` with EX.

If Build200 still feels coarse, do not immediately add smoothing/interpolation. First determine whether the remaining perceptual difference comes from actual `transitionProgress` publication cadence, opacity/compositing cost, or EX having a different blend curve. Any next code change requires new evidence.

## Protected contracts

Do not modify for this task unless new direct evidence requires it:

- immediate left/right double-tap MPV Seek and rapid repeated double-tap behavior;
- STRM / HTTP 302 / 115-CDN client-direct media path;
- HTTP Range / 206 and session cache;
- Emby Resume/progress synchronization;
- abnormal short-media / premature EOF tolerance and diagnostics;
- MPV primary playback path;
- PiP frozen architecture;
- no NAS media-byte relay;
- never restore `targetTime / duration × fileSize` as a Seek/Transport anchor.
