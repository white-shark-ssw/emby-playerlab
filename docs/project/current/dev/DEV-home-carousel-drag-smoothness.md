# DEV-home-carousel-drag-smoothness

## Status

**Active — Build198 CI scheduling blocked before job creation; IPA not produced**

- **Work ID**：`DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords**：轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- **Task**：优化 OnePlayer 首页 V3 轮播图手动横向拖动，目标达到用户 EX 参考录屏同级别的丝滑、细腻和跟手，不出现起滑大跳、不跟手、卡顿、抖动、冻结后追帧或松手停在中间态。
- **Evidence sync**：2026-08-27 +08:00。
- **Current instruction**：继续完成 Build198 IPA，但禁止盲目重复 CI。必须固定真实 run/job/SHA 取证；只有明确失败证据支持时才改 workflow 或源码。当前连接器无法 dispatch 新 workflow，也不能重跑 queued/0-job run，因此在 GitHub Actions 调度阻塞被解释或解除前，不再制造触发提交。

## Acceptance contract

1. 手指极小横向移动必须立即、细腻、连续反馈；不得先积累一段位移后突然追上。
2. 慢拖、快速拖、按住左右反向穿越中心必须连续。
3. Logo、评分、年份、类型、剧情简介属于对应轮播页，默认必须继续随页面整体横向平移。
4. 松手必须可靠 complete 或 cancel，绝不能冻结在两页中间。
5. Hero 区纵向滑动必须继续交给首页 `ScrollView`；详情点击正常；自动轮播正常。
6. 不得影响 Player / MPV / PiP / Transport / Cache / Emby Session / STRM→302→115/CDN client-direct 等 P0/Frozen 合同。
7. Build183 类“前景固定 + interactive crossfade”只有在正确的 page-slide 基础框架真机稳定后仍无法达到可接受细腻度时，才是用户明确允许的最终 fallback；不得未经允许提前改交互。

## Current accepted / parallel identities

- **Accepted overall runtime baseline**：OnePlayer **0.14.32 / Build199**，已真机接受并合并到 `main`。
- `main` at this evidence capture：`bd1cb7ea3a2be161e13503b88c8a69f5b9441e9e`；Build199 product merge is already accepted, and later documentation/checkpoint cleanup commits do not change that accepted product identity.
- Carousel current candidate：**OnePlayer 0.14.31 / Build198**。
- Carousel working branch：`perf/home-carousel-single-owner-build198`。
- PR：none。
- Current carousel branch head：**`294a5b8d993d753690fcaa71a0b5d790b81babe1`**。
- Current branch relationship to `main@bd1cb7e...`：**ahead 13 / behind 70**, merge base `3c0782c93c37bedf4193a76648c9c7ecff91a9e3`.
- Build198 remains an independent A/B candidate based on the earlier accepted carousel baseline. Do not merge/rebase the 70 newer main commits merely to make CI green or before the Build198 A/B result, because that would change the test variable. Final integration, if Build198 is accepted, must resync against then-current `main` separately.

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

### Current Build198 diff scope

Current branch compared with current `main` still changes only the Build198 feature/CI paths below; no intended Player / MPV / PiP / UnifiedTransport / Cache / Emby Session / Add/Edit Emby product files are touched:

- `.github/workflows/temp-build198-carousel-ci.yml` — temporary CI helper; current helper includes icon preparation and no longer has the trigger-only `paths` filter.
- `Sources/Core/AppIdentity.swift`
- `Sources/UI/EmbyHomeCarouselInteractionV3.swift`
- `Sources/UI/EmbyHomeCarouselStateV3.swift`
- `Sources/UI/EmbyHomeCoreV3.swift`
- `Sources/UI/EmbyHomeHeroV3.swift`
- `docs/changelog/CHANGELOG_v0_14_31_build198.md`
- `scripts/check_home_carousel_single_owner.py`

The exact compare at this evidence capture reports those eight paths only. Frozen/P0 media paths are not part of the Build198 diff.

## Build198 validation history

### Earlier dedicated-CI attempts

Two early attempts stopped before real compile because old repository checks were already stale relative to the accepted baseline:

1. old `check_home_immersive_carousel.py` still expected `AdaptiveHeroRevealMetrics.backdropPinOffset`, while accepted source had already moved that calculation into Hero-local source;
2. old `check_home_horizontal_tap_routing.py` still searched `EmbyServerRootViewV3.swift` for `private func landscapeRow`, which is no longer true on accepted source.

Do **not** mutate Build198 product code merely to satisfy those historical script assumptions. The dedicated Build198 workflow is intentionally scoped to the new single-owner contract + Python syntax + exact diff/Frozen guard + real Xcode Release/MinOS/IPA pipeline.

### Run 32890283594 — real compile passed, post-build validation failed

- Workflow：`Build198 Carousel Single Owner IPA`
- Run：**`32890283594`**
- Job：**`97940357582`**
- Source/head SHA：**`2a3cec5f3d004db0617aa5a1c3417701a96d5140`**
- Conclusion：**failure**

Concrete evidence reached in this run:

- Build198 dedicated single-owner source contract: **PASS**.
- Python syntax / exact scope / P0-Frozen diff guard: **PASS**.
- Xcode 16.4 environment / dependency resolution: **PASS**.
- **Real Xcode Release compilation: PASS**. Current evidence does not justify changing the gesture/runtime source because Swift/UIKit compilation succeeded.
- Failure occurs **after Release compile**, at step **`Locate and validate app`**.
- IPA packaging/upload did not complete; no Build198 IPA was produced.

### Workflow evidence after the failure

The post-build failure was compared against the repository's known successful unsigned-IPA workflow rather than guessed from product source:

- the successful IPA pipeline runs `python3 scripts/generate_oneplayer_icons.py` before project generation/build;
- the failing Build198 helper did not run that icon-generation step;
- the OnePlayer icon asset catalog references generated PNG resources;
- therefore commit **`2746b62774228d94bd8bf56db57cb04ff4406970`** adds the same icon preparation step before Build198 project generation/build.

This is a workflow-only, evidence-supported fix. It has **not** been promoted to “root cause proven by rerun”, because GitHub Actions has not scheduled a job for the fixed source yet. The connector did not expose a stable decoded line containing the exact old validator error, so do not invent one.

### Fixed-source run 32984758776 — scheduler never created a job

- Fixed source SHA：**`2746b62774228d94bd8bf56db57cb04ff4406970`**.
- Run：**`32984758776`**, workflow run #4.
- Created：`2026-08-26T15:20:13Z`.
- Current observed state：**`queued`**, conclusion `null`.
- `updated_at` remained equal to creation time throughout repeated checks.
- Jobs endpoint repeatedly returned **`jobs: []`**.
- Therefore this run never reached Xcode, dependency resolution, source validation, app validation, packaging, or artifact upload. It must not be called CI passed or CI failed-at-build; it is blocked before job creation.

### Trigger investigation — stop point

The investigation deliberately avoided blind reruns:

1. Connector capabilities were checked. It can rerun failed jobs/runs, but it exposes no `workflow_dispatch`, no cancel for the queued run, and no operation to rerun a queued/0-job run.
2. Rerunning old failed run `32890283594` was rejected because it would execute old SHA `2a3cec5...` without the icon preparation fix.
3. A one-off no-op trigger commit `a569155d443433a5f4769dfe506fec6ab9bdd0e6` produced no Actions run/check suite and was removed from the active branch; do not use it as a source baseline.
4. The active branch was restored to `2746b62`, then a dedicated temporary branch was used to make one deterministic trigger change: remove the helper's `paths: [.github/workflows/temp-build198-carousel-ci.yml]` filter while retaining the exact Build198 branch filter and all build gates.
5. That trigger-only workflow commit is **`294a5b8d993d753690fcaa71a0b5d790b81babe1`**. The Build198 branch was fast-forwarded to it. No business/runtime source changed from `2746b62`.
6. At the latest evidence check, SHA `294a5b8d...` had **0 workflow runs and 0 check suites**. Therefore no additional trigger commits, workflow clones, retries, ref churn, or speculative CI edits should be made until the GitHub Actions event/scheduling state is understood or becomes operable.

Current evidence level:

**Build198 = Code written ✅ / scoped contract previously ✅ / diff-Frozen guard previously ✅ / Release compile previously ✅ / icon-preparation workflow fix written ✅ / fixed-source CI not scheduled (queued/0-job) / IPA not produced / real-device not tested / not stable.**

## Critical do-not-do list

- Do not restart the carousel design from Build193.
- Do not change the Build198 gesture/runtime source merely because CI is blocked; Release compilation already passed.
- Do not blindly create another Build198 run/trigger commit while run `32984758776` remains queued with zero jobs and the connector cannot dispatch/cancel it.
- Do not re-enable stale old test assumptions by modifying accepted product source.
- Do not add timer/watchdog/retry/fallback/interpolation/debounce/throttle.
- Do not combine Stage 1 with atomic transition snapshot work, blur optimization, predicted-touch rendering or EX crossfade fallback.
- Do not change Player/Transport/Cache/PiP/Emby media byte path.
- Do not change Build198 identity away from **0.14.31 / 198**.
- Do not merge/rebase current `main` into the Build198 A/B candidate simply because the feature branch is behind; final integration resync is a separate step after acceptance.
- Do not claim Build198 is solved until target-device acceptance.

## Next exact action

1. Treat `perf/home-carousel-single-owner-build198@294a5b8d993d753690fcaa71a0b5d790b81babe1` as the current Build198 CI-source branch. The runtime/product content is the same Build198 single-owner candidate as `2746b62`; `294a5b8d` only changes the temporary workflow trigger condition.
2. First resolve or observe a real GitHub Actions scheduling transition for fixed source. The existing fixed run is `32984758776`; if it finally creates a job, inspect that job directly. Do not trigger another run merely to see whether it behaves differently.
3. If a fixed-source job runs, required gates are: single-owner contract, exact diff/Frozen guard, icon preparation, Xcode Release build, app identity **0.14.31 (198)**, `MinimumOSVersion = 15.0`, unsigned IPA packaging, artifact upload.
4. If the job fails, read the exact failing step/log before any modification. Only make the smallest evidence-backed workflow/packaging or product fix.
5. After success, download the artifact and independently verify artifact ZIP integrity, `Payload/*.app`, `CFBundleShortVersionString=0.14.31`, `CFBundleVersion=198`, `MinimumOSVersion=15.0`, IPA SHA-256 and source ZIP SHA-256.
6. Only after artifact verification mark **CI passed / IPA produced**. Then remove/restore the temporary Build198 workflow without altering successful CI-source attribution.
7. Send the verified Build198 IPA to the user. Target-device Stage-1 validation order: tiny initial drag → small drag release must cancel fully → committed/fast flick must complete fully → hold and reverse through center → vertical Hero scroll → detail tap → compare continuous feel with EX.
8. If Stage 1 lifecycle is real-device stable but page-slide remains perceptually much coarser than EX, only then consider Stage 2 transition-publication/atomicity. If a correct Stage 1+subsequent page-slide path still cannot approach EX, the user-authorized fixed-spatial interactive crossfade is the evidence-supported fallback.
9. If Build198 is accepted, resync/reconcile it against then-current `main` as a separate integration task; do not contaminate the A/B candidate before device validation.

## Evidence labels

- Build185：real-device rejected — coarse initial page movement.
- Build187：real-device diagnostic confirmed — SwiftUI first useful samples already 4–16pt, maxFPS=120.
- Build189：real-device rejected — native movement + SwiftUI release could freeze.
- Build193：real-device rejected — passive native movement + underlying SwiftUI release still froze; hybrid ownership rejected.
- Build198：**current Stage-1 single-owner candidate; old source Release compilation passed, workflow icon preparation has been fixed, fixed-source Actions scheduling is blocked before job creation, no IPA yet, no real-device result.**
