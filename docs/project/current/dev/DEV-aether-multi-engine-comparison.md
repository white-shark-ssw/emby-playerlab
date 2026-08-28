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
- **Build candidate:** OnePlayer `0.14.57` / Build `224` — unique Aether fast-seek candidate; global Build223 was already occupied by the parallel Home task when this package was allocated.
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
  - do **not** add Aether `FFmpegBuild` / second FFmpeg dependency。
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
- Evidence before device testing: **Code written / CI passed / IPA produced+verified / real-device not yet tested / not stable**.

## Build219 real-device result — first Aether comparison

User supplied the Build219 playback log from the target iPhone 15 Pro Max / iOS 17.0. This changes the task state from CI/IPA-only to real-device tested.

### Seek result

- 14 Aether `SeekEvent.landed` completions were recorded; 13 were classified as `bufferHit=true` by the Build219 adapter.
- Completion latency: minimum **370.9 ms**, median **865.2 ms**, mean **1001.5 ms**, maximum **2261.3 ms**. The 13 buffer-hit seeks still had a median of **915.6 ms**.
- Precision is excellent: median absolute target→rendered error was about **0.614 ms**, maximum **2.239 ms**.
- The user's observation is confirmed: Build219 Aether Seek is very precise but repeatedly high-latency. It is not literally one fixed delay; the sample spans ~0.37–2.26 s, but most seeks pay a heavy common path.

### Transport churn identified from log + exact Build219 source

This candidate has a host-bridge defect that confounds any conclusion about Aether's intrinsic Seek floor:

- The log contains **2917 observed** `[Resume] exact-byte authority confirmed` events and **2917 observed** `[SeekTransportTrace] phase=actor-enter ... target=0.000 duration=0.000` events. Diagnostics backpressure separately dropped **4328 + 409** events, so the real event count is higher.
- During the ~70 s session, observed Transport activity was **5413 Range task starts / 5364 task cancellations / 49 completed sequential tasks**.
- `AetherTransportIOReader.read()` calls `confirmConcretePlaybackByte(current)` after every successful read; the observed read size is normally 256 KiB.
- `UnifiedResumeAuthority.confirmConcretePlaybackByte()` calls `prioritizeSeek(position: 0, duration: 0)` and then `prioritizeOffset(offset)`.
- Ordinary Aether sequential consumption therefore repeatedly creates a fake pending user-seek token; the following exact byte-offset demand reanchors the cache window and cancels/restarts healthy 115/CDN sequential lanes.
- MPV does not call this on every read: `MPVUnifiedStreamBridge` confirms playback-byte authority only after a sustained post-seek read cluster. The Aether per-read use is not a protected P0 transport contract and should not be retained.

Concrete example: the first +10 s seek requested target 11.800 while Aether already reported a playable range extending to ~73.733 s (`bufferHit=true`). It still took **1132.6 ms**; during that interval Transport repeatedly reanchored/cancelled slot 0, and the seek landed only after a fresh CDN first chunk arrived (~680 ms for that request). Therefore at least part of the high latency is self-inflicted by the Build219 adapter/transport interaction, not evidence that “Aether exact Seek itself always needs ~1 s”.

The best observed landed time is still ~371 ms, so Aether itself may retain a non-trivial exact-seek floor after this transport churn is removed. That must be measured in a clean follow-up build rather than guessed now.

### Other Build219 device evidence

- STRM/redirect transport resolved successfully as HTTP **206**, `redirects=2`, `range=true`, `looksLike115=true`; active media ranges came directly from `cdnfhnfile.115cdn.net`.
- No playback `error`, `failed`, `stall`, `premature EOF`, media EOF, network read timeout or Aether recovery event appears in this session.
- Startup: click→transport resolve ready was ~**1037 ms**; Aether `load begin`→`load ready` was ~**106 ms**; timeline was advancing with ~73 s reported forward playable by `17:37:43.712Z`.
- Playback rate was changed through 3×, 4×, 5×, 6× and 8× without an Aether error/stall record.
- Emby progress/report calls are not separately exposed by this playback log surface, so this file alone is not evidence to accept or reject Resume/Progress synchronization.

**Evidence after this log:** Code written / CI passed / IPA produced+verified / **real-device tested with Aether Seek-latency + per-read transport-churn defect confirmed** / not stable.


## Build222 / 0.14.55 — per-read authority churn correction

Build219 real-device evidence proved that ordinary Aether sequential reads were incorrectly promoted through the user-seek authority path. The minimal correction is commit `6f65f6a562c2f4af8a7720b33eb56d4b14b071bd`:

- `AetherTransportIOReader.read()` no longer calls `confirmConcretePlaybackByte(current)` after every successful read;
- Aether/FFmpeg `IOReader.seek()` still uses the exact byte offset and calls `prioritizeOffset(candidate)`;
- stall recovery still reprioritizes the reader's exact current byte cursor;
- no UnifiedTransport core algorithm, MPV fast-Seek path, timer, retry, fallback, watchdog, time→byte estimate or second network owner was added.

Identity guard before allocation found global Build219 already owned by Home-carousel, Build220 by poster-grid and Build221 by Home-carousel, so this Aether follow-up uses unique **OnePlayer 0.14.55 / Build222**.

### Build222 CI / IPA evidence

- Exact tested source: `224199f90d12b39367ae7981463aedd70cdbfe2d`.
- Runtime fix commit: `6f65f6a562c2f4af8a7720b33eb56d4b14b071bd`.
- Workflow run/job: `33103909150 / 98628547449` — **success** on Xcode 26.3.
- Source-contract validation passed: no `confirmConcretePlaybackByte` remains in `AetherTransportIOReader`; exact-byte `prioritizeOffset(candidate)` and recovery `prioritizeOffset(current)` remain present.
- Release compile, Swift package resolution, IPA identity/MinOS validation and artifact upload passed.
- Artifact: `OnePlayer-0.14.55-build222-aether-seekfix-224199f90d12b39367ae7981463aedd70cdbfe2d`; ID `9659820803`; digest `sha256:98e3c51177a4803ae0cbefb91d9584a1373b4d6946e2396901e6de475a73252b`.
- IPA: `OnePlayer-0.14.55-build222-aether-seekfix-224199f-unsigned.ipa`; SHA-256 `a7566dc53a60880096a41ee36bf3eab1dd43f14e2ff4a9b86c1a78372a7af660`.
- Source ZIP SHA-256: `8def2320dc5190b6f76bbfc6147a2d1f6d89c7c9821446e259f59d418116e923`.
- Built identity: `com.embyplayerlab.app`, `0.14.55 (222)`, `MinimumOSVersion=16.0`.
- Independent post-download verification reproduced the IPA SHA-256 and `unzip -t` reported no compressed-data errors.
- Evidence: **Code written / CI passed / IPA produced+verified / Build222 real-device retest pending / not stable**.

Next device test should repeat the Build219 Aether Seek sequence and compare `SeekEvent.landed` latency plus Range task start/cancel/finish counts. The purpose is to separate the remaining intrinsic Aether exact-seek floor from the removed Build219 adapter-induced transport churn.

## Build224 / 0.14.57 — bounded Aether fast seek + truthful rate UI

Build224 is a narrow follow-up on top of the Build222 transport correction. Source inspection established that Aether's native AVPlayer host used exact zero-tolerance seek for every programmatic seek, while OnePlayer's existing `bufferHit` diagnostic is forward-range shaped and therefore cannot safely decide the left/right double-tap contract. The app now routes by Seek intent instead of by that diagnostic:

- `.forward` / `.backward` use a finite **±0.75 s** tolerance through Aether's native AVPlayer host;
- `.absolute` remains exact (`toleranceSeconds = 0`) for scrub/absolute positioning;
- the vendor API default remains exact, so callers that do not opt in preserve existing behavior;
- bounded tolerance is passed through Aether's existing seek/reconcile/re-anchor path; no unbounded tolerance, second corrective seek, timer, retry, fallback, watchdog or Transport algorithm change is added;
- `bufferHit` remains diagnostic only and no longer gates whether fast tolerance is used.

Vendor branch `vendor/aetherengine-oneplayer-6.50.0` commit `7422d45727f3bea9a4aa1b616138448488a394d8` adds only the optional `toleranceSeconds` parameter and finite AVPlayer tolerances. OnePlayer product commit `704643e1887ffcecdf3f46f598aba74b603c8475` wires `.forward/.backward` to 0.75 s and `.absolute` to 0.

The same source review confirmed Aether's public `setRate` clamps video playback to `maxSupportedRate = 2.0` (3.0 for audio-only), while OnePlayer's generic speed panel exposed values through 8×. Build224 therefore queries the active Aether engine's real `maxSupportedRate`, clamps the controller command to that value and filters the speed picker accordingly. MPV/other existing paths retain the 8× list. No Aether core rate limit is raised or bypassed.

### Build224 CI / IPA evidence

- Exact tested repository source: `9e25454361b6f5ac71bb97de6771684a57ceb47d`.
- App fast-seek/rate patch commit: `704643e1887ffcecdf3f46f598aba74b603c8475`.
- Aether vendor revision: `7422d45727f3bea9a4aa1b616138448488a394d8`.
- Xcode 26.3 workflow run/job: `33112527059 / 98658753903` — **success**.
- Build contract validation, package resolution, Release compile, IPA validation and artifact upload all passed.
- Product artifact: `OnePlayer-0.14.57-build224-aether-fastseek-9e25454361b6f5ac71bb97de6771684a57ceb47d`; ID `9663285742`; artifact digest `sha256:a97ef293d9c453458ae8c6404d6146a0f501ec444fbf5ed1c6278e957068e073`.
- IPA: `OnePlayer-0.14.57-build224-aether-fastseek-9e25454-unsigned.ipa`; SHA-256 `85b1f5ae81c10843816d75f97ebf648dc5d5c21932b352bc4ef0b16f605ffae0`.
- Source ZIP SHA-256: `1716aa08f9e07c973b65a17b8c23b9b2fb1ace783bc751aa6c176a58c466c747`.
- Built identity: `com.embyplayerlab.app`, `0.14.57 (224)`, `MinimumOSVersion=16.0`.
- Independent artifact download reproduced the artifact/IPA hashes and `unzip -t` reported no compressed-data errors.
- Evidence: **Code written / CI passed / IPA produced+verified / Build224 real-device test pending / not stable**.

Build224 does not alter MPV fast Seek, UnifiedTransport/Session Cache algorithms, Emby reporting, PiP, MDK or the STRM→302→115/CDN client-direct path.

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
- [x] First real-device Aether comparison/log analysis completed; high Seek latency + per-read transport reanchor defect confirmed.
- [ ] Clean post-fix Aether↔MPV comparison completed.
- [ ] Stable/frozen decision made.

## Validation state

- **Code written:** Yes — Build224 bounded Aether seek tolerance and engine-aware rate UI are committed on top of the Build222 transport correction.
- **CI passed:** Yes — Build224 run/job `33112527059 / 98658753903` succeeded on exact source `9e25454361b6f5ac71bb97de6771684a57ceb47d`.
- **IPA produced:** Yes — artifact `9663285742`; IPA SHA-256 `85b1f5ae81c10843816d75f97ebf648dc5d5c21932b352bc4ef0b16f605ffae0`; source ZIP SHA-256 `1716aa08f9e07c973b65a17b8c23b9b2fb1ace783bc751aa6c176a58c466c747`; MinOS 16.0 verified.
- **Real-device tested:** Build219 yes — precise but high-latency Seek and per-read transport churn confirmed. Build224 fast-seek candidate has not yet been device-tested.
- **Stable / frozen:** No.

## Next exact action

Install Build224 / 0.14.57 on iPhone 15 Pro Max / iOS 17.0. With Aether selected, compare left/right double-tap and rapid repeated double-tap responsiveness against the prior exact-seek behavior, confirm absolute scrub remains acceptably precise, and confirm the speed panel exposes only rates supported by Aether (video ≤2×) while MPV still exposes its existing higher-rate choices. Capture the playback log so `AetherSeek request ... tolerance=0.75` and landed latency can be compared. Do not mark Aether fast Seek solved or stable until target-device evidence confirms it.
