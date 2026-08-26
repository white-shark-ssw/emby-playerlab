# DEV-home-carousel-drag-smoothness

## Status

**Active — Build201 target-device direction improved (“有点那种感觉了”); Build203 raises foreground travel to 30% and uses an accelerating opacity curve. CI in progress.**

- Work ID: `DEV-home-carousel-drag-smoothness`
- Routing aliases / keywords: 轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- Accepted overall baseline remains OnePlayer **0.14.32 / Build199** on `main`; this carousel line is independent and not stable.
- Evidence sync: 2026-08-27 +08:00.

## Retained contract

Build198 remains the input foundation:

`one UIKit interaction surface → one begin/move/end/cancel owner → one V3HomeCarouselTransitionState → SwiftUI render`

Do not change without new direct evidence:

- 0.5pt axis acquisition;
- vertical acquisition yields to Home `UIScrollView`;
- horizontal acquisition owns the gesture through end/cancel;
- actual touch drives rendering, predicted touch is release-only;
- commit threshold 0.28;
- predicted-distance release gate 0.48 × width;
- existing settle ownership/timings;
- no second SwiftUI drag/release owner;
- no interpolation/timer/watchdog/retry/debounce/throttle.

Player / MPV / PiP / Transport / Cache / Emby Session / STRM→302→115/CDN client-direct paths remain outside this task.

## Historical evidence retained

- Build185: first visible movement roughly 10/12/16 px versus EX roughly 1/1/2 px.
- Build187: first useful horizontal samples roughly 4.33/8.00/15.67/11.00pt, maxFPS=120, Low Power Mode off.
- Build189 / Build193: split move/end ownership could freeze between pages; rejected architecture.
- Build198 / 0.14.31: single UIKit owner fixed lifecycle/settle/reversal behavior, but minimum/subtle drag remained too coarse versus EX.
- Build200 / 0.14.33: fixed foreground + linear crossfade passed CI/IPA but target-device rejected the semantic regression because foreground no longer slid horizontally. Fully fixed foreground must not return.

## Build201 — target-device result

Build201 restored horizontal foreground movement with `travel = width * 0.15` and retained linear `1-progress / progress` opacity.

Identity/evidence:

- version/build: **OnePlayer 0.14.34 / Build201**
- branch: `perf/home-carousel-short-travel-build201`
- tested source: `e61070146d91bac45400e3f95e28eead756faa81`
- successful run/job: `32993286519` / `98255950676`
- artifact ID: `9615585817`
- IPA SHA-256: `d889f2c36b3f617b429e4f39ba54d39d7f2826a058a2d4f874bc7a9bb574db58`
- MinOS 15.0 verified.

Target-device result on 2026-08-27:

- user: **“有点那种感觉了”** — 15% short-travel direction is materially closer to the desired feel;
- user requested travel increase **15% → 30%**;
- user requested transition opacity to change very little at drag start and increasingly faster later;
- this must work identically for left/right swipes and first↔last wrap boundaries.

**Build201 = Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / direction partially positive / parameter not accepted as final / not stable.**

## Build203 — current candidate

Build202 is occupied by the independent poster-scroll task, so the next carousel identity is **OnePlayer 0.14.36 / Build203**.

Branch: `perf/home-carousel-accelerating-blend-build203`
Base: Build201 tested source `e61070146d91bac45400e3f95e28eead756faa81`.

Runtime changes are deliberately limited to `AppIdentity.swift` and `EmbyHomeCarouselStateV3.swift`:

- foreground total travel: `0.15 × width` → **`0.30 × width`**;
- outgoing/incoming horizontal offset formulas and direction ownership remain unchanged;
- the existing single clamped `transitionProgress` remains the only visual progress owner;
- backdrop and foreground use the same accelerating blend: **`blend = progress²`**;
- outgoing opacity = `1 - blend`; incoming opacity = `blend`;
- this matches the requested perceptual behavior: very small opacity change at drag start, increasingly faster change later;
- the curve is direction-independent. Existing `neighborCarouselItemID` uses `(index + direction + count) % count`, so left/right swipes and first↔last wrapping use the same blend without a second edge/boundary state machine.

Unchanged:

- `EmbyHomeCarouselInteractionV3.swift` input owner;
- 0.5pt acquisition / 0.28 commit / 0.48×width predicted release gate;
- release/cancel/settle ownership;
- Hero/Core ownership, vertical scrolling, detail tap and auto-advance;
- all Frozen/P0 playback/transport/cache/PiP/session paths.

Build203 current source before CI result: `69beee45b93dc11c7c5be2ee4b81a5a0157f2653`.
Feature diff from Build201 contains the Build201→Build203 CI workflow rename, `AppIdentity.swift`, `EmbyHomeCarouselStateV3.swift`, Build203 changelog and updated contract checker only. Frozen/P0 source guard passed.

CI run: `32995898318`; job `98264917294`; Release pipeline in progress at this checkpoint update.

## Next exact action

1. Finish Build203 CI/IPA and independently verify identity/MinOS/hashes.
2. Target-device A/B against Build201 and EX.
3. Verify tiny drag: opacity change should begin subtly while horizontal motion remains obvious.
4. Verify later transition: opacity should accelerate rather than remain linear.
5. Verify normal left/right, first→last and last→first wrap drags use the same visual curve and settle correctly.
6. Verify reversal, cancel/commit, vertical Hero scroll, detail tap and auto-advance remain unchanged.
7. Do not alter gesture ownership or add smoothing infrastructure unless new device evidence requires it.
