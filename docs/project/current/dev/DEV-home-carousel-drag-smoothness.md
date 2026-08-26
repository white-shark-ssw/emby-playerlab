# DEV-home-carousel-drag-smoothness

## Status

**Active — handoff ready**

- **Work ID**：`DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords**：轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- **Task**：优化 OnePlayer 首页 V3 轮播图手动横向拖动，目标达到用户 EX 参考录屏同级别的丝滑、细腻和跟手，不出现起滑大跳、不跟手、卡顿、抖动、冻结后追帧或松手停在中间态。
- **Handoff time**：2026-08-26 22:05 +08:00。
- **User handoff instruction**：当前会话停止继续构建/修改；新会话从本文档接手。后续不要猜、不要重复无效 CI；先定位 Build198 post-build validation 的真实失败原因，直到生成并校验 IPA 后再发给用户。

## Acceptance contract

1. 手指极小横向移动必须立即、细腻、连续反馈；不得先积累一段位移后突然追上。
2. 慢拖、快速拖、按住左右反向穿越中心必须连续。
3. Logo、评分、年份、类型、剧情简介属于对应轮播页，默认必须继续随页面整体横向平移。
4. 松手必须可靠 complete 或 cancel，绝不能冻结在两页中间。
5. Hero 区纵向滑动必须继续交给首页 `ScrollView`；详情点击正常；自动轮播正常。
6. 不得影响 Player / MPV / PiP / Transport / Cache / Emby Session / STRM→302→115/CDN client-direct 等 P0/Frozen 合同。
7. Build183 类“前景固定 + interactive crossfade”只有在正确的 page-slide 基础框架真机稳定后仍无法达到可接受细腻度时，才是用户明确允许的最终 fallback；不得未经允许提前改交互。

## Current accepted / parallel identities

- **Accepted overall runtime baseline**：OnePlayer **0.14.28 / Build195**。
- `main` current head at handoff：`3c0782c93c37bedf4193a76648c9c7ecff91a9e3`；Build195 PR #258 已合并，玩家大选集 LazyHStack/SeasonId 分组已真机接受。
- Parallel Active task：`DEV-add-emby-page-optimization`，working branch `feat/add-emby-page-optimization`，**Build197 / 0.14.30 已由该任务占用**。不要复用 Build197。
- Carousel current candidate：**OnePlayer 0.14.31 / Build198**。
- Carousel working branch：`perf/home-carousel-single-owner-build198`。
- PR：none。
- Branch head at handoff：**`2a3cec5f3d004db0617aa5a1c3417701a96d5140`**。
- Resume identity guard result at handoff：Build198 branch head 与 CI source 一致；branch 相对 `main@3c0782c9...` ahead 11 / behind 0。

## Why the architecture changed

### Build185 / Build187 — pure SwiftUI input is too coarse at drag start

- Build185 restored the required full-page foreground slide and removed old 4pt/1.08 start gates, but target-device recordings still showed first visible page movement around **10 / 12 / 16 px** versus EX around **1 / 1 / 2 px**.
- Build187 real-device diagnostics proved the source of the initial quantization: SwiftUI reported an initial `0,0`, but the first useful horizontal/axis-lock/transition samples were already approximately **4.33pt / 8.00pt / 15.67pt / 11.00pt**.
- Same device logs confirmed `UIScreen.main.maximumFramesPerSecond = 120` and Low Power Mode off. Therefore continued 0.5/0.2/0.1pt threshold tuning is not evidence-supported; SwiftUI `DragGesture` in the vertical `ScrollView` path is not delivering sufficiently fine first horizontal samples.

### Build189 / Build193 — hybrid move/end ownership is invalid

- Build189 used native raw/coalesced movement while SwiftUI still owned release. Target device could drag to partial progress but release could leave the carousel frozen between pages.
- Build193 tried making the native sampler passive and leaving SwiftUI as the sole release owner. Target device reproduced the same freeze.
- Source layout showed movement and release lived on different input/hit-test surfaces: native interactive overlay above Hero + underlying SwiftUI gesture. This hybrid architecture is rejected. Do not patch it with timer/watchdog/reconciliation/fallback.
- Build193 playback-log follow-up was inconclusive because Playback logging was disabled; absence of `HomeCarouselDragTiming` is not evidence for or against SwiftUI `onEnded`. Do not ask user to repeat Build193 just for that log.

### EX forensic evidence

Repeated frame/template review of the EX reference recording shows outgoing/incoming Hero content is effectively **spatially fixed** during transitions (matched title regions ≈0 px horizontal shift; background ≈0–1 px) while blend weight changes continuously. In a slow transition the estimated blend increment is about **1% per 30fps recorded frame median**. Mapping the same normalized 1% progress to OnePlayer's ~510pt full-width slide produces about **5pt spatial movement**, explaining why the same input granularity looks much harsher under page translation.

This explains why Build183 fixed/crossfade felt somewhat finer, but the user rejected its unauthorized interaction change. Current order remains: first prove a correct single-owner page-slide; only if that stable implementation still cannot approach EX feel may the user-authorized fixed-spatial interactive blend be adopted as fallback.

## Build198 Stage 1 — single UIKit lifecycle owner

### Goal

Stage 1 changes **only gesture lifecycle ownership**. Do not combine this with transition-state atomization, blur/compositing changes, predicted-touch rendering, interpolation/smoothing, crossfade, timer, watchdog, debounce, throttle, retry or fallback.

Target structure:

`one UIKit interaction surface → one complete begin/move/end/cancel owner → existing carousel transition state → SwiftUI render only`

### Implemented behavior

- New `Sources/UI/EmbyHomeCarouselInteractionV3.swift` provides the native carousel interaction layer/custom continuous recognizer.
- Hero no longer relies on a separate SwiftUI drag lifecycle for manual carousel movement/release. The native interaction surface owns the horizontal gesture from begin through move to end/cancel.
- The same interaction surface coordinates detail tap and horizontal drag; do not reintroduce overlapping native-move + SwiftUI-end ownership.
- First meaningful raw motion uses approximately **0.5pt** only to determine direction. Vertical determination fails the carousel recognizer so the ancestor homepage `UIScrollView` remains authoritative; horizontal determination begins the carousel gesture and owns it through release.
- Build193-style unconditional simultaneous recognition is not the intended model. Horizontal carousel recognition and vertical ScrollView arbitration are explicit.
- Rendering publishes only the **latest actual touch position once per UIEvent**. Do not loop historical `coalescedTouches` and publish multiple SwiftUI progress values in one event.
- Predicted touch information is not used to render ahead of the finger. It is retained only for release prediction/commit semantics so the existing fast-flick behavior can remain equivalent without inventing an arbitrary velocity magic number.
- Existing commit/cancel semantics remain: progress threshold **0.28**, predicted-distance gate corresponding to **0.48 × width**, existing complete/cancel settle durations, auto-advance and artwork/backdrop behavior.
- Foreground page-slide contract remains unchanged: from/to Logo/rating/year/type/overview travel with their page; no Build183 fixed foreground/crossfade in Stage 1.
- High-frequency carousel transition ownership remains local to `V3HomeCarouselTransitionState`; do not move per-finger progress/from/to/drag state back to Home root.

### Build198 diff against accepted main

Current branch compared with `main@3c0782c93c37bedf4193a76648c9c7ecff91a9e3` changes exactly these paths:

- `.github/workflows/temp-build198-carousel-ci.yml` — **temporary CI helper; still present at current branch head and must be removed/restored after final valid Build198 CI**.
- `Sources/Core/AppIdentity.swift`
- `Sources/UI/EmbyHomeCarouselInteractionV3.swift` — new native single-owner interaction layer.
- `Sources/UI/EmbyHomeCarouselStateV3.swift`
- `Sources/UI/EmbyHomeCoreV3.swift`
- `Sources/UI/EmbyHomeHeroV3.swift`
- `docs/changelog/CHANGELOG_v0_14_31_build198.md`
- `scripts/check_home_carousel_single_owner.py`

No intended changes to Player / MPV / PiP / UnifiedTransport / Cache / Emby Session / Add/Edit Emby product files.

## Build198 validation history

### Earlier dedicated-CI attempts

Two early attempts stopped before real compile because old repository checks were already stale relative to accepted Build195 `main`:

1. old `check_home_immersive_carousel.py` still expected `AdaptiveHeroRevealMetrics.backdropPinOffset`, while current accepted main had already moved that calculation into Hero-local source;
2. old `check_home_horizontal_tap_routing.py` still searched `EmbyServerRootViewV3.swift` for `private func landscapeRow`, which is no longer true on accepted main.

Do **not** mutate Build198 product code merely to satisfy those historical script assumptions. The third dedicated workflow was intentionally scoped to the new Build198 single-owner contract + Python syntax + exact diff/Frozen guard + real Xcode Release/MinOS/IPA pipeline.

### Current effective CI attempt

- Workflow：`Build198 Carousel Single Owner IPA`
- Workflow file：`.github/workflows/temp-build198-carousel-ci.yml`
- Run：**`32890283594`**
- Job：**`97940357582`**
- Event：push
- Source/head SHA：**`2a3cec5f3d004db0617aa5a1c3417701a96d5140`**
- Conclusion：**failure**

Evidence reached in this run:

- Build198 dedicated single-owner source contract: **PASS**.
- Python syntax / exact scope / P0-Frozen diff guard: **PASS**.
- Xcode 16.4 environment / dependency resolution: **PASS**.
- **Real Xcode Release compilation: PASS**. This is important: current evidence does not justify changing the gesture/runtime source because Swift/UIKit compilation succeeded.
- Failure occurs **after Release compile**, at step **`Locate and validate app`**.
- IPA packaging/upload did not complete; **Build198 currently has no valid IPA artifact and must not be described as CI passed or IPA produced**.

Current evidence level:

**Build198 = Code written ✅ / scoped contract ✅ / diff-Frozen guard ✅ / Release compile ✅ / post-build app validation ❌ / IPA not produced / real-device not tested / not stable.**

## Critical do-not-do list for the next session

- Do not restart the carousel design from Build193.
- Do not change the Build198 gesture/runtime source merely because CI is red; Release compilation already passed.
- Do not rerun CI blindly before identifying the exact `Locate and validate app` failure.
- Do not re-enable stale old test assumptions by modifying accepted product source.
- Do not add timer/watchdog/retry/fallback/interpolation/debounce/throttle.
- Do not combine Stage 1 with atomic transition snapshot work, blur optimization, predicted-touch rendering or EX crossfade fallback.
- Do not change Player/Transport/Cache/PiP/Emby media byte path.
- Do not reuse Build197 or another Active task's candidate identity.
- Do not claim Build198 is solved until target-device acceptance.

## Next exact action — new session starts here

1. New session routes explicitly to **`DEV-home-carousel-drag-smoothness`** and re-reads `AGENTS.md`, `START_HERE.md`, `CURRENT_WORK.md`, `CURRENT_WORK_DEV.md`, this checkpoint, current `MODULE_STATUS.md`, `PROJECT_STATE.md`, `TECHNICAL_DECISIONS.md`, `BUILD_TEST_INDEX.md`.
2. Re-run resume identity guard before any write: confirm `main` has not materially advanced, carousel branch remains `perf/home-carousel-single-owner-build198@2a3cec5f...`, Build198 remains unique, and parallel Build197/other Active candidates have not collided.
3. **First technical action is not a code change:** fetch the decoded logs for Job `97940357582` and inspect the exact output of step `Locate and validate app`. Also inspect that step's actual shell in `.github/workflows/temp-build198-carousel-ci.yml` and compare its assumed `.app` path / identity checks with the Xcode Release output path.
4. Only if the log directly proves a CI/packaging-path or identity-validation bug, make the smallest workflow/packaging fix. Do not touch gesture product source unless the log explicitly proves a product-side app build/identity problem.
5. Re-run the dedicated Build198 Release pipeline only after that evidence-based fix. Required final gates: single-owner contract, exact diff/Frozen guard, Xcode Release build, app identity **0.14.31 (198)**, `MinimumOSVersion = 15.0`, unsigned IPA packaging, artifact upload.
6. After success, restore/remove `.github/workflows/temp-build198-carousel-ci.yml` from the durable feature branch, without altering the successful CI source attribution.
7. Download the artifact and independently verify: artifact ZIP integrity, `Payload/*.app`, `CFBundleShortVersionString=0.14.31`, `CFBundleVersion=198`, `MinimumOSVersion=15.0`, IPA SHA-256 and source ZIP SHA-256.
8. Update this checkpoint plus relevant `PROJECT_STATE.md` / `MODULE_STATUS.md` / `TECHNICAL_DECISIONS.md` / `BUILD_TEST_INDEX.md` with **CI passed / IPA produced only**; do not mark real-device solved.
9. Send the verified Build198 IPA to the user. Target-device Stage-1 validation order: tiny initial drag → small drag release must cancel fully → committed/fast flick must complete fully → hold and reverse through center → vertical Hero scroll → detail tap → compare continuous feel with EX.
10. If Stage 1 lifecycle is real-device stable but page-slide remains perceptually much coarser than EX, only then consider Stage 2 transition-publication/atomicity. If a correct Stage 1+subsequent page-slide path still cannot approach EX, the user-authorized fixed-spatial interactive crossfade is the evidence-supported fallback.

## Evidence labels at handoff

- Build185：real-device rejected — coarse initial page movement.
- Build187：real-device diagnostic confirmed — SwiftUI first useful samples already 4–16pt, maxFPS=120.
- Build189：real-device rejected — native movement + SwiftUI release could freeze.
- Build193：real-device rejected — passive native movement + underlying SwiftUI release still froze; hybrid ownership rejected.
- Build198：**current Stage-1 single-owner candidate; Release source compiles, post-build validation unresolved, no IPA yet, no real-device result.**
