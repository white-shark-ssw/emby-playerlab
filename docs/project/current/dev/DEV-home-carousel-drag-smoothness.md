# DEV-home-carousel-drag-smoothness

- **Status:** Active — Build291 reverse/title/Dock corrections user-confirmed; Build292 rapid swipe/fade native regression and exact-source CI running.
- **Work ID:** DEV-home-carousel-drag-smoothness
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps / native presentation / Dock
- **Working branch:** perf/home-carousel-progress-scope-build286
- **Draft PR:** #289 — open/unmerged
- **Current exact product head:** 23ed1864f63d4701509df98b72d15e67038f801a
- **Predecessor / device-positive geometry:** Build291 / dbeaa9d3472c85a5c238598da3aac41d8e49f43c
- **Reserved candidate:** OnePlayer 0.15.25 / Build292 / home-carousel-rapid-fade
- **CI control branch/head:** ci/build292-home-carousel-rapid-fade-20261005 / 8dc55421a62325a6611f54f337ffc9c56d4f9208
- **CI workflow/run/job:** .github/workflows/build292-home-carousel-rapid-fade.yml / 37341422303 / 111869158278
- **Target / MinOS:** iPhone 15 Pro Max / iOS 17.0; iOS 15.0

## Latest controlling device evidence

2026-10-06: user confirms Build291 fixes the previously reported reverse motion, logo/text title overlap and Dock upward regression. New issues: continuous quick swipes cannot advance continuously, so 120FPS cannot yet be tested; artwork/content seam is too hard. IMG_8032/8033 screenshots visible in conversation are qualitative evidence only. Provided local copies were missing. No final smoothness/120FPS acceptance inferred.

Resume identity guard passed: PR#289 and product branch both dbeaa9d at start; main499b628 before this task's new documentation. Poster283, Aether235 and completed Search remain isolated. Build292/0.15.25 and its candidate were unused across current checkpoints, Build index, remote branches and latest CI. All private screenshots/recordings remain outside public GitHub.

## Completed

- Build291 geometry: foreground bounds/center, no ordinary-progress page relayout, resources cannot snap a running native animator; accepted viewport+bottom-safe-area root extent keeps Dock placement independent of native render overscan.
- Build291 CI/IPA independently verified: run37336790243/job111853475339, artifact11356997513, IPA SHA a5a20c47f39a1df06b41211894dc01a3755ce939387574fa164fd02a484e8708; MinOS15.0; user-confirmed fixes above.
- Build292 source correction: committed same-direction takeover is rebased from actual presentation position to its committed target, retaining outgoing page across negative origin. New qualifying swipe can commit following neighbor. Three-page bounded takeover resumes incoming span before center rather than queuing unseen pages. Reverse takeover preserved.
- Broader native artwork fade spans full Hero/content boundary into same sampled solid color; no additional blur. HomeCore/Dock and input recognizer byte-identical to Build291.
- Product changes exactly AppIdentity, NativePresentation, RuntimeState, changelog. Frozen/P0, shared images/Poster, detail/navigation and MinOS untouched.

## Validation state

Source/static scope reviewed. Native suite contains 8 actual-source tests: prior geometry/reversal, vertical/resource geometry, release/presentation interruption, reverse/stale completion, accepted Dock; new consecutive committed swipe in both directions, rebased reversal, full Hero mask. Build291 is negative control for consecutive swipe and fade tests. CI run37341422303 has passed the native regression stage (Build291 negative control and full8-test candidate suite); Release/package/device results pending. Initial CI37341265451 failed before compile due old-version changelog path in guard; CI-only correction, product unchanged.

## Pending / Next exact action

Finish actual UIKit negative-control/candidate regressions and exact-source Release CI; inspect source ZIP comment/bytes, IPA integrity/checksum/bundle/version/build, Info.plist+Mach-O MinOS15.0; save user IPA and provide HTTPS artifact. Then receive device rapid consecutive/reverse/cancel, fade, title/Dock, vertical scroll/stretch/refresh and navigation results. Do not claim120FPS from screenshots, simulator or CI.

## Rejected / protected

Build289/290 remain device-rejected. Keep Build291 geometry fix; do not reintroduce transformed frame writes, guessed Dock offsets, logo cache/fallback, interpolation/prediction/timer/watchdog, broad renderer rewrite or extra high-frequency SwiftUI owner. Preserve0.28/500pt/s,0.22/0.18/0.62s and6s auto. All Frozen/P0 contracts and iOS15.0 remain protected.

## Build292 — consecutive committed takeover / full Hero fade (2026-10-06)

Build291 **target-device positive for the reported reverse movement, logo/text overlap and Dock alignment fixes**. User reports new failures: consecutive quick swipes cannot advance continuously, artwork/content seam looks too hard. IMG_8032/8033 are qualitative screenshots, not a 120Hz trace. No broad smoothness acceptance is inferred.

Source diagnosis: interrupted committed release retains old current/from until completion, so repeated swipes can keep targeting the same page. Build292 promotes the committed target only for same-direction takeover with presentation-relative negative origin and retained outgoing resident page, preserving foreground offsets. A qualifying fresh swipe may then commit the next neighbor; a reverse takeover retains the existing path. Runtime owns the commit intent; native renderer owns no second progress value. When the incoming anchor remains before center, takeover resumes its bounded three-page span instead of queuing invisible pages. Thresholds/times remain0.28/500pt/s and0.22/0.18/0.62s;6s auto unchanged.

Native clear artwork now fades across full foreground Hero height rather than clipping at shorter backdrop height; broadened mask fades into the same sampled solid color. No new blur or frame layout on ordinary progress. HomeCore/Dock geometry is byte-identical to device-positive Build291. Shared images/Poster, detail/navigation and Frozen/P0 remain untouched; iOS15.0.

Reserved **OnePlayer0.15.25 / Build292 / home-carousel-rapid-fade**; product branch perf/home-carousel-progress-scope-build286 / Draft PR#289; exact product **23ed1864f63d4701509df98b72d15e67038f801a**; predecessor Build291 **dbeaa9d3472c85a5c238598da3aac41d8e49f43c**. Product changes exactly AppIdentity, NativePresentation, RuntimeState and changelog. CI control branch **ci/build292-home-carousel-rapid-fade-20261005**, head **8dc55421a62325a6611f54f337ffc9c56d4f9208**; detached exact-source guard and native tests compare previous Build291 with candidate. First control run failed before compilation because its changelog pathname used the old version suffix; corrected in CI only, product unchanged.

Evidence: **Code written / static scope reviewed / native simulator tests+Release CI+IPA pending / device validation pending / no120FPS or stable claim**. Next: run actual consecutive-swipe negative control and full candidate suite, build/package/MinOS audit, independently inspect exact-source ZIP and IPA, hand off HTTPS artifact for real-device continuous quick switching, cancellation/reversal, gradual fade and retained title/Dock/vertical behavior.
