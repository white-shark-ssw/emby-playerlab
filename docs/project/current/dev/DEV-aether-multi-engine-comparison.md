# DEV-aether-multi-engine-comparison

- **Status:** Active
- **Work ID:** `DEV-aether-multi-engine-comparison`
- **Routing aliases / keywords:** `Aether内核 / Aether引擎 / 多引擎对比 / 播放引擎选择 / MDK开放 / Aether`
- **Task:** 将 AetherEngine 接入 OnePlayer；在现有“播放设置 → 播放器引擎”选择中开放 Aether，并将当前生产构建隐藏的 MDK 手动引擎重新开放，用于 MPV / Aether / MDK 多引擎真机对比测试。

## User intent / acceptance criteria

1. OnePlayer 正常 App 构建可使用 Aether 播放引擎，不创建独立测试 App 作为最终交付。
2. 继续使用现有 `PlayerEnginePreference` / `PlayerSettingsView` 引擎选择入口；播放设置中至少可人工选择：
   - MPV 高兼容引擎；
   - Aether；
   - MDK 高性能/实验引擎。
3. 当前选择决定**新播放会话**的引擎；本任务不额外引入播放中热切换需求，除非后续用户明确要求。
4. MDK 从当前 `MDK_LAB` 隐藏状态提升为正常 App 可手动选择的实验引擎，但不得恢复为自动 fallback / 自动播放权威。
5. Aether 也先作为**人工选择、实验对比**引擎；在真机证据形成前不得替换 MPV 主力播放路径。
6. MPV / Aether / MDK 的对比必须尽可能共享 OnePlayer 已有媒体源解析、请求头、Emby Session/Resume、诊断与传输合同；不得为 Aether 或 MDK 复制另一套 115/CDN 网络栈。
7. STRM → HTTP 302 → 115/CDN 必须保持客户端直连；NAS 绝不能成为媒体字节中转站。
8. 必须保护当前 P0：左右双击立即 Seek、连续快速双击立即响应、Range/206、Session Cache、Emby Resume/Progress、异常短片/提前 EOF 容错、播放诊断日志。
9. 严禁重新采用 `targetTime / duration × fileSize` 时间→字节比例猜测。
10. 对比测试至少记录：首帧、普通 Seek、连续快速双击 Seek、拖动 Seek、已缓存命中/未命中表现、STRM/302/115 Range 行为、异常短片、字幕/音轨、后台/恢复、Emby Resume/Progress，以及各引擎特有错误/卡顿日志。
11. 目标真机仍为 iPhone 15 Pro Max / iOS 17.0。
12. OnePlayer Deployment Target 优先继续保持 iOS 15.0。AetherEngine 官方当前最低 iOS 16.0，因此实现前必须先验证依赖集成方式；未经证据证明 iOS 15.0 无法保留，不得直接提高 App Deployment Target。

## Baseline

- **Base branch:** `main`
- **Base commit at task creation:** `7e7e82ccf548b960567445e848260b71ab8a50b2`
- **Main accepted product baseline:** OnePlayer 0.14.32 / Build199（以当前 `PROJECT_STATE.md` 为准；并行 UI 任务可拥有更高独立 Build candidate，但不自动改变本任务产品基线）
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment target policy:** prefer iOS 15.0; never above iOS 17.0

## Working branch / PR / head commit

- **Working branch:** `feat/aether-multi-engine-comparison`
- **PR:** none yet
- **Head commit:** no product-code commit yet; branch is created from the task-registration baseline and must be rechecked before implementation
- **Build candidate:** not allocated

## Evidence

### Current source facts

- `Sources/Player/PlayerEngine.swift`
  - `PlayerEngineKind` / `PlayerEnginePreference` already own engine identity and persisted selection.
  - Current `selectableCases` exposes MPV in normal builds and only exposes `.ksAVIO` under `MDK_LAB && canImport(KSPlayer)`.
  - No Aether engine kind exists yet.
- `Sources/UI/PlayerSettingsView.swift`
  - Existing “播放器引擎” Picker already binds to `PlayerEnginePreference.selectableCases`.
  - Existing semantics explicitly state the setting affects new playback sessions.
- `Sources/Player/PlayerController.swift`
  - Owns the active `PlayerEngine`, engine kind, shared `PlaybackTransportContext`, Emby progress reporting, Seek orchestration and diagnostics.
  - Engine creation is centralized through `PlayerController.makeEngine(...)`.
- `Sources/UI/PlayerScreen.swift`
  - Surface selection currently has MPV / `.ksAVIO` / AVPlayer branches; Aether requires a real rendering surface integration rather than only adding an enum case.
- `Sources/UI/LocalMDKDirectEngine.swift`
  - A direct `swift_mdk.Player` + `MTKView` PlayerEngine implementation already exists but is compiled only under `MDK_LAB && canImport(swift_mdk)`.
- `project.mdklab.yml`
  - Existing MDK lab uses local `MDKLab/SwiftMDKOnePlayer` package and `MDK_LAB` compilation condition.
- `project.yml`
  - Normal production target currently depends on MPVKit only; MDK/Aether production dependencies are not yet present.

### External Aether fact to verify during implementation

- Candidate dependency identified as `superuser404notfound/AetherEngine`.
- Current public documentation advertises Swift Package integration and an `AetherPlayerView` / `AetherPlayerSurface` host API.
- Current documented minimum is iOS 16.0 / Swift 6.0 / Xcode 16.0.
- This is an integration constraint, **not** permission to raise OnePlayer's Deployment Target before compatibility options are tested.

## Files / modules in scope

Expected, subject to real call-site verification before edits:

- `project.yml` and dependency configuration required for Aether / production MDK availability
- `Sources/Player/PlayerEngine.swift`
- `Sources/Player/PlayerController.swift`
- `Sources/Player/PlaybackOrchestrator.swift` only if required by explicit manual engine-kind resolution
- new Aether `PlayerEngine` adapter and rendering surface files, placed in existing Player/UI module structure
- existing MDK production adapter path (`Sources/UI/LocalMDKDirectEngine.swift`) or the minimum evidence-backed promotion of the already-tested MDK implementation
- `Sources/UI/PlayerScreen.swift` rendering-surface dispatch
- `Sources/UI/PlayerSettingsView.swift` only if labels/footer need adjustment after selectable cases are correct
- `Sources/Diagnostics/*` only where needed to give equivalent engine comparison evidence
- related build workflow/project generation files only if required for the new dependencies
- this checkpoint and permanent `docs/project/` records when implementation/test evidence changes

## State owner / shared dependencies

- **Engine preference owner:** `PlayerEnginePreference` + `PlayerPreferenceKeys.enginePreference`
- **Active playback owner:** `PlayerController`
- **Playback session/orchestration owner:** existing `PlaybackOrchestrator` / controller flow; no duplicate engine-selection state
- **Transport owner:** existing `PlaybackTransportContext` / UnifiedTransport / Session Cache
- **Emby session owner:** existing PlayerController + Emby client reporting path
- **Rendering owner:** engine-specific surface hosted by `PlayerScreen`, without tying Player/Transport/Cache lifecycle to SwiftUI view lifecycle

## Frozen / do-not-touch

This task is allowed to add the minimum engine-integration seams required by the user, but must not casually rewrite Frozen/P0 behavior:

- MPV remains current main playback authority until comparison evidence says otherwise.
- MPV fast-seek semantics must remain unchanged.
- UnifiedTransport / Session Cache ownership and client-direct STRM→302→115/CDN contract must remain unchanged.
- Emby Resume/Progress lifecycle remains shared and engine-independent.
- PiP Build173 frozen path must not be modified unless Aether/MDK capability wiring demonstrably requires an engine-specific capability declaration; no PiP redesign in this task.
- No speculative retry/fallback/timer/watchdog/compatibility shim or unrelated refactor.
- No time→byte ratio seek mapping.

## Parallel conflicts checked against

Checked at task creation against the current Active checkpoints:

- `DEV-home-carousel-drag-smoothness` — independent Home carousel/UI work; Player core is explicitly out of scope there.
- `DEV-page-cache-optimization` — page-cache/navigation work; Player/MPV/PiP/UnifiedTransport/Range/206/playback Cache are explicitly do-not-touch there.
- `DEV-poster-grid-smoothness` — poster/grid/image-performance work; playback core is explicitly do-not-touch there.

**Result:** no current source/state-owner conflict that blocks creating this as an independent branch. Recheck before final CI/IPA/merge because `main` may advance while the tasks run in parallel.

## Completed

- [x] New independent Work ID selected.
- [x] Current Active task conflict preflight completed.
- [x] Current engine preference, settings UI, controller ownership, rendering dispatch, MDK lab adapter and production dependency configuration inspected.
- [x] Aether candidate repository and current minimum platform requirement identified.
- [ ] Aether dependency integrated.
- [ ] Aether PlayerEngine adapter implemented.
- [ ] Aether rendering surface integrated.
- [ ] MDK production/manual engine exposed.
- [ ] MPV / Aether / MDK all visible in playback engine selection.
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

No implementation claim is made by task creation.

## Pending

1. Confirm the production-safe Aether dependency integration under the iOS 15.0 deployment policy; specifically determine whether Aether can be isolated/conditionally available without raising the whole App target.
2. Inspect Aether public APIs at the selected version and map only the required `PlayerEngine` contract: prepare/play/pause/rate/seek/reload/metrics/stop plus render surface/state callbacks.
3. Inspect the current `makeEngine` switch and rendering/capabilities call sites completely before adding `.aether`.
4. Determine the minimum promotion path for the existing `LocalMDKDirectEngine` into the normal target without reviving MDK automatic fallback behavior.
5. Only after the above, make the smallest product-code change on the dedicated branch.
6. Before allocating a Build candidate, recheck `BUILD_TEST_INDEX.md`, all Active checkpoints and existing CI/IPA candidates.

## Next exact action

On `feat/aether-multi-engine-comparison`, perform an **integration feasibility pass before product-code edits**:

1. pin/inspect the intended AetherEngine release and its `Package.swift` platform/Swift requirements;
2. verify whether OnePlayer can keep deployment target iOS 15.0 while making Aether available on iOS 16+ (or document concrete build-system proof that it cannot);
3. inspect complete `PlayerController.makeEngine`, `PlayerCapabilities`, surface dispatch, and the existing MDK lab package wiring;
4. write down the minimal file-level patch plan in this checkpoint;
5. then implement Aether + MDK manual selection without changing automatic/fallback authority.

## Rejected / do-not-repeat

- Do not make Aether or MDK an automatic fallback merely because they are now selectable.
- Do not replace MPV as default/main authority before real-device comparison evidence.
- Do not duplicate UnifiedTransport / 115/CDN fetch logic inside Aether or MDK adapters.
- Do not route media bytes through NAS.
- Do not add speculative recovery timers/watchdogs just to normalize different engine behaviors.
- Do not raise Deployment Target to iOS 16.0 simply because Aether documents iOS 16.0 minimum; first prove lower-target coexistence is impossible under the project compatibility policy.
- Do not reuse MDK lab conclusions as proof that production integration is already safe; lab and normal target dependency/lifecycle wiring differ.

## Open questions / risks

- AetherEngine currently documents iOS 16.0 minimum, while OnePlayer policy prefers iOS 15.0. This may require conditional availability/isolation or, only after proof, a deployment-target decision.
- Aether uses its own FFmpeg/VideoToolbox/AVPlayer-backed internals; codec/runtime symbol overlap and packaging behavior with MPVKit/MDK must be verified in the real app target rather than guessed.
- Existing MDK adapter contains lab-only behavior and historical experiments. Promotion must separate the reusable engine implementation from obsolete lab-only fallback/diagnostic assumptions.
- Engine capabilities (PiP, system route, picture size, presentation effects) must be declared explicitly per engine; absence of a capability is preferable to faking compatibility.
- The comparison matrix must distinguish `Code written` / `CI passed` / `IPA produced` / `Real-device tested` / `Stable` at all times.
