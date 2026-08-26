# DEV-home-carousel-drag-smoothness

## Status

**Active — Build198 CI passed and verified IPA produced; target-device validation pending**

- **Work ID**：`DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords**：轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- **Task**：优化 OnePlayer 首页 V3 轮播图手动横向拖动，目标达到用户 EX 参考录屏同级别的丝滑、细腻和跟手，不出现起滑大跳、不跟手、卡顿、抖动、冻结后追帧或松手停在中间态。
- **Evidence sync**：2026-08-27 +08:00。
- **Current instruction**：Build198 已完成 CI/IPA 阶段。下一步只做目标设备 A/B；不得把 CI/IPA 成功写成真机已解决。

## Acceptance contract

1. 手指极小横向移动必须立即、细腻、连续反馈；不得先积累一段位移后突然追上。
2. 慢拖、快速拖、按住左右反向穿越中心必须连续。
3. Logo、评分、年份、类型、剧情简介属于对应轮播页，默认必须继续随页面整体横向平移。
4. 松手必须可靠 complete 或 cancel，绝不能冻结在两页中间。
5. Hero 区纵向滑动必须继续交给首页 `ScrollView`；详情点击正常；自动轮播正常。
6. 不得影响 Player / MPV / PiP / Transport / Cache / Emby Session / STRM→302→115/CDN client-direct 等 P0/Frozen 合同。
7. Build183 类“前景固定 + interactive crossfade”只有在正确的 page-slide 基础框架真机稳定后仍无法达到可接受细腻度时，才是用户明确允许的最终 fallback；不得未经允许提前改交互。

## Current identities

- **Accepted overall runtime baseline**：OnePlayer **0.14.32 / Build199**，已真机接受并合并到 `main`。
- `main` at this evidence capture：`2cdbf4913898aedda66225381b30ab13d52cecd6`。
- Carousel candidate：**OnePlayer 0.14.31 / Build198**。
- Working branch：`perf/home-carousel-single-owner-build198`。
- PR：none。
- Successful CI / IPA source：**`a569155d443433a5f4769dfe506fec6ab9bdd0e6`**。
- Durable branch head after deleting temporary CI helpers：**`c769f2c4c05fffdb36e90d78d8baddec5e0e7c21`**。
- Tested-source → durable-head compare：**only `.github/workflows/temp-build198-carousel-ci.yml` is removed; product/runtime files are unchanged**。
- Durable Build198 branch relative to current `main` at capture：**ahead 17 / behind 72**, merge base `3c0782c93c37bedf4193a76648c9c7ecff91a9e3`。
- Build198 remains an independent A/B candidate. Do not merge/rebase newer `main` work into this test candidate before the target-device result, because that would change the A/B variable. Final integration is a separate step if Build198 is accepted.

## Why this architecture exists

### Build185 / Build187 — pure SwiftUI input is too coarse at drag start

- Build185 restored the required full-page foreground slide and removed old start gates, but target-device recordings still showed first visible page movement around **10 / 12 / 16 px** versus EX around **1 / 1 / 2 px**.
- Build187 diagnostics proved the first useful SwiftUI horizontal/axis-lock samples were already about **4.33pt / 8.00pt / 15.67pt / 11.00pt**.
- The same device reported maxFPS=120 and Low Power Mode off. Therefore further tiny SwiftUI threshold tuning is not evidence-supported.

### Build189 / Build193 — split move/end ownership is rejected

- Build189 used native movement while SwiftUI still owned release; target device could freeze between pages after release.
- Build193 made native capture passive while SwiftUI remained release owner; target device reproduced the same freeze.
- Movement and release must not live on separate hit-test/input owners. Do not patch that architecture with timer/watchdog/reconciliation/fallback.

### EX evidence

EX reference analysis showed foreground/background regions remain effectively spatially fixed while blend weight changes continuously. Build183 therefore felt somewhat finer, but it changed the required page-slide semantics without authorization. Current order remains: prove the correct single-owner page-slide first; only if that stable path still cannot approach EX feel may the explicitly allowed fixed-spatial interactive blend be considered.

## Build198 Stage 1 — single UIKit lifecycle owner

Target structure:

`one UIKit interaction surface → one complete begin/move/end/cancel owner → existing carousel transition state → SwiftUI render only`

Implemented behavior:

- `Sources/UI/EmbyHomeCarouselInteractionV3.swift` is the native single-owner interaction layer/custom continuous recognizer.
- The Hero no longer splits manual movement and release between native and SwiftUI gesture owners.
- The same interaction surface coordinates detail tap and horizontal drag.
- First meaningful raw motion uses approximately **0.5pt** only for direction acquisition. Vertical acquisition fails the carousel recognizer so the ancestor Home `UIScrollView` remains authoritative; horizontal acquisition owns the carousel through end/cancel.
- Rendering publishes only the latest actual touch position once per UIEvent; it does not replay coalesced touches into multiple SwiftUI progress publications.
- Predicted touch is not rendered ahead of the finger; it is used only for existing release prediction/commit semantics.
- Existing commit/cancel semantics remain: progress threshold **0.28**, predicted-distance gate corresponding to **0.48 × width**, and existing settle durations.
- Logo/rating/year/type/overview remain part of their page and continue page-slide semantics in Stage 1.
- High-frequency transition ownership remains local to `V3HomeCarouselTransitionState`.

## Durable Build198 product diff

After CI-helper cleanup, current Build198 branch changes only these durable feature paths relative to its merge-base line:

- `Sources/Core/AppIdentity.swift`
- `Sources/UI/EmbyHomeCarouselInteractionV3.swift`
- `Sources/UI/EmbyHomeCarouselStateV3.swift`
- `Sources/UI/EmbyHomeCoreV3.swift`
- `Sources/UI/EmbyHomeHeroV3.swift`
- `docs/changelog/CHANGELOG_v0_14_31_build198.md`
- `scripts/check_home_carousel_single_owner.py`

No Player / MPV / PiP / UnifiedTransport / Cache / Emby Session / Add/Edit Emby product path is part of the durable Build198 diff.

## CI / packaging evidence

### Failed source — run 32890283594

- Source：`2a3cec5f3d004db0617aa5a1c3417701a96d5140`
- Run：`32890283594`
- Job：`97940357582`
- Result：failure after real Xcode Release compilation.
- Passed before failure：single-owner contract, Python syntax, diff/Frozen guard, Xcode/dependencies, **Release compilation**.
- Failed step：`Locate and validate app`.
- No IPA was produced from this run.

The repository's known-good IPA workflow was then compared with the Build198 helper. The Build198 helper was missing the required `python3 scripts/generate_oneplayer_icons.py` preparation step. Commit `2746b62774228d94bd8bf56db57cb04ff4406970` added only that workflow preparation; no carousel runtime source was changed for this packaging fix.

### Successful Build198 run

- Workflow：`Build198 Carousel Single Owner IPA`
- Run：**`32987054824`**
- Job：**`98235720724`**
- Source/head SHA：**`a569155d443433a5f4769dfe506fec6ab9bdd0e6`**
- Event：push
- Result：**success**
- All job gates passed:
  - source checkout
  - Build198 single-owner contract + exact diff/Frozen guard
  - Xcode 16.4/tool setup
  - OnePlayer icon generation
  - project/dependency generation
  - **Xcode Release build**
  - **built app identity/icon validation**
  - **MinOS validation**
  - **unsigned IPA/source packaging**
  - **artifact upload**

This successful rerun proves the workflow/package correction was sufficient; no product/runtime code change was required to get the Build198 app through validation and packaging.

## Verified Build198 artifact

- Artifact：`OnePlayer-0.14.31-build198-home-carousel-single-owner`
- Artifact ID：**`9613342337`**
- Artifact size：`22,124,833` bytes
- Artifact digest：**`sha256:4597f6b9bcdd74a44441632f72c5c4b9127aab03e3dad7e38478c552cae773f3`**
- IPA：`OnePlayer-0.14.31-build198-home-carousel-single-owner-unsigned.ipa`
- IPA SHA-256：**`9432928b31898c0c3f05e7e0affb6949c23339a37edd8f14c1d47343ff31f3d8`**
- Source ZIP：`OnePlayer-0.14.31-build198-source.zip`
- Source ZIP SHA-256：**`00e3fd353c487d185469a2bd9679031cc8a3da9829b310281d8e638c10cd046d`**
- Independent artifact ZIP integrity check：PASS
- Independent IPA ZIP integrity check：PASS
- `CFBundleIdentifier`：`com.embyplayerlab.app`
- `CFBundleDisplayName` / `CFBundleName`：`OnePlayer`
- `CFBundleShortVersionString`：`0.14.31`
- `CFBundleVersion`：`198`
- `MinimumOSVersion`：`15.0`
- App executable runtime Mach-O minOS：`15.0`
- Primary icon：`OnePlayerIcon`
- Alternate icon：`OnePlayerAltIcon`
- MinOS audit：PASS, required device ceiling `17.0`

Evidence level now:

**Build198 = Code written ✅ / scoped contract ✅ / diff-Frozen guard ✅ / CI passed ✅ / IPA produced + independently verified ✅ / real-device not tested / not stable.**

## CI-helper cleanup

After the valid artifact was captured:

- temporary one-shot dispatcher was deleted;
- `.github/workflows/temp-build198-carousel-ci.yml` was deleted from the durable feature branch;
- durable branch head is `c769f2c4c05fffdb36e90d78d8baddec5e0e7c21`;
- compare from tested source `a569155d...` to cleanup head changes only removal of the temporary Build198 workflow; product/runtime files are unchanged.

Do not re-add these helpers merely for documentation or to create another identical IPA.

## Target-device validation — next exact action

Install the verified Build198 IPA on **iPhone 15 Pro Max / iOS 17.0** and test in this order:

1. tiny initial horizontal drag — look specifically for the first visible movement granularity versus EX;
2. small drag + release — must cancel fully, never remain between pages;
3. committed drag / fast flick — must complete fully;
4. hold and reverse through center repeatedly — no pause/freeze/catch-up;
5. vertical drag on Hero — Home vertical `ScrollView` must remain authoritative;
6. detail tap — must still enter detail normally;
7. auto-advance — must remain normal;
8. compare portrait and landscape subjective `drag / layout / settle` feel with EX.

If Stage 1 is lifecycle-stable but still perceptually too coarse, then inspect transition publication/atomicity before considering the user-authorized fixed-spatial crossfade fallback. Do not add interpolation/timer/watchdog/retry/debounce/throttle without new evidence.

If Build198 is accepted on device, resync the durable product diff against then-current `main` in a separate integration step and rerun any validation affected by that resync. Do not claim the current old-base CI automatically covers future merged source.

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
