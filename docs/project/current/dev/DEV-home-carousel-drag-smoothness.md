# DEV-home-carousel-drag-smoothness

- **Status:** Active — Build291 reverse/title/Dock corrections user-confirmed; Build292 rapid swipe/fade native regressions+CI+IPA verified; target-device pending.
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

Actual-source simulator8tests/0failures; Build291 negative control2tests/10expected failures confirms consecutive same-page retention and shorter/harder mask. Exact-source Release CI37341422303/job111869158278 passed. Artifact11359555710, source ZIP comment/bytes, IPA integrity/checksums/bundle0.15.25/292 and Info.plist+Mach-O MinOS15.0 independently verified. Full identities below. IPA saved and supplied for user testing; Build292 device and120FPS pending. Initial CI37341265451 failed before compile due old-version changelog pathname in guard; corrected CI-only, product unchanged.

## Pending / Next exact action

Receive Build292 target-device continuous fast switching, immediate reversal, held reversal, release/cancel takeover and artwork/content gradient results. Recheck retained title/Dock, vertical scroll/stretch/refresh and navigation. Sustained presented120FPS remains a separate device gate; screenshots/simulator/CI cannot establish it. Candidate, exact source, IPA/source/MinOS independently verified below. No additional rebuild without new evidence.

## Rejected / protected

Build289/290 remain device-rejected. Keep Build291 geometry fix; do not reintroduce transformed frame writes, guessed Dock offsets, logo cache/fallback, interpolation/prediction/timer/watchdog, broad renderer rewrite or extra high-frequency SwiftUI owner. Preserve0.28/500pt/s,0.22/0.18/0.62s and6s auto. All Frozen/P0 contracts and iOS15.0 remain protected.

## Build292 — consecutive committed takeover / full Hero fade (2026-10-06)

Build291 **target-device positive for the reported reverse movement, logo/text overlap and Dock alignment fixes**. User reports new failures: consecutive quick swipes cannot advance continuously, artwork/content seam looks too hard. IMG_8032/8033 are qualitative screenshots, not a 120Hz trace. No broad smoothness acceptance is inferred.

Source diagnosis: interrupted committed release retains old current/from until completion, so repeated swipes can keep targeting the same page. Build292 promotes the committed target only for same-direction takeover with presentation-relative negative origin and retained outgoing resident page, preserving foreground offsets. A qualifying fresh swipe may then commit the next neighbor; a reverse takeover retains the existing path. Runtime owns the commit intent; native renderer owns no second progress value. When the incoming anchor remains before center, takeover resumes its bounded three-page span instead of queuing invisible pages. Thresholds/times remain0.28/500pt/s and0.22/0.18/0.62s;6s auto unchanged.

Native clear artwork now fades across full foreground Hero height rather than clipping at shorter backdrop height; broadened mask fades into the same sampled solid color. No new blur or frame layout on ordinary progress. HomeCore/Dock geometry is byte-identical to device-positive Build291. Shared images/Poster, detail/navigation and Frozen/P0 remain untouched; iOS15.0.

Reserved **OnePlayer0.15.25 / Build292 / home-carousel-rapid-fade**; product branch perf/home-carousel-progress-scope-build286 / Draft PR#289; exact product **23ed1864f63d4701509df98b72d15e67038f801a**; predecessor Build291 **dbeaa9d3472c85a5c238598da3aac41d8e49f43c**. Product changes exactly AppIdentity, NativePresentation, RuntimeState and changelog. CI control branch **ci/build292-home-carousel-rapid-fade-20261005**, head **8dc55421a62325a6611f54f337ffc9c56d4f9208**; detached exact-source guard and native tests compare previous Build291 with candidate. First control run failed before compilation because its changelog pathname used the old version suffix; corrected in CI only, product unchanged.

Evidence: **Code written / static scope reviewed / native simulator tests+Release CI+IPA pending / device validation pending / no120FPS or stable claim**. Next: run actual consecutive-swipe negative control and full candidate suite, build/package/MinOS audit, independently inspect exact-source ZIP and IPA, hand off HTTPS artifact for real-device continuous quick switching, cancellation/reversal, gradual fade and retained title/Dock/vertical behavior.

### Build292 verified handoff — 2026-10-06 (Asia/Shanghai)

- **OnePlayer 0.15.25 / Build292**, exact product **23ed1864f63d4701509df98b72d15e67038f801a**; branch perf/home-carousel-progress-scope-build286 / Draft PR#289 open/unmerged. Product head and PR identity rechecked before final docs/handoff.
- Dedicated CI **37341422303 / 111869158278 — success**, control head **8dc55421a62325a6611f54f337ffc9c56d4f9208**. Detached exact product checkout above; CI control head is not packaged source.
- Actual-source native simulator suite **8 tests / 0 failures**. Build291 negative control gives **2 tests / 10 expected assertions**, reproducing both same-page retention under consecutive swipes (both directions) and shorter/harder artwork mask extent. Previous geometry, resource/vertical updates, release interruption, reverse/cancel/stale completion and accepted Dock regression remain green. New candidate verifies consecutive committed takeover without a foreground position jump, rebased reversal, full Hero mask. Simulator results do not prove target-device 120FPS.
- Artifact **OnePlayer-0.15.25-build292-home-carousel-rapid-fade**, ID **11359555710**, 22568055 bytes, digest **sha256:3748e9021d3c63d86426a1679cab04fc58194006b3bebad54bda50c1b0e7ddff**.
- IPA **OnePlayer-0.15.25-build292-home-carousel-rapid-fade-unsigned.ipa**, **18606692 bytes**, SHA256 **881705509a433e75751fe4b8101d8a70ce3a5c398e95309d1bb6b0fb0b908d9c**. Source ZIP SHA256 **18528c4d850e25dd35d4250033832d70cf39910ee4407defd101b0359c84d62f**; archive comment equals exact product SHA; AppIdentity/NativePresentation/RuntimeState/HomeCore bytes independently match inspected candidate. All archive integrity and CI checksum files pass.
- Bundle **com.embyplayerlab.app**, version/build **0.15.25 / 292**, Info.plist MinOS **15.0**, executable LC_BUILD_VERSION **15.0**; CI embedded/runtime MinOS audit OK; CADisableMinimumFrameDurationOnPhone=true.
- Evidence: **Code written / native regressions passed / exact-source Release CI passed / IPA produced+independently verified / Build292 target-device pending / no final120FPS or stable claim**. Build291 reverse/title/Dock corrections have user-confirmed device-positive feedback; Build289/290 remain rejected.
- **Next exact action:** receive Build292 device results for repeated fast same-direction swipes, immediate reversal, held drag/reversal, release/cancel takeover, artwork/content gradient, image-logo/title, Dock, vertical scroll/stretch/refresh and detail push/pop. Actual sustained presented120FPS remains a separate device goal. Do not rebuild or retune without new source/device evidence.

## Build292 device result / Build293 reservation — 2026-10-06

User confirms long frames repaired and stable120FPS on target device. New continuous rapid-swipe flicker is rejected; user additionally says bottom artwork/content colors still mismatch. RPReplay_Final1791219024.mp4 is4.93s/30fps/510x1108/148frames, qualitative flicker evidence; numerical120FPS is user report, not derived from recording. Source interruption reads foreground geometry but reconstructs artwork alpha from nonlinear progress, drops prior still-contributing images on rebase, and recomputes base color. Build293 captures presentation image weights and base color before interruption, retains outgoing contributions across rebasing/real input, fades all old artworks at new tail, and clears handoff at settle. No new product progress owner. For seam, image average currently samples central80%, not lower edge; contrast/artwork still tint Hero end. Use lower-edge sample, end both overlays before content boundary so last Hero strip and content share exactly the same solid base.

Reserve OnePlayer0.15.26/Build293/home-carousel-handoff exclusively; no duplicate checkpoint/Build index/branch/latest CI identity. Existing branch/PR#289 head23ed1864, maina1834c10 match. Poster/Aether/Search isolation unchanged. Runtime/input/HomeCore/fade geometry/performance path remain byte-identical to user-positive292 except targeted native alpha/base handoff and explicit seam coloring. iOS15/Frozen/P0 protected.

Next exact action: publish candidate, actual-layer opacity/color takeover negative control against292 plus repeated handoffs and prior suite; exact-source Release/IPA/MinOS audit, independently verify and provide copyableHTTPS artifact. Code draft local, CI/IPA pending; flicker/seam device pending; preserve user-reported292120FPS outcome. Private recording stays outside GitHub.
