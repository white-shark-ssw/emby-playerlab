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
- **Pre-product merge head:** `b70e9c1c4e7b7f77da97e10bc55e9dc598bdc29b`
- **Initial materialized Build219 source:** `dc0c30a0f2f1e85d27f80934d82b1ca07246f5ef`
- **Build219 compile-fix source commit:** `90557148e66e1d074cc2831dcb8023ea22dde7e0`
- **PR:** none yet
- **Build candidate:** OnePlayer `0.14.52` / Build `219`
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
- **Rendering owner:** `PlayerScreen` hosts an engine-owned view; SwiftUI does not own Aether engine/session lifecycle.
- **Recovery owner:** `PlaybackOrchestrator`.
- Existing `MediaTransportSession.recoverStall(position:duration:)` contains an old time→byte approximation; **Aether does not call it**. Aether recovery reprioritizes its reader's last real byte cursor through `prioritizeOffset`.
- `PlaybackOrchestrator` classifies `.aether` as a UnifiedTransport-backed kind so premature EOF/stall handling does not fall into non-Unified reload behavior.

## Implemented Build219 product patch

1. **Dependency/build wiring**
   - exact Aether 6.50.0 source is pinned for the product candidate;
   - static `AetherEngine` target uses current MPVKit FFmpeg + `Dovi=Libdovi` without a second FFmpeg stack;
   - App Deployment Target is 16.0 for this candidate;
   - dedicated Build219 workflow uses Xcode 26.3.
2. **Engine identity** — `Sources/Player/PlayerEngine.swift`
   - `.aether` kind/preference added;
   - existing settings Picker exposes Aether when `canImport(AetherEngine)`;
   - automatic remains MPV.
3. **Transport bridge** — `Sources/Player/AetherTransportIOReader.swift`
   - synchronous demux-thread read is backed by the existing Transport session;
   - exact byte cursor; `seek` reprioritizes exact offsets;
   - no time→byte approximation.
4. **Engine adapter** — `Sources/Player/AetherPlayerEngine.swift`
   - engine owns `AetherEngine`, `AetherPlayerView`, IO reader/load task and state subscriptions;
   - control/state/seek completion maps into existing `PlayerEngine`/`PlayerSnapshot` contracts;
   - stall recovery reprioritizes the reader's last real byte cursor only;
   - no Aether-specific retry/watchdog/fallback.
5. **Controller/surface**
   - explicit `.aether` factory branch and controller view accessor added;
   - `Sources/UI/AetherPlayerSurface.swift` is a thin host only; lifecycle remains controller/engine-owned.
6. **Capabilities/settings/orchestration**
   - `.aether` is in UnifiedTransport-backed orchestration sets;
   - `PlayerExperienceState` now has an explicit conservative Aether capability case: no system route picker, PiP, audio-track or subtitle-selection claim; rotation and generic outer picture-size layout remain available;
   - frozen PiP implementation is unchanged.

## Build219 CI evidence

### Attempt 1 — failed before IPA

- Workflow run: `33086503411`
- App Release job: `98567466674`
- Source entering the build line: materialized product candidate `dc0c30a0f2f1e85d27f80934d82b1ca07246f5ef`.
- Swift package resolution completed successfully; Aether/MPVKit dependency graph was therefore not the blocker.
- First real Release compiler error: exhaustive `PlayerEngineKind` switch in `Sources/UI/PlayerExperienceState.swift` did not include `.aether`.
- No IPA artifact was produced; only diagnostics existed.
- Aether actor-isolation diagnostics in that log were warnings/notes under the Swift 5 host and are not treated as the first blocker.

### Compile fix

- Commit `90557148e66e1d074cc2831dcb8023ea22dde7e0` adds only the missing explicit `.aether` capability case.
- No speculative concurrency refactor or unrelated warning cleanup was included.
- The original one-shot materialization workflow was then made rerunnable without touching product source; an initial validation-order mistake was corrected before the successful run.

### Successful Build219 candidate

- Exact tested repository source: `b1a06cb2b3dc9cf715fc5d49a7b324780aa23981`.
- Workflow run/job: `33096553966 / 98602865604` — **success**.
- Release compile, package resolution, IPA identity validation and artifact upload all passed.
- Product artifact: `OnePlayer-0.14.52-build219-aether-b1a06cb2b3dc9cf715fc5d49a7b324780aa23981`; ID `9656814369`; artifact digest `sha256:f2e984c56ebf1b74a7eaf39ff43f08cee2e9a0edaa0ae65d6406d2fefd2fc75a`.
- IPA: `OnePlayer-0.14.52-build219-aether-b1a06cb-unsigned.ipa`; SHA-256 `8df11d2db597fd6841a3708976824b21879ee0d47257c1766d1704cc4196d06d`.
- Source ZIP SHA-256: `61148b209d543c233502c8412f9448fffa143a97f5753c25595626c72b3e31e4`.
- Built identity: `CFBundleIdentifier=com.embyplayerlab.app`, `CFBundleShortVersionString=0.14.52`, `CFBundleVersion=219`, `MinimumOSVersion=16.0`.
- Local post-download verification reproduced the IPA SHA-256 exactly and `unzip -t` reported no compressed-data errors.
- Evidence is now **Code written / CI passed / IPA produced+verified / real-device not yet tested / not stable**.

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
- [x] Aether dependency/product source wiring committed.
- [x] Aether `PlayerEngine` adapter committed.
- [x] Aether rendering surface/settings selection committed.
- [x] First Build219 CI attempt produced actionable Release compiler evidence; dependency resolution passed, App compile failed, no IPA.
- [x] Missing `.aether` capability switch fixed minimally at `90557148...`.
- [x] Product CI passed (`33096553966 / 98602865604`).
- [x] IPA produced and independently verified (artifact `9656814369`).
- [ ] Real-device comparison completed.
- [ ] Stable/frozen decision made.

## Validation state

- **Code written:** Yes — Build219 Aether product integration plus the explicit capability-switch compile fix are committed.
- **CI passed:** Yes — Build219 run/job `33096553966 / 98602865604` succeeded on exact source `b1a06cb2b3dc9cf715fc5d49a7b324780aa23981`.
- **IPA produced:** Yes — artifact `9656814369`; IPA SHA-256 `8df11d2db597fd6841a3708976824b21879ee0d47257c1766d1704cc4196d06d`; MinOS 16.0 verified.
- **Real-device tested:** No.
- **Stable / frozen:** No.

## Next exact action

Install Build219 / 0.14.52 on iPhone 15 Pro Max / iOS 17.0 and compare Aether against the retained MPV authority on startup/first frame, normal and rapid double-tap Seek, scrub Seek, STRM→302→115/CDN Range behavior, cache hit/miss, abnormal short media, background/resume and Emby Resume/Progress. Record only observed device evidence; do not promote Aether to automatic authority from CI/IPA alone.
