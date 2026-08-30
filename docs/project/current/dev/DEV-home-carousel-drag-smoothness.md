# DEV-home-carousel-drag-smoothness

- **Status:** Active — reopened 2026-08-30 by new Build241 target-device evidence; Build262 first clean product source written, CI/IPA pending.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps
- **Task:** Preserve the accepted Build241 carousel appearance/gesture feel while fixing two newly proven regressions: rapid consecutive horizontal swipes must remain owned by the carousel instead of falling through to the Home vertical ScrollView; active drag + release/settle must eliminate long-frame spikes sufficiently to approach EX's stable 120 FPS behavior on iPhone 15 Pro Max / iOS 17.0.
- **Base branch:** `main`
- **Reopen base commit:** `8536cd811963b405cdd39ba84a723e5e68d02ba0`
- **Working branch:** `perf/home-carousel-rapid-swipe-120hz-build262`
- **Current clean product source:** `86ac642ec33ad927a1bc3688824bfe0909b22bab`
- **PR:** none yet
- **Current candidate allocation:** OnePlayer `0.14.95 (262)` — Build261 is already occupied by the parallel poster task and must not be reused.
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment Target:** keep iOS 15.0.

## Controlling real-device evidence

The user's new 2026-08-30 recordings are explicitly confirmed to be **Build241 / OnePlayer 0.14.74**.

1. EX rapid consecutive carousel swipes hold the on-screen refresh indicator at 120 FPS with no visible drop in the supplied recording.
2. OnePlayer Build241 fluctuates strongly during the same stress pattern; visible indicator samples include sub-60 values and drops to roughly 30/44 FPS. The recording itself is 30 fps, so the overlay is treated as the display-FPS evidence, not the video file frame rate.
3. OnePlayer rapid repeated horizontal swipes intermittently move the Home vertical ScrollView instead of continuing the carousel; EX does not show this ownership failure.
4. This evidence revokes the prior Build241 final/frozen classification. Build241 remains the merged runtime baseline and the visual/behavioral foundation to preserve, but the carousel task is Active again.
5. Build242 remains diagnostic-only and must never be inherited as product behavior. Build257 remains an unmerged auto-advance/vertical-inertia containment fallback and does not address this manual rapid-swipe problem.

## Source evidence and Build262 first patch

### Rapid-swipe ownership

Build241 decided horizontal vs vertical as soon as max displacement reached 0.5 pt. A tiny diagonal first sample could therefore fail the carousel recognizer before meaningful intent was visible. Build262 replaces that one-sample rule inside the existing recognizer with a small **spatial** hysteresis only: wait until 2 pt dominant travel, accept a direction once it is at least 1.15× the other axis, and if still ambiguous resolve by the dominant axis at 6 pt. No timer/debounce/throttle/interpolator/second gesture owner is added.

Build241 also rejected any new drag while `transitionToID != nil && !isCarouselDragging`, creating a real 0.18–0.23 s ownership dead window during cancel/commit settle. Build262 keeps the same transition state owner but lets a new horizontal acquisition interrupt an endpoint settle: if model progress is already 1, settle immediately on the committed target; if model progress is already 0, clear the cancelled transition. Existing delayed settle closures keep their identity/progress guards and therefore become no-ops after the interrupt. A new `HomeCarouselRapidSwipe` diagnostic records these interruptions.

The existing Build241 `>=500 pt/s` velocity commit and `>=0.28` ordinary progress commit remain unchanged. Commit/cancel animations remain 0.22/0.18 s when they are not interrupted by a new user gesture.

### Long-frame / 120 Hz A/B

Current source already requests exact device maximum refresh through the existing carousel cadence `CADisplayLink`, and `CADisableMinimumFrameDurationOnPhone=true` is already present. Therefore Build262 does not add another refresh requester.

Historical Build219/241 logs repeatedly associated the worst 34–50 ms display gaps with newly presented Hero/persistent 1400 px surfaces. Build230 moved persistent target first presentation out of active drag by reusing the existing current+previous+next resident window; its target-device result rejected it only as a **title-shimmer fix** (`慢拖文字还是会有抖动`), not as a long-frame/FPS fix. Build262 therefore re-tests that exact persistent-residency lifecycle for the new 120-FPS acceptance question. It adds no new residency state and retains blur30 and normal outgoing/incoming opacity crossfade. Build231/Build241 foreground `compositingGroup()` remains.

## Final clean product-tree scope at `86ac642e...`

Relative to reopen base `8536cd...`, only three product files differ:

1. `Sources/Core/AppIdentity.swift` — candidate source identity `0.14.95`.
2. `Sources/UI/EmbyHomeCarouselInteractionV3.swift` — spatial axis hysteresis + endpoint settle interruption in the existing UIKit owner.
3. `Sources/UI/EmbyHomeHeroV3.swift` — existing current/previous/next window reused for persistent backdrop residency.

Failed temporary materializer workflow files were removed/restored byte-for-byte before declaring this product source. No workflow, Player, MPV, PiP, Transport, Cache, Emby Session, Search or Poster file remains in the final product diff.

## Parallel-task guard

- `DEV-poster-grid-smoothness` owns Build261 and separate shared 3×3 diagnostics. Its current source scope does not own the Build241 manual carousel recognizer/state/Hero files.
- `DEV-aether-multi-engine-comparison` remains separate Player work and does not overlap Home carousel UI state ownership.
- Search Build256 is completed/merged; do not reopen Search behavior.
- No Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM/302/115/CDN source is in scope.

## Acceptance criteria

1. Repeated fast horizontal swipes can be issued immediately after finger-up without a 0.18–0.23 s carousel ownership dead window.
2. Once horizontal intent is established, the Home vertical ScrollView cannot steal the gesture during that touch sequence.
3. Direction acquisition is robust to tiny initial diagonal/noisy samples without adding a perceptible horizontal dead zone.
4. Build241's accepted direction, 500 pt/s fling threshold, 0.28 progress threshold, full-width page motion, three-slot Hero residency, foreground compositing, persistent visual style, and 0.22/0.18 settle feel remain unless new device evidence specifically requires changing one.
5. Active drag + settle cadence instrumentation remains available and must distinguish ordinary 8.3 ms frames from long frames.
6. Candidate must compile/package at MinOS 15.0 and produce an identity-verified IPA before handoff.
7. Final acceptance requires target-device stress A/B versus EX; CI/IPA alone is not success.

## Validation state

- Code written: ✅ — clean product source `86ac642ec33ad927a1bc3688824bfe0909b22bab`.
- Exact diff scope: ✅ — three product files only.
- CI passed: ❌ pending.
- IPA produced: ❌ pending.
- Real-device tested: Build241 regression evidence ✅; Build262 pending.
- Stable/frozen: ❌.

## Pending / next exact action

Open the Build262 draft PR, run an exact-source Release iOS build/IPA workflow against `86ac642e...`, verify bundle/version/build/MinOS and artifact/source hashes, then hand the IPA to the user. Target-device test must stress immediate repeated horizontal swipes, confirm whether Home vertical scrolling still steals ownership, compare the FPS overlay against EX, and return the App log so `HomeCarouselRapidSwipe` plus `HomeCarouselCadence` worst gaps/image roles can be evaluated. Specifically watch the first 200–500 ms after committed settle for a new hitch caused by resident-window rotation; if persistent residency merely moves the cost, reject it rather than stacking more smoothing layers.
