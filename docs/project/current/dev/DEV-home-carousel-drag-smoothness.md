# DEV-home-carousel-drag-smoothness

- **Status:** Active — reopened 2026-08-30 by new Build241 target-device evidence.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps
- **Task:** Preserve the accepted Build241 carousel appearance/gesture feel while fixing two newly proven regressions: rapid consecutive horizontal swipes must remain owned by the carousel instead of falling through to the Home vertical ScrollView; active drag + release/settle must eliminate long-frame spikes sufficiently to approach EX's stable 120 FPS behavior on iPhone 15 Pro Max / iOS 17.0.
- **Base branch:** `main`
- **Reopen base commit:** `7158152f6593f4c302a98ca9e6b02103418b24b1`
- **Working branch:** `perf/home-carousel-rapid-swipe-120hz-build262`
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

## Current source evidence

- `V3HomeCarouselInteractionRecognizer` decides axis as soon as max displacement reaches 0.5 pt. If vertical displacement is larger at that first sample it fails immediately, allowing the parent Home ScrollView to win.
- `shouldBeginNativeCarouselDrag` currently rejects a new horizontal gesture while `transitionToID != nil && !isCarouselDragging`.
- Commit settle uses `.easeOut(duration: 0.22)` and clears transition state about 0.23 s later; cancel uses 0.18/0.19 s. Therefore rapid second swipes can land inside a real settle ownership dead window.
- `V3HomeCarouselCadenceDiagnostics` already requests exact device maximum frame rate with `CAFrameRateRange` while the carousel interaction is active. The new problem is therefore not merely a missing 120 Hz request.
- Historical Build241 cadence evidence showed episodic ~34–50 ms display gaps, frequently near first/full persistent/Hero image presentation. Historical Build230 already tried persistent three-slot residency; do not reintroduce it blindly without checking its device verdict.

## Parallel-task guard

- `DEV-poster-grid-smoothness` owns Build261 and separate shared 3×3 diagnostics. Its current source scope does not own the Build241 manual carousel recognizer/state/Hero files.
- `DEV-aether-multi-engine-comparison` remains separate Player work and does not overlap Home carousel UI state ownership.
- Search Build256 is completed/merged; do not reopen Search behavior.
- No Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM/302/115/CDN source is in scope.

## Acceptance criteria

1. Repeated fast horizontal swipes can be issued immediately after finger-up without a 0.18–0.23 s carousel ownership dead window.
2. Once horizontal intent is established, the Home vertical ScrollView cannot steal the gesture during that touch sequence.
3. Direction acquisition is robust to tiny initial diagonal/noisy samples without adding a perceptible horizontal dead zone.
4. Build241's accepted direction, 500 pt/s fling threshold, 0.28 progress threshold, full-width page motion, three-slot Hero residency, persistent appearance, and 0.22/0.18 settle feel remain unless new device evidence specifically requires changing one.
5. Active drag + settle cadence instrumentation remains available and must distinguish ordinary 8.3 ms frames from long frames.
6. Candidate must compile/package at MinOS 15.0 and produce an identity-verified IPA before handoff.
7. Final acceptance requires target-device stress A/B versus EX; CI/IPA alone is not success.

## Completed

- Reopen identity confirmed by user: supplied OnePlayer recording = Build241.
- Build241 remains current merged runtime baseline through PR #262.
- New real-device regressions recorded in `MODULE_STATUS.md`.
- Build261 collision detected; Build262 / 0.14.95 allocated to this task.
- Working branch created from reopen base commit.

## Validation state

- Code written: ❌
- CI passed: ❌
- IPA produced: ❌
- Real-device tested: Build241 regression evidence ✅; Build262 pending.
- Stable/frozen: ❌

## Pending / next exact action

Inspect the historical Build230 persistent-residency result and current Build241 recognizer/state/cadence call sites. Implement the smallest source changes that remove the rapid-swipe ownership dead window and improve axis acquisition without creating a second gesture owner. Then add/retain targeted cadence evidence for active drag + settle and build OnePlayer 0.14.95 (262) for target-device stress A/B. Do not guess at blur/image changes until source + prior device evidence supports them.
