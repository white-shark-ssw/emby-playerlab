# DEV-home-carousel-drag-smoothness

## Status

**Active — Build223 / 0.14.56 is now CI/IPA verified as the current Home vertical diagnostic A/B; target-device testing is pending. It is based on current `main` / accepted Build216 product code and removes only the immersive Home root mount of the always-on full-screen `persistentCarouselBackdrop`. Hero artwork, carousel preload, auto-advance timing, horizontal interaction, navigation and all playback/P0 paths remain unchanged. Build221 remains the separate horizontal persistent-drag A/B with target-device testing pending. Build222 vertical offscreen auto-advance isolation was target-device tested and rejected as sufficient.**

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

Passive carousel path measured around 50–60 Hz on the 120 Hz target device. Delivered touch → progress publication → SwiftUI render followed almost one-for-one; coalesced touch data was denser but did not drive render.

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device diagnostic tested ✅ / ~60 Hz baseline established / stable ❌.

### Build219 / 0.14.52

Drag-local device-max refresh request raised delivered touch / progress / SwiftUI render / display to roughly 103 / 99 / 98 / 110 Hz, and the on-screen meter repeatedly reached 118–120 FPS. Remaining discrete 34–50 ms gaps frequently correlated with Hero/persistent 1400px image callbacks; the strongest repeated pattern was ~50 ms about 19.6–25.3 ms after a persistent callback.

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device diagnostic tested ✅ / 120 Hz request effectiveness proven ✅ / stable ❌.

## Current image-presentation conclusion

Source inspection established:

- Hero and persistent use separate `EmbyCachedRemoteImage` instances for the same 1400px backdrop;
- transition may present current + target Hero and current + target persistent simultaneously;
- persistent is a full-screen image with `scaleEffect(1.12)` + `blur(radius: 30)`;
- preload/cache can make decode/data adoption warm, but it does not pre-render later SwiftUI/CoreAnimation presentation/compositing work;
- Build212 measured synchronous callback/contrast work itself at only ~1–3 ms, so the repeated later ~50 ms gap is more consistent with presentation/compositing than decode or contrast calculation.

Do not add delayed publication, debounce/throttle, smoothing timers, speculative preload changes or lower image quality without a direct A/B.

## Build221 / 0.14.54 — horizontal persistent-drag isolation

- branch: `diag/home-carousel-persistent-drag-isolation-build221`
- tested source: `26fc82771b6778af14974fdac293ece0685fc76d`
- artifact ID: `9654120029`
- IPA SHA-256: `d2ee4fb2d40c251399951bc72ba6ad35fbe8ba3bfd72b861274b9b2c38fe0d9c`
- during active horizontal drag only: current persistent stays opaque and target persistent is not mounted;
- Hero transition and Build219 high-refresh request remain unchanged;
- normal persistent transition resumes after release.

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending ❌ / diagnostic only / stable ❌.

## Build222 / 0.14.55 — vertical offscreen auto-advance isolation

Independent vertical A/B based on accepted Build216/main product source, not Build221.

- tested source: `694221315c727ea055ea3b5ef7a9ea03a260fe80`
- run/job: `33101409110 / 98619779746`
- artifact ID: `9658757261`
- IPA SHA-256: `8cf6d454bf7eec64207875e9c20a1bbc6b125578f11fb777bfdda4fa6b5c5bfe`
- only new runtime behavior: automatic carousel transition could start only while Home was at top/rest (`abs(homeRawScrollMinY) <= 0.5`).

Target-device result: user still perceived Home vertical hitching. This candidate is rejected as sufficient. Do not carry the top-only guard into later vertical diagnostics.

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / hypothesis rejected as sufficient / stable ❌.

## Build223 / 0.14.56 — vertical persistent-backdrop isolation

### Identity

- branch: `diag/home-carousel-persistent-backdrop-isolation-build223`
- base: `main` head at branch creation `da5ad1dc6341481b12b8ae3e8b85cc5e5bb31a05`
- tested source / CI head: `af54d693d91303ea9bd201b5525e24f3e15ad931`
- temporary workflow/trigger were removed after successful packaging; product source is unchanged by cleanup.
- run/job: `33110117601 / 98650408622` — success
- artifact: `OnePlayer-0.14.56-build223-persistent-backdrop-isolation`
- artifact ID: `9662245993`
- artifact ZIP SHA-256: `cdc741253866243bf2f2ae111e46807e64a5deefecdc30d46ee6a75f31a0eba1`
- IPA SHA-256: `a925714dceb138df7808079b5784f3337afe92245bd790c42c290eac82ccd73c`
- source ZIP SHA-256: `b14860b0a5889b39be17eeac8aeacf0621c6c68784058f463f00eae3057a5432`
- independently re-opened artifact confirms bundle `com.embyplayerlab.app`, OnePlayer `0.14.56 (223)`, `MinimumOSVersion=15.0` and `CADisableMinimumFrameDurationOnPhone=true`.

### Exact runtime change

One presentation variable only:

- `Sources/UI/EmbyHomeCoreV3.swift`: immersive Home no longer mounts `persistentCarouselBackdrop(...)` at the root ZStack;
- `persistentCarouselBackdrop` / `carouselPersistentImage` remain implemented in `EmbyHomeHeroV3.swift` and the existing `.blur(radius: 30)` remains in source;
- `carouselPreloadLayer` remains mounted;
- Hero artwork remains mounted and unchanged;
- Build222 top-only auto-advance guard is absent; normal Build216 auto-advance behavior remains;
- horizontal carousel state/gesture ownership is unchanged;
- no Player/MPV/PiP/Transport/Cache/Session source changed.

The packaged exact source was independently re-opened and those assertions were rechecked after CI.

### Evidence level

- Code written ✅
- Exact scope/Frozen guard ✅
- CI passed ✅
- IPA produced+verified ✅
- Real-device tested ❌
- Stable ❌

Legacy unrelated `temp-*` workflows may still auto-fail on branch pushes; they are not Build223 evidence. The dedicated run above is the controlling CI result.

## Parallel/identity note

A separate Aether workstream has historical material whose filename also contains `Build222`, while its checkpoint did not allocate that identity. Do not reuse 222. Build223 is reserved to this carousel diagnostic.

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

Install Build223 on iPhone 15 Pro Max / iOS 17.0 and test **Home vertical scrolling with carousel enabled**. The decisive A/B question is whether removing only the always-mounted blurred persistent backdrop materially changes the tactile hitching.

Also note the expected visual change below/around Hero caused by this diagnostic removal; visual degradation alone does not invalidate the performance A/B.

- If vertical smoothness materially improves, persistent full-screen presentation is a causal component; next redesign its presentation ownership while preserving the visual effect.
- If smoothness is unchanged, do not keep Build223 behavior; isolate the next measured component (preload or Hero presentation) one at a time.
- Keep Build221 horizontal testing separate; do not combine horizontal and vertical experiments before each has direct target-device evidence.
