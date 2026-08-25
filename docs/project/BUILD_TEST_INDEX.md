# OnePlayer Build / Test Index

This is a milestone index, not a list of every experimental build.

| Milestone | Main purpose | Result / current meaning |
|---|---|---|
| Build84 / 0.13.17 | MDK RecoveryIsolation | Protected app/exit lifecycle better; did not prove abnormal media was solved. |
| Build96 | MDK single-generation safety | Avoided unsafe same-process MDK generation rebuild after failure. |
| Build98 / 0.13.31 | Recovery/refresh continuation | Continued protection and detail-state work; protection ≠ MDK compatibility solved. |
| Build111 / 0.13.44 | MDK Seek / transport-tail experiments | Real-device feedback still showed worse long-tail Seek than MPV. |
| Build131 / 0.13.64 | MPV intent Seek | Fast double-tap recovered low latency; exact scrub path demonstrated precision/latency trade-off. |
| Build145 / 0.13.78 | MPV fast keyframe Seek convergence | Current fast-Seek architecture established; no-cache tests reported roughly P50 86.6 ms, P90 106 ms, P95 111.8 ms. |
| Build146 / 0.13.79 | MPV Seek code cleanup | Removed historical experiment scaffolding while keeping Build145 runtime contract. |
| Build160 / 0.13.93 | PiP native handoff work | Introduced/expanded SampleBuffer handoff and fresh-frame return gating. |
| Build167 / 0.14.0 | PiP lifecycle semantics | `vid=no` background video suspension; PiP X changed to `pauseAndSuspend`. |
| Build170 / 0.14.3 | Persistent PiP visual bridge | SampleBuffer host remains visual bridge while MPV renderer recovers. |
| Build171 / 0.14.4 | PiP authority/seek-tail guard | Added return authority alignment and a rare long-tail visual escape. |
| Build172 / 0.14.5 | PiP handoff authority controls | Real-device analysis showed periodic bridge catch-up introduced visible churn. |
| Build173 / 0.14.6 | PiP Seek completion + return simplification | PiP freeze baseline. This was a previous overall accepted functional baseline; PiP remains frozen at this architecture unless a materially better renderer-lifecycle idea appears. |
| Build174 / 0.14.7 | First player episode selector + auto-next | Dedicated standard MPV CI passed and IPA produced. User installed it and confirmed the selector/data path on device, but rejected the large gray sheet/X/title presentation; partial real-device evidence only. |
| Build175 / 0.14.8 | Episode selector UI / season interaction refinement | Dedicated standard MPV Release CI passed and IPA produced. Real-device screenshot confirmed the fixed bottom-button layout direction, but exposed lower button visual bleed through transparent overview text and a left-aligned `正在播放` badge. Not accepted as stable UI. |
| **Build176 / 0.14.9** | Episode overlay visual-layer follow-up and task completion | Previous accepted functional baseline. Dedicated standard MPV Release CI passed, IPA produced, user accepted the result, and final merge PR #253 landed at `d10e0d63b429f72a664193a1a5bacf728cac50b6`. Its player episode-selection/session contract remains stable and is inherited by Build178 and later candidates. |
| Build177 / 0.14.10 | Preliminary home carousel drag smoothness | Dedicated Release CI passed and IPA was produced on the older Build173 isolated baseline, but it was superseded before user distribution after `main` advanced through accepted Build178. It remains preliminary implementation/CI evidence only. |
| **Build178 / 0.14.11** | Canonical Emby episode ordering for non-standard series | **Previous accepted baseline, merged to `main` and inherited by Build184.** Uses `/Shows/{SeriesId}/Episodes` server order instead of forcing generic Items `ParentIndexNumber,IndexNumber`; dedicated standard MPV Release CI passed, IPA produced, user accepted the result on device, and PR #254 merged at `9e0d0cecb2df0a263a9a4a4c1f92c2d0e473d78f`. |
| **Build179 / 0.14.12** | First accepted-baseline home carousel smoothness candidate | Dedicated standard MPV Release CI passed and IPA produced. **Real-device rejected:** small movements still had a dead zone and left↔right reversal could pause then jump a large distance. |
| **Build180 / 0.14.13** | Continuous home carousel drag through zero/reversal | Dedicated Release CI/IPA succeeded. Real-device test confirmed reversal continuity was fixed, but initial motion still felt coarse and overall smoothness remained below EX. **Partial improvement / rejected for acceptance.** |
| **Build181 / 0.14.14** | Detail-page warm presentation + Hero scroll isolation | Dedicated Release CI/IPA succeeded. Target-device recording showed detail scroll clearly improved, but force-quit/relaunch lost the session-only warm metadata. **Partial success, cold-start requirement failed.** |
| **Build182 / 0.14.15** | Persistent detail presentation cache | Extends Build181's safe presentation snapshot to `Library/Caches` while retaining live Emby refresh and playback/session boundaries. Dedicated Release CI/IPA succeeded; user accepted detail scrolling plus force-quit/relaunch restoration on target device. **Frozen for these two requirements.** |
| **Build183 / 0.14.16** | Carousel fixed-foreground crossfade experiment | Dedicated Release CI/IPA succeeded. User said the feel seemed somewhat finer, but Logo/rating/year/type/overview were pinned instead of moving with their carousel page. **Interaction regression; rejected as default direction.** |
| **Build184 / 0.14.17** | Detail performance/cache + visual hierarchy completion | Inherits accepted Build181/182 detail scroll and persistent presentation cache, moves “视频信息” below “更多类似” and above the bottom glass media-source card, and uses 19 pt bold main detail section headers. Dedicated Release CI/IPA succeeded; user accepted the final result on target device and PR #255 merged to `main`. **Current accepted overall baseline.** |
| **Build185 / 0.14.18** | Restore carousel page-slide semantics + refine initial axis acquisition | Dedicated Release CI passed and IPA produced. **Real-device rejected:** page-slide interaction/reversal were correct, but first visible movement remained about 10/12/16 px versus EX about 1/1/2 px and ongoing drag remained visibly coarser. |
| **Build186 / 0.14.19** | Carousel drag-cadence instrumentation | Dedicated Release CI/IPA succeeded from accepted Build184 integration; passive timing was implemented, but its generic category routed to App logs and the package was not distributed for diagnosis. |
| **Build187 / 0.14.20** | Exportable carousel drag-cadence diagnostic | Same drag behavior as Build186; routes `HomeCarouselDragTiming` through the existing playback-log export. Dedicated Release CI passed, IPA produced and downloaded checksums verified. **Current carousel diagnostic candidate; real-device evidence pending.** |

## Current accepted baseline

- OnePlayer **0.14.17 / Build184**
- canonical branch: `main`
- final merge PR: `#255`
- final merge commit: `5bf00bb0f48d0b640bcbea740d4c17c9f8e7be8f`
- development branch: `feat/detail-episode-page-optimization`
- clean product head before merge: `63d4114ca6ef97b419ec31163e6431af5cf2d002`
- dedicated CI source: `0238f2c8fd202df6e7ba52d582b1614c9230eef9`
- CI run: `32851745960`
- artifact: `OnePlayer-0.14.17-build184-detail-visual-refinement`
- artifact ID: `9564647845`
- IPA: `OnePlayer-0.14.17-build184-detail-visual-refinement-unsigned.ipa`
- IPA SHA-256: `d89953c76b678fe1bc0b9f3fcc8b5b5b3ea430ec74bdd420834b427c91d47eb4`
- target device: iPhone 15 Pro Max / iOS 17.0
- evidence level: **Code written / CI passed / IPA produced / real-device accepted / stable for completed detail requirements / merged to main**

Build182 remains real-device accepted/frozen for the two detail performance/cache requirements and is inherited by Build184. Build184 / 0.14.17 is the accepted overall runtime baseline merged to `main`; Build185 is real-device rejected and Build187 / 0.14.20 is the current independent home-carousel diagnostic candidate pending recording plus exported playback log.

## Episode-selection evidence trail

Build174 standard MPV Release source commit / run / artifact:

- `2d4c4cae7deac930e040ca7579b462d9952ce60d`
- run `32776020154`
- `OnePlayer-0.14.7-build174-episode-picker`

Build174 was installed on the target device and produced actionable selector-UI feedback. It is not a stable UI baseline.

Build175 standard MPV Release source commit / run / artifact:

- `cbd700dbb6ae884dbd6b9cca8cb110d590e3d39d`
- run `32780288067`
- `OnePlayer-0.14.8-build175-episode-picker-ui`

Build175 passed its dedicated contract checks, Xcode 16.4 Release compile, app identity validation, iOS 15.0 MinOS validation, IPA packaging and artifact upload. The user then tested it and reported the transparent overview/button overlap and badge alignment issue.

Build176 product source / dedicated CI source / run / artifact:

- product source before temporary helper: `f701f0446d65e84fc686f69ec14d60402c94839c`
- dedicated CI source: `221630297dc1080279bb8a3f05d69586461b328c`
- run `32782048086`
- `OnePlayer-0.14.9-build176-episode-picker-ui`
- workflow-restored branch head: `4b26a7d3a9826c58bfdddd6aafaeb9eeb5c7c943`

Build176 passed the dedicated selector/frozen-file contract checks, Xcode 16.4 Release compile, OnePlayer 0.14.9 (176) app identity validation, iOS 15.0 MinOS validation, IPA packaging and artifact upload. User real-device acceptance made its player episode-selection/session contract stable; Build178 and later candidates inherit that contract unchanged.

## Build178 episode-ordering evidence

- task: `DEV-nonstandard-episode-sorting` — completed and checkpoint retired after merge
- branch: `fix/nonstandard-episode-sorting`
- PR: `#254` — merged
- merge commit: `9e0d0cecb2df0a263a9a4a4c1f92c2d0e473d78f`
- clean product head after restoring the temporary helper: `8718f60a1b0a3d0034473f1cc1769c0b5bc3665f`
- dedicated standard MPV Release CI source: `db9aa2498fba5c6b092bfec2427042859e32b26a`
- CI run: `32836693548`
- artifact: `OnePlayer-0.14.11-build178-episode-ordering`
- artifact ID: `9558981442`
- artifact archive digest: `sha256:b4f75969157eb929f8bccec50cc9fcaf51025f1696370a7143c20e1d59b8d158`
- IPA: `OnePlayer-0.14.11-build178-episode-ordering-unsigned.ipa`
- IPA SHA-256: `2e4ed5be2c32535249ea2049a9686f6ac24a217e04535806ee6ee4721e78ba5b`
- source zip SHA-256: `eb2059c776a5bdc09d17462a1085a63a1c7fdc5e4a80ea3a4fa18c6b9aefd214`
- CI evidence: ordering contract passed; Build176 downstream/frozen files unchanged; Xcode 16.4 Release build passed; app identity validated as 0.14.11 (178); app/runtime Mach-O MinOS validated at 15.0; IPA packaged and uploaded.
- real-device evidence: user accepted Build178 on 2026-08-25 and explicitly approved task completion and code merge.
- stable contract: canonical series order comes from `GET /Shows/{SeriesId}/Episodes`; OnePlayer preserves server order and does not add client-side title/file/date/ID/artificial-number fallback sorting.

## Build179 home-carousel evidence

- task: `DEV-home-carousel-drag-smoothness` — Active, Build179 rejected and continued as Build180
- integration base: accepted Build178 runtime at `main@967b743c88d68b05205eb39f1de75cab41362e8b`
- branch: `perf/home-carousel-drag-smoothness-build179`
- workflow-restored branch head: `839cc0c3506c68e1c04887e438a77575a10fd8a0`
- dedicated standard MPV Release CI source: `22515402f4d17e1a9b4073c535265b65ba55f52d`
- CI run: `32841344067`
- artifact: `OnePlayer-0.14.12-build179-home-carousel-smoothness`
- artifact ID: `9560700233`
- artifact archive digest: `sha256:5d4b06c3fbcc0515a3ce8293c60701ec8ddd31b6632a7bd4d0fac5717d242a24`
- IPA: `OnePlayer-0.14.12-build179-home-carousel-smoothness-unsigned.ipa`
- IPA SHA-256: `80f2c70215fe3f1c9323894eedbd22c5f61b29bcfb61e3a6e14115a4b932ddd8`
- MinOS: app and main runtime Mach-O validated at iOS 15.0; compatibility audit OK
- real-device evidence: persistent start dead zone plus freeze/large catch-up jump when reversing direction through center.
- evidence level: **Code written / CI passed / IPA produced / real-device tested and rejected / not stable**

## Build180 home-carousel evidence

- branch: `perf/home-carousel-drag-smoothness-build180`
- product head before temporary helper: `cdc86d7fd75b30194b5363bf9abb497da2cc5a7b`
- dedicated standard MPV Release CI source: `8d630a200cd1e0d9b06da90bc7d71e0fb4a7b6c5`
- workflow-restored branch head: `452ba27a661b4427471a975de99bb30e5e59a469`
- CI run: `32845376285` — success
- artifact: `OnePlayer-0.14.13-build180-home-carousel-continuous-drag`
- artifact ID: `9562183159`
- IPA SHA-256: `9da61f301e610fd2dd8a20aafba22dd55fb415e609ac8b2fe8923407d73d40cc`
- MinOS: app/runtime Mach-O validated at iOS 15.0
- real-device evidence: reversal continuity fixed; initial visible motion still coarse and overall feel below EX.
- evidence level: **Code written / CI passed / IPA produced / real-device tested / partial improvement / rejected for acceptance**

## Build183 home-carousel crossfade evidence

- branch: `perf/home-carousel-drag-smoothness-build183`
- dedicated standard MPV Release CI source: `b7fc842ddfe245a42e68a7d80082e11e63f17938`
- workflow-restored branch head: `4569dc4b0bb711328a50c5c074d8913329e9812c`
- CI run: `32849750890` — success
- artifact: `OnePlayer-0.14.16-build183-home-carousel-crossfade`
- artifact ID: `9563857302`
- IPA SHA-256: `ad96332ea3ce0bab9eabd03cfe16e39fe5a3c10513eacb4c072f9f8cd0133e57`
- implementation: foreground Logo/rating/year/type/overview stopped horizontal travel and crossfaded in place.
- real-device evidence: user said the feel seemed somewhat finer but immediately identified the changed interaction; the fixed foreground prevented valid comparison with the established slide behavior.
- result: **diagnostically useful but interaction regression / rejected as default direction**.

## Build185 home-carousel evidence

- task: `DEV-home-carousel-drag-smoothness` — Active, current carousel candidate
- branch: `perf/home-carousel-drag-smoothness-build185`
- base product semantics: Build180 clean carousel line `452ba27a661b4427471a975de99bb30e5e59a469`
- product head before temporary CI helper: `1297d740795dec868368e80119c562e4932abc9e`
- dedicated standard MPV Release CI source: `79f74d438ed8eade5061d6f9b76df4ebdd66a344`
- workflow-restored branch head: `7e7918c83fce16ada9863956179dc971f79ebe28`
- CI run: **`32853247583` — success**
- artifact: `OnePlayer-0.14.18-build185-home-carousel-axis-acquisition`
- artifact ID: **`9565234614`**
- artifact digest: `sha256:9799657b332469f65ec117eb7d28eb524ba22f4f5a8887a4a057ad7775164e8d`
- IPA: `OnePlayer-0.14.18-build185-home-carousel-axis-acquisition-unsigned.ipa`
- IPA SHA-256: **`1f7ec2f6d09540b344ad10c36c438c4626bf40be3985d01b0d1b3404818e9b24`**
- source zip SHA-256: `a67c6ad7515ae363ba8bf05ffaee6ef830f1c706762e4517485ec9d93e7c5925`
- MinOS: app/runtime Mach-O validated at iOS 15.0
- implementation: restores Build180 foreground page-slide mapping; `DragGesture(minimumDistance: 0)` remains; old `abs(horizontal) > abs(vertical) * 1.08` initial gate is removed; non-render `dragAxis` locks once at first meaningful 0.5pt vector, horizontal stays carousel-owned through reversal, vertical stays ScrollView-owned for the gesture.
- CI evidence: page-slide restoration, fixed-foreground regression guard, axis-acquisition contract, home/scroll/series-order checks, Build176/178/P0/Frozen zero-diff, Xcode 16.4 Release build, 0.14.18 (185) identity, MinOS and IPA packaging all passed.
- identity note: a carousel-internal Build184 run also passed CI but was discarded before distribution because the parallel detail task already owned Build184 / 0.14.17. Build185 is the valid unique carousel identity.
- real-device result: **rejected** after OP vs EX recordings quantified first visible movement around 10/12/16 px vs 1/1/2 px and coarser ongoing increments.
- evidence level: **Code written / CI passed / IPA produced / real-device tested and rejected / not stable**

## Build186 / Build187 home-carousel cadence evidence

- Build186 CI source `80d7b8b503d10bd8d10d62714afa9557a5988ab4`; run `32858062142` success; artifact `9567101523`; IPA SHA-256 `08cdf0398e024f8cc64dd75b2e6dfecab2b26833807feb810e280034b345f780`. Build186 preserved Build185 behavior and added passive timing, but was not distributed after confirming its generic timing log was outside the existing playback-log export.
- Build187 branch `perf/home-carousel-drag-cadence-build187`; only runtime delta vs Build186 is `DiagnosticsLogger.shared.playback("HomeCarouselDragTiming", ...)`; version 0.14.20 / Build187.
- Build187 CI source `6d562b2f5cf76be41cb0e763c8f3c50c4f0d724f`; restored head `468986492f639959f7f31129dadf5b49e781d37f`; run **`32860057516` success**.
- Artifact `OnePlayer-0.14.20-build187-home-carousel-drag-timing`; ID **`9567940931`**; digest `sha256:0eb2a44b736a84e8237415465f064f6a23a163b5ef802875b483cda672b19766`; IPA SHA-256 **`5fa04513919b5e2928ee2ca09cf45dddc79c91d64858971f571b423dbb2d50f8`**; source ZIP SHA-256 `70ef0df0ef48c9be558674cfd892a39e9836780602992e482f2f0d806d24d40a`; MinOS 15.0.
- Evidence: Build186 = **Code written / CI passed / IPA produced / not distributed for diagnosis**; Build187 = **Code written / CI passed / IPA produced / real-device pending / not stable**.

## Build181 detail-page evidence

- task: `DEV-detail-episode-page-optimization` — Active; superseded for cold-start testing by Build182
- branch: `feat/detail-episode-page-optimization`
- accepted runtime base: Build178 at `967b743c88d68b05205eb39f1de75cab41362e8b`
- dedicated standard MPV Release CI source: `917c43554876ce7c8751c10356f081cf2c1fe92b`
- workflow-restored branch head: `a8c445af44036218c6c085ae3b4b657ddb0902b1`
- CI run: `32845717063` — success
- artifact: `OnePlayer-0.14.14-build181-detail-page-performance`
- artifact ID: `9562323675`
- IPA SHA-256: `698d80d59767134c9479d517cedf24bf6494e73099d2f9125fa3d7a431d5a2f8`
- MinOS: app/runtime Mach-O validated at iOS 15.0
- real-device evidence: scroll clearly improved; force-quit/relaunch still showed cold presentation before Build182.
- evidence level: **Code written / CI passed / IPA produced / real-device tested / partial success / not stable**

## Build182 persistent detail-cache evidence

- task: `DEV-detail-episode-page-optimization`
- branch: `feat/detail-episode-page-optimization`
- dedicated standard MPV Release CI source: `f086fc0609f745d737e07d01dba18593285b20be`
- workflow-restored branch head: `6352671ba843e692c671c66c663c01a43b7848fb`
- CI run: `32848214004` — success
- artifact: `OnePlayer-0.14.15-build182-persistent-detail-cache`
- artifact ID: `9563302306`
- IPA SHA-256: `b9638df6f70f11be5f030ec7136a42125f2bc3a16af220c1d8b6de1b0cb3ce4c`
- MinOS: app/runtime Mach-O validated at iOS 15.0
- real-device evidence: user accepted both detail scroll smoothness and force-quit/relaunch presentation restoration; these two requirements are frozen.
- authority boundary: presentation cache does not own PlaybackInfo/MediaSource/PlaySession/ResolvedPlaybackSource/115-CDN temporary URL; server refresh remains final authority.

## Build184 detail visual evidence

- task: `DEV-detail-episode-page-optimization` — Active, pending visual acceptance
- branch: `feat/detail-episode-page-optimization`
- frozen base: Build182 workflow-restored head `6352671ba843e692c671c66c663c01a43b7848fb`
- UI product commit: `583d156d51e46ca4f913cbd268d18f8cbdb05b2f`
- dedicated CI source: `0238f2c8fd202df6e7ba52d582b1614c9230eef9`
- workflow-restored branch head: `8ea6fc2347f899bd65bda315305a8091e38b1c3d`
- CI run: `32851745960` — success
- artifact: `OnePlayer-0.14.17-build184-detail-visual-refinement`
- artifact ID: `9564647845`
- IPA SHA-256: `d89953c76b678fe1bc0b9f3fcc8b5b5b3ea430ec74bdd420834b427c91d47eb4`
- MinOS: app/runtime Mach-O validated at iOS 15.0
- product delta: “视频信息” follows “更多类似” and precedes the bottom glass media-source summary; main section headers are 19 pt bold; card body text/Hero/spacing are unchanged.
- evidence level: **Code written / CI passed / IPA produced / real-device pending / not stable**

## Main integration evidence

Build176 was merged through PR #253 and established the accepted player episode-selection/session contract.

Build178 was developed from the accepted Build176 `main` runtime baseline. Dedicated run `32836693548` passed, and after user real-device acceptance PR #254 merged at `9e0d0cecb2df0a263a9a4a4c1f92c2d0e473d78f`. Build178 remains the current accepted overall functional baseline.

Build182 is frozen for the two detail performance/cache requirements but remains on its feature line. Build184 detail visual refinement and Build185 carousel interaction are independent active candidates with unique Build identities and no current runtime file/state-owner overlap.

## Maintenance rule

Add a row only when a build materially changes architectural understanding, becomes a real-device reference point, or freezes/rejects a direction.
