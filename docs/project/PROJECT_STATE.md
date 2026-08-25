# OnePlayer Project State

_Last updated after Build190 / OnePlayer 0.14.23 completed dedicated carousel Release CI/IPA, while the independent detail line produced Build191 / OnePlayer 0.14.24 after Build190 detail screenshots confirmed quick-range selection retention but exposed summary/card title mismatch. Build191 now reuses the card title formatter and has dedicated Release CI/IPA evidence. Build184 / OnePlayer 0.14.17 remains the accepted overall functional baseline on `main`; neither Build190 nor Build191 replaces it until target-device evidence is accepted._

## Current functional baseline

The latest **real-device accepted** functional baseline is:

- Product: **OnePlayer**
- Version: **0.14.17**
- Build: **184**
- Canonical branch: `main`
- Final merge PR: **#255**
- Final merge commit: `5bf00bb0f48d0b640bcbea740d4c17c9f8e7be8f`
- Development branch: `feat/detail-episode-page-optimization`
- Clean product head before merge: `63d4114ca6ef97b419ec31163e6431af5cf2d002`
- Dedicated CI source: `0238f2c8fd202df6e7ba52d582b1614c9230eef9`
- Dedicated CI run: **32851745960**
- Artifact: `OnePlayer-0.14.17-build184-detail-visual-refinement`
- IPA SHA-256: `d89953c76b678fe1bc0b9f3fcc8b5b5b3ea430ec74bdd420834b427c91d47eb4`
- Deployment Target: **iOS 15.0**
- Required target device: **iPhone 15 Pro Max / iOS 17.0**
- Evidence: **Code written / CI passed / IPA produced / real-device accepted / stable for current requirements / merged to main**

Build184 inherits the accepted Build176 player episode-selection/session contract and Build178 canonical Emby TV episode-ordering contract, then adds the real-device accepted detail-page line: Build181 Hero-only high-frequency scroll ownership, Build182 persistent presentation-only detail cache, and Build184 visual hierarchy refinement. The user accepted the final Build184 UI on 2026-08-25 and explicitly approved completion and merge through PR #255.

Build179 / OnePlayer 0.14.12 is **not** an accepted carousel baseline. Its dedicated Release CI passed and IPA was produced, but the user installed it on the target device and reported that small drags still had a dead zone and direction reversal still produced a visible pause followed by a large catch-up jump. Build179 is therefore real-device tested / rejected.

Build180 / OnePlayer 0.14.13 is a **historical partial-improvement carousel build**: real-device testing confirmed reversal continuity improved, but initial motion still felt coarse, so it was not accepted. Build185 / OnePlayer 0.14.18 restored the required page-slide interaction but was also **real-device rejected**. Build187 / OnePlayer 0.14.20 completed the diagnostic gate on real device: first useful SwiftUI horizontal samples were already about 4.33/8.00/15.67/11.00pt with maxFPS=120 and Low Power Mode off. Build189 / OnePlayer 0.14.22 proved native raw/coalesced sampling could drive intermediate progress, but was **real-device rejected** because releasing the finger could leave that partial transition frozen instead of completing/cancelling. Build190 / OnePlayer 0.14.23 is now the valid independent carousel candidate with CI/IPA evidence.

Build181 / OnePlayer 0.14.14 is now a **detail-page diagnostic reference rather than the current candidate**. Target-device recording shows the previous obvious detail scroll pause→catch-up pattern is clearly improved, but a force-quit/relaunch still resets its session-only warm metadata and briefly returns the text-title/episode-loading state. It is real-device tested but not stable.

Build182 / OnePlayer 0.14.15 is **real-device accepted and frozen for detail scrolling plus force-quit/relaunch presentation restoration** on iPhone 15 Pro Max / iOS 17.0. Its architecture is now inherited by the accepted Build184 overall baseline on `main`.

Build184 / OnePlayer 0.14.17 is **real-device accepted, stable for the completed detail-page requirements, and merged to `main` through PR #255**. It preserves Build182 detail performance/cache behavior and only adds the accepted visual hierarchy changes: `视频信息` below `更多类似`, above the bottom glass media-source summary, with the main section headers at 19 pt bold.

Build188 / OnePlayer 0.14.21 established the independent **detail/episode-selection navigation candidate**: select-only horizontal cards, compact selected-episode summary and non-dismissing full picker playback. Dedicated Release CI/IPA succeeded. Target-device follow-up then showed missing default visible selection and quick range buttons clearing selection/title, so Build188 was not accepted.

The detail branch later produced its own **0.14.23 / Build190** package (`OnePlayer-0.14.23-build190-detail-selection-defaults`, IPA SHA-256 `2f05197cebe43b6a50c2eb84225b7d134f364f82baf58772f86d10653f2f298c`). User screenshots from that exact distributed artifact positively confirm quick `10-19 / 20-24` range jumps now retain the target first episode blue selection and summary state. Those screenshots also exposed a pure display inconsistency between the compact summary and horizontal-card title. The same 0.14.23 / Build190 identity was later occupied independently by the home-carousel candidate, so detail no longer reuses that identity; attribution of the screenshots remains tied to the detail artifact SHA above.

Build191 / OnePlayer 0.14.24 is now the independent **detail summary-title follow-up candidate**. `selectedEpisodeSelectionSummary` directly reuses `displayEpisodeTitle(episode)`, the exact formatter used by the selected horizontal card, so the two strings are intentionally identical. Dedicated Release run `32875670990` passed; artifact `OnePlayer-0.14.24-build191-detail-summary-title` ID `9573898096`; downloaded IPA SHA-256 `03c7dd61c2f151d537e78ec6727f888381d86839ea1ff75f0bbb388c3c56a354`; source ZIP SHA-256 `25c28eb7529cb371aa4b2d991691811c041bdecc4e9904538c663fb976267a98`; MinOS 15.0. **Real-device evidence is pending; accepted baseline remains Build184.**

## Accepted episode-selection and ordering contracts

Build176 established the stable in-player episode-selection/session behaviour:

- existing OnePlayer player-bottom control coordinates remain unchanged;
- player episode entry opens an in-player horizontal episode overlay rather than a large sheet;
- no explicit X close button and no `选集 / 剧名` header; tapping the player area above the selector dismisses it;
- landscape safe-area placement avoids the notch / Dynamic Island side inset;
- compact `第N季` menu filters the existing episode list in place without starting playback;
- detail-style 174×98 episode cards show a one-line episode title and up to two lines of Emby overview text;
- the current episode keeps a white outline and centered `正在播放` badge;
- a localized bottom fade prevents the unchanged lower player buttons from visually bleeding through the episode overview text;
- manually selecting another episode replaces the complete source-owned playback session while the fullscreen host stays presented;
- `自动加载下一集` uses the existing trusted natural-end / `PrematureEOFGuard` gate and does not advance on premature EOF, abnormal short-media recovery, network starvation, or raw engine EOF.

The episode media/session rule remains source-owned replacement rather than in-place source mutation. Each selected episode receives a fresh `PlayerController`, `PlaybackOrchestrator`, `PlaybackTransportContext` and Emby playback session. Episode metadata may be loaded ahead of selection, but 115/CDN temporary media URLs are resolved only when the user selects an episode or a trusted natural end requests the next one.

Build178 adds the canonical episode-order contract:

- `seriesEpisodes(seriesId:)` uses Emby's TV-specific `GET /Shows/{SeriesId}/Episodes` endpoint;
- OnePlayer preserves Emby's returned episode order instead of forcing generic Items `ParentIndexNumber,IndexNumber` sorting;
- `SeasonId` remains the season-membership authority but is not a second in-season ordering owner;
- pagination and ID-preserving deduplication remain;
- no title, filename, DateCreated, item-ID or artificial episode-number fallback sorting is introduced;
- detail page, all-episodes view, player picker and trusted auto-next consume the same canonical episode array.

The original failing non-standard series had 165 episodes with `nilIndex=164`; Build178 was accepted on real device after switching the shared data path to Emby's TV ordering authority.

## Current parallel feature candidates

### Build191 / OnePlayer 0.14.24 — detail selected-episode title unification

`DEV-detail-episode-selection-navigation` remains Active. Build191 preserves Build190-detail selection/navigation behavior and changes only the compact selected-episode summary formatter.

- branch: `feat/detail-episode-selection-navigation`
- functional commit: `6dc3f69d90049cd9228bdf006e50fc3402c1c6b9`
- dedicated CI source: `63fb252936360b284d75c4477d41587193e4fbd8`
- workflow-restored head: `516f5cf6e8832af083d3c2605e365cb1dcb7119a`
- CI run: **`32875670990` — success**
- artifact: `OnePlayer-0.14.24-build191-detail-summary-title`; ID `9573898096`; digest `sha256:f5403fad91f65ac3cd1810452f7aed9a4537f7a6d46b822f87e83261738dae61`
- IPA SHA-256: `03c7dd61c2f151d537e78ec6727f888381d86839ea1ff75f0bbb388c3c56a354`; source ZIP SHA-256: `25c28eb7529cb371aa4b2d991691811c041bdecc4e9904538c663fb976267a98`
- MinOS: 15.0
- implementation: compact selected-episode summary returns the existing `displayEpisodeTitle(episode)` result used by the horizontal card; no second title-format owner remains
- unchanged: default selection, quick-range selection, full-picker playback return path, canonical ordering, detail cache/scroll, Player/PiP/Transport/Cache
- evidence level: **Code written / CI passed / IPA produced / real-device pending / not stable**

### Build190 / OnePlayer 0.14.23 — home-carousel native movement + SwiftUI release ownership

`DEV-home-carousel-drag-smoothness` remains Active. Build190 directly fixes the Build189 target-device release-settle regression without reverting native fine-grained movement sampling.

- Build189 real-device result: **rejected** — drag progress followed the finger, but releasing could leave the page frozen at the exact intermediate progress; supplied recording was 9.07 s / 30 fps and showed repeated partial-transition freezes
- source cause: Build189 native recognizer entered `.began/.changed` for horizontal motion while complete/cancel remained exclusively in SwiftUI `DragGesture.onEnded`
- branch: `fix/home-carousel-native-release-build190`
- dedicated CI source: `8effb767af988c9bb4e6230ffc8b1a7f664c2619`
- Release-workflow-restored head: `817897ef6bd95d710657c3d12acc4d48ec8f2d39`
- CI run: **`32873473886` — success**
- artifact: `OnePlayer-0.14.23-build190-home-carousel-native-release`; ID `9573068806`; digest `sha256:355afc63f6b87251fce6c200af4796733bff8b947a27e71293e596745467437e`
- IPA SHA-256: `873abefa8c585ba577222a00d6feb99639bf3aa60861334d178eb8b4a26a24ba`; source ZIP SHA-256: `e9491fbf27610421d46e1fd1325be1d8d86c6e6d7010adfd721ae542a34fd0cb`
- MinOS: 15.0
- implementation: native raw/coalesced sampler remains the sole movement-progress owner but no longer claims horizontal recognition; SwiftUI removes per-frame `onChanged` writes and remains the sole `onEnded` / `predictedEndTranslation` / commit-cancel owner
- unchanged: 0.28 progress / 0.48×width predicted commit, full-page foreground travel, reversal continuity, backdrop/auto-advance/detail click, Player/PiP/Transport/Cache/Emby session contracts
- evidence level: **Code written / CI passed / IPA produced / real-device pending / not stable**

### Build189 / OnePlayer 0.14.22 — home-carousel native-touch input

`DEV-home-carousel-drag-smoothness` remains Active. Build189 directly follows the Build187 real-device proof that SwiftUI's first useful drag sample already arrives several points into the gesture.

- Build188 identity note: carousel 0.14.21 / Build188 is invalid because the parallel detail-selection task already owns Build188; do not distribute or attribute that carousel package
- branch: `perf/home-carousel-native-touch-build189-from187`
- product head before temporary CI helper: `36bfd4c1600add86dccc0f9917eea28dc39173f4`
- dedicated CI source: `7ddb4453abdf671c936a7f42d72fb837d943cc73`
- workflow-restored branch head: `c3b122f6f2934dc5c32c67e0fcae392a5c13cd14`
- CI run: **`32868634314` — success**
- artifact: `OnePlayer-0.14.22-build189-home-carousel-native-touch`; ID `9571260479`; digest `sha256:e33fdc0b4b185b3062e43ee3e506ff40399a8dbee8872c5344a1b7a4a9b65726`
- IPA SHA-256: `50c74bd43935a31ca3dda781c04a1113c2ce616c7da9e24e438cba78988c3a6d`; source ZIP SHA-256: `ae7b226aa20063700f3a0964714b2a89fe5e7c0eee4bf8b5cae371e432c791e4`
- MinOS: 15.0
- implementation boundary: UIKit raw/coalesced touch samples drive manual progress; existing full-page foreground travel and SwiftUI predicted release commit/cancel remain unchanged; P0/Frozen files zero-diff
- evidence level: **Code written / CI passed / IPA produced / real-device pending / not stable**

### Build187 / OnePlayer 0.14.20 — home-carousel drag cadence diagnostic

`DEV-home-carousel-drag-smoothness` remains Active. Build187 preserves Build185 page-slide behavior and adds exportable timing evidence rather than another threshold tweak.

- accepted runtime base: Build184 `main@dcd6cc6d01319e13ccb991967a190ae1f915053b`
- branch: `perf/home-carousel-drag-cadence-build187`
- dedicated CI source: `6d562b2f5cf76be41cb0e763c8f3c50c4f0d724f`
- workflow-restored branch head: `468986492f639959f7f31129dadf5b49e781d37f`
- CI run: `32860057516` — **success**
- artifact: `OnePlayer-0.14.20-build187-home-carousel-drag-timing`; ID `9567940931`; digest `sha256:0eb2a44b736a84e8237415465f064f6a23a163b5ef802875b483cda672b19766`
- IPA SHA-256: `5fa04513919b5e2928ee2ca09cf45dddc79c91d64858971f571b423dbb2d50f8`; source ZIP SHA-256: `70ef0df0ef48c9be558674cfd892a39e9836780602992e482f2f0d806d24d40a`
- MinOS: 15.0
- diagnostic summary: first/lock/transition translations, sample count/duration, avg callback Hz, max gap, maximumFramesPerSecond and Low Power Mode; emitted once at gesture end through the exported playback-log channel
- real-device evidence: first useful horizontal/lock/transition samples about 4.33/8.00/15.67/11.00pt; maxFPS=120; Low Power Mode=false; diagnostic gate confirmed.
- evidence level: **Code written / CI passed / IPA produced / real-device tested / diagnostic confirmed / not stable**

### Build180 / OnePlayer 0.14.13 — home carousel continuous drag

`DEV-home-carousel-drag-smoothness` remains Active. Build179 proved that localizing high-frequency state was necessary but insufficient: the remaining gesture/progress policy itself created a real-device dead zone.

- accepted integration base inherited through Build179: Build178 runtime at `main@967b743c88d68b05205eb39f1de75cab41362e8b`
- Build179 clean product head: `839cc0c3506c68e1c04887e438a77575a10fd8a0`
- Build180 branch: `perf/home-carousel-drag-smoothness-build180`
- Build180 product head before temporary CI helper: `cdc86d7fd75b30194b5363bf9abb497da2cc5a7b`
- dedicated CI source: `8d630a200cd1e0d9b06da90bc7d71e0fb4a7b6c5`
- workflow-restored branch head: `452ba27a661b4427471a975de99bb30e5e59a469`
- CI run: `32845376285` — **success**
- artifact: `OnePlayer-0.14.13-build180-home-carousel-continuous-drag`
- artifact ID: `9562183159`
- IPA SHA-256: `9da61f301e610fd2dd8a20aafba22dd55fb415e609ac8b2fe8923407d73d40cc`
- MinOS: app/runtime Mach-O validated at iOS 15.0
- evidence level: **Code written / CI passed / IPA produced / real-device pending / not stable**

Build180 keeps the Build179 single `V3HomeCarouselTransitionState` owner and localized Hero/backdrop scopes, but changes manual drag to receive movement from 0 pt, applies horizontal-dominance only until the drag is initially acquired, removes the additional `abs(horizontal) > 4` gate, and removes the first 8% delayed/smoothstep blend so small finger movement immediately changes visual progress. Existing commit/cancel thresholds, settle animations and auto-advance timing remain unchanged.

### Build181 / OnePlayer 0.14.14 — detail-page scroll isolation diagnostic

`DEV-detail-episode-page-optimization` remains Active on branch `feat/detail-episode-page-optimization`.

- accepted runtime base: Build178 at `967b743c88d68b05205eb39f1de75cab41362e8b`
- dedicated CI source: `917c43554876ce7c8751c10356f081cf2c1fe92b`
- workflow-restored branch head: `a8c445af44036218c6c085ae3b4b657ddb0902b1`
- CI run: `32845717063` — **success**
- artifact: `OnePlayer-0.14.14-build181-detail-page-performance`
- artifact ID: `9562323675`
- IPA SHA-256: `698d80d59767134c9479d517cedf24bf6494e73099d2f9125fa3d7a431d5a2f8`
- MinOS: app/runtime Mach-O validated at iOS 15.0
- real-device evidence: first new recording (10.2 s / 30 fps) no longer shows the old obvious stop→catch-up scroll pattern; continuous inertial portions move frame-to-frame with generally smooth decay. Second recording (5.7 s / 30 fps) after force quit/relaunch shows the known series briefly returning to text title + episode loading before Logo/episodes, proving process-only `NSCache` is insufficient.
- evidence level: **Code written / CI passed / IPA produced / real-device tested / scroll clearly improved / cold-relaunch warm start failed / not stable**

Build181 warm-starts safe detail presentation metadata (`episodes`, `seasons`, `imageInfos`, `similarItems`) using session-level `NSCache` while the normal Emby load still refreshes server-owned data. PlaybackInfo, MediaSource, PlaySession, ResolvedPlaybackSource and temporary 115/CDN URLs are explicitly excluded. High-frequency native detail scroll offset is moved out of root render state and observed only by the Hero scope; native ScrollView and existing Hero stretch/crop/pin mathematics remain unchanged.

### Build182 / OnePlayer 0.14.15 — persistent detail presentation cache

Build182 follows the direct real-device failure in Build181 and changes only the presentation-cache lifetime.

- branch: `feat/detail-episode-page-optimization`
- accepted runtime base: Build178 at `967b743c88d68b05205eb39f1de75cab41362e8b`
- product delta vs Build181: `Sources/UI/EmbyDetailPerformanceState.swift` keeps the existing `NSCache` hot path and atomically stores the same safe snapshot under `Library/Caches/OnePlayer/DetailPresentation`; `EmbyMediaDetailView.swift` needs no new call-path change
- model boundary: existing `LibraryItem` / `EmbyImageInfo` remain `Decodable`; Build182 maps their current fields to Emby-compatible JSON inside the detail performance state and rebuilds them with the existing `JSONDecoder`, avoiding a shared-model Codable refactor
- playback boundary: PlaybackInfo, MediaSource, PlaySession, ResolvedPlaybackSource and temporary 115/CDN URLs remain excluded; live Emby refresh remains unconditional and server-owned
- dedicated CI source: `f086fc0609f745d737e07d01dba18593285b20be`
- workflow-restored branch head: `6352671ba843e692c671c66c663c01a43b7848fb`
- CI run: `32848214004` — **success**
- artifact: `OnePlayer-0.14.15-build182-persistent-detail-cache`
- artifact ID: `9563302306`
- artifact digest: `sha256:16e9e6b728b9e0bbfc295896f791e96f253d0e1516771eaac140534c0c405d67`
- IPA SHA-256: `b9638df6f70f11be5f030ec7136a42125f2bc3a16af220c1d8b6de1b0cb3ce4c`
- MinOS: app/runtime Mach-O validated at iOS 15.0
- real-device evidence: user accepted and froze the detail scrolling and force-quit/relaunch restoration on iPhone 15 Pro Max / iOS 17.0.
- evidence level: **Code written / CI passed / IPA produced / real-device accepted / frozen for these two requirements**

Build182 CI passed the persistent-cache contract, Build181 Hero isolation, existing Hero/detail range/media/resume contracts, Build178 episode ordering and P0/Frozen zero-diff, then Xcode 16.4 Release compile, 0.14.15 (182) app identity, iOS 15.0 MinOS and IPA packaging/upload. Downloaded artifact IPA/source checksums were verified again after CI.

An earlier detail 0.14.13 / Build180 package also passed Release CI but was retired before user testing after discovering the parallel home-carousel task had already made Build180 its active identity. It is not a valid test baseline.

### Build184 / OnePlayer 0.14.17 — detail visual hierarchy refinement

`DEV-detail-episode-page-optimization` remains Active for UI refinement while Build182 performance/cache behavior stays frozen.

- branch: `feat/detail-episode-page-optimization`
- dedicated CI source: `0238f2c8fd202df6e7ba52d582b1614c9230eef9`
- workflow-restored branch head: `8ea6fc2347f899bd65bda315305a8091e38b1c3d`
- CI run: `32851745960` — success
- artifact ID: `9564647845`
- IPA SHA-256: `d89953c76b678fe1bc0b9f3fcc8b5b5b3ea430ec74bdd420834b427c91d47eb4`
- MinOS: 15.0
- real-device evidence: user reported the final Build184 visual result had no problem and explicitly approved acceptance, task completion and code merge on iPhone 15 Pro Max / iOS 17.0.
- merge: PR `#255`, merge commit `5bf00bb0f48d0b640bcbea740d4c17c9f8e7be8f`.
- evidence level: **Code written / CI passed / IPA produced / real-device accepted / stable for completed detail requirements / merged to main**

Build184 changes only the detail visual hierarchy: “视频信息” is below “更多类似” and directly above the bottom glass media-source summary, and main section headers use 19 pt bold. Build182 Hero scroll/persistent presentation cache and playback/order/transport contracts remain unchanged.

### Build179 / OnePlayer 0.14.12 — rejected carousel candidate

- branch: `perf/home-carousel-drag-smoothness-build179`
- workflow-restored branch head: `839cc0c3506c68e1c04887e438a77575a10fd8a0`
- dedicated CI source: `22515402f4d17e1a9b4073c535265b65ba55f52d`
- CI run: `32841344067` — success
- artifact: `OnePlayer-0.14.12-build179-home-carousel-smoothness`
- artifact ID: `9560700233`
- IPA SHA-256: `80f2c70215fe3f1c9323894eedbd22c5f61b29bcfb61e3a6e14115a4b932ddd8`
- MinOS: app/runtime Mach-O validated at iOS 15.0
- real-device result: **rejected on iPhone 15 Pro Max / iOS 17.0** — small drag still did not move immediately; reversing through the center could pause and then jump a large distance
- evidence level: **Code written / CI passed / IPA produced / real-device tested and rejected / not stable**

The Build179 rejection does not affect Build176/178 accepted player/order contracts because those files were zero-diff from the accepted Build178 base.

## Core playback architecture

```text
Emby / STRM
    ↓
HTTP 302
    ↓
115 / CDN
    ↓
iPhone
    ↓
UnifiedTransport
    ↓
Session cache / real byte demand
    ↓
Player engine
```

Hard rule: **NAS must never proxy the actual media byte stream.**

The public HTTPS entry remains the server entry point. The client must not hard-code the home's dynamic IPv4/port or implement a competing STUN resolution path.

## Current engine strategy

- **MPV** — daily/main playback engine and the reference engine for fast, consistent Seek.
- **MDK** — manual backup/experimental engine. It is not the automatic compatibility authority.
- **AVPlayer** — retained where appropriate; do not let ordinary UI work destabilise the player core.

## MPV Seek contract

The fast Seek architecture is frozen from the Build145/146 line:

- one real MPV Seek;
- native mode `absolute+keyframes`;
- no hidden `absolute+exact` correction;
- no second corrective native Seek;
- cache-only keyframe lookup is metadata assistance, not another playback owner;
- session keyframe map + background metadata refill may improve future decisions;
- long-GOP media can still physically limit ±10-second precision.

Exact Seek was tested and rejected as the normal runtime path because its latency was too high for the project's P0 interaction goal.

## PiP status

PiP development remains **temporarily frozen at Build173** even though the overall accepted functional baseline is now Build178.

Accepted PiP behaviour:

- native system PiP;
- SampleBuffer-based PiP visual path;
- MPV remains playback/audio/time authority;
- PiP Seek completion is owned by the visual commit, not callback entry;
- Build173 removed repeated periodic bridge rebase/catch-up behaviour;
- MPV native Seek remains `absolute+keyframes`;
- PiP X semantics remain `pauseAndSuspend`, not Stop;
- Build167 `vid=no` background video suspension remains part of the design;
- UnifiedTransport/cache semantics are not changed for PiP.

Known remaining issue:

- Returning from PiP to the full player can still be dominated by MPV `gpu-next` / MoltenVK renderer cold recovery. Some real-device returns remain visibly slower than desired.
- This is currently accepted rather than reopening a large renderer-ownership redesign.

Do not start a new PiP optimisation build unless there is a materially new architectural idea or a regression.

## Frozen project principles

- left double-tap immediately rewinds;
- right double-tap immediately fast-forwards;
- repeated fast double-taps must not wait for debounce accumulation;
- jump duration is configurable;
- STRM + 302 + 115 direct playback must work;
- Range/206 is required;
- Emby progress/resume synchronisation is required;
- abnormal short media / premature EOF must not be trusted blindly;
- diagnostic logs must remain exportable;
- real player byte demand, not time→byte proportional guessing, drives transport decisions;
- SwiftUI must not own player/cache/network/session lifecycles;
- native iOS navigation and interactive pop remain system-owned.

## Current development direction

Build184 / OnePlayer 0.14.17 remains the real-device accepted overall `main` runtime baseline. Build179, Build180 and Build185 carousel candidates are rejected by real-device evidence; Build183 is rejected as the default direction because it changed the established foreground page-slide interaction. Build187 / OnePlayer 0.14.20 is the current carousel drag-cadence diagnostic candidate with CI/IPA evidence and requires iPhone 15 Pro Max / iOS 17.0 recording plus exported playback log before any further rendering change. `DEV-detail-episode-selection-navigation` is a separate active task and currently does not overlap Home carousel files/state owners.

New work should proceed module-by-module without casually touching:

- MPV Seek;
- PiP;
- UnifiedTransport;
- cache semantics;
- system navigation.

If a new module requires changes in one of those frozen areas, state the reason explicitly before modifying it.
