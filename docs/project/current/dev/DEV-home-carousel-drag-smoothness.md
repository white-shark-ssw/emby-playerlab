# DEV-home-carousel-drag-smoothness

## Status

**Active — Build203 target-device exposed the remaining issue: 30% total travel is still too short overall, yet raw-progress spatial mapping makes the first visible displacement too large. Carousel Build204 / 0.14.37 was retired before distribution because that identity is already owned by the independent poster-scroll task. Build205 keeps the same UIKit owner, raises total travel to 80%, and applies the existing `progress²` visual curve to spatial offset as well as opacity. CI/IPA verified; target-device validation pending.**

- Work ID: `DEV-home-carousel-drag-smoothness`
- Routing aliases / keywords: 轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- Accepted overall baseline: OnePlayer **0.14.32 / Build199** on `main`.
- Target device: iPhone 15 Pro Max / iOS 17.0.
- Evidence sync: 2026-08-27 +08:00.

## Retained input contract

Build198 remains the input foundation:

`one UIKit interaction surface → one begin/move/end/cancel owner → one V3HomeCarouselTransitionState → SwiftUI render`

Do not change without new direct evidence:

- 0.5pt axis acquisition;
- vertical acquisition yields to Home `UIScrollView`;
- horizontal acquisition owns the gesture through end/cancel;
- actual touch drives raw `transitionProgress`; predicted touch is release-only;
- commit threshold 0.28;
- predicted-distance gate 0.48 × width;
- existing settle ownership/timings;
- no second SwiftUI drag/release owner;
- no interpolation/timer/watchdog/retry/debounce/throttle.

Player / MPV / PiP / Transport / Cache / Emby Session / STRM→302→115/CDN client-direct paths remain outside this task.

## Key real-device history

- Build185/187: first visible / useful horizontal motion remained much coarser than EX; SwiftUI input cadence was not fine enough to justify more threshold tuning.
- Build189/193: split move/end ownership could freeze between pages; rejected architecture.
- Build198 / 0.14.31: single UIKit owner fixed lifecycle/settle/reversal behavior, but minimum/subtle drag still felt too coarse versus EX.
- Build200 / 0.14.33: fully fixed foreground + crossfade passed CI/IPA but was rejected because foreground stopped sliding horizontally. Fully fixed foreground must not return.
- Build201 / 0.14.34: 15% horizontal travel restored directional slide and user reported **“有点那种感觉了”**; this proved short-travel visual mapping can reduce the perceived initial jump, but 15% was not enough total travel.

## Build203 — target-device result

Build203 / 0.14.36 used:

- foreground travel `0.30 × width`;
- opacity/backdrop blend = clamped `progress²`;
- foreground spatial offset still used **raw linear `transitionProgress`**;
- existing left/right + first↔last modulo neighbor ownership unchanged.

Verified evidence:

- branch: `perf/home-carousel-accelerating-blend-build203`
- tested source: `69beee45b93dc11c7c5be2ee4b81a5a0157f2653`
- durable cleanup head: `edafd5d784cfacdcf8c451fad93535a55fb880fb`
- CI run/job: `32995898318` / `98264917294` — success
- artifact ID: `9616576496`
- IPA SHA-256: `cee7241b73c4dc38efb6593c3d6ec9f54981f8e5a609be78a491b869df685226`
- MinOS 15.0 independently verified.

Latest target-device result on 2026-08-27:

- 30% total travel still feels insufficient overall;
- unlike 15%, 30% makes the **initial drag jitter / first visible displacement** perceptible again;
- user explicitly identified that 15% may have felt closer partly because the entire travel was very small;
- requested the spatial motion to use the same restrained-start / accelerating-later idea as opacity, while increasing total travel to **80%**.

Conclusion: the remaining issue is now more specifically attributed to **raw progress → spatial offset mapping**, not to gesture ownership and not simply to total travel length.

**Build203 = Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / rejected as final parameterization / not stable.**

## Retired carousel Build204 identity collision

A carousel package was briefly created as `0.14.37 / Build204` with the intended 80% + `progress²` spatial mapping and completed CI. During mandatory global project-state reread, the independent poster-scroll task was found to already own **OnePlayer 0.14.37 / Build204** with its own verified source/artifact.

Therefore:

- carousel `0.14.37 / Build204` is **retired and must not be distributed or used for attribution**;
- its successful CI does not reserve or redefine Build204;
- canonical Build204 ownership remains the poster-scroll task;
- carousel moved unchanged product intent to Build205 / 0.14.38.

## Build205 — current candidate

Identity:

- OnePlayer **0.14.38 / Build205**
- branch: `perf/home-carousel-eased-travel-build205`
- base: Build203 durable cleanup head `edafd5d784cfacdcf8c451fad93535a55fb880fb`
- tested source: **`e5f2e7b4135eca333d5dda24545f19ee8d0be439`**
- durable cleanup head: **`70d6cca676911e656591aae6b342c771cc92b9fe`**
- tested-source → cleanup-head delta: only `.github/workflows/temp-build205-carousel-ci.yml` deletion; product/runtime source unchanged.

Runtime changes are limited to `Sources/Core/AppIdentity.swift` and `Sources/UI/EmbyHomeCarouselStateV3.swift`:

- total foreground travel: `0.30 × width` → **`0.80 × width`**;
- `visualProgress = carouselBackdropBlendProgress(transitionProgress)`;
- existing blend helper remains clamped `progress²`;
- outgoing offset = `-direction × visualProgress × travel`;
- incoming offset = `direction × (1 - visualProgress) × travel`;
- opacity remains outgoing `1-blend`, incoming `blend` using the same `progress²` curve;
- raw `transitionProgress` is unchanged and remains the release/commit authority.

This separates the two requirements that previously fought each other:

- at raw progress 0.10, Build203 spatial displacement was `0.30 × 0.10 = 0.03 width`; Build205 is `0.80 × 0.10² = 0.008 width`, so the start is materially more restrained even though total travel is much larger;
- at raw progress 0.50, Build205 reaches `0.80 × 0.25 = 0.20 width`;
- at progress 1.0 it reaches the requested full 80% travel.

Left/right and first↔last boundaries continue to use the existing direction sign plus `(index + direction + items.count) % items.count`; there is no edge-specific state machine or duplicate progress owner.

Build203→Build205 scoped delta is limited to:

- `Sources/Core/AppIdentity.swift`
- `Sources/UI/EmbyHomeCarouselStateV3.swift`
- `docs/changelog/CHANGELOG_v0_14_38_build205.md`
- `scripts/check_home_carousel_single_owner.py`
- temporary Build205 CI workflow, removed after evidence capture.

No Frozen/P0 runtime file is in the diff.

## Build205 CI / packaging evidence

- CI run/job: **`32998533448` / `98273968966` — success**
- source contract/Frozen guard, Xcode 16.4, icon generation, dependencies, Release build, app identity, MinOS, IPA/source packaging and upload: all success.
- artifact: `OnePlayer-0.14.38-build205-home-carousel-eased-travel`
- artifact ID: **`9617634710`**
- artifact digest: **`sha256:3efb42f2ff3bf7ea7ed31a58f188b30c449e4cb0b703b111ee47ef98e3a51671`**
- independently downloaded artifact ZIP SHA-256: `3efb42f2ff3bf7ea7ed31a58f188b30c449e4cb0b703b111ee47ef98e3a51671` — exact digest match.
- IPA: `OnePlayer-0.14.38-build205-home-carousel-eased-travel-unsigned.ipa`
- IPA SHA-256: **`fe4a81ebee9d330526c108edf2ab4652632ae5b204719864e0b5dee486086479`**
- source ZIP SHA-256: **`b556620d0d312259e6d2e823c7f8079109f44c13e00c56b1718cfcfea4cd38f1`**
- embedded checksum files match independent IPA/source hashes.
- independent IPA `unzip -t`: PASS.
- independent Info.plist: bundle `com.embyplayerlab.app`, display/name `OnePlayer`, version/build `0.14.38 (205)`, `MinimumOSVersion=15.0`, primary `OnePlayerIcon`, alternate `OnePlayerAltIcon`.

**Build205 = Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device pending / not stable.**

## Next exact action

1. Install/test the verified Build205 IPA on iPhone 15 Pro Max / iOS 17.0.
2. A/B against Build203 and EX.
3. Focus first on the first few millimeters of drag: the first visible horizontal displacement should be much smaller than Build203 despite the larger 80% total travel.
4. Confirm mid/late drag accelerates naturally and reaches a substantially larger total slide than Build201/203.
5. Verify left/right, first→last, last→first, reversal, cancel/commit, vertical Hero scroll, detail tap and auto-advance.
6. Do not alter the UIKit owner or raw commit/release thresholds unless new target-device evidence requires it.
