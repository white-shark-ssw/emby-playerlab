# OnePlayer Project State

_Last updated after Build178 / OnePlayer 0.14.11 non-standard episode-ordering CI + IPA handoff. Build176 remains the latest real-device accepted baseline._

## Current functional baseline

The latest **real-device accepted** functional baseline is:

- Product: **OnePlayer**
- Version: **0.14.9**
- Build: **176**
- Canonical branch: `main`
- Final merge PR: **#253**
- Final merge commit: `d10e0d63b429f72a664193a1a5bacf728cac50b6`
- Development branch: `feat/player-episode-picker-0.14.7`
- Development PR: **#249** (historical / superseded by final main merge PR #253)
- Product source before the temporary Build176 CI helper: `f701f0446d65e84fc686f69ec14d60402c94839c`
- Dedicated CI source: `221630297dc1080279bb8a3f05d69586461b328c`
- Workflow-restored branch head after Build176 CI: `4b26a7d3a9826c58bfdddd6aafaeb9eeb5c7c943`
- Main-synchronization merge on the feature branch: `1ff5598c18e8c46856efecbd1d2f15df422098c6`
- Dedicated CI run: **32782048086**
- Artifact: `OnePlayer-0.14.9-build176-episode-picker-ui`
- Deployment Target: **iOS 15.0**
- Required target device: **iPhone 15 Pro Max / iOS 17.0**
- Evidence: **Code written / CI passed / IPA produced / real-device accepted / stable for current requirements / merged to main**

`main` contains the accepted Build176 product tree. Build177 and Build178 are parallel feature candidates and do **not** replace this accepted baseline until their respective real-device tests pass.

Before PR #253, `main` had advanced independently with project governance/history/CI files only. The synchronization step preserved those current `main` files while reusing the exact accepted Build176 product trees/blobs for `Sources`, `Resources`, `Config`, `scripts`, project specs and Podfile. No runtime source was changed by synchronization, so no Build177 was created merely for the merge.

Build176 completes the player episode-selection task for the current requirements. The accepted behaviour includes:

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

The episode media/session rule is source-owned replacement rather than in-place source mutation. Each selected episode receives a fresh `PlayerController`, `PlaybackOrchestrator`, `PlaybackTransportContext` and Emby playback session. Episode metadata may be loaded ahead of selection, but 115/CDN temporary media URLs are resolved only when the user selects an episode or a trusted natural end requests the next one.

## Current feature candidates

### Build177 / OnePlayer 0.14.10 — home carousel smoothness

`DEV-home-carousel-drag-smoothness` owns Build177. Its source/CI/real-device state is tracked independently in its checkpoint. Build177 must not be reused by another task.

### Build178 / OnePlayer 0.14.11 — canonical episode ordering

`DEV-nonstandard-episode-sorting` owns Build178. User real-device comparison established that OnePlayer's current order is wrong for a 165-item non-standard series while EplayerX matches Emby; app diagnostics show `nilIndex=164`. The minimal fix changes shared `seriesEpisodes(seriesId:)` from generic Items + forced `ParentIndexNumber,IndexNumber` ordering to Emby's TV-specific `/Shows/{SeriesId}/Episodes` endpoint and preserves the server-returned order.

Current Build178 evidence:

- branch `fix/nonstandard-episode-sorting`
- draft PR #254 against `main`
- clean product head `8718f60a1b0a3d0034473f1cc1769c0b5bc3665f`
- dedicated standard MPV Release CI source `db9aa2498fba5c6b092bfec2427042859e32b26a`
- CI run `32836693548` = **success**
- artifact `OnePlayer-0.14.11-build178-episode-ordering`
- IPA SHA-256 `2e4ed5be2c32535249ea2049a9686f6ac24a217e04535806ee6ee4721e78ba5b`
- Xcode 16.4 Release build passed; app identity = 0.14.11 (178); App/runtime Mach-O MinOS = 15.0
- evidence level: **Code written / CI passed / IPA produced**
- fixed ordering real-device validation: **pending**

Build178 does not modify PlayerController, Player episode-selection/session ownership, MPV Seek, PiP, UnifiedTransport, cache, STRM/302/115 direct transport, or Emby progress/resume. Do not merge/promote Build178 until the known abnormal series and at least one normal indexed series pass target-device validation.

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

PiP development remains **temporarily frozen at Build173** even though the overall accepted functional baseline is now Build176.

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

Build176 / OnePlayer 0.14.9 remains the real-device accepted `main` baseline. Parallel feature work is currently isolated by task/build identity: Build177 is reserved for home-carousel drag smoothness and Build178 for Emby canonical episode ordering. Each candidate must retain its own branch, CI/IPA evidence and real-device acceptance; neither may be described as stable merely because CI passed.

New work should proceed module-by-module without casually touching:

- MPV Seek;
- PiP;
- UnifiedTransport;
- cache semantics;
- system navigation.

If a new module requires changes in one of those frozen areas, state the reason explicitly before modifying it.
