# DEV-aether-multi-engine-comparison

- **Status:** Active
- **Work ID:** `DEV-aether-multi-engine-comparison`
- **Routing aliases / keywords:** `Aether内核 / Aether引擎 / Aether接入 / 播放引擎选择 / 多引擎对比 / Aether`
- **Task:** 将 AetherEngine 接入正常 OnePlayer App，并继续使用现有“播放设置 → 播放器引擎”入口人工选择 Aether，与 MPV 做真机对比。**MDK 按用户最新要求暂缓，本阶段不处理。**

## Acceptance criteria

1. Aether 只作为人工选择的实验引擎；MPV 继续是默认/自动播放权威，Aether 不进入 automatic fallback。
2. 继续使用 `PlayerEnginePreference` + `PlayerPreferenceKeys.enginePreference`；设置只影响新播放会话，不新增热切换状态。
3. Aether 复用现有 `PlaybackTransportContext` / UnifiedTransport / Session Cache / Emby Session/Resume/Progress，不复制 115/CDN 网络栈。
4. STRM → HTTP 302 → 115/CDN 必须继续客户端直连，NAS 不得中转媒体字节。
5. 保护 P0：左右双击立即 Seek、连续快速双击立即响应、Range/206、Session Cache、Emby Resume/Progress、异常短片/提前 EOF、播放诊断日志、MPV 主力路径。
6. Aether transport 只接受 FFmpeg/Aether `IOReader.seek` 给出的真实 byte offset；禁止 `targetTime / duration × fileSize`。
7. 目标真机：iPhone 15 Pro Max / iOS 17.0。
8. 因 Aether 6.50.0 模块本身要求 iOS 16，Aether 产品 candidate 的 Deployment Target 允许从 15.0 **精确提高到 16.0**；没有证据支持更高版本。
9. Aether 6.50.0 当前源码需要比 Xcode 16.4 / iOS 18.5 SDK 更新的 API；本任务产品构建工具链采用已验证可构建当前 OnePlayer 的 **Xcode 26.3**。
10. MDK 本阶段不修改。

## Baseline / identity

- **Base branch:** `main`
- **Base commit at task creation:** `7e7e82ccf548b960567445e848260b71ab8a50b2`
- **Latest main synced before product integration:** `fa90fc31ecf15edd8d9bfbbdb576a949338d6d65`
- **Working branch:** `feat/aether-multi-engine-comparison`
- **Current branch merge head before product code:** `b70e9c1c4e7b7f77da97e10bc55e9dc598bdc29b`
- **PR:** none yet
- **Build candidate:** not allocated
- **Target device:** iPhone 15 Pro Max / iOS 17.0

## Proven feasibility evidence

### Aether release / platform

- Exact upstream: `superuser404notfound/AetherEngine` **6.50.0**, commit `546287f2eef7d810b3947070839a85c653f79e46`.
- `Package.swift` is Swift tools 6.0 and declares iOS 16.0 minimum.
- Direct iOS 15 host import probe failed with: `compiling for iOS 15.0, but module 'AetherEngine' has a minimum deployment target of iOS 16.0`.
- `if #available(iOS 16, *)` therefore cannot retain an iOS 15 App target while statically importing Aether.
- An iOS16-only runtime bridge was considered but rejected: it adds a dynamic compatibility boundary/loader shim to Player core solely to preserve iOS15 and is not a minimal integration.
- Raising only manifest declarations is also rejected because upstream Aether/FFmpeg artifacts and source use the newer floor/API surface.

### Single-FFmpeg coexistence

- OnePlayer pins MPVKit 1.0.0, which already supplies FFmpeg n8.1.2 modules and Libdovi.
- Direct upstream Aether SwiftPM would add another FFmpeg stack with overlapping module/symbol ownership; rejected.
- Successful Xcode 26.3 feasibility shape:
  - clone exact Aether 6.50.0 source;
  - compile `Sources/AetherEngine` as an XcodeGen `library.static` target named/module `AetherEngine`;
  - `SWIFT_VERSION: 6.0` for that target;
  - depend only on current MPVKit product;
  - `OTHER_SWIFT_FLAGS: $(inherited) -module-alias Dovi=Libdovi`;
  - do **not** add Aether `FFmpegBuild` / second FFmpeg dependency.
- This static-target probe compiled/linked successfully on Xcode 26.3, establishing the narrow one-FFmpeg path.

### Toolchain

- The same Aether 6.50.0 static-target shape failed under Xcode 16.4 because upstream source uses API/SDK surfaces unavailable in that toolchain, including `AVSampleBufferDisplayLayer.preferredDynamicRange`, `VTRegisterSupplementalVideoDecoderIfAvailable` availability differences, and newer strict-concurrency AVFoundation behavior.
- Maintaining local source patches just to stay on Xcode16.4 is rejected as an unnecessary Aether fork burden.
- Unchanged current OnePlayer Release product was separately built on Xcode 26.3 while still targeting iOS15; workflow run `33070636640` succeeded. Therefore the toolchain upgrade itself does not require Player behavior changes.

## Verified Aether host API

- `AetherEngine` is `@MainActor`.
- Lifecycle/control: `init()`, async `load(source:startPosition:options:...)`, `play()`, `pause()`, async `seek(to:)`, `setRate(_:)`, `reloadAtCurrentPosition()`, `stop(...)`.
- Rendering: `bind(view:)` / `unbind(view:)` with UIKit `AetherPlayerView`; engine holds the bound view weakly.
- State: `state`, `playbackPhase`, `isBuffering`, `isSeeking`, `seekEvents`, `clock.currentTime`, `duration`, `hasFirstFrameReadyForDisplay`.
- Custom source: `MediaSource.custom(IOReader, formatHint:)`.
- `IOReader` runs `read`/`seek` on Aether demux threads and uses exact byte `SEEK_SET/CUR/END` plus `AVSEEK_SIZE=65536`.

## Current OnePlayer ownership / call sites

- **Engine preference owner:** `PlayerEnginePreference` + `PlayerPreferenceKeys.enginePreference`.
- **Active engine / Emby reporting / seek owner:** `PlayerController`.
- **Engine factory:** `PlayerController.makeEngine(...)`.
- **Transport owner:** one existing `PlaybackTransportContext`; Aether receives its `session` exactly like MPV.
- **Rendering owner:** `PlayerScreen` hosts an engine-owned view; SwiftUI must not own Aether engine/session lifecycle.
- **Recovery owner:** `PlaybackOrchestrator`.
- Existing `MediaTransportSession.recoverStall(position:duration:)` contains an old time→byte approximation; **Aether must not call it**. Aether recovery will reprioritize its reader's last real byte cursor through `prioritizeOffset`.
- `PlaybackOrchestrator` must classify `.aether` as a UnifiedTransport-backed kind so premature EOF/stall handling does not fall into non-Unified reload behavior.

## Minimal product patch plan

1. **Dependency/build wiring**
   - exact Aether 6.50.0 source available at a pinned repository path/dependency mechanism;
   - add static `AetherEngine` target using current MPVKit FFmpeg + `Dovi=Libdovi`;
   - App Deployment Target 16.0;
   - Xcode 26.3 build workflow/toolchain for this candidate.
2. **Engine identity** — `Sources/Player/PlayerEngine.swift`
   - add `.aether` kind/preference;
   - expose in `selectableCases` only when `canImport(AetherEngine)`;
   - automatic remains MPV.
3. **Transport bridge** — new `AetherTransportIOReader`
   - synchronous demux-thread read backed by async `TransportDataSession.read`, following `MPVUnifiedStreamBridge`'s proven blocking pattern;
   - exact byte cursor; `seek` → `prioritizeOffset`;
   - cancellation unblocks active read;
   - independent reader shares the same Transport session but owns its own cursor;
   - regular media reports `discImageProbeEnabled=false`.
4. **Engine adapter** — new `AetherPlayerEngine`
   - owns `AetherEngine`, `AetherPlayerView`, IO reader/load task and Combine subscriptions;
   - maps Aether state/clock/duration/buffering to `PlayerSnapshot`;
   - maps Aether `seekEvents.landed(renderedTime:)` to `onSeekCompleted`;
   - preserves controller's synchronous `prepare`/immediate `play` contract with a `wantsPlayback` flag while async Aether load is in flight;
   - `setPlaybackRate` → `setRate`;
   - `recoverStall` → exact current reader cursor reprioritization only;
   - no Aether-specific retry/watchdog/fallback.
5. **Controller/surface**
   - factory branch for explicit `.aether`;
   - controller accessor for engine-owned `AetherPlayerView`;
   - thin `UIViewRepresentable` host in `PlayerScreen` without moving engine/session ownership into SwiftUI.
6. **Capabilities/settings/orchestration**
   - conservative explicit Aether capabilities; do not redesign frozen PiP;
   - existing settings Picker automatically shows Aether; update explanatory footer only;
   - add `.aether` to UnifiedTransport-backed recovery sets.
7. Run product Release CI first. Do not allocate/claim IPA or device validation until that evidence exists.

## Frozen / do-not-touch

- MPV remains default/main authority and its fast-seek path is unchanged.
- No Aether automatic fallback.
- UnifiedTransport / Session Cache / client-direct STRM→302→115/CDN ownership remains unchanged.
- Emby Resume/Progress remains controller-owned and engine-independent.
- PiP Build173 frozen architecture is not redesigned.
- No speculative retry/fallback/timer/watchdog/compatibility shim/unrelated refactor.
- No time→byte ratio seek mapping.
- No MDK changes in this phase.

## Parallel conflict guard

- Rechecked before product integration after syncing `main`.
- Main changes since the previous sync were project documentation and Home/poster UI task checkpoint updates; no Player/Transport source ownership conflict was introduced.
- Home carousel / page cache / poster-grid tasks continue to exclude Player/MPV/Transport core from their scope.

## Completed

- [x] Work ID / independent branch created.
- [x] Player ownership/settings/surface/transport definitions inspected.
- [x] MDK deferred by current user scope.
- [x] Aether 6.50.0 exact tag/commit inspected.
- [x] iOS15 direct-import incompatibility proven.
- [x] Non-minimal runtime bridge/fork routes rejected.
- [x] Single-FFmpeg static Aether target proven on Xcode26.3.
- [x] Xcode16.4 incompatibility proven from actual compile errors.
- [x] Unchanged OnePlayer Release baseline passed on Xcode26.3 (`33070636640`).
- [x] Branch resynced to latest main before product code (`b70e9c1...`).
- [x] Aether load/control/view/IO/seek-event APIs verified from source/docs.
- [ ] Aether dependency/product source wiring committed.
- [ ] Aether `PlayerEngine` adapter committed.
- [ ] Aether rendering surface/settings selection committed.
- [ ] Product CI passed.
- [ ] IPA produced.
- [ ] Real-device comparison completed.
- [ ] Stable/frozen decision made.

## Validation state

- **Code written:** No product Aether code yet.
- **CI passed:** Feasibility only — single-FFmpeg/Xcode probes and unchanged OnePlayer Xcode26 baseline; **no Aether product CI yet**.
- **IPA produced:** No.
- **Real-device tested:** No.
- **Stable / frozen:** No.

## Next exact action

Implement the minimal product patch above on `feat/aether-multi-engine-comparison`, beginning with the pinned Aether source/dependency wiring and then the Aether IOReader/PlayerEngine adapter. After code is committed, update `TECHNICAL_DECISIONS.md`, `MODULE_STATUS.md` / `PROJECT_STATE.md` as required and run a dedicated Xcode26.3 Release CI before any IPA/device claim.
