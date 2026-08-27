# DEV-home-carousel-drag-smoothness

## Status

**Active — Build223 / 0.14.56 code is now written as the next Home vertical diagnostic A/B. It is based on current `main` / accepted Build216 product code and removes only the immersive Home root mount of the always-on full-screen `persistentCarouselBackdrop`. Hero artwork, carousel preload, auto-advance timing, horizontal interaction, navigation and all playback/P0 paths remain unchanged. CI/IPA and target-device testing are still pending. Build221 remains the separate horizontal persistent-drag A/B with target-device testing pending. Build222 vertical offscreen auto-advance isolation was target-device tested and rejected as sufficient.**

- Work ID: `DEV-home-carousel-drag-smoothness`
- Routing aliases / keywords: 轮播图滑动卡顿 / 轮播图丝滑 / 首页轮播 / carousel drag / carousel smoothness
- Target device: iPhone 15 Pro Max / iOS 17.0
- Deployment Target policy: remain iOS 15.0
- Accepted overall product baseline: OnePlayer 0.14.49 / Build216 on `main`
- Historical continuation source for this session: user-supplied `轮播图优化v2.md`; treat it as historical evidence when current GitHub docs omit earlier conversation details.

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
- existing settle/reversal ownership remains;
- no second SwiftUI drag/release owner;
- no interpolation/timer/watchdog/retry/debounce/throttle smoothing layer.

Player / MPV / PiP / UnifiedTransport / Range/206 / playback Cache / Emby Session / STRM→302→115/CDN client-direct paths are outside this task and must remain unchanged.

## Controlling real-device evidence

### Build215 / 0.14.48

Acquisition-relative render baseline + opaque interactive foreground:

- initial drag became about as fine as EX;
- previous foreground blur/ghosting disappeared;
- overall tactile smoothness still trailed EX (user description: EX feels like smooth glass, OnePlayer like rough paper).

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / partial success / stable ❌.

### Build217 / 0.14.50

Cadence diagnostic established that the passive carousel path was effectively around 50–60 Hz even though the target device reported 120 Hz capability. Delivered touch → progress publication → SwiftUI render followed almost one-for-one; coalesced touch data was much denser but was not used as render authority.

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device diagnostic tested ✅ / ~60 Hz baseline established / stable ❌.

### Build219 / 0.14.52

Drag-local device-max refresh request raised the same path to roughly:

- delivered touch ~103 Hz;
- progress publish ~99 Hz;
- SwiftUI render ~98 Hz;
- display ~110 Hz;
- on-screen meter repeatedly reached 118–120 FPS.

This proves the high-refresh request is effective and should not be replaced by another easing/smoothing layer. Remaining discrete 34–50 ms gaps frequently correlated in time with Hero/persistent 1400px image callbacks. Strongest repeated pattern: ~50 ms display gap about 19.6–25.3 ms after persistent callback.

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device diagnostic tested ✅ / 120 Hz request effectiveness proven ✅ / stable ❌.

## Current image-presentation conclusion

Source inspection established:

- Hero and persistent use separate `EmbyCachedRemoteImage` instances for the same 1400px backdrop;
- transition may present current + target Hero and current + target persistent simultaneously;
- persistent is a full-screen image with `scaleEffect(1.12)` + `blur(radius: 30)`;
- preload/cache can make decode/data adoption warm, but it does not pre-render the later SwiftUI/CoreAnimation presentation/compositing work;
- Build212 had already measured the synchronous callback/contrast work itself at only ~1–3 ms, so the repeated later ~50 ms gap is more consistent with presentation/compositing than decode or contrast calculation.

Do not respond to this evidence by adding delayed image publication, debounce/throttle, timers, speculative preload changes or lower image quality without a direct A/B.

## Build221 / 0.14.54 — horizontal persistent-drag isolation

- branch: `diag/home-carousel-persistent-drag-isolation-build221`
- tested source: `26fc82771b6778af14974fdac293ece0685fc76d`
- artifact ID: `9654120029`
- IPA SHA-256: `d2ee4fb2d40c251399951bc72ba6ad35fbe8ba3bfd72b861274b9b2c38fe0d9c`
- during active horizontal drag only: keep current persistent opaque and do not mount target persistent;
- Hero transition and Build219 high-refresh request remain unchanged;
- normal persistent transition resumes after release.

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending ❌ / diagnostic only / stable ❌.

Next horizontal action remains target-device A/B if the user wants to continue that lane.

## Build222 / 0.14.55 — vertical offscreen auto-advance isolation

Independent vertical A/B based on accepted Build216/main product source, not Build221.

- tested source: `694221315c727ea055ea3b5ef7a9ea03a260fe80`
- run/job: `33101409110 / 98619779746`
- artifact ID: `9658757261`
- IPA SHA-256: `8cf6d454bf7eec64207875e9c20a1bbc6b125578f11fb777bfdda4fa6b5c5bfe`
- only new runtime behavior: automatic carousel transition may start only while Home is at top/rest (`abs(homeRawScrollMinY) <= 0.5`);
- persistent backdrop, preload, Hero and manual horizontal interaction were unchanged.

Target-device result: user still perceived Home vertical hitching. The candidate is rejected as sufficient. Do not carry this guard into the next vertical diagnostic.

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / hypothesis rejected as sufficient / stable ❌.

## Build223 / 0.14.56 — vertical persistent-backdrop isolation

### Identity

- working branch: `diag/home-carousel-persistent-backdrop-isolation-build223`
- base: current `main` head `da5ad1dc6341481b12b8ae3e8b85cc5e5bb31a05`
- product baseline under that head remains Build216 source behavior (`AppIdentity` 0.14.49 before this candidate)
- Build223 candidate identity is newly allocated; repository search found no existing Build223 checkpoint/branch before creation.

### Exact code change

Runtime scope is intentionally one variable:

- `Sources/UI/EmbyHomeCoreV3.swift`: immersive Home no longer mounts `persistentCarouselBackdrop(...)` at the root ZStack;
- `persistentCarouselBackdrop` and `carouselPersistentImage` remain implemented in `EmbyHomeHeroV3.swift`;
- the 30pt blur path therefore remains available in source but does not participate in this vertical A/B presentation;
- `carouselPreloadLayer` remains mounted;
- Hero artwork remains mounted and unchanged;
- automatic carousel timing/transition ownership remains Build216 behavior (Build222 top-only guard is not carried over);
- horizontal gesture/state ownership is unchanged;
- `AppIdentity` is 0.14.56 for this candidate;
- no Player/P0/Frozen code is touched.

Current branch diff against base is limited to:

- `Sources/Core/AppIdentity.swift` (+2/-2)
- `Sources/UI/EmbyHomeCoreV3.swift` (+1/-2)
- `docs/changelog/CHANGELOG_v0_14_56_build223.md`
- this checkpoint update

Static source re-read confirms immersive root still mounts `carouselPreloadLayer` and the root system-background fallback remains; the persistent root mount is absent.

### Evidence level

- Code written ✅
- Diff scope reviewed ✅
- CI passed ❌
- IPA produced ❌
- Real-device tested ❌
- Stable ❌

Push-triggered legacy temporary workflows on the repository currently fail on this branch; those failures are unrelated stale workflow helpers and are not Build223 validation evidence. Do not count them as candidate CI.

## Parallel/identity note

A separate Aether workstream has produced a user-library artifact whose filename also contains `Build222`, while its current GitHub checkpoint still says no Build is allocated. That historical identity inconsistency must not cause reuse of 222. Build223 is reserved to this carousel diagnostic branch.

## Rejected directions not to repeat

- fixed foreground that removes required horizontal slide;
- 15% / 30% / 80% travel tuning as the primary fix;
- whole-range easing (`progress²` or similar) to hide coarse input;
- page-center spacing below full Hero width;
- split native movement + SwiftUI release ownership;
- recoupling foreground alpha to backdrop blend;
- coalesced-touch-driven second visual owner without new evidence;
- debounce/throttle/timer/interpolator/watchdog/retry smoothing;
- treating Build222 offscreen auto-advance guard as a solution after its real-device rejection.

## Next exact action

1. Produce a clean Build223 CI/IPA using the standard MPV/Xcode 16.4 build path, not any stale temporary workflow that happens to auto-run on push.
2. Verify OnePlayer 0.14.56 / Build223 identity, MinOS 15.0 and exact product diff.
3. Target-device test Home vertical scrolling with carousel enabled. The decisive A/B question is whether removing only the always-mounted blurred persistent backdrop materially changes the tactile hitching.
4. Also note the expected visual difference below/around Hero caused by the diagnostic removal; visual degradation by itself does not invalidate the performance A/B.
5. If vertical smoothness materially improves, persistent full-screen presentation becomes a causal component and the next step is to redesign its presentation ownership without removing the visual effect. If smoothness is unchanged, do not keep Build223 behavior; move to the next measured component (preload or Hero presentation) one at a time.
6. Keep Build221 horizontal test lane separate; do not merge horizontal and vertical experiments before each has direct target-device evidence.
