# DEV-home-carousel-drag-smoothness

- **Status:** Active — Build292 user-reported stable120FPS; Build293 rapid flicker and floor-color correction queued for native/Release CI.
- **Work ID:** DEV-home-carousel-drag-smoothness
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe /120fps / native presentation / Dock
- **Working branch:** perf/home-carousel-progress-scope-build286
- **Draft PR:** #289 — open/unmerged
- **Current exact product head:** fa8ff44ff4a5384fd4603a64b33354f941764a8c
- **Predecessor:** Build292 /23ed1864f63d4701509df98b72d15e67038f801a
- **Reserved candidate:** OnePlayer0.15.26 / Build293 /home-carousel-handoff
- **CI control branch/head:** ci/build293-home-carousel-handoff-20261005 /4a26035ab17e0cf61b3f647055a13a0c745c4280
- **CI workflow/run/job:** .github/workflows/build293-home-carousel-handoff.yml /37345215494 /111882105262 — macOS runner queued
- **Target / MinOS:** iPhone15ProMax/iOS17.0; iOS15.0

## Latest controlling device results

Build291: user confirms reverse motion, logo/text overlap and Dock repairs. Build292: user confirms long frames repaired and stable120FPS, but rejects rapid consecutive flicker and still-mismatched artwork/content floor colors. RPReplay_Final1791219024.mp4:4.93s/30fps/510x1108/148frames; flicker visual evidence,120FPS is user report rather than derived from recording. Private recording remains outside GitHub.

## Completed / validation

Resume guard passed against branch/PR head23ed1864 and maina1834c10. No Build293/0.15.26 duplicate across checkpoints/index/remote branches/latest CI. Poster283/Aether235/Search isolated. Build293 code written+scope/static check complete. Captures native presentation opacity/base color; retains all contributing outgoing artwork during rebasing, fades all old artwork in next tail, clears at settle. Lower-edge sample plus clear image/contrast end before content boundary share same solid floor. Delta exactly AppIdentity/NativePresentation/changelog. Runtime/input/HomeCore/Dock/vertical/shared images/Poster/detail/navigation/Frozen/P0 byte-identical to Build292; MinOS15 unchanged.

Native suite10 actual-source tests:4 consecutive opacity/base-color handoffs, outgoing retention, two-color lower-edge sample orientation/common floor, and prior8 geometry/release/reverse/cancel/Dock cases. Build292 negative control for2 new tests. First control1e3e8dd run37345056451 cancelled while strengthening sample orientation test; current4a26035 run above is authoritative, product unchanged. Native/Release/IPA pending.

## Pending / Next exact action

Wait for current native negative-control/candidate suite and exact-source Release CI. If regression fails inspect actual assertion/compiler logs; do not suppress tests. Then independently verify artifact/source ZIP comment+bytes, IPA integrity/checksum/bundle/version/build and Info.plist+Mach-O MinOS15. Save IPA and deliver copyableHTTPS artifact URL. Next device gate: rapid repeated handoffs/flicker, lower color seam, preserved120FPS, title/Dock, vertical scroll/stretch/refresh/navigation. Build293 is not device accepted.

## Protected / rejected

Preserve Build291 geometry and Build292 user-positive cadence. Build289/290 rejected. No transformed frame writes, guessed Dock offsets, extra blur/timer/watchdog/interpolation/product progress owner/full-tree high-frequency SwiftUI. Preserve0.28/500pt/s and0.22/0.18/0.62s,6s auto; all Frozen/P0 and iOS15.0.

## Build293 — artwork/base-color presentation handoff; shared lower-edge floor

2026-10-06: Build292 device feedback confirms stable120FPS and removal of long frames. Rapid continuous switching still flickers, and user reports artwork/content color mismatch. Recording4.93s/30fps is qualitative only;120FPS is user report. Build293 captures all actual artwork presentation opacities and actual base color before interrupting; preserves them across page rebasing/real finger motion; fades every captured outgoing page in the new tail, clears at settle. No second product progress owner. Source also used central80% image average for floor; now lower-edge18% sample carries image edge color downward, and clear-image/contrast overlays end at90% Hero height so its last strip and content share exactly one solid base. No new blur, per-progress layout, timer or SwiftUI invalidation.

Product0.15.26/Build293 exact fa8ff44ff4a5384fd4603a64b33354f941764a8c (parent23ed1864), PR#289/branchperf/home-carousel-progress-scope-build286. CI4a26035ab17e0cf61b3f647055a13a0c745c4280/ci/build293-home-carousel-handoff-20261005. Delta exactly AppIdentity, NativePresentation, changelog. Runtime/input/HomeCore/Dock/vertical/shared images/Poster/detail/navigation/Frozen/P0 byte-identical to user-positive292; MinOS15. Tests compare actual layer alpha/base before/after four handoffs, retain outgoing pages, lower-edge sample orientation and common floor; prior eight regressions retained. Native/CI/IPA pending; user-reported292120FPS positive,293 flicker/color/performance device pending. Next exact action: complete10-test suite and292 negative control, exact-source Release/IPA/MinOS, independently verify handoff artifact.
