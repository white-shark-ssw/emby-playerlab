# DEV-home-carousel-drag-smoothness

- **Status:** Active — Build262 / 0.14.95 exact-source CI/IPA verified; target-device rapid-swipe + 120 FPS A/B pending.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps
- **Task:** Preserve the accepted Build241 carousel appearance/gesture feel while fixing two newly proven regressions: rapid consecutive horizontal swipes must remain owned by the carousel instead of falling through to the Home vertical ScrollView; active drag + release/settle must eliminate long-frame spikes sufficiently to approach EX's stable 120 FPS behavior on iPhone 15 Pro Max / iOS 17.0.
- **Base branch:** `main`
- **Reopen main checkpoint commit:** `8536cd811963b405cdd39ba84a723e5e68d02ba0`
- **Working branch:** `perf/home-carousel-rapid-swipe-120hz-build262`
- **Draft PR:** #269
- **Exact Build262 product source:** `86ac642ec33ad927a1bc3688824bfe0909b22bab`
- **Current candidate:** OnePlayer `0.14.95 (262)` — Build261 is owned by the parallel poster task and must not be reused.
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment Target:** iOS 15.0.

## Controlling real-device evidence — Build241 reopen

The user's 2026-08-30 recordings are explicitly confirmed to be **Build241 / OnePlayer 0.14.74**.

1. EX rapid consecutive carousel swipes hold the on-screen refresh indicator at 120 FPS with no visible drop in the supplied recording.
2. OnePlayer Build241 fluctuates strongly during the same stress pattern; visible indicator samples include sub-60 values and drops to roughly 30/44 FPS. The recording itself is 30 fps, so the overlay is treated as the display-FPS evidence, not the video file frame rate.
3. OnePlayer rapid repeated horizontal swipes intermittently move the Home vertical ScrollView instead of continuing the carousel; EX does not show this ownership failure.
4. This evidence revokes the prior Build241 final/frozen classification. Build241 remains the merged runtime baseline and visual/behavioral foundation, but the carousel task is Active again.
5. Build242 remains diagnostic-only and must never be inherited as product behavior. Build257 remains an unmerged auto-advance/vertical-inertia containment fallback and does not address this manual rapid-swipe problem.

## Build262 exact runtime delta

Relative to the reopen main source, the exact product commit `86ac642e...` changes only three product files:

1. `Sources/Core/AppIdentity.swift`
   - candidate identity only: `0.14.95`.
2. `Sources/UI/EmbyHomeCarouselInteractionV3.swift`
   - replaces the old 0.5 pt one-sample axis decision with small spatial hysteresis inside the same UIKit recognizer: no decision below 2 pt; horizontal/vertical wins at a 1.15 dominance ratio; ambiguous motion waits only until 6 pt and then selects the larger axis;
   - adds `prepareCarouselForNewInteractiveDrag()` so a new horizontal swipe can take over a completed commit/cancel settle endpoint instead of being rejected during the delayed cleanup window;
   - commit endpoint logs `HomeCarouselRapidSwipe interrupt=commit-settle`; cancel endpoint logs `interrupt=cancel-settle`;
   - retains one UIKit gesture owner, Build241 `>=500 pt/s` direction-aware fling gate and `>=0.28` ordinary progress gate.
3. `Sources/UI/EmbyHomeHeroV3.swift`
   - persistent blurred backdrop reuses the existing derived current/previous/next `carouselHeroResidentItems` window and unchanged `carouselOpacity(for:)` instead of mounting the transition target for the first time during interaction;
   - this re-tests historical Build230 persistent residency **only against the newly established long-frame/FPS acceptance question**. Build230 was rejected as a title-shimmer fix, not proven ineffective for FPS/long frames;
   - retains Build231 foreground `compositingGroup()`, Build226 Hero residency and blur radius 30.

No Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / Search / poster-grid product files are changed.

## Settle ownership proof

Source re-check after code writing confirms the interruption mechanism matches the real state owner:

- `completeInteractiveTransition(to:)` executes `withAnimation(.easeOut(duration: 0.22)) { transitionProgress = 1 }`, then delays only cleanup by 0.23 s.
- `cancelInteractiveTransition()` executes `withAnimation(.easeOut(duration: 0.18)) { transitionProgress = 0 }`, then delays only cleanup by 0.19 s.
- Therefore during the former dead window the model state is already exactly at 1 or 0 while SwiftUI is presenting the animation. Build262's endpoint check is not an inferred timer heuristic; it observes that authoritative state and either calls the existing `settleCarousel(on:)` or clears the completed cancel endpoint before admitting the next horizontal gesture.

## Historical presentation evidence retained

- Build219 proved the exact device-max refresh request materially raises carousel delivery/render/display cadence but still recorded episodic ~34–50 ms display gaps, many near Hero/persistent 1400 px presentation callbacks.
- Build225 target-Hero isolation materially improved horizontal fineness; Build226 converted that into current/previous/next Hero residency.
- Build228 keeps the max-refresh request alive through settle/cancel and remains retained.
- Build230 persistent three-slot residency did not fix title shimmer; that narrow rejection remains valid. It did not establish a long-frame/FPS verdict.
- Build231 page-level foreground `compositingGroup()` materially improved title stability and remains retained.

## Build262 CI / package evidence

- Exact product source: `86ac642ec33ad927a1bc3688824bfe0909b22bab`.
- Dedicated exact-source CI branch: `ci/build262-carousel-20260830`.
- Workflow explicitly sets `PRODUCT_SHA=86ac642ec33ad927a1bc3688824bfe0909b22bab`, checks out that SHA, asserts `git rev-parse HEAD == PRODUCT_SHA`, verifies Build241 guardrails and then builds that checkout.
- CI run/job: **`33311662277 / 99257718260` — success**.
- Artifact: `OnePlayer-0.14.95-build262-carousel-rapid-120hz`, ID **`9732204076`**.
- GitHub artifact digest: `sha256:3558a391076ec952faf93ccdd8be94c2649ebfbf835d228466fae31b0aa8406b`; independently recomputed after download and matched exactly.
- IPA SHA-256: **`0e2a70edb9c5a22df87d0c2a028845dd54b516240f158c205087a0c889133bd5`**.
- Exact source ZIP: `OnePlayer-0.14.95-build262-86ac642-source.zip`; SHA-256 **`b4d6e917478755285e7575e45d71458a3731371dbf05ca9b85a37013f0cf37fa`**.
- Reopened built package validation: bundle `com.embyplayerlab.app`, display/name `OnePlayer`, version `0.14.95`, build `262`, `MinimumOSVersion=15.0`; executable Mach-O minOS audit also passes 15.0.
- Source ZIP independently inspected and contains the Build262 axis hysteresis, rapid-settle takeover, retained 500/0.28 gates, two `carouselHeroResidentItems` presentation uses, one foreground `compositingGroup()` and blur30.

## Parallel-task guard

- `DEV-poster-grid-smoothness` owns Build261 and its own shared 3×3 diagnostics. Do not reuse Build261 or inherit its branch.
- `DEV-aether-multi-engine-comparison` remains separate Player work and does not overlap Home carousel UI state ownership.
- Search Build256 remains completed/merged; do not reopen Search behavior.
- No Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN source is in scope.

## Acceptance criteria

1. Repeated fast horizontal swipes can be issued immediately after finger-up without the former 0.18–0.23 s carousel ownership dead window.
2. Once horizontal intent is established, the Home vertical ScrollView cannot steal the gesture during that touch sequence.
3. Direction acquisition is robust to tiny initial diagonal/noisy samples without adding a perceptible horizontal dead zone.
4. Build241's accepted direction, 500 pt/s fling threshold, 0.28 progress threshold, full-width page motion, three-slot Hero residency, foreground compositing and 0.22/0.18 normal settle feel remain unless new device evidence specifically requires changing one.
5. Active drag + settle cadence instrumentation remains available and distinguishes ordinary ~8.3 ms frames from long frames.
6. Candidate compiles/packages at MinOS 15.0 and produces an identity-verified IPA before handoff. **Build262 passes this gate.**
7. Final acceptance requires target-device stress A/B versus EX; CI/IPA alone is not success.

## Validation state

- Code written: ✅ exact product source `86ac642e...`.
- CI passed: ✅ run/job `33311662277 / 99257718260`.
- IPA produced + independently verified: ✅ artifact `9732204076`, IPA SHA above.
- Real-device tested: Build241 regression evidence ✅; **Build262 pending**.
- Stable/frozen: ❌.

## Next exact action

Install Build262 on iPhone 15 Pro Max / iOS 17.0 and run the same stress comparison used to reopen the task:

1. rapidly swipe the carousel horizontally several times with the next finger-down occurring immediately after the prior finger-up; verify Home does not move vertically and no carousel swipe is lost during the settle tail;
2. keep the on-screen FPS indicator visible and compare rapid repeated swipes against EX; record whether OnePlayer can hold near 120 and whether 30/44-class drops remain;
3. watch for any new post-settle hitch, excessive memory/visual regression or backdrop mismatch from persistent three-slot residency;
4. export the App log. Inspect `HomeCarouselRapidSwipe` and `HomeCarouselCadence` before deciding whether Build262 advances, partially passes, or must split gesture ownership from long-frame work.

Do not merge PR #269 or re-freeze the carousel until this target-device evidence exists.
