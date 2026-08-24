# OnePlayer Project State

_Last updated after Build175 / OnePlayer 0.14.8 episode-selector UI refinement CI/IPA candidate._

## Current functional baseline

The latest **real-device accepted** functional test baseline remains:

- Product: **OnePlayer**
- Version: **0.14.6**
- Build: **173**
- Development branch: `fix/pip-seek-completion-return-simplify-0.14.6`
- PR: **#238**
- Known head during Build173 handoff: `4f7acf8da06ded00db735b07210983a0d2dd5be6`
- Deployment Target: **iOS 15.0**
- Required target device: **iPhone 15 Pro Max / iOS 17.0**

The repository `main` branch is not necessarily the latest functional player baseline. Always resolve the current test branch/build before analysing logs or changing player code.

## Current development candidate

**OnePlayer 0.14.8 / Build175** is the current episode-selection real-device test candidate:

- branch: `feat/player-episode-picker-0.14.7`
- draft PR: **#249**
- standard MPV Release build source commit: `cbd700dbb6ae884dbd6b9cca8cb110d590e3d39d`
- dedicated CI run: **32780288067**
- artifact: `OnePlayer-0.14.8-build175-episode-picker-ui`
- state: **Code written / CI passed / IPA produced / real-device pending**

Build174 / OnePlayer 0.14.7 was installed on device and confirmed that the selector opened and displayed episode data, but the first selector presentation was rejected visually: the large gray material sheet, explicit X close button, and `选集 / 剧名` header did not match the desired player interaction. That real-device feedback is the reason for Build175; Build174 is not a stable/frozen UI baseline.

Build175 keeps the existing OnePlayer player-bottom button layout fixed. The selector itself is now an overlay over the player control layer: no large sheet background, no explicit close button, no `选集 / 剧名` title block, normal landscape safe-area insets, compact `第N季` menu, in-place season filtering, and detail-page-style 174×98 episode cards with a title plus up to two lines of Emby overview text. Tapping the player area above the selector dismisses it. Selecting a season only browses; it does not resolve or start media.

The episode media/session rule remains source-owned replacement rather than in-place source mutation. The fullscreen host remains presented, while each selected episode receives a fresh `PlayerController`, `PlaybackOrchestrator`, `PlaybackTransportContext` and Emby playback session. Episode metadata can be prepared, but 115/CDN temporary media URLs are resolved only when the user selects an episode or a trusted natural end requests the next one.

Automatic next episode is gated by the same `PrematureEOFGuard` semantics used by the player: only a non-premature natural end may advance. Premature EOF, abnormal short-media recovery, network starvation and raw engine EOF are not enough.

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

PiP development is **temporarily frozen at Build173**.

Accepted current behaviour:

- native system PiP;
- SampleBuffer-based PiP visual path;
- MPV remains playback/audio/timeline authority;
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

Build175 episode selection is the active real-device test candidate. Until accepted, Build173 remains the real-device accepted functional baseline.

New work should proceed module-by-module without casually touching:

- MPV Seek;
- PiP;
- UnifiedTransport;
- cache semantics;
- system navigation.

If a new module requires changes in one of those frozen areas, state the reason explicitly before modifying it.
