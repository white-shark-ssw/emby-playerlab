# OnePlayer Project State

_Last updated after Build182 / OnePlayer 0.14.15 was accepted and frozen for detail scrolling plus force-quit/relaunch presentation restoration, and Build184 / OnePlayer 0.14.17 passed dedicated Release CI and produced an IPA for the next detail visual-hierarchy refinement. Build178 remains the accepted overall functional baseline._

## Current functional baseline

The latest **real-device accepted** functional baseline is:

- Product: **OnePlayer**
- Version: **0.14.11**
- Build: **178**
- Canonical branch: `main`
- Final merge PR: **#254**
- Final merge commit: `9e0d0cecb2df0a263a9a4a4c1f92c2d0e473d78f`
- Development branch: `fix/nonstandard-episode-sorting`
- Clean product head before merge: `8718f60a1b0a3d0034473f1cc1769c0b5bc3665f`
- Dedicated CI source: `db9aa2498fba5c6b092bfec2427042859e32b26a`
- Dedicated CI run: **32836693548**
- Artifact: `OnePlayer-0.14.11-build178-episode-ordering`
- IPA SHA-256: `2e4ed5be2c32535249ea2049a9686f6ac24a217e04535806ee6ee4721e78ba5b`
- Deployment Target: **iOS 15.0**
- Required target device: **iPhone 15 Pro Max / iOS 17.0**
- Evidence: **Code written / CI passed / IPA produced / real-device accepted / stable for current requirements / merged to main**

Build178 inherits the accepted Build176 player episode-selection/session contract and adds the accepted canonical Emby TV episode-ordering contract. The user completed target-device validation on 2026-08-25 and explicitly approved this task for acceptance, completion and merge.

Build179 / OnePlayer 0.14.12 is **not** an accepted carousel baseline. Its dedicated Release CI passed and IPA was produced, but the user installed it on the target device and reported that small drags still had a dead zone and direction reversal still produced a visible pause followed by a large catch-up jump. Build179 is therefore real-device tested / rejected.

Build180 / OnePlayer 0.14.13 is the current **home-carousel test candidate**. Dedicated standard MPV Release CI passed and IPA was produced; target-device evidence is pending, so it does not replace Build178.

Build181 / OnePlayer 0.14.14 is now a **detail-page diagnostic reference rather than the current candidate**. Target-device recording shows the previous obvious detail scroll pause→catch-up pattern is clearly improved, but a force-quit/relaunch still resets its session-only warm metadata and briefly returns the text-title/episode-loading state. It is real-device tested but not stable.

Build182 / OnePlayer 0.14.15 is **real-device accepted and frozen for detail scrolling plus force-quit/relaunch presentation restoration** on iPhone 15 Pro Max / iOS 17.0. It remains a feature-line reference while Build178 stays the overall merged baseline.

Build184 / OnePlayer 0.14.17 is the current **detail visual-hierarchy test candidate**. It only reorders/renames the media-information section and slightly reduces main section-header typography; dedicated Release CI passed and IPA was produced. Real-device visual acceptance is pending.

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
- evidence level: **Code written / CI passed / IPA produced / real-device pending / not stable**

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

Build178 / OnePlayer 0.14.11 remains the current real-device accepted `main` runtime baseline. Build179 carousel is explicitly rejected by real-device evidence. Build180 / OnePlayer 0.14.13 is the current carousel test candidate with CI/IPA evidence. Build181 / OnePlayer 0.14.14 is a real-device-tested partial-success detail reference: scroll is clearly improved but cold-relaunch warm start failed. Build182 / OnePlayer 0.14.15 is the current detail cold-relaunch test candidate with CI/IPA evidence. Build180 and Build182 both require iPhone 15 Pro Max / iOS 17.0 validation before acceptance.

New work should proceed module-by-module without casually touching:

- MPV Seek;
- PiP;
- UnifiedTransport;
- cache semantics;
- system navigation.

If a new module requires changes in one of those frozen areas, state the reason explicitly before modifying it.
