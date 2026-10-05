# DEV-home-carousel-drag-smoothness

- **Status:** Active — Build291 code written and native simulator regressions passed; Release CI/package verification in progress. Build289/290 remain real-device rejected.
- **Work ID:** DEV-home-carousel-drag-smoothness
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps / native presentation / Dock
- **Task:** Correct reverse foreground movement, logo/text overlap and Dock upward regression; continue evidence-backed Home carousel refinement.
- **Working branch:** perf/home-carousel-progress-scope-build286
- **Draft PR:** #289 — open/unmerged
- **Current exact product head:** dbeaa9d3472c85a5c238598da3aac41d8e49f43c
- **Parent/rejected source:** Build290 / 9e0bb371fe65c29524b92ac1892bab84b6684444
- **Reserved candidate:** OnePlayer 0.15.24 / Build291 / home-carousel-geometry
- **CI control branch/head:** ci/build291-home-carousel-geometry-20261005 / f7ea52f37fae6b3858c8366bd705299b33a29689
- **CI workflow:** .github/workflows/build291-home-carousel-geometry.yml (push, exact product SHA guard)
- **Target / MinOS:** iPhone15ProMax / iOS17.0; iOS15.0

## Latest controlling real-device evidence

User continues the exact Work ID and permits evidence-backed restructuring. RPReplay_Final1791212395(1).mp4: 9.17 s / 30fps / 510×1108. Reported reverse movement during swipes, image-logo/text-title alternation and Dock too high. Build290 unchanged native runtime provides no improvement; Build289/290 rejected, no accepted native candidate. Private video remains outside public GitHub; 30fps recording is qualitative evidence, not a 120Hz trace.

Resume guard passed against PR/branch/head and other Active task branch/candidate identities. Build291 / 0.15.24 had no conflicting checkpoint, branch, Build index or latest CI candidate. Poster Build283, Aether Build235 and completed Search remain separate. No unmerged parallel code is imported. Main advancement consists of task documentation relative to the inspected product line, not a reason to merge old carousel source into this branch.

## Concrete diagnosis / completed patch

1. Build290 applyVisualState sets foreground transform then layoutVisiblePages sets the transformed foreground frame to x=0. UIKit changes the untransformed base center to satisfy that frame, cancelling finger movement, superimposing outgoing logo and incoming text pages, and giving release animation a displaced start. Apple's UIView contract forbids setting frame under nonidentity transform. Geometry now uses bounds/center and ordinary progress no longer calls page layout. Geometry boundaries prepare all resident nodes; visible vertical geometry retains X motion.
2. Accepted Build286 root layout includes viewport + bottom safe area via persistent backdrop. Build290 replaced it with viewport-only frame while retaining the same Dock inset. Native top overscan now renders as an overlay of exactly the accepted Build286 extent; Dock itself is unchanged. No compensating padding/constants added.
3. Native configure and bridge configure reapplied final visual model during an active UIViewPropertyAnimator. Resource configuration now updates prepared content without snapping that animator to its target. No new motion/selection/resource owner.

Product delta from Build290 is exactly AppIdentity, HomeCore, NativePresentation and changelog. RuntimeState/Interaction/Hero/vertical state and all shared Poster/images, detail/navigation, Player/MPV/PiP/Transport/Cache/Session paths remain unchanged. Preserve 0.28/500pt/s, 0.22/0.18/0.62s, 6s auto, acquisition semantics and max-refresh-through-settle.

## Validation state / pending

- Code written and local diff/scope review done.
- Dedicated control harness compiles real NativePresentation, runtime class and metric definitions; only unrelated delivery/diagnostic services are stubbed. UIKit tests check full-width separation/base centers under both directions and reversal, vertical/resource callbacks, release direction, takeover continuity and invalidated completion.
- Dock harness extracts the actual Home root expression from accepted Build286 and candidate source, preserving the server root/safe-area/navigation structure for comparison.
- Rejected Build290 runs the same geometry/Dock assertions as a negative control; candidate must pass. Simulator results are distinct from user real-device acceptance.
- Native regression step passed in run 37336790243 / job 111853475339: rejected Build290 negative control failed assertions as required, candidate suite passed. Exact-source product guard passed. Release compile, artifact retrieval, digest/source/IPA/plist/MinOS verification still pending. No current IPA291 has been claimed.

## Next exact action

Inspect the Build291 dedicated workflow run for f7ea52f37fae6b3858c8366bd705299b33a29689. Resolve actual test/compiler failures from logs (no guessed patches). Continue through successful Release/IPA and independent artifact identity verification; refresh this checkpoint and project authority, then hand the verified candidate to the user for target-device slow/rapid/reversal/release/title/Dock and Home vertical/navigation checks.

## Rejected / protected

Do not repeat guessed Dock offsets, progress smoothing/interpolation, retry/timer/watchdog, broad second renderer rewrite or logo cache/fallback without evidence. Native implementation is not yet device accepted. The frame violation explains a concrete geometry failure; it does not prove the final presented FPS goal. Build286 narrowing, blur-only removal, foreground count reduction and pixel-grid rounding remain insufficient prior directions. All Frozen/P0 contracts and iOS15.0 remain protected.
