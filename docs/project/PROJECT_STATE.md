# OnePlayer Project State

_Last updated after Build179 / OnePlayer 0.14.12 home-carousel CI success and IPA production; Build179 still awaits real-device validation, so Build178 remains the accepted functional baseline._

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

Build179 / OnePlayer 0.14.12 is now the current **home-carousel test candidate**, not the accepted baseline. Its dedicated Release CI passed and IPA was produced, but there is no Build179 real-device evidence yet.

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
- no title, filename, DateCreated, item-ID or artificial-number fallback sorting is introduced;
- detail page, all-episodes view, player picker and trusted auto-next consume the same canonical episode array.

The original failing non-standard series had 165 episodes with `nilIndex=164`; Build178 was accepted on real device after switching the shared data path to Emby's TV ordering authority.

## Current parallel feature candidates

### Build179 / OnePlayer 0.14.12 — home carousel smoothness

`DEV-home-carousel-drag-smoothness` has been synchronized from its older Build173/Build177 preliminary line onto the accepted Build178 runtime baseline.

- integration base: `main@967b743c88d68b05205eb39f1de75cab41362e8b`, which already contains accepted Build176/178 runtime behavior
- branch: `perf/home-carousel-drag-smoothness-build179`
- workflow-restored branch head: `839cc0c3506c68e1c04887e438a77575a10fd8a0`
- dedicated CI source: `22515402f4d17e1a9b4073c535265b65ba55f52d`
- CI run: `32841344067` — **success**
- artifact: `OnePlayer-0.14.12-build179-home-carousel-smoothness`
- artifact ID: `9560700233`
- IPA SHA-256: `80f2c70215fe3f1c9323894eedbd22c5f61b29bcfb61e3a6e14115a4b932ddd8`
- MinOS: app/runtime Mach-O validated at iOS 15.0
- evidence level: **Code written / CI passed / IPA produced / real-device not yet tested / not stable**

The Build179 product diff is limited to the two home-carousel source files, AppIdentity, changelog and two relevant static checks. CI explicitly verifies Build176/178 accepted player/order files and the P0 playback/transport/cache files are unchanged from the Build178 base. Build179 should only replace Build178 as the accepted baseline after the user validates the carousel on the target device.

Build179 CI completed after `main` advanced from `967b743` to `2f3209ad`; compare showed that advancement only added `docs/project/current/dev/DEV-detail-episode-page-optimization.md` and changed no runtime source, so it does not invalidate the Build179 test package.

### Detail / episode page optimization

`DEV-detail-episode-page-optimization` is a separate Active task on branch `feat/detail-episode-page-optimization`, created from the same accepted Build178 runtime baseline. No Build has been assigned yet. Its current expected scope is detail/episode UI rather than home-carousel files/state owner, so the two tasks can proceed independently unless future requirements expand into shared infrastructure.

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

Build178 / OnePlayer 0.14.11 remains the current real-device accepted `main` runtime baseline. Build179 is the current carousel test candidate with CI/IPA evidence only. The separate detail/episode page optimization task is also Active and must re-check shared files/state owners if its scope expands.

New work should proceed module-by-module without casually touching:

- MPV Seek;
- PiP;
- UnifiedTransport;
- cache semantics;
- system navigation.

If a new module requires changes in one of those frozen areas, state the reason explicitly before modifying it.
