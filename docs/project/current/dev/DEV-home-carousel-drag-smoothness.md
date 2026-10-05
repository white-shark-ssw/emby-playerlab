# DEV-home-carousel-drag-smoothness

- **Status:** Active — Build291 simulator regressions, exact-source CI and independently verified IPA complete; target-device acceptance pending.
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

Native simulator, exact-source Release, artifact/IPA/source identity and MinOS verification complete. Package supplied for user testing. Build289/290 remain rejected; Build291 is not real-device tested or stable.

## Next exact action

Receive the user's Build291 iPhone15ProMax/iOS17 result and compare slow/rapid/held reversal/release/settle takeover, title continuity, Dock position, vertical scroll/stretch/refresh and detail navigation. Diagnose any residual issue from the exact dbeaa9d product source. No additional rebuild or speculative rewrite is justified before that evidence. If image-logo/text alternation remains with correct page spacing, investigate itemID/logoURL callbacks specifically rather than assuming resource loss.

## Rejected / protected

Do not repeat guessed Dock offsets, progress smoothing/interpolation, retry/timer/watchdog, broad second renderer rewrite or logo cache/fallback without evidence. Native implementation is not yet device accepted. The frame violation explains a concrete geometry failure; it does not prove the final presented FPS goal. Build286 narrowing, blur-only removal, foreground count reduction and pixel-grid rounding remain insufficient prior directions. All Frozen/P0 contracts and iOS15.0 remain protected.


### Build291 verification and handoff — 2026-10-06 (Asia/Shanghai)

- OnePlayer **0.15.24 (291)**; product branch perf/home-carousel-progress-scope-build286 / Draft PR#289; exact product head **dbeaa9d3472c85a5c238598da3aac41d8e49f43c** unchanged at final guard.
- CI control head **f7ea52f37fae6b3858c8366bd705299b33a29689**; run/job **37336790243 / 111853475339** — success. Control checkout explicitly builds the product SHA above; CI control head is not the packaged product source.
- Rejected Build290 negative control: 3 tests, 48 expected assertion failures. Logs reproduce actual foreground page separation **0 rather than 430 pt**, and incorrect Home Dock extent. Candidate native simulator suite: **5 tests / 0 failures**, covering both directions/reversal, vertical/resource geometry, release direction, presentation-position takeover, invalidated completion and extracted accepted Build286 Dock layout. Simulator tests do not establish iOS17 target-device acceptance or real-content 120FPS.
- Artifact **OnePlayer-0.15.24-build291-home-carousel-geometry**, ID **11356997513**, size 22566239 bytes, digest **sha256:86b85caa6a5453c27e3731c050d5854d09623a13bd1b39632a91851f0639a3b3**.
- IPA **OnePlayer-0.15.24-build291-home-carousel-geometry-unsigned.ipa**, 18604463 bytes, SHA256 **a5a20c47f39a1df06b41211894dc01a3755ce939387574fa164fd02a484e8708**.
- Exact-source ZIP SHA256 **fc60c2cc52201c39d0111c4340052e1fe1f365e7f9a4079ad7e0edb3157e37c6**. ZIP commit comment equals product SHA; NativePresentation/HomeCore/AppIdentity bytes match inspected candidate. Both archive integrity and CI checksum files independently verified.
- Bundle **com.embyplayerlab.app**, version/build **0.15.24 / 291**, Info.plist MinOS **15.0**, main executable LC_BUILD_VERSION independently read as **15.0**; CI runtime MinOS audit OK; CADisableMinimumFrameDurationOnPhone=true.
- Evidence: **Code written / native simulator regression passed / exact-source CI passed / IPA produced+independently verified / target-device pending / not stable**. Private recording remains outside public repo. No final FPS or title-resource-loss verdict is inferred.
- Next gate: iPhone15ProMax/iOS17.0 slow drag, held reversals, repeated quick switches, commit/cancel takeover, image-logo/text-title continuity, bottom Dock, Home vertical scroll/stretch/refresh and detail push/pop. If title alternation persists with page separation repaired, trace itemID/logoURL/resource callbacks; do not guess another cache/fallback.
