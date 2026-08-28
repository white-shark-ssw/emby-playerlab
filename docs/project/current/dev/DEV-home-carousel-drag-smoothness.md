# DEV-home-carousel-drag-smoothness

## Status

**Active — Build228 / 0.14.61 is the current horizontal release-tail max-refresh A/B. Build227 is now target-device tested and rejected as a title-shimmer fix: physical-pixel foreground X rounding did not remove the movie-title jitter. The same Build227 recording reveals a separate release-tail smoothness issue, and exact source inspection proves the proven device-max refresh request was invalidated at `touchesEnded` before the existing 0.22s/0.18s automatic settle/cancel animation. Build228 returns to the cleaned Build226 presentation baseline and changes only that refresh-request lifetime through settle/cancel. Build228 CI/IPA is verified; target-device test pending. Build216 remains the accepted overall runtime baseline.**

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

## Build221 / 0.14.54 — horizontal persistent-drag presentation isolation

- tested source `26fc82771b6778af14974fdac293ece0685fc76d`
- cleanup `1d6df7f2490a5ef5968cafb229a46cba93c622db`
- run/job `33090175887 / 98580579889` — success
- artifact `9654120029`
- IPA SHA-256 `d2ee4fb2d40c251399951bc72ba6ad35fbe8ba3bfd72b861274b9b2c38fe0d9c`
- MinOS 15.0.

Exact runtime isolation: during active horizontal drag, the current persistent backdrop stays mounted at opacity 1 and the target persistent backdrop is not mounted. Hero current/target artwork transition, foreground movement, Build219 high-refresh request, release/settle and all P0/Frozen paths remain unchanged; normal persistent transition resumes after release.

### 2026-08-28 target-device result

User feedback on iPhone 15 Pro Max / iOS 17.0:

- **initial take-up / first movement feels okay**;
- **overall carousel feel still does not match EX**;
- during switching there appears to be a **brighter pale/white bottom glow**.

The supplied ~30 fps screen recording visibly contains washed/brighter intermediate frames during several horizontal transitions, so the brightness report is not treated as imagination. Exact Build221 source explains a plausible A/B-specific cause: while dragging, the persistent layer is frozen on the outgoing item, but current/target Hero artwork still crossfades above it. In light appearance, `persistentCarouselBackdrop` also keeps its `systemBackground` gradient. The intermediate Hero transparency therefore exposes an outgoing-image persistent/material backing that no longer matches the incoming Hero, making the pale/white lower glow more visible. This is a diagnostic visual regression, not an intended design.

Controlling conclusion: Build221 does **not** provide enough horizontal improvement to accept the frozen-persistent strategy, and it introduces a visible presentation mismatch. Persistent presentation may still contribute to measured gaps, but freezing it during the whole active drag is rejected as the final solution.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / horizontal real-device tested ✅ / initial take-up acceptable / overall still worse than EX / pale-white transition regression observed / stable ❌.

## Build225 / 0.14.58 — horizontal target-Hero presentation isolation

- branch: `diag/home-carousel-hero-drag-isolation-build225`
- exact base: Build219 tested source `0b894bc37fcd0086aeaf9e1a29de0e85f5b0ee94`
- identity: OnePlayer `0.14.58`, Build `225`
- Build225 does **not** inherit Build221's persistent freeze; persistent current/target crossfade is the normal Build219 behavior.
- During active horizontal drag only, the already-mounted current `carouselHeroArtwork` stays opacity 1 and `transitionTargetCarouselItem` Hero artwork is not mounted. When drag ends, normal Hero target mounting/crossfade resumes for release/settle.
- `carouselHeroArtwork` implementation, image loader, 1400px request, mask/scrim, preload, foreground page motion, acquisition-relative input, 0.28/0.48 release rules and Build219 exact device-max refresh request are unchanged.
- No Player / MPV / PiP / Transport / Cache / Emby Session / P0/Frozen source changes.

Why this variable: Build219's residual gaps correlated with both Hero and persistent callbacks. Build221 directly tested the persistent-side drag isolation and did not close the EX hand-feel gap, while also creating a visual mismatch. The remaining direct horizontal suspect is target Hero first presentation. Suppressing only the target Hero mount during active drag avoids unmounting the already-visible current Hero at touch acquisition and isolates newly presented Hero work without changing gesture ownership or motion math.

CI / package evidence:

- exact tested source: `350fd5d07ae2e77907bcf497deb819dfea6a28b1`;
- dedicated Xcode 16.4 run/job: `33149313932 / 98777365879` — success;
- artifact: `OnePlayer-0.14.58-build225-hero-drag-isolation`, ID `9677114082`;
- artifact SHA-256: `5e6d94602ef2c08ff3611bb8d749c6c9bd69df8a5f5bdeb089677ffa15cf3914`;
- IPA SHA-256: `221162e47de335b665cad6e0dd48aa82a8e27bb50cadcc24c2c6888d26db000a`;
- source ZIP SHA-256: `2849308d7a8e8f5c479a17e30ef6645bcf87f5f358065ba8b6dba7608623095e`;
- independent package reopen confirms bundle `com.embyplayerlab.app`, OnePlayer `0.14.58 (225)`, `MinimumOSVersion=15.0`, `CADisableMinimumFrameDurationOnPhone=true`;
- independent source reopen confirms target-Hero suppression only during active drag, normal persistent target crossfade retained, Build219 exact max-refresh retained, acquisition-relative render retained, and 0.28/0.48 release gates retained.

The earlier Build225 Action attempts were CI harness/setup failures before compilation (hard-coded Build219 version assertion and then non-idempotent patch helper) and are superseded by the successful dedicated run above; they are not product runtime evidence.

### 2026-08-28 horizontal real-device result

User feedback on iPhone 15 Pro Max / iOS 17.0: **“这版本感觉明显细腻了一些。”** This is the first direct horizontal real-device evidence that moving target clear-Hero first presentation out of the active finger-tracking phase materially improves tactile fineness.

Controlling conclusion: target `carouselHeroArtwork` 1400px first presentation during active drag is a **material causal contributor** to the remaining rough-paper feel. This does not prove Hero presentation is the only residual source. Build225 itself remains diagnostic rather than final because it intentionally withholds the incoming clear Hero during active drag and restores it only after release.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / horizontal real-device tested ✅ / materially finer feel ✅ / diagnostic visual compromise / stable ❌.

## Build226 / 0.14.59 — three-slot Hero residency

Build226 is the visual-preserving follow-up to Build225's positive target-Hero isolation. It keeps at most three clear Hero presentations resident for the settled item: current + previous + next, derived from the existing `currentCarouselItemID`. Both possible horizontal targets are therefore already mounted before active finger tracking, while normal Hero and persistent crossfades remain intact.

CI / package evidence:

- branch: `perf/home-carousel-hero-residency-build226`;
- exact tested source: `df1c9afce1dc96495dba16aa52e39254f23c7f65`;
- dedicated Xcode 16.4 run/job: `33151618930 / 98784687139` — success;
- artifact ID: `9677979449`;
- IPA SHA-256: `881638aec2b31bef6b3b6b08bbd31c978eb5f4454683225ad4a212ccad99fe34`;
- source ZIP SHA-256: `5342c7af8145fc32e1b131947f7ce05f3ee8f81c0de39179c92c51c958cfe2b0`;
- OnePlayer `0.14.59 (226)`, MinOS 15.0 independently verified.

### 2026-08-28 horizontal real-device result

User feedback on iPhone 15 Pro Max / iOS 17.0 after testing Build226:

- the first recording shows the **overall carousel is now fairly close to EX**;
- hand feel is **much better than the original OnePlayer carousel**, confirming the Hero-residency direction is correct;
- the user still feels there is room for further refinement, so Build226 is not yet stable/frozen;
- a second slow-drag recording exposes a separate visible issue: the large white movie-title text appears to shimmer/jitter while moving horizontally.

Both supplied recordings are `510×1108 @ 30 fps`. They are useful for visual/presentation evidence but cannot by themselves prove 120 Hz cadence parity. Frame-by-frame inspection of the slow-drag recording shows the title, rating/year/type row and overview translate together as one foreground page with stable relative geometry. The most visible instability is the high-contrast title glyph edge/clarity changing during slow horizontal movement, which supports a foreground text rasterization/compositing hypothesis rather than a title-only state or layout jump. This is not yet proof that physical-pixel alignment is the final fix.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / horizontal real-device tested ✅ / overall materially positive and fairly close to EX ✅ / residual slow-drag title shimmer observed / stable ❌.

## Build227 / 0.14.60 — foreground physical-pixel alignment A/B

Build227 rounded only the final foreground-page X offset to the current display physical-pixel grid while retaining Build226 Hero residency, normal Hero/persistent crossfades, Build215 acquisition-relative movement, Build219 device-max refresh request and the existing release rules.

CI / package evidence:

- branch: `diag/home-carousel-foreground-pixel-align-build227`;
- exact tested source: `7ac8de30b76192ee3cd9c9382edca74b9ff5e69d`;
- dedicated Xcode 16.4 run/job: `33153825917 / 98791806487` — success;
- artifact ID: `9678871748`;
- IPA SHA-256: `b24d8abcd91f4faa74e06d8485bac3611725c561d9c99144c17def4b8ef26766`;
- source ZIP SHA-256: `16bc14dd82cae7d2599f23fefaf7b5e4d9c95db6a17dbaa08921e3749f41d278`;
- OnePlayer `0.14.60 (227)`, MinOS 15.0 independently verified.

### 2026-08-28 horizontal real-device result

User feedback on iPhone 15 Pro Max / iOS 17.0: **movie-title text still has a visible jitter/shimmer feel**, so physical-pixel X rounding is rejected as a sufficient title-stability fix and must not be carried forward merely for that purpose. The same recording also exposes a second issue: after the finger is released, the automatic commit/cancel tail does not feel as silky as the active drag.

The accompanying Build227 App log shows that active drag still requests 120 fps, but slow/long drags are not uniformly perfect: one 6175.8 ms drag recorded `display_p95_gap_ms=25.01`, 177 display intervals >=12.5 ms and 41 >=20 ms; another 4642.0 ms drag kept p95 at 8.34 ms but still had a 39.58 ms maximum gap. This means the remaining title symptom cannot be reduced to a title-only geometry jump or solved by 1/3pt quantization alone.

More importantly, exact Build227 source inspection identifies a release-tail lifecycle discontinuity: the UIKit recognizer calls `V3HomeCarouselCadenceDiagnostics.shared.end(reason: "ended")` inside `touchesEnded` **before** `finishNativeCarouselDrag(...)` starts the existing 0.22 s commit / 0.18 s cancel animation. `end(...)` immediately invalidates the exact-max `CADisplayLink`, so Build219's proven high-refresh request covers active finger tracking but not the automatic release tail. The old cadence summary also ends at touch release, so it cannot measure the tail the user is now reporting.

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / horizontal real-device tested ✅ / title pixel-alignment hypothesis rejected as sufficient / release-tail cadence lifecycle issue identified in real source / stable ❌.

## Build228 / 0.14.61 — release-tail max-refresh lifecycle A/B

Build228 returns to the cleaned Build226 presentation baseline; Build227 physical-pixel rounding is intentionally absent. It changes only the lifetime of the already-proven Build219 device-max carousel refresh request:

- horizontal acquisition still starts the same exact-max `CADisplayLink` request;
- `touchesEnded` / ordinary `touchesCancelled` no longer invalidate that request before release handling;
- an interactive commit keeps the request until the existing 0.22 s animation reaches `settleCarousel`;
- an interactive cancel keeps it until the existing 0.18 s cancel completion;
- horizontal acquisition that ends without any transition releases immediately through explicit no-transition/no-target cleanup;
- no new timer, interpolation, retry, watchdog, fallback, gesture owner or duplicate state is introduced.

Build226 three-slot Hero residency, normal Hero/persistent crossfades, raw acquisition-relative foreground X, 0.28 commit threshold, 0.48×width predicted-distance gate and the existing 0.22/0.18 easing/durations are unchanged. This isolates refresh-request lifetime before changing release animation math.

CI / package evidence:

- branch: `perf/home-carousel-release-refresh-build228`;
- exact base: cleaned Build226 head `f9f1ecf6334c14641dbdf780a5b09a118495b8ec`;
- exact tested source: `bdf63c7562fcd1edc1d224872230e988ac462281`;
- dedicated Xcode 16.4 run/job: `33156739621 / 98801196041` — success;
- artifact: `OnePlayer-0.14.61-build228-release-refresh`, ID `9679963420`;
- artifact SHA-256: `0b3a3a2b4d38f5f0bbff4a406e1523e161f7f6600065b9e5ee9e00cd075938bc`;
- IPA SHA-256: `cda90b62e3cabd3199e1cfbc1b2e1c77b8a84d023a7c7b9c8e2ff66ab9edcf44`;
- source ZIP SHA-256: `d91b014486e5fb1c5c9798b2b56bf45f0bad4f9e47f433a9f862c5fa586ecf68`;
- independent package reopen confirms bundle `com.embyplayerlab.app`, OnePlayer `0.14.61 (228)`, `MinimumOSVersion=15.0` and `CADisableMinimumFrameDurationOnPhone=true`;
- independent source reopen confirms Build227 pixel rounding is absent, Build226 Hero residency remains, exact max-refresh remains, and the request now ends at interactive settle/cancel completion rather than touch release.

Build228 also makes the existing cadence log cover the automatic tail: successful commits should now end with `reason=settled`, and cancels with `reason=cancelled-settled`, so the next target-device log can directly measure tail display cadence.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device pending ❌ / diagnostic candidate / stable ❌.
## Rejected directions not to repeat

- Build222 offscreen-auto-advance guard as a fix;
- Build223 permanent persistent-backdrop removal;
- carrying Build223 Dock appearance forward;
- arbitrary 15% / 30% / 80% travel tuning;
- whole-range easing to hide coarse input;
- split native-move + SwiftUI-release ownership;
- recoupling foreground alpha to backdrop blend;
- coalesced-touch second visual owner without new evidence;
- debounce/throttle/timer/interpolator/watchdog/retry smoothing;
- Build227 physical-pixel foreground X rounding as a sufficient movie-title shimmer fix.

## Next exact action

Install Build228 on iPhone 15 Pro Max / iOS 17.0 and compare directly with Build226/227. Primary acceptance is the **finger-release automatic tail**: test short committed swipes, longer committed drags, partial drags that cancel back, and rapid repeated adjacent-page transitions. Judge whether the moment after finger release now keeps the same fine cadence as active drag. Export the App log after the test; Build228 cadence summaries should end at `reason=settled` / `reason=cancelled-settled` and now include the release animation itself. Do not expect Build228 to directly fix the already-confirmed title shimmer because foreground text presentation during active drag is unchanged. If release tail improves materially, retain the extended high-refresh lifecycle and then return to the remaining title/cadence issue separately. If it does not, keep Build226 residency but inspect release velocity continuity / fixed-duration easing next; do not stack an easing change before this refresh-lifetime A/B is tested.
