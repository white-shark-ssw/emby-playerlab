# DEV-aether-multi-engine-comparison

- **Status:** Active
- **Work ID:** `DEV-aether-multi-engine-comparison`
- **Routing aliases / keywords:** `Aether内核 / Aether引擎 / Aether接入 / 播放引擎选择 / 多引擎对比 / Aether`
- **Task:** 先完成 AetherEngine 接入可行性与最小改动路径验证；目标是在正常 OnePlayer App 的现有“播放设置 → 播放器引擎”中人工选择 Aether，与 MPV 做真机对比。**MDK 按用户最新要求暂缓，本阶段不处理。**

## User intent / acceptance criteria

1. 当前阶段优先确认 Aether 的真实 iOS / Swift / 依赖限制，以及它能否在不破坏现有 MPV 与 P0 合同的前提下以最小改动接入。
2. 若进入实现，继续使用现有 `PlayerEnginePreference` / `PlayerSettingsView` 引擎选择入口；至少人工选择 MPV 与 Aether，不另造一套设置状态。
3. Aether 先作为**人工选择、实验对比**引擎；在真机证据形成前不得替换 MPV 主力播放路径，也不得成为自动 fallback。
4. 当前选择只决定**新播放会话**使用的引擎；本任务不新增播放中热切换，除非用户后续明确要求。
5. Aether 必须尽可能复用 OnePlayer 已有媒体源解析、请求头、Emby Session/Resume、诊断与 UnifiedTransport / Session Cache；不得复制一套 115/CDN 网络栈。
6. STRM → HTTP 302 → 115/CDN 必须保持客户端直连；NAS 绝不能成为媒体字节中转站。
7. 必须保护当前 P0：左右双击立即 Seek、连续快速双击立即响应、Range/206、Session Cache、Emby Resume/Progress、异常短片/提前 EOF 容错、播放诊断日志。
8. 严禁重新采用 `targetTime / duration × fileSize` 时间→字节比例猜测。
9. 目标真机仍为 iPhone 15 Pro Max / iOS 17.0。
10. OnePlayer Deployment Target 原则上仍优先保持 iOS 15.0；只有在依赖/核心 API 已有具体证据证明无法兼容时才允许讨论提高，并必须先记录低版本方案为何不可行。
11. **MDK 暂缓：** 本阶段不修改 `MDK_LAB`、MDK 依赖、MDK 引擎可见性或 MDK fallback 逻辑。

## Baseline

- **Base branch:** `main`
- **Base commit at task creation:** `7e7e82ccf548b960567445e848260b71ab8a50b2`
- **Main accepted product baseline:** OnePlayer 0.14.32 / Build199（以当前 `PROJECT_STATE.md` 为准；并行 UI 任务可拥有更高独立 Build candidate，但不自动改变本任务产品基线）
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment target policy:** prefer iOS 15.0; never above iOS 17.0

## Working branch / PR / head commit

- **Working branch:** `feat/aether-multi-engine-comparison`
- **PR:** none yet
- **Head commit:** `9b46d1d4a1755c229d52dd2ae8dccb4f06b71181` — task registration only; no product-code commit yet
- **Build candidate:** not allocated

## Evidence

### Current OnePlayer source facts

- `project.yml`
  - normal App target is iOS 15.0, Xcode 16.4, `SWIFT_VERSION: 5.0`;
  - production package currently includes MPVKit 1.0.0, not Aether.
- `Sources/Player/PlayerEngine.swift`
  - `PlayerEngineKind` / `PlayerEnginePreference` already own engine identity and persisted selection;
  - current normal build exposes MPV; no Aether kind exists yet.
- `Sources/UI/PlayerSettingsView.swift`
  - existing “播放器引擎” Picker already binds to `PlayerEnginePreference.selectableCases`;
  - no need为 Aether 新造设置状态或第二套选择 UI。
- `Sources/Player/PlayerController.swift`
  - owns active `PlayerEngine`, shared `PlaybackTransportContext`, Emby progress reporting, Seek orchestration and diagnostics;
  - engine creation is centralized in `PlayerController.makeEngine(...)`;
  - MPV receives `transportContext?.session`, so shared transport ownership already has明确 precedent。
- `Sources/Player/MPVUnifiedStreamBridge.swift`
  - proves `TransportDataSession` can be adapted into a synchronous byte-oriented read/seek source without NAS relay or time→byte guess;
  - this is the architectural reference for an Aether custom `IOReader`, not code to duplicate blindly.
- `Sources/UI/PlayerScreen.swift`
  - current surface dispatch has MPV / `.ksAVIO` / AVPlayer branches; Aether requires one real hosted view branch.

### Aether current release / platform facts — verified 2026-08-27

- Latest upstream release inspected: `superuser404notfound/AetherEngine` **6.49.0**.
- `AetherEngine` 6.49.0 `Package.swift`:
  - `swift-tools-version: 6.0`;
  - minimum iOS **16.0**;
  - depends on `FFmpegBuild` 2.4.x and `LibDovi` 2.0.x.
- `FFmpegBuild` current `Package.swift` also declares minimum iOS **16.0**.
- `LibDovi` current `Package.swift` also declares minimum iOS **16.0**.
- This is **not only a manifest floor**: `FFmpegBuild/build.sh` actually compiles iOS FFmpeg/dav1d/zimg/zvbi artifacts with `arm64-apple-ios16.0` / deployment `16.0`.
- Therefore an iOS 15 OnePlayer target cannot safely consume upstream Aether by merely wrapping imports/calls in `@available(iOS 16, *)`; SwiftPM dependency compatibility is checked before runtime availability, and the shipped FFmpeg artifacts themselves have an iOS 16 floor.
- Keeping OnePlayer iOS 15 while using current upstream Aether would require maintaining forks and rebuilding at least Aether's FFmpeg dependency stack for iOS 15, followed by source/API audit. That is **not a minimal-change integration** and is not currently justified.

### Aether public API fit

- `AetherEngine` is `@MainActor`, exposes `load`, `play`, `pause`, async `seek(to:)`, state/buffering/clock publishers and `stop`.
- `AetherPlayerView` is a UIKit view; the engine binds to it and internally hosts its active `AVPlayerLayer` / `AVSampleBufferDisplayLayer`.
- `AetherEngine.IOReader` is public and provides byte `read`, absolute `seek`, `close`, optional `cancel` / `makeIndependentReader`.
- This API shape maps cleanly to the existing OnePlayer `PlayerEngine` abstraction and allows an Aether adapter to consume `TransportDataSession` instead of creating a second independent 115/CDN transport path.
- App-layer integration itself is therefore relatively small; the unresolved problem is dependency/link coexistence, not the `PlayerEngine` protocol shape.

### MPVKit / Aether FFmpeg coexistence facts

- OnePlayer pins MPVKit **1.0.0**.
- MPVKit 1.0.0 ships **FFmpeg n8.1.2** and declares binary targets named `Libavcodec`, `Libavdevice`, `Libavfilter`, `Libavformat`, `Libavutil`, `Libswresample`, `Libswscale`, etc.
- Aether `FFmpegBuild` current source also builds **FFmpeg n8.1.2**, which is favorable for a possible single-FFmpeg adaptation.
- However `FFmpegBuild` itself declares targets with overlapping names such as `Libavcodec`, `Libavformat`, `Libavutil`, `Libswresample`, `Libswscale`, `Libavfilter`.
- SwiftPM requires target/module names to be unique across the package graph. Therefore **directly adding upstream AetherEngine beside current upstream MPVKit is not a clean package-resolution path** even after raising the app target to iOS 16.
- Aether's own public API documentation additionally warns that its ordinary `avcodec_*` / `avformat_*` / `avutil_*` / `swr_*` symbols can bind to another FFmpeg in the host process; using two independent FFmpeg builds can produce runtime ABI/feature mismatches whose symptoms look like engine bugs.
- Because MPVKit already brings a full FFmpeg into OnePlayer, the correct feasibility direction is **one FFmpeg in the process**, not two parallel copies.
- Both projects using n8.1.2 makes a shared-FFmpeg experiment technically plausible, but it is **not yet proven safe**: Aether depends on its own FFmpegBuild configuration/patches and a separate `Dovi` module, while MPVKit has its own FFmpeg configuration and `Libdovi` packaging. Feature/API coverage must be proven by build/link/runtime evidence before adopting this route.

## Current feasibility conclusion

1. **Upstream Aether + current iOS 15 target:** not compatible as a minimal change. The dependency stack and actual FFmpeg artifacts require iOS 16.
2. **Raise OnePlayer to iOS 16 + directly add upstream Aether beside MPVKit:** still not an evidence-backed safe path because of SwiftPM target-name overlap and dual-FFmpeg symbol ownership.
3. **Potential narrow path:** make Aether and MPV share a single FFmpeg n8.1.2 dependency through a small dependency-packaging adaptation, then validate compile/link/runtime behavior. This avoids two FFmpeg copies but requires a focused feasibility spike before player code is touched.
4. Because the user asked for minimum changes and current evidence does not yet prove the single-FFmpeg adaptation, **no product code or Deployment Target change should be made yet**.

## Files / modules in scope

Immediate feasibility scope only:

- `project.yml` — inspect only until dependency coexistence is proven; do not raise deployment target yet
- MPVKit 1.0.0 package/build metadata
- AetherEngine 6.49.0 package/public API/build metadata
- Aether `FFmpegBuild` / `LibDovi` dependency metadata
- this checkpoint

If dependency feasibility is later proven and user approves implementation, expected minimal app-layer scope becomes:

- `project.yml` / dependency wiring
- `Sources/Player/PlayerEngine.swift`
- new Aether `PlayerEngine` adapter
- new thin Aether `IOReader` backed by existing `TransportDataSession`
- `Sources/Player/PlayerController.swift`
- `Sources/UI/PlayerScreen.swift`
- `Sources/UI/PlayerSettingsView.swift` only if labels/footer need adjustment
- capability declarations only where required; no PiP redesign

Explicitly deferred:

- `Sources/UI/LocalMDKDirectEngine.swift`
- `project.mdklab.yml`
- `MDK_LAB` / MDK package promotion
- MDK engine selection/fallback behavior

## State owner / shared dependencies

- **Engine preference owner:** `PlayerEnginePreference` + `PlayerPreferenceKeys.enginePreference`
- **Active playback owner:** `PlayerController`
- **Playback session/orchestration owner:** existing `PlaybackOrchestrator` / controller flow; no duplicate engine-selection state
- **Transport owner:** existing `PlaybackTransportContext` / UnifiedTransport / Session Cache
- **Emby session owner:** existing PlayerController + Emby client reporting path
- **Rendering owner:** engine-specific surface hosted by `PlayerScreen`, without tying Player/Transport/Cache lifecycle to SwiftUI view lifecycle
- **FFmpeg ownership constraint:** do not knowingly ship two independently-owned FFmpeg stacks in the same OnePlayer process without explicit build/link/runtime proof.

## Frozen / do-not-touch

- MPV remains current main playback authority until comparison evidence says otherwise.
- MPV fast-seek semantics must remain unchanged.
- UnifiedTransport / Session Cache ownership and client-direct STRM→302→115/CDN contract must remain unchanged.
- Emby Resume/Progress lifecycle remains shared and engine-independent.
- PiP Build173 frozen path must not be redesigned in this task.
- No speculative retry/fallback/timer/watchdog/compatibility shim or unrelated refactor.
- No time→byte ratio seek mapping.
- Do not alter MDK in the current Aether-first phase.

## Parallel conflicts checked against

Checked at task creation against the current Active checkpoints:

- `DEV-home-carousel-drag-smoothness` — independent Home carousel/UI work; Player core is explicitly out of scope there.
- `DEV-page-cache-optimization` — page-cache/navigation work; Player/MPV/PiP/UnifiedTransport/Range/206/playback Cache are explicitly do-not-touch there.
- `DEV-poster-grid-smoothness` — poster/grid/image-performance work; playback core is explicitly do-not-touch there.

**Result:** no current source/state-owner conflict that blocks the Aether feasibility task. Recheck before final CI/IPA/merge because `main` may advance while tasks run in parallel.

## Completed

- [x] New independent Work ID selected.
- [x] Current Active task conflict preflight completed.
- [x] Current engine preference, settings UI, controller ownership and rendering dispatch inspected.
- [x] User narrowed immediate scope to Aether; MDK explicitly deferred.
- [x] Latest Aether release identified as 6.49.0.
- [x] Aether / FFmpegBuild / LibDovi iOS floors inspected.
- [x] Confirmed Aether's FFmpeg artifacts are actually built for iOS 16, not merely declared as iOS 16.
- [x] Confirmed `@available` cannot make current upstream Aether a valid iOS 15 SwiftPM dependency.
- [x] MPVKit 1.0.0 FFmpeg packaging inspected; direct package-graph overlap with Aether identified.
- [x] Confirmed MPVKit and Aether currently both use FFmpeg n8.1.2, leaving a possible single-FFmpeg adaptation to test.
- [ ] Single-FFmpeg dependency adaptation proven by build/link/runtime evidence.
- [ ] User decision on accepting a minimum iOS 16 target if the dependency coexistence spike succeeds.
- [ ] Aether dependency integrated.
- [ ] Aether PlayerEngine adapter implemented.
- [ ] Aether rendering surface integrated.
- [ ] MPV / Aether both visible in playback engine selection.
- [ ] CI passed.
- [ ] IPA produced.
- [ ] Real-device comparison completed.
- [ ] Stable/frozen decision made.

## Validation state

- **Code written:** No
- **CI passed:** No
- **IPA produced:** No
- **Real-device tested:** No
- **Stable / frozen:** No

The compatibility investigation changed no product code and did not raise the App deployment target.

## Pending

1. Do **not** add upstream Aether directly to `project.yml` yet.
2. If the user wants to continue, perform a dependency-only feasibility spike for **one shared FFmpeg n8.1.2** between MPVKit and Aether, without touching Player/Transport behavior.
3. In that spike, verify:
   - SwiftPM resolves with no duplicate target/module collision;
   - Aether compiles against the chosen FFmpeg headers/modules;
   - required Aether mux/decoder/encoder symbols/features exist;
   - Dovi packaging can use one implementation without duplicate C symbols;
   - MPVKit still links and initializes;
   - Aether initializes and reports the expected FFmpeg runtime version.
4. Only if that succeeds should the project discuss raising OnePlayer's deployment target from iOS 15.0 to **exactly iOS 16.0** for Aether. No higher floor is currently justified.
5. Only after dependency coexistence is proven should app-layer Aether integration begin.
6. Before allocating a Build candidate, recheck `BUILD_TEST_INDEX.md`, all Active checkpoints and existing CI/IPA candidates.

## Next exact action

Await the user's decision whether to proceed with the **dependency-only single-FFmpeg feasibility spike**. If approved:

1. keep `feat/aether-multi-engine-comparison` as the product branch;
2. do not change playback behavior or expose Aether in settings yet;
3. construct the smallest package-level experiment that gives Aether access to one FFmpeg n8.1.2 implementation already compatible with MPVKit, rather than importing Aether's second independent FFmpeg copy;
4. run package resolution + iOS build/link checks;
5. record whether MPVKit and Aether can coexist in one App target before touching `PlayerEngine` / `PlayerController`.

## Rejected / do-not-repeat

- Do not make Aether an automatic fallback merely because it becomes selectable later.
- Do not replace MPV as default/main authority before real-device comparison evidence.
- Do not duplicate UnifiedTransport / 115/CDN fetch logic inside an Aether adapter.
- Do not route media bytes through NAS.
- Do not add speculative recovery timers/watchdogs just to normalize engine behavior.
- Do not use `@available(iOS 16, *)` as if it solved the package's iOS 16 deployment floor; it does not.
- Do not lower only Aether/FFmpegBuild `Package.swift` platform declarations to iOS 15; the current FFmpeg binaries themselves are built for iOS 16.
- Do not raise Deployment Target to iOS 16 merely to get past the first error while leaving the MPVKit/Aether dual-FFmpeg conflict unresolved.
- Do not add both upstream FFmpeg stacks and hope link order is harmless.
- Do not modify MDK while the user has explicitly deferred it.

## Open questions / risks

- Aether requires iOS 16 in its actual binary dependency stack. If Aether is ultimately accepted, OnePlayer's minimum iOS likely must become 16.0 unless the project takes on a non-minimal dependency rebuild/fork.
- MPVKit and Aether currently both use FFmpeg n8.1.2, but their configuration/patch sets are different; version equality alone is not proof that one binary set satisfies both engines.
- Aether also depends on a separate `Dovi` module while MPVKit packages `Libdovi`; one-Dovi ownership must be solved together with one-FFmpeg ownership.
- Aether's Swift 6 package is being consumed from an app currently configured with `SWIFT_VERSION: 5.0`. Xcode 16.4 satisfies the toolchain floor, but coexistence of language modes should be proven by the same build spike rather than assumed.
- Engine capabilities (PiP, system route, picture size, presentation effects) must later be declared explicitly; absence of a capability is preferable to faking compatibility.
- Evidence levels remain separate: dependency resolve/build success will still not equal IPA or real-device playback success.
