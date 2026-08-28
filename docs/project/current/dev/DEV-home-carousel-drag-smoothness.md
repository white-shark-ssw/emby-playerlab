# DEV-home-carousel-drag-smoothness

## Status

**Active — scope corrected after the 2026-08-28 Build224 target-device report. The user still sees visible jitter during Home vertical inertial scrolling, but this task is specifically about carousel horizontal swipe/drag smoothness. Build222–224 vertical Home scrolling A/Bs are now supporting diagnostics only and must not be used as the acceptance gate for the carousel task. Build224 therefore records a vertical-only real-device result, not a horizontal carousel verdict. The current direct carousel candidate returns to Build221 / 0.14.54, whose horizontal persistent-drag isolation is already CI/IPA verified and still needs target-device horizontal A/B. Build216 remains the accepted overall product baseline.**

- Work ID: `DEV-home-carousel-drag-smoothness`
- Target device: iPhone 15 Pro Max / iOS 17.0
- Deployment Target policy: remain iOS 15.0
- Accepted overall product baseline: OnePlayer 0.14.49 / Build216 on `main`
- Historical continuation source: user-supplied `轮播图优化v2.md`

## Scope correction — 2026-08-28

The user explicitly clarified that the active goal is **carousel optimization**, not general Home vertical scrolling smoothness. This changes the acceptance scope:

- the primary acceptance path is horizontal carousel swipe/drag feel on the target device;
- evaluate first-move granularity, sustained finger tracking, reversal continuity, backdrop/foreground continuity, release/settle and the subjective gap versus EX;
- Home vertical inertial scrolling may still reveal shared image/compositor pressure, but it is supporting evidence only and cannot pass/fail the carousel interaction task;
- Build222–224 are therefore closed as a vertical supporting-diagnostic detour and must not drive another vertical-only Build225;
- resume the existing Build221 horizontal A/B before writing any new carousel patch.

## Retained interaction contract

Build198 remains the input foundation:

`one UIKit interaction surface → one begin/move/end/cancel owner → one V3HomeCarouselTransitionState → SwiftUI render`

Retain unless new direct device evidence proves otherwise:

- vertical acquisition yields to Home `UIScrollView`;
- horizontal acquisition owns the gesture through end/cancel;
- acquisition-relative foreground X from Build215;
- full-width page slots (`pageStep = width`) from Build208;
- interactive foreground remains opaque;
- predicted touch is release-only;
- commit threshold remains 0.28;
- predicted-distance release gate remains 0.48 × width;
- no second SwiftUI drag/release owner;
- no interpolation/timer/watchdog/retry/debounce/throttle smoothing layer.

Player / MPV / PiP / UnifiedTransport / Range/206 / playback Cache / Emby Session / STRM→302→115/CDN client-direct paths are outside this task and must remain unchanged.

## Controlling evidence

### Build215 / 0.14.48

Acquisition-relative render baseline + opaque interactive foreground fixed the coarse start and ghosting, but overall tactile smoothness still trailed EX (user description: EX feels like smooth glass, OnePlayer like rough paper).

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / partial success / stable ❌.

### Build217 / 0.14.50

Passive carousel path measured around 50–60 Hz on the 120 Hz target device. Delivered touch → progress publication → SwiftUI render followed almost one-for-one; coalesced touch data was denser but did not drive render.

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device diagnostic tested ✅ / ~60 Hz baseline established / stable ❌.

### Build219 / 0.14.52

Drag-local device-max refresh request raised delivered touch / progress / SwiftUI render / display to roughly 103 / 99 / 98 / 110 Hz, with the on-screen meter repeatedly reaching 118–120 FPS. Remaining discrete 34–50 ms gaps frequently correlated with Hero/persistent 1400px image callbacks; strongest repeatable persistent pattern was ~50 ms about 19.6–25.3 ms after callback.

The actual Build219 tested source explicitly tagged image callbacks as three separate roles: `hero`, `persistent`, and `preload`. In the recorded 15 worst-gap samples at or above 25 ms, 11 occurred within 30 ms of the latest **Hero/persistent** callback. Repeated samples included persistent callback → 19.6–25.3 ms → 50 ms display gap, plus Hero callback → ~10.9–11.2 ms → ~26.7–39.2 ms gap. The controlling evidence therefore points more strongly to Hero/persistent presentation than to preload.

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device diagnostic tested ✅ / 120 Hz request effectiveness proven ✅ / stable ❌.

### Build222 / 0.14.55

Independent vertical A/B blocked new automatic carousel transitions after Home left the top. Target-device feedback still perceived vertical hitching, so offscreen auto-advance alone is rejected as sufficient.

- tested source `694221315c727ea055ea3b5ef7a9ea03a260fe80`
- run/job `33101409110 / 98619779746`
- artifact `9658757261`
- IPA SHA-256 `8cf6d454bf7eec64207875e9c20a1bbc6b125578f11fb777bfdda4fa6b5c5bfe`

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / rejected as sufficient / stable ❌.

## Build223 / 0.14.56 — persistent-backdrop isolation

### Build / package identity

- branch: `diag/home-carousel-persistent-backdrop-isolation-build223`
- tested source / CI head: `af54d693d91303ea9bd201b5525e24f3e15ad931`
- run/job: `33110117601 / 98650408622` — success
- artifact ID: `9662245993`
- IPA SHA-256: `a925714dceb138df7808079b5784f3337afe92245bd790c42c290eac82ccd73c`
- independently verified OnePlayer `0.14.56 (223)`, bundle `com.embyplayerlab.app`, MinOS 15.0.

### Exact runtime change and real-device result

Only `Sources/UI/EmbyHomeCoreV3.swift` presentation mounting changed: immersive Home stopped mounting `persistentCarouselBackdrop(...)` at the root ZStack. `carouselPreloadLayer`, Hero artwork, normal Build216 auto-advance, horizontal interaction and all P0/Frozen paths remained unchanged.

2026-08-28 target-device result on iPhone 15 Pro Max / iOS 17.0:

- **Home vertical scrolling still had obvious perceptible jitter.**
- Removing the always-mounted full-screen persistent backdrop therefore does **not** materially solve the vertical hitch family and is rejected as a sufficient fix.
- The bottom Dock also changed appearance. Dock source was unchanged; its `.ultraThinMaterial` lost the full-screen backdrop behind it and became a gray/translucent strip. This is an unintended diagnostic visual regression, not a Dock redesign, and must not be carried forward.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / vertical hypothesis rejected as sufficient / unintended Dock visual regression / stable ❌.

## Why Build224 isolates Hero before preload

The next variable is not arbitrary:

1. Build219 distinguished `hero`, `persistent`, and `preload` callback roles in the actual tested source.
2. The strongest recorded long-gap correlation was specifically Hero/persistent, not preload.
3. Build223 has now directly tested removal of the persistent presentation and did not materially improve vertical smoothness.
4. The remaining evidence-backed presentation component in that pair is the Hero clear 1400px image surface.

Therefore Build224 isolates only Hero artwork mounting. Preload remains unchanged so this A/B does not mix two hypotheses.

## Build224 / 0.14.57 — Hero artwork presentation isolation

### Identity / CI evidence

- branch: `diag/home-carousel-hero-artwork-isolation-build224`
- base at branch creation: `2e02e87773c05295f6e3c88a67f3fa4e110edd92`
- identity: OnePlayer `0.14.57`, Build `224`
- tested CI head / exact source snapshot: `b6ee3361f183257a2ae01f1336506ab4a4c1a254`
- dedicated Xcode 16.4 run/job: `33142773132 / 98757057369` — success
- artifact ID: `9674622017`
- IPA SHA-256: `5b8c973cb5d34cf843f2649bda72f6a3f48ab5766c023b9c3e587f9eb4d9c845`
- source ZIP SHA-256: `6537f85e6f644ccc85491ec357040bdac766e2ee63ef98ba1af5ec253d134a86`
- OnePlayer `0.14.57 (224)`, bundle `com.embyplayerlab.app`, MinOS 15.0 independently verified.

### Exact product diff

Against its main base, product source changes are only `Sources/Core/AppIdentity.swift` plus removal of the current/target `carouselHeroArtwork` mounts from `immersiveCarouselHero`. The Hero implementation itself remains in source. Root persistent backdrop, 30pt persistent blur, preload, foreground/logo/text/page indicators, normal auto-advance, horizontal interaction/state ownership and all P0/Frozen paths remain unchanged.

### 2026-08-28 target-device result and scope meaning

User feedback on iPhone 15 Pro Max / iOS 17.0: **Home vertical inertial scrolling still visibly jitters.** This proves only that removing the clear Hero artwork mount is not sufficient to remove the separate Home vertical hitch. The reported test did **not** evaluate the intended horizontal carousel drag feel, so Build224 must not be described as accepted or rejected for horizontal carousel smoothness.

The more important scope correction is that general Home vertical scrolling is not the primary goal of `DEV-home-carousel-drag-smoothness`. Build224 closes the vertical-only detour; do not extend it into another vertical-only candidate.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device vertical-only tested ✅ / horizontal carousel verdict not established ❌ / stable ❌.

## Build221 / 0.14.54 — separate horizontal lane

- tested source `26fc82771b6778af14974fdac293ece0685fc76d`
- artifact `9654120029`
- IPA SHA-256 `d2ee4fb2d40c251399951bc72ba6ad35fbe8ba3bfd72b861274b9b2c38fe0d9c`
- during active horizontal drag only, current persistent remains opaque and target persistent is not mounted; Hero transition and high-refresh request remain.

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending ❌ / diagnostic only / stable ❌.

## Rejected directions not to repeat

- Build222 offscreen-auto-advance guard as a fix;
- Build223 permanent persistent-backdrop removal;
- carrying Build223 Dock appearance forward;
- arbitrary 15% / 30% / 80% travel tuning;
- whole-range easing to hide coarse input;
- split native-move + SwiftUI-release ownership;
- recoupling foreground alpha to backdrop blend;
- coalesced-touch second visual owner without new evidence;
- debounce/throttle/timer/interpolator/watchdog/retry smoothing.

## Next exact action

Return to the carousel itself. Use the already CI/IPA-verified **Build221 / 0.14.54** for target-device horizontal A/B before writing any Build225. Test repeated left/right drags on the carousel, especially:

- first visible movement after acquisition;
- sustained 1:1 finger tracking / “smooth glass vs rough paper” feel;
- rapid reversal continuity;
- whether backdrop presentation still produces perceptible drag-time catches;
- release/settle separately, because Build221 intentionally restores the normal persistent transition after release.

If Build221 materially improves horizontal drag, persistent backdrop presentation during active drag is a causal component and the next patch should redesign that horizontal presentation path without removing the normal visual result. If Build221 is essentially unchanged, reject that isolation as sufficient and choose the next horizontal-only variable from the Build219 evidence. Do not use Home vertical inertial scrolling as the acceptance gate for the carousel task.
