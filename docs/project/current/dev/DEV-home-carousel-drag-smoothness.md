# DEV-home-carousel-drag-smoothness

## Status

**Active — Build236 start-step handling + Build231 foreground compositing + Build226 Hero residency + Build228 max-refresh-through-settle/release-tail are frozen-for-current-phase. Build237 persistent source-over correction is now also target-device accepted because the reported white flash is gone. Build237 halving of the predicted-total-distance fling gate to 0.24×width is rejected as sufficient: EX accepts almost-in-place flicks while OnePlayer still feels distance-bound. Build238 / 0.14.71 is the current measurement-only candidate to log real release velocity and predicted extra travel before replacing the distance-based fling gate. Slow-drag commit remains 0.28. Whole carousel remains Active only for fling-intent release behavior; stable ❌.**

- Work ID: `DEV-home-carousel-drag-smoothness`
- Working branch: `diag/home-carousel-release-intent-build238`
- Current candidate: OnePlayer `0.14.71 (238)`
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
- ordinary slow-drag commit threshold remains 0.28; the legacy predicted-total-distance fling gate is no longer a frozen contract and Build237 proved that simply lowering its width fraction is insufficient;
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

### 2026-08-28 target-device result — release tail accepted for now

User feedback on iPhone 15 Pro Max / iOS 17.0 after testing the carousel Build228 package: **“差不多了，尾巴这里先这样吧。”** This is acceptance of the release-tail subproblem for the current phase, not acceptance of the entire carousel task.

Controlling conclusion:

- retain Build226 current+previous+next clear-Hero residency as the current presentation foundation;
- retain Build228's extension of the already-proven device-max refresh request through interactive settle/cancel instead of ending it at `touchesEnded`;
- do **not** continue tuning the existing 0.22 s commit / 0.18 s cancel duration, easing or release-velocity mapping without new regression evidence;
- Build227 physical-pixel foreground X rounding remains rejected because the movie-title shimmer was still visible;
- slow-drag movie-title shimmer and the remaining overall feel gap versus EX remain open, so the Home carousel module is still Active and not Stable/frozen as a whole.

Attribution warning: a parallel poster-scroll task also used the identity `Build228 / 0.14.61`. For this carousel result, use branch `perf/home-carousel-release-refresh-build228`, exact tested source `bdf63c7562fcd1edc1d224872230e988ac462281`, run/job `33156739621 / 98801196041`, artifact `9679963420`, and IPA SHA-256 `cda90b62e3cabd3199e1cfbc1b2e1c77b8a84d023a7c7b9c8e2ff66ab9edcf44`; never attribute by build number alone.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / horizontal real-device tested ✅ / release-tail subproblem accepted-for-now ✅ / whole carousel stable ❌.

## Build230 / 0.14.63 — persistent three-slot residency A/B

Build230 starts from the cleaned carousel Build228 foundation and changes one presentation-lifecycle variable: the full-screen persistent backdrop now reuses the already-derived settled current + previous + next residency window instead of mounting only current plus a newly-created `transitionTargetCarouselItem` during active drag.

Why this variable is evidence-backed:

- Build219's residual 34–50 ms gaps repeatedly correlated with both Hero and persistent 1400px presentation callbacks;
- Build225/226 moved target Hero first presentation out of active finger tracking and produced a large real-device hand-feel improvement;
- Build227 still showed slow-drag title shimmer / cadence variability, while exact source still mounted the target persistent only after `transitionToID` appeared;
- `carouselPersistentImage` remains a full-screen 1400px presentation with `scaleEffect(1.12)` and `blur(radius: 30)`, so target persistent first presentation is the remaining directly evidenced heavyweight mount in the drag path.

Exact runtime change: `persistentCarouselBackdrop(size:)` now iterates `carouselHeroResidentItems` and applies the unchanged `carouselOpacity(for:)` to each persistent image. This keeps normal outgoing→incoming backdrop crossfade and does **not** repeat Build221's frozen-outgoing-backdrop visual mismatch. No new residency state is added; the existing derived current/previous/next window is reused.

Retained contracts: Build226 Hero residency, raw acquisition-relative foreground X, normal foreground opacity, Build228 max-refresh-through-settle, existing 0.22s/0.18s release tail, 0.28 commit threshold, 0.48×width predicted-distance gate, preload, shared `EmbyCachedRemoteImage`, and all P0/Frozen playback/transport/session paths are unchanged. Build227 physical-pixel rounding remains absent.

CI / package evidence:

- branch: `perf/home-carousel-persistent-residency-build230`;
- exact base: cleaned carousel Build228 head `e957a11325e5d605cec794b89b26ffc36cd96c06`;
- exact tested source: `6324bb2063bf1631b8b922abc8e11149bd7a86b0`;
- dedicated Xcode 16.4 run/job: `33167765310 / 98837170851` — success;
- artifact: `OnePlayer-0.14.63-build230-persistent-residency`, ID `9684378135`;
- artifact SHA-256: `7b822dc1e1555705e0a794ea57214da666b6f320813b01b61aacb058f95f1378`;
- IPA SHA-256: `6cea81f8e806ec159d9e811871076c18aa41fceb99b3c621516c490cfc339b4e`;
- source ZIP SHA-256: `f0955926306e502d34e1835d9b5daffd7499c5bdc15abede9b31744eba9ee4ec`;
- independent package reopen confirms OnePlayer `0.14.63 (230)`, bundle `com.embyplayerlab.app`, `MinimumOSVersion=15.0`, `CADisableMinimumFrameDurationOnPhone=true`, and IPA/source checksum integrity;
- independent source reopen confirms two uses of the same three-slot residency window (Hero + persistent), normal persistent opacity crossfade, blur30 retained, Build228 release-through-settle retained, 0.28/0.48 release rules retained, and Build227 pixel rounding absent.

Important target-device risk to watch: after a committed settle, the current/previous/next window rotates and a new far-neighbor persistent presentation becomes resident outside direct finger tracking. If Build230 merely moves a visible hitch to immediately after settle, or the extra resident blurred layers increase compositor/memory pressure, reject this implementation even if active drag improves.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device pending ❌ / diagnostic candidate / stable ❌.
### 2026-08-28 Build230 target-device result — title shimmer unchanged

User feedback on iPhone 15 Pro Max / iOS 17.0: **“慢拖文字还是会有抖动”**. This directly rejects persistent three-slot residency as a sufficient fix for the known slow-drag movie-title shimmer. It does not prove persistent presentation has zero cost, and the user did not provide a controlling Build230 verdict for overall hand feel or post-settle behavior in this report. Do not carry Build230 persistent residency forward merely as the title fix.

This result narrows the next investigation back to foreground presentation/compositing. Build226 frame inspection already showed title, metadata and overview translating as one page with stable relative geometry; Build227 rejected physical-pixel X quantization; Build230 now shows moving target persistent first presentation out of active drag still leaves the title shimmer.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / horizontal real-device title-shimmer A/B tested ✅ / title fix rejected as sufficient / whole Build230 overall-feel verdict incomplete / stable ❌.

## Build231 / 0.14.64 — foreground page compositing A/B

Build231 returns to the cleaned carousel Build228 foundation and intentionally does **not** carry Build230 persistent residency or Build227 physical-pixel rounding. Its only runtime presentation change is one SwiftUI `compositingGroup()` boundary on each existing carousel foreground page **before** the unchanged opacity and X offset modifiers.

Purpose: test whether the visible slow-drag title shimmer is caused by foreground child-layer compositing/presentation while the entire page is translated, rather than by title geometry, pixel-grid alignment or target persistent first-mount timing. No second gesture/state owner, timer, interpolation, drawingGroup/Metal rasterization path, retry, watchdog or smoothing layer is added.

Retained contracts: Build226 current+previous+next clear-Hero residency, original current+target persistent crossfade/mount behavior, Build228 device-max refresh through settle/cancel, acquisition-relative foreground X, opaque interactive foreground, 0.28 commit threshold, 0.48×width predicted-distance gate, existing 0.22/0.18 release timing, preload/shared image loader, and all Frozen/P0 playback/transport/session paths. Build227 pixel rounding is absent.

CI / package evidence:

- branch: `diag/home-carousel-foreground-compositing-build231`;
- exact base: cleaned carousel Build228 head `e957a11325e5d605cec794b89b26ffc36cd96c06`;
- exact tested source: `d30092b8354553063c6d96b62a6f2f4387676601`;
- dedicated Xcode 16.4 run/job: `33169864030 / 98844082214` — success;
- artifact: `OnePlayer-0.14.64-build231-foreground-compositing`, ID `9685231197`;
- artifact SHA-256: `6f5c3eed03c170c57cbba315ffc636dbe0ebb829a903fdec7fe5844c92634d74`;
- IPA SHA-256: `b92eb47971c546cfe7044ebdbd94cc27a108f0febead32ec811d55e400df4571`;
- source ZIP SHA-256: `847b1cd13c87b61f0e418a250b4bc6e79f75f970187875a701d9830c5b452f07`;
- independent package reopen confirms OnePlayer `0.14.64 (231)`, bundle `com.embyplayerlab.app`, `MinimumOSVersion=15.0`, `CADisableMinimumFrameDurationOnPhone=true`, and checksum integrity;
- independent source reopen confirms exactly one foreground `.compositingGroup()` before opacity/X offset, Build226 Hero residency retained, original Build228 persistent current+target behavior retained, Build228 release-through-settle retained, and Build227 pixel rounding absent.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device pending ❌ / diagnostic candidate / stable ❌.
### 2026-08-28 Build231 target-device result — foreground compositing validated

User feedback on iPhone 15 Pro Max / iOS 17.0: **“这次文字明显稳下来了，也不糊”**. This directly validates the Build231 page-level `compositingGroup()` as an effective fix for the known slow-drag movie-title shimmer, without the blur regression that would make the approach unacceptable.

The result is narrow but strong: Build231 changed only the foreground compositing boundary on top of the cleaned Build228 foundation, so the prior title shimmer was materially caused by foreground child-layer compositing/presentation rather than title geometry, physical-pixel X rounding, or persistent-neighbor first-mount timing. Retain the Build231 compositing boundary unless new target-device regression evidence overturns it.

The same target-device session exposed a **new/previously-unconfirmed start-step consistency symptom**: if the finger touches the carousel and waits briefly before moving, the first visible drag step is very short; if the finger touches and immediately moves, the first visible step often feels as coarse as older builds. The user explicitly notes uncertainty about whether this existed before Build231. Therefore do not attribute it to Build231 or change acquisition behavior without measurement.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / horizontal target-device title-shimmer tested ✅ / foreground compositing materially positive ✅ / no blur regression ✅ / whole carousel stable ❌.

## Build232 / 0.14.65 — start-step timing/translation diagnostics

Build232 starts from the cleaned Build231 branch head and intentionally changes **no carousel behavior**. It keeps the now-positive Build231 foreground `compositingGroup()`, Build226 Hero residency, original current+target persistent behavior, Build228 exact-max refresh through settle/cancel, acquisition-relative render X, 0.28 commit threshold, 0.48×width predicted-distance gate, and existing release timing.

The only runtime delta is measurement inside the existing UIKit recognizer / cadence logger. `HomeCarouselCadence` now records:

- `touch_down_to_acquire_ms`: touch-down timestamp → the delivered move that wins horizontal axis acquisition;
- `acquisition_x`: existing touch-down-relative X at acquisition;
- `acquire_to_first_render_ms`: acquisition delivered touch → first later delivered move that can publish visible render motion;
- `first_render_x`: first acquisition-relative visible X passed to the existing drag owner;
- `first_total_x`: first touch-down-relative delivered X corresponding to that visible move.

No coalesced/predicted sample is promoted to visual authority; no timer, interpolation, smoothing, threshold/easing change or second state owner is added. This diagnostic is specifically meant to compare “touch then immediately drag” against “touch, wait briefly, then drag” before deciding whether the acquisition baseline/sample ownership needs a behavioral change.

CI / package evidence:

- branch: `diag/home-carousel-start-step-diagnostics-build232`;
- exact base: cleaned Build231 head `40a2e26fa16becb6830b400a030e4882300788d4`;
- exact tested source: `de11d7483075daf7463faaa5519432478463a271`;
- cleanup head after temporary CI removal: `01cbe7162b6e4d8882f987204fc585a2eed01284`;
- dedicated Xcode 16.4 run/job: `33174155718 / 98858347691` — success;
- artifact: `OnePlayer-0.14.65-build232-start-step-diagnostics`, ID `9686946353`;
- artifact SHA-256: `4f5286e4d49967d4af9f400b6ec32fe557319f55b15a08bd98f091892e7e86f1`;
- IPA SHA-256: `0366bffeda255f799621c0b0ffeb2780ef1adaa44c9d7b9f01ce14f0fe84b528`;
- source ZIP SHA-256: `9cc292766910f9c5c58b65c22c8ea4fcd2f53bc6e36428cb5c4bc2a12580c3ae`;
- independent package reopen confirms OnePlayer `0.14.65 (232)`, bundle `com.embyplayerlab.app`, `MinimumOSVersion=15.0`, and `CADisableMinimumFrameDurationOnPhone=true`;
- independent source reopen confirms Build231 `compositingGroup()` retained, diagnostic fields present, acquisition-relative X / 0.28 / 0.48 retained, and Build228 `settled` / `cancelled-settled` refresh lifetime retained.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / behavior unchanged by design / target-device diagnostic pending ❌ / stable ❌.
### 2026-08-28 Build232 target-device result — first-step split proven; title compositing remains partial

User feedback on iPhone 15 Pro Max / iOS 17.0 is controlling: **immediate touch-and-drag has a high probability of a large/coarse first visible step, while touching/holding briefly before dragging is almost always a short/fine first step.** The user also reports that movie-title jitter was visible again in this Build232 session.

Uploaded App log `OnePlayer-App-1787924071.log` contains 34 `HomeCarouselCadence` drags. The new first-step measurements are strongly bimodal:

- 20/34 first visible steps are only **0.33–2.33pt**;
- 14/34 are **8.00–13.67pt**;
- there are **zero** first-step samples between 2.33pt and 8.00pt;
- median `acquire_to_first_render_ms` is **8.34ms**, so the split is not explained by some gestures waiting tens of milliseconds longer after acquisition;
- small-step drags have median absolute `acquisition_x` about **13.5pt**, while large-step drags have median absolute `acquisition_x` about **5.17pt**. The acquisition-relative first step therefore depends strongly on which delivered touch becomes the acquisition baseline and how far the next delivered touch travels in the following 120Hz interval.

The log does not encode the user's intended “immediate” vs “hold” label per gesture, so the user's repeated tactile classification remains authority for mapping those two measured populations to the two start patterns. The measured bimodality independently confirms that the first visible motion is not continuously varying noise.

Build231 foreground compositing is **retained as materially beneficial but no longer considered sufficient by itself**. Build232 intentionally kept the same `compositingGroup()` rendering path, yet title jitter was observed again. The same session also contains residual cadence degradation: 16/34 drags have display p95 around 16.67ms and 5/34 have average SwiftUI render intervals at or above 20ms. Because no exact video timestamp maps the visible title jitter to one specific cadence sample, treat this as supporting evidence that residual frame-delivery instability can still expose title shimmer; do not claim a complete causal mapping from this log alone.

Evidence: Build232 Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device first-step diagnostic tested ✅ / immediate-vs-hold symptom confirmed ✅ / title jitter still reproducible ✅ / stable ❌.

## Build233 / 0.14.66 — acquisition-local first-frame A/B

Build233 is the minimum behavior change supported by the Build232 first-step measurement. It retains Build231 foreground `compositingGroup()`, Build226 current+previous+next clear-Hero residency, original current+target persistent behavior, Build228 device-max refresh through settle/cancel, the existing 0.28 commit threshold, 0.48×width predicted-distance gate, and unchanged release timing.

At the one UIEvent where horizontal ownership is acquired, the recognizer inspects only the immediately preceding real coalesced touch sample from that same event. If that predecessor exists and its delta continues in the already-selected horizontal direction, it becomes the one-time render baseline and the **current delivered touch is published immediately on the acquisition event**. If no suitable predecessor exists, Build232 acquisition-relative behavior is preserved. After acquisition, every interactive render update remains driven by normal delivered touches; predicted touch stays release-only. There is no timer, interpolation, artificial step cap, easing, debounce/throttle, retry/watchdog, or second state owner.

This is intentionally an A/B, not a frozen replacement for the Build215 acquisition contract. Its purpose is to remove the extra acquisition-frame dead interval without returning to touch-down-relative jump behavior. Build232 cadence fields remain in place: a successful acquisition-local path should often show `acquire_to_first_render_ms≈0` with a short real `first_render_x`, especially for the immediate-drag pattern.

CI / package evidence:

- branch: `perf/home-carousel-acquisition-first-frame-build233`;
- exact base: cleaned Build232 tree at `d4db105b9412cbb3d66a9b351f9ba49d2b1bb742`;
- exact tested source: `4912234b579a2b8eeba7d5e7f5c6159248953efe`;
- cleanup head after temporary build CI removal: `fa3386eea8fbe5476bcfa85a2443ac30b45a5e22`;
- dedicated Xcode 16.4 run/job: `33177534304 / 98869934770` — success;
- artifact: `OnePlayer-0.14.66-build233-acquisition-first-frame`, ID `9688349642`;
- artifact SHA-256: `dbd6ea9767875f39f382180abf890147e3c7b78389637a1138fcae712338a1f6`;
- IPA SHA-256: `717ee926877e9867272f78790e06b3181b4e0f17d7d71d9494ca0540184a019b`;
- source ZIP SHA-256: `e76f5e10738fc820fb2efb5a008c99a9fc9a30841956cdf35e902d2bd2229c21`;
- independent package reopen confirms OnePlayer `0.14.66 (233)`, bundle `com.embyplayerlab.app`, `MinimumOSVersion=15.0`, and `CADisableMinimumFrameDurationOnPhone=true`;
- independent source reopen confirms Build231 `compositingGroup()`, Build226 Hero residency, Build228 settle/cancel refresh lifetime, 0.28/0.48 release rules and the one-event acquisition predecessor logic are present.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device pending ❌ / A/B only / stable ❌.
### 2026-08-28 Build233 target-device result — acquisition-local path helps, but fallback remains coarse

User feedback on iPhone 15 Pro Max / iOS 17.0: **the large first-step symptom still occurs at roughly half-or-more subjective frequency, while movie-title text seems less jittery in this build.** The uploaded Build233 App log `OnePlayer-App-1787932695.log` contains 67 `HomeCarouselCadence` drags and gives a more precise split:

- overall `|first_render_x| >= 2.5pt`: **32/67 (47.8%)**;
- overall `|first_render_x| >= 5pt`: **28/67 (41.8%)**;
- overall `|first_render_x| >= 8pt`: **15/67 (22.4%)**;
- 42/67 drags used the Build233 acquisition-local same-event path (`acquire_to_first_render_ms≈0`): median first step **2.0pt**, `>=5pt` **12/42 (28.6%)**, `>=8pt` **2/42**;
- 25/67 drags fell back to the prior next-delivered-move path: median first step **8.33pt**, `>=5pt` **16/25 (64%)**, `>=8pt` **13/25**.

Controlling conclusion: Build233 proves that using a real acquisition-local predecessor can materially reduce first-step coarseness **when that path is available**, but it does not solve the start-step problem because roughly 37% of recorded starts still fall back and some accepted predecessor deltas are themselves large. Build233 is therefore not accepted as the final acquisition contract.

The current Build233 logger cannot tell whether fallback happened because no predecessor existed, because a predecessor had zero delta, or because the same-direction guard rejected it. It also does not record predecessor age/delta for accepted cases. Therefore changing/removing the guard, choosing a different coalesced sample, or imposing an artificial step cap would be speculative. Measure those facts first.

Title/cadence evidence remains separate. The user reports the text looks less jittery. This session has 42/67 drags with display p95 ≈8.34ms and 18/67 at ≈16.67ms, a cleaner distribution than the prior Build232 session. This supports the observed improvement but does not timestamp-match a particular visible title event, so do not claim complete title stability or a one-to-one cadence cause. Retain Build231 foreground `compositingGroup()` as beneficial, not fully sufficient.

Evidence: Build233 Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅ / acquisition-local path partially positive ✅ / overall start-step fix insufficient ❌ / title subjectively improved but not frozen / stable ❌.

## Build234 / 0.14.67 — acquisition coalesced-decision diagnostics

Build234 is measurement-only on top of Build233. It does **not** change which coalesced predecessor Build233 accepts, when the acquisition event publishes, the fallback path, post-acquisition delivered-touch ownership, Hero/persistent presentation, foreground compositing, release timing/thresholds, or refresh-rate lifetime.

The existing acquisition helper now reports to `HomeCarouselCadence`:

- `acq_coalesced_count`: number of real coalesced samples available on the acquisition UIEvent;
- `acq_predecessor_status`: `accepted`, `none`, `zero`, or `direction`;
- `acq_predecessor_delta_x`: current delivered acquisition X minus the immediately preceding real coalesced sample X when one exists;
- `acq_predecessor_age_ms`: predecessor timestamp age relative to the current delivered acquisition touch.

These fields directly answer why Build233 produced 25/67 fallback starts and why a subset of the 42 accepted same-event starts still had a >=5pt first step. No timer, interpolation, step cap, easing, debounce/throttle, retry/watchdog, predicted-touch render authority, or second state owner is added.

CI / package evidence:

- branch: `diag/home-carousel-acquisition-coalesced-diagnostics-build234`;
- exact base: cleaned Build233 branch head `4f2dd8832c66e10d8d48e95fcf757d40f9efb80c`;
- exact tested source: `528168da7c6b6df26bf1a907439becdb5cc4c980`;
- cleanup head after temporary build/apply CI removal: `f07a46b52e96cd1d363293c046d9d614047c7e47`;
- dedicated Xcode 16.4 run/job: `33189068688 / 98909569541` — success;
- artifact: `OnePlayer-0.14.67-build234-acquisition-diagnostics`, ID `9693038983`;
- artifact SHA-256: `d819f7a7ccd02bbc73f8201861c6b4a77b4627832d50e16de3f1e42f524786e8`;
- IPA SHA-256: `ddd8b884dd5095a3eb72e47b8a2726ac9bf32e9dc7000aafe9aeef596296a59c`;
- source ZIP SHA-256: `4c2ca8e92eae8449f6aa9e52228b78418c79924e35a5821c978a4046a71d58fb`;
- independent package reopen confirms OnePlayer `0.14.67 (234)`, bundle `com.embyplayerlab.app`, `MinimumOSVersion=15.0`, and `CADisableMinimumFrameDurationOnPhone=true`;
- independent source reopen confirms Build233 acquisition behavior retained, Build231 `compositingGroup()`, Build226 Hero residency, Build228 settle/cancel refresh lifetime and 0.28/0.48 release rules retained.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / behavior unchanged by design / target-device diagnostic pending ❌ / stable ❌.
### 2026-08-28 Build234 target-device result — acquisition-event predecessor absence proven

The uploaded Build234 App log `OnePlayer-App-1787935463.log` contains **31** `HomeCarouselCadence` drags. The new acquisition-decision fields provide a decisive split:

- predecessor status is only **`accepted` 20/31** or **`none` 11/31**; there are **zero `direction`** and **zero `zero`** rejections;
- every `none` case has **`acq_coalesced_count=1`**, meaning the acquisition UIEvent exposes only the current delivered touch and no earlier same-event real sample exists;
- those 11 `none` / fallback starts have median `|first_render_x|` **9.0pt**, with **9/11 >=5pt** and **7/11 >=8pt**; median acquisition→first-render delay is **8.34ms**;
- the 20 `accepted` starts have median first step **3.0pt**, with **4/20 >=5pt** and **1/20 >=8pt**; acquisition→first-render is **0ms**;
- accepted predecessor age is **4.17ms in 19/20** cases and 8.34ms once, so accepted large starts are primarily large real predecessor deltas, not stale tens-of-milliseconds samples;
- acquisition-event coalesced counts for accepted starts are 2–5 samples (15/20 have 3), versus exactly 1 sample for every `none` case.

Controlling conclusion: Build234 disproves the hypothesis that Build233 fallback is mainly caused by the same-direction guard. The dominant residual failure is **same-event predecessor unavailability**: when UIKit gives only one acquisition-event sample, Build233 has no real earlier sample available and falls back to the next delivered event, recreating the coarse first step. Therefore do **not** remove the direction guard and do not add a synthetic step cap/interpolation. The next behavior A/B, if implemented, should stay within the same single UIKit owner and use only real touch samples to address the one-sample acquisition case.

A directly evidence-backed candidate is to extend the already-proven acquisition-local idea by at most one event: only when acquisition had `status=none` / one sample, inspect the **first post-acquisition UIEvent** for a real immediately preceding coalesced sample and, if present and direction-compatible, use that real predecessor as the one-time render baseline while publishing that event's delivered touch. If that first post-acquisition event also has no predecessor, preserve the existing fallback rather than inventing motion. This exact next-event availability is not yet measured, so treat such a change as an A/B rather than a frozen contract.

Cadence/title evidence remains supporting, not causal proof. This Build234 session has **25/31** drags with display p95 around **8.34ms** and only 6/31 above that, consistent with the prior subjective report that title text looks steadier. Build231 `compositingGroup()` remains retained as beneficial but not complete/frozen.

Evidence: Build234 Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device diagnostic tested ✅ / same-event predecessor absence proven ✅ / behavior fix not yet tested ❌ / stable ❌.

## Build236 / 0.14.69 — first post-acquisition real-predecessor A/B

Build234 target-device evidence records 31 drags with 20 `accepted` acquisition events and 11 `none` events. Every `none` event has `acq_coalesced_count=1`, with zero `direction` and zero `zero` rejections; those fallback starts have median first visible step 9.0pt and >=5pt in 9/11 cases. This directly justifies extending the one-time real-coalesced-baseline rule by at most one UIEvent only for those one-sample acquisition cases.

Build236 preserves Build233 acquisition-event behavior. If acquisition already has an accepted predecessor, nothing changes. If acquisition is exactly `none` with count 1, the first post-acquisition `touchesMoved` checks only real coalesced samples whose timestamp is after the acquisition touch and before the current delivered touch. The immediately preceding direction-compatible real sample may become the render baseline once; the visual publication is still the current delivered touch. If no such sample exists, the old fallback is preserved. The pending path is cleared after that first post-acquisition event. No timer, interpolation, numeric step cap, easing, debounce/throttle, predicted render authority or second owner is introduced.

Build235 / 0.14.68 is reserved by the independent Aether task. Build236 / 0.14.69 is the unique carousel candidate after branch/active-checkpoint collision checks.

Evidence: code patch prepared on `perf/home-carousel-post-acquisition-baseline-build236`; CI/IPA pending at this checkpoint; real-device pending; stable ❌.

### CI / IPA evidence

- branch: `perf/home-carousel-post-acquisition-baseline-build236`;
- exact base: cleaned Build234 head `b0acb9e6db610341468f039076b77c1910765ad3`;
- exact tested source: `7811f34104daaea8734e72404bcb2fadb6fa37f7`;
- dedicated Xcode 16.4 run/job: `33193485825 / 98924631982` — success;
- artifact: `OnePlayer-0.14.69-build236-post-acquisition-baseline`, ID `9694861946`;
- artifact SHA-256: `3a45d3400ac396fbc47a38ec6974e8983d90e9a949c0ce37bf68f8e9d7051bd0`;
- IPA SHA-256: `8e248cb5834be4bcc261e3e1b63db3c334b805a4245aab56c74a5fe5951cd4c5`;
- source ZIP SHA-256: `256fa108bd8823e9f699036d8e85009b763e5b0bd11e5d357c8c352e0360f454`;
- independent package reopen confirms bundle `com.embyplayerlab.app`, OnePlayer `0.14.69 (236)`, `MinimumOSVersion=15.0`, and `CADisableMinimumFrameDurationOnPhone=true`;
- independent source reopen confirms Build236 pending path only for acquisition `none/count=1`, one first-post-acquisition real predecessor check, Build231 foreground `compositingGroup()`, Build226 Hero residency, Build228 settle/cancel max-refresh lifetime, unchanged 0.28/0.48 release rules, and no Build227 pixel rounding / Build230 persistent residency.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device pending ❌ / stable ❌.

### 2026-08-29 Build236 target-device result — post-acquisition real baseline materially reduces coarse starts

User feedback on iPhone 15 Pro Max / iOS 17.0: **“感觉大步长几率是有明显下降，而且标题文字抖动也非常轻微了。”** The uploaded Build236 App log `OnePlayer-App-1787938053.log` contains 53 `HomeCarouselCadence` drags and confirms the first-step improvement:

- overall `|first_render_x| >= 2.5pt`: **11/53 (20.8%)**;
- overall `|first_render_x| >= 5pt`: **10/53 (18.9%)**;
- overall `|first_render_x| >= 8pt`: **3/53 (5.7%)**;
- 28 acquisition-event `accepted` starts: median first step **1.67pt**; `>=5pt` **6/28**; `>=8pt` **1/28**;
- 20 acquisition-event `none` starts entered Build236's one-time post-acquisition path; **16/20** found a real predecessor on the first post-acquisition UIEvent and then had median first step **2.0pt**, `>=5pt` **0/16**, `>=8pt` **0/16**;
- the remaining **4/20** still had only one sample on the first post-acquisition event (`post_acq_predecessor_status=none`); these remain coarse with median first step **7.84pt**, `>=5pt` **4/4**, `>=8pt` **2/4**;
- 4 acquisition `direction` cases and 1 `zero` case were not a practical coarse-start source in this capture: all five first steps stayed below 2.5pt.

This confirms Build236's exact mechanism is effective: when Build234's one-sample acquisition event can obtain one real direction-compatible predecessor on the immediately following UIEvent, the old coarse fallback is removed without synthetic interpolation or a step cap. The residual avoidable coarse-start family is now narrowly the **4/53 cases where both acquisition and the first post-acquisition event expose no predecessor**. Separately, six `>=5pt` acquisition-accepted starts are real 4.17ms predecessor deltas of roughly 5.33–11pt; do not hide those real finger velocities with an artificial first-step cap.

Title/cadence evidence is also positive but not frozen complete. User reports title jitter is now very slight. Display p95 is ≈8.34ms in **44/53** drags, ≈16.67ms in 7/53, with one 10.09ms and one 14.05ms sample. Rare long-tail display gaps still exist (max 50.01ms) and this capture still records one persistent image callback per drag, so residual cadence work remains possible; however Build230 already proved persistent residency alone is not a sufficient title fix, so do not reopen that strategy without new targeted evidence.

Evidence: Build236 Code written ✅ / scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅ / coarse-start probability materially reduced ✅ / title jitter very slight ✅ / residual 4/53 no-predecessor fallback + rare cadence tails remain / stable ❌.

### 2026-08-29 Build237 target-device result — white flash fixed; predicted-total-distance fling gate rejected as sufficient

User target-device feedback on iPhone 15 Pro Max / iOS 17.0: **the transition white flash is gone**, but the carousel still cannot be committed by the very short, almost-in-place fling that EX accepts easily. The user describes OnePlayer as still having a strong resistance/boundary and explicitly questions the distance-based method.

This splits Build237 cleanly:

- **Persistent source-over white-flash correction: accepted.** Keep outgoing persistent fully opaque while incoming fades over it. The user directly confirms the white flash is gone.
- **Predicted-total-distance gate 0.48×width → 0.24×width: rejected as sufficient.** Halving the distance merely moved the boundary; it did not reproduce EX-style fling intent. Current source still commits by `actualProgress >= 0.28` OR `max(actualDistance, predictedDistance) >= width * 0.24`, where `predictedDistance` is the predicted endpoint measured from touch-down origin. A short, fast fling can therefore still fail if its predicted total displacement does not cross the fixed width fraction.

The next release contract must not be chosen by guessing another width fraction. Preserve the ordinary 0.28 slow-drag progress rule for now, retain the accepted Build237 white-flash correction, and measure release intent from real terminal touch velocity plus predicted **extra** travel before selecting a velocity/fling gate.

Evidence: Build237 Code written ✅ / scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅ / white-flash fix accepted ✅ / 0.24 predicted-total-distance fling approach insufficient ❌ / stable ❌.

## Build237 / 0.14.70 — shorter fling gate + persistent white-flash correction

User accepts freezing most Build236 carousel refinement rather than chasing the residual 4/53 double-no-predecessor starts. A new comparison against EX exposes two remaining release/presentation details: EX can commit after a much shorter drag followed by a fling, while OnePlayer's predicted-distance gate is still `0.48 × width`; and OnePlayer shows a brief bright/white flash during carousel switching.

Exact source evidence for the flash: `persistentCarouselBackdrop` places two opaque images above a `systemBackground` root but applies complementary opacities (`1-blend` and `blend`) to the two separate source-over layers. At midpoint, two 0.5-opacity opaque layers cover only 75% in source-over composition, so the underlying light system background can leak through. The existing light/dark scrim and system-background gradient predate Build236 and are not removed. Build237 keeps the outgoing persistent image fully opaque and fades only the incoming persistent image from 0→1 using the unchanged backdrop blend progress, which yields the intended visual color interpolation without exposing the root background.

The release change is equally narrow: only the predicted-distance gate becomes `0.24 × width`; actual-progress commit remains `0.28`. No velocity owner, timer, interpolation, extra easing or synthetic fling logic is added. Build236 start-step handling, Build231 foreground `compositingGroup()`, Build226 Hero residency, Build228 max-refresh-through-settle and all P0/Frozen paths remain unchanged.

### CI / IPA evidence

- branch: `perf/home-carousel-fling-whiteflash-build237`;
- exact base: cleaned Build236 head `f85333b58980af26af5f28ca842277f22a289347`;
- exact tested source / CI head: `185df6a9e53387b095f35a60fa5d01b44f5af3db`;
- dedicated Xcode 16.4 run/job: `33202505078 / 98955194172` — success;
- artifact: `OnePlayer-0.14.70-build237-fling-whiteflash`, ID `9698408945`;
- artifact SHA-256: `6c9eb827653eab83d4eb146f602e742d0b124bd8697cb964d7164c188b72b7cd`;
- IPA SHA-256: `aadc7d05d72d059eadfd166647127acdab0685cc259458795b562b4f1bbb28d9`;
- source ZIP SHA-256: `022cfe9fab14aba0f902b413ecf903e5e8c807e6be90a82dfd8c6b094c7d75a7`;
- independent package reopen confirms bundle `com.embyplayerlab.app`, OnePlayer `0.14.70 (237)`, `MinimumOSVersion=15.0`, `CADisableMinimumFrameDurationOnPhone=true`;
- independent source reopen confirms the only runtime deltas from Build236 are the predicted-distance gate `0.48×width → 0.24×width` and the persistent source-over crossfade correction; Build236 post-acquisition baseline, Build231 foreground `compositingGroup()`, Build226 Hero residency, Build228 0.22/0.18 release tail and exact-max refresh remain.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device pending ❌ / stable ❌.


## Build238 / 0.14.71 — release-intent measurement only

Build238 is measurement-only on top of Build237. It does not change `shouldCommit`, slow-drag progress, predicted-total-distance behavior, Build236 start-step handling, Build231 foreground compositing, Build226 Hero residency, Build228 release-tail/max-refresh lifetime or Build237 persistent source-over white-flash correction.

The custom UIKit recognizer now logs one `HomeCarouselRelease` line at horizontal release with:

- `actual_x` and acquisition-relative `rendered_x`;
- latest `predicted_x` and the actual translation at the same prediction event (`prediction_base_x`);
- `predicted_extra_x = predicted_x - prediction_base_x`, which measures forecast extra travel rather than total displacement from touch-down;
- `last_move_delivered_velocity_x` from consecutive delivered move samples;
- `last_move_coalesced_velocity_x` from the latest two real coalesced samples in the move UIEvent;
- `end_velocity_x` from the final delivered end sample relative to the last move;
- `touch_duration_ms`.

No velocity threshold is applied in Build238. This avoids guessing a numeric fling gate before target-device data separates intended short flicks from short slow drags.

### CI / IPA evidence

- branch: `diag/home-carousel-release-intent-build238`;
- exact base: cleaned Build237 head `6d9243395f273dec224ba695e14d433405345c11`;
- exact tested source / CI head: `780283bc722e39564240d996ca3c522bc61c6066`;
- dedicated Xcode 16.4 run/job: `33204499623 / 98961981208` — success;
- artifact: `OnePlayer-0.14.71-build238-release-diagnostics`, ID `9699150399`;
- artifact SHA-256: `59baa8223ba6d652cde77cf7e6af286545b12ef6a762df110bc20d18f6524cf3`;
- IPA SHA-256: `3539fd2f8c83c56838242a69350c473bd0088a65c273a5a0c0b4f3676878efd4`;
- source ZIP SHA-256: `fefe660a5f578ed4fd3f2a55abbd73dc9fc4e41a1378467335d46989affefd01`;
- independent package reopen confirms bundle `com.embyplayerlab.app`, OnePlayer `0.14.71 (238)`, `MinimumOSVersion=15.0`;
- independent source reopen confirms Build237 white-flash correction and unchanged `0.28 / 0.24` release behavior are retained, with only release-intent measurements added.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / behavior intentionally unchanged / target-device diagnostic pending ❌ / stable ❌.

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

Target-device test OnePlayer 0.14.71 / Build238 and export the App log. Perform two clearly labeled gesture families on the same carousel: (A) about 12–15 **almost-in-place quick flicks** that should feel like EX-style commits, and (B) about 8–10 **short slow drags/releases** that should remain cancellations. Build238 intentionally keeps Build237 release behavior, so judge the gestures by intent rather than whether OnePlayer currently commits. Compare `last_move_delivered_velocity_x`, `last_move_coalesced_velocity_x`, `end_velocity_x` and `predicted_extra_x` between the two families. Only if the target-device distributions separate should Build239 replace the predicted-total-distance fling gate with a velocity/fling-intent gate. Do not guess another width fraction and do not reopen the frozen-for-current-phase Build236/231/226/228 foundation or the accepted Build237 white-flash correction without regression evidence.
