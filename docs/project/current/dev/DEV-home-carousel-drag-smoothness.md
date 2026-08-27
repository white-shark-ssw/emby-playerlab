# DEV-home-carousel-drag-smoothness

## Status

**Active — Build223 / 0.14.56 has now been target-device tested and is rejected as a sufficient Home vertical-smoothness fix. The user still feels obvious vertical jitter after removing only the always-mounted full-screen `persistentCarouselBackdrop`. The same diagnostic also exposes an unintended Dock appearance regression: the Dock source is unchanged, but its `.ultraThinMaterial` no longer has the full-screen persistent backdrop behind it, so the bottom bar becomes a visibly gray/translucent strip. Build223 behavior must not be retained. Build221 remains the separate horizontal persistent-drag A/B with target-device testing pending.**

- Work ID: `DEV-home-carousel-drag-smoothness`
- Target device: iPhone 15 Pro Max / iOS 17.0
- Deployment Target policy: remain iOS 15.0
- Accepted overall product baseline: OnePlayer 0.14.49 / Build216 on `main`
- Historical continuation source: user-supplied `轮播图优化v2.md`

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
- base: `da5ad1dc6341481b12b8ae3e8b85cc5e5bb31a05`
- tested source / CI head: `af54d693d91303ea9bd201b5525e24f3e15ad931`
- run/job: `33110117601 / 98650408622` — success
- artifact ID: `9662245993`
- artifact ZIP SHA-256: `cdc741253866243bf2f2ae111e46807e64a5deefecdc30d46ee6a75f31a0eba1`
- IPA SHA-256: `a925714dceb138df7808079b5784f3337afe92245bd790c42c290eac82ccd73c`
- source ZIP SHA-256: `b14860b0a5889b39be17eeac8aeacf0621c6c68784058f463f00eae3057a5432`
- independently verified OnePlayer `0.14.56 (223)`, bundle `com.embyplayerlab.app`, MinOS 15.0.

### Exact runtime change

Only `Sources/UI/EmbyHomeCoreV3.swift` presentation mounting changed: immersive Home stopped mounting `persistentCarouselBackdrop(...)` at the root ZStack. `carouselPreloadLayer`, Hero artwork, normal Build216 auto-advance, horizontal interaction and all P0/Frozen paths remained unchanged. `persistentCarouselBackdrop` / `carouselPersistentImage` and `.blur(radius: 30)` remained implemented in source.

### 2026-08-28 target-device result

User test on iPhone 15 Pro Max / iOS 17.0:

- **Home vertical scrolling still has obvious perceptible jitter.**
- Therefore removing the always-mounted full-screen persistent backdrop does **not** materially solve the vertical hitch family and is rejected as a sufficient fix.
- User also reported the bottom Dock changed appearance in this build and supplied a screenshot.

Source re-check for the Dock:

- Build223 product diff contains only `Sources/Core/AppIdentity.swift` and `Sources/UI/EmbyHomeCoreV3.swift`; `EmbyServerRootViewV3.swift` is unchanged.
- Home Dock still uses `.ultraThinMaterial` whenever `selectedTab == .home && homeCarouselActive`.
- In the accepted baseline, `persistentCarouselBackdrop(...).ignoresSafeArea()` sat behind the whole immersive Home, including the Dock region.
- Build223 removed that layer while leaving the material Dock unchanged; therefore the material samples a different backing surface and appears as the gray/translucent strip seen on device.
- This is an unintended diagnostic visual side effect, **not** an intentional Dock redesign, and must not be carried forward.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / vertical hypothesis rejected as sufficient / unintended Dock visual regression observed / stable ❌.

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

Do **not** build the next candidate on top of Build223 visual behavior. Start from the accepted Build216/main presentation contract so the normal persistent background and Dock appearance are restored, then isolate exactly one remaining carousel-owned presentation component.

Before choosing the next code change, re-read the existing Build219 callback/gap evidence and current loader mount points to decide between Hero presentation and preload as the next single-variable A/B. Do not change both in one build. Keep Build221 horizontal testing separate.
