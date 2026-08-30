# DEV-home-carousel-drag-smoothness

- **Status:** Active — Build262 target-device stress is partially positive for rapid-swipe/FPS but rejected as a product candidate because the carousel presentation can hard-freeze while interaction state continues; Build264 / 0.14.97 exact-source CI/IPA is verified and awaits target-device rollback A/B.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps
- **Task:** Preserve the accepted Build241 carousel appearance/gesture feel while fixing the reopened rapid consecutive swipe ownership failure and improving active-drag/settle cadence toward EX on iPhone 15 Pro Max / iOS 17.0.
- **Base branch:** `main`
- **Build262 branch:** `perf/home-carousel-rapid-swipe-120hz-build262`
- **Build262 PR:** #269 — closed without merge after the hard-freeze result.
- **Current working branch:** `perf/home-carousel-rapid-swipe-build264`
- **Current Draft PR:** #272
- **Current exact product source:** `323a1ba8c76382de7b893d50e3cf17388747b05f`
- **Current candidate:** OnePlayer `0.14.97 (264)` — Build263 belongs to the parallel poster task and must not be reused.
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment Target:** iOS 15.0.

## Controlling Build241 reopen evidence

The user's 2026-08-30 recordings were explicitly confirmed as Build241 / OnePlayer 0.14.74. EX held the on-screen 120 FPS indicator through repeated fast horizontal swipes, while Build241 visibly fell as low as roughly 30/44 FPS and rapid consecutive horizontal swipes could fall through into the Home vertical ScrollView. This revoked the former whole-carousel final/frozen status. Build241 remains the merged visual/behavior baseline to preserve.

## Build262 / 0.14.95 implementation

Exact product source: `86ac642ec33ad927a1bc3688824bfe0909b22bab`.

Relative to the Build241-derived reopen source, Build262 changed only:

1. `Sources/Core/AppIdentity.swift` — candidate identity.
2. `Sources/UI/EmbyHomeCarouselInteractionV3.swift`
   - spatial axis hysteresis inside the existing UIKit recognizer: no decision below 2 pt; horizontal/vertical wins at 1.15 dominance; ambiguous motion waits only until 6 pt then chooses the larger axis;
   - `prepareCarouselForNewInteractiveDrag()` admits a new horizontal swipe during the old 0.18–0.23 s delayed-cleanup window only when the authoritative transition progress is already at the completed commit/cancel endpoint;
   - preserves one UIKit gesture owner, Build241 direction-aware `>=500 pt/s` fling gate and ordinary `>=0.28` progress gate.
3. `Sources/UI/EmbyHomeHeroV3.swift`
   - experimental persistent blurred backdrop residency reused `carouselHeroResidentItems` (current/previous/next) instead of the Build241 current+transition-target persistent structure.

Build262 exact-source CI run/job `33311662277 / 99257718260` passed; artifact `9732204076`; IPA SHA-256 `0e2a70edb9c5a22df87d0c2a028845dd54b516240f158c205087a0c889133bd5`; source ZIP SHA-256 `b4d6e917478755285e7575e45d71458a3731371dbf05ca9b85a37013f0cf37fa`; built MinOS 15.0.

## Build262 target-device evidence — 2026-08-30

User supplied `RPReplay_Final1788096734.mp4`, `卡住了.mp4` and `OnePlayer-App-1788096766.log` from Build262.

### Positive result — rapid swipe / cadence

- User repeatedly stress-tested rapid swipes and reports the FPS no longer falls very low; it generally holds around **90–100 FPS**, a material improvement over the Build241 recording with roughly 30/44-class drops.
- The log contains 24 releases, 24 release decisions, 24 `HomeCarousel` settles, 24 cadence summaries and **9 `HomeCarouselRapidSwipe` interrupts**.
- Those interrupts prove the new settle-takeover path is actually exercised on the target device rather than merely compiling.
- Do not yet attribute the full FPS improvement to one Build262 sub-change because Build262 changed both interaction continuity and persistent presentation residency.

### Rejection — hard visual presentation freeze

The second recording shows a severe new regression: after roughly the first couple seconds the carousel remains visibly stuck on the same blended/partial-transition frame while the user continues swiping repeatedly.

The matching log disproves an interaction-state-machine freeze:

- after `NavigationRace event=open-server server=Shark` at `13:32:37.771Z`, the stuck-video interval contains **11 release events and 11 corresponding `HomeCarousel settled` events**;
- settled item IDs continue changing (`143014 → 143013 → 143017 → 143016 → 143018 → 150628 → 143014 → 143013 → 143017 → 143016 → 143018`) while the recorded carousel picture stays frozen;
- two rapid-settle interrupts also occur in that interval;
- there is no crash/fatal/error and no single unfinished transition left in the log.

Therefore the severe symptom is a **presentation/render/compositor path failure while the authoritative carousel interaction/current-item state continues to advance**. This is not evidence to undo the Build262 recognizer/settle-continuity improvement.

The only new Build262 presentation experiment relative to the long-lived Build241 baseline is persistent current/previous/next residency. That path is therefore rejected for the next product candidate under rapid-swipe stress. This does not reject Build226 clear-Hero three-slot residency; only the persistent blurred backdrop experiment is rolled back.

## Build264 / 0.14.97 minimum rollback A/B

Build264 is branched directly from exact Build262 product source `86ac642e...` so the proven interaction changes are retained without later workflow/docs noise.

Exact product source: `323a1ba8c76382de7b893d50e3cf17388747b05f`.

Relative to Build262 exact source, exactly two files change:

1. `Sources/Core/AppIdentity.swift`: `0.14.95 → 0.14.97` only.
2. `Sources/UI/EmbyHomeHeroV3.swift`: only `persistentCarouselBackdrop(size:)` returns to the Build241 current + transition-target structure and `carouselBackdropBlendProgress(transitionProgress)` blend.

`Sources/UI/EmbyHomeCarouselInteractionV3.swift` is byte-identical to Build262, preserving axis hysteresis and rapid settle takeover. Build226 clear-Hero current/previous/next residency, Build231 foreground `compositingGroup()`, blur30, 500 pt/s/0.28 gates, one UIKit owner, normal 0.22/0.18 settle feel, and P0/Frozen playback/transport contracts remain unchanged.

### Build264 CI / package evidence

- Working branch: `perf/home-carousel-rapid-swipe-build264`.
- Draft PR: #272.
- Exact-source CI helper branch: `ci/build264-carousel-20260830`.
- CI run/job: **`33315346306 / 99267618336` — success**; every workflow step passed.
- Artifact: `OnePlayer-0.14.97-build264-carousel-persistent-rollback`, ID **`9733296528`**.
- GitHub artifact digest: **`sha256:b3acb0efc4cbbf3b2c05e9cfeb88638aeadf25776f3c1fc6b904f18436855b4f`**; independently recomputed after download and matched exactly.
- IPA SHA-256: **`fe8354eaa0cb6afeb59454d6afd31c8e5da3e78bcade1242af499f7db7c51499`**.
- Exact source ZIP: `OnePlayer-0.14.97-build264-323a1ba-source.zip`; SHA-256 **`30e8bd7b3c41df3a9b83625da2c6bfdf3d978e64af0a6c5ba6a3cab421dababd`**.
- Independently reopened actual IPA: bundle `com.embyplayerlab.app`, display/name `OnePlayer`, version `0.14.97`, build `264`, `MinimumOSVersion=15.0`.
- Independently unpacked source verifies Build262 axis hysteresis + rapid-settle takeover + 500/0.28 gates are retained; `ForEach(carouselHeroResidentItems)` occurs exactly once (accepted clear-Hero path only); persistent backdrop contains Build241 current + transition-target layering; one foreground `compositingGroup()` and blur30 remain.

## Parallel-task guard

- `DEV-poster-grid-smoothness` owns Build263 / 0.14.96 and Draft PR #271.
- `DEV-aether-multi-engine-comparison` remains separate Player work and owns its own Build identity.
- Search Build256 remains accepted/merged and its semantics are protected.
- No Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN code is in scope.

## Acceptance criteria

1. Repeated fast horizontal swipes can start immediately after the previous finger-up without the former settle ownership dead window.
2. Once horizontal intent is acquired, Home vertical scrolling does not steal the touch sequence.
3. No hard visual freeze occurs while rapid swiping, including long repeated stress runs.
4. Build241 visual direction, 500 pt/s fling gate, 0.28 progress gate, full-width motion, clear-Hero three-slot residency, foreground compositing and 0.22/0.18 normal settle remain.
5. Rapid-swipe FPS materially improves over the Build241 low-drop behavior; final comparison remains target-device/EX controlled.
6. Candidate compiles/packages at MinOS 15.0 with exact-source identity verification before handoff. **Build264 passes this gate.**
7. Final acceptance requires target-device stress A/B; CI/IPA alone is not success.

## Validation state

- Build262 Code written / CI passed / IPA produced: ✅.
- Build262 real-device tested: ✅ — rapid-swipe/FPS partial positive, **hard presentation freeze rejection**; not stable.
- Build264 Code written: ✅ exact source `323a1ba...`.
- Build264 CI passed: ✅ run/job `33315346306 / 99267618336`.
- Build264 IPA produced + independently verified: ✅ artifact `9733296528`, hashes/identity above.
- Build264 real-device tested: ❌.
- Stable/frozen: ❌.

## Next exact action

Install Build264 on iPhone 15 Pro Max / iOS 17.0 and repeat the same rapid consecutive horizontal-swipe stress. Verify the Build262 hard visual freeze no longer occurs; verify Home vertical scrolling does not steal the horizontal sequence; record the on-screen FPS range to determine how much of Build262's roughly 90–100 FPS improvement survives without persistent residency; and export the App log. Do not merge PR #272 or re-freeze until this target-device evidence exists.
