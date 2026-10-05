from pathlib import Path
import re

project_state = Path('docs/project/PROJECT_STATE.md')
module_status = Path('docs/project/MODULE_STATUS.md')
technical = Path('docs/project/TECHNICAL_DECISIONS.md')
build_index = Path('docs/project/BUILD_TEST_INDEX.md')
task = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')

text = project_state.read_text()
text, count = re.subn(r'_Last updated 2026-10-05:.*?_\n', '_Last updated 2026-10-05: Home carousel Build290 / 0.15.23 is now target-device rejected. The user reports the carousel problem has no improvement at all versus the prior candidate, while the bottom Dock changed from Build289 offscreen/downward displacement to an incorrect upward displacement. Therefore neither the Build289 native-presentation runtime nor the Build290 one-line Home-root frame correction is accepted/stable. Build216 remains the accepted packaged overall baseline; Poster/Aether remain separate active lines; Search Build256 and all P0 playback/transport contracts remain protected._\n', text, count=1, flags=re.S)
assert count == 1
start = text.index('## Active: Home carousel — Build289 rejected on device; Build290 Dock-layout correction packaged, target-device pending')
end = text.index('## Historical accepted interaction foundation: Home carousel — Build241 / 0.14.74', start)
replacement = '''## Active: Home carousel — Build289/Build290 target-device rejected; new diagnosis required\n\nThe latest 2026-10-05 iPhone 15 Pro Max / iOS 17.0 result now rejects **Build290 / 0.15.23** as well as Build289. The user's direct result is: the carousel problem shows **no improvement at all**, and the bottom Dock merely changed from Build289's downward/offscreen displacement to an incorrect upward displacement. A second uploaded recording analyzed in the same session is 9.17 seconds at 30 FPS; it corroborates the visible Dock position error and is qualitative visual evidence only, not a numerical 120 Hz measurement.\n\nBuild290 exact source remains **`9e0bb371fe65c29524b92ac1892bab84b6684444`** on Draft PR **#289** / `perf/home-carousel-progress-scope-build286`, identity **OnePlayer 0.15.23 / Build290**. Its CI/package evidence remains valid: Xcode 16.4 run/job `37325862505 / 111816942719`, artifact `11352810860`, IPA SHA-256 `734e2f40fd3d6c694c79feb060d675128927cd0ff2c9c541791be1b1a5a1cf2e`, source ZIP SHA-256 `1a3d3b50abaf3707193da427ed3512d223fb0005e7fe33ef891486916ddf7de4`, MinOS 15.0. Those facts establish only Code written / CI passed / IPA produced. Build290 is now also **real-device tested and rejected**.\n\nThe layout interpretation must be updated. Build289's oversized native surface coincided with the Dock being pushed below the viewport. Build290 added one root `.frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)` line while preserving the Build289 native carousel runtime; target-device evidence shows that this did not restore the accepted Dock geometry and instead moved the Dock too high. Therefore the Build290 root-frame line is **not an accepted correction**, and D032's pre-device wording about an "accepted correction" is superseded by the later Build290 rejection. Do not continue by guessing Dock padding/insets. Reconcile the root/safe-area/overlay ownership against the accepted pre-Build289 Home layout first.\n\nThe carousel conclusion is equally important: Build290 kept the Build289 native-presentation runtime unchanged except for AppIdentity and the one Home-root frame line, yet the user reports no carousel improvement. The current resident native hierarchy / direct transform / separate artwork blend / `UIViewPropertyAnimator` implementation has therefore **not demonstrated a target-device smoothness benefit**. This does not prove UIKit/native presentation can never help; it does prove the current implementation must not be promoted or tuned as though the architecture already solved the problem.\n\nNext development must resume from the written handoff in `docs/project/current/dev/DEV-home-carousel-drag-smoothness.md`, verify PR #289/head identity, compare Build290 Home root layout with the pre-native Build286/Build288 Home layout, and inspect/measure the actual high-frequency input→state→bridge→native-view transform path before changing code. No shared Poster image pipeline, Player/MPV/PiP, UnifiedTransport, playback Cache/Session, STRM/302/115/CDN or Seek contract is authorized to change from this result. Home remains Active and not Frozen.\n\n'''
project_state.write_text(text[:start] + replacement + text[end:])

lines = module_status.read_text().splitlines()
home = [i for i, line in enumerate(lines) if line.startswith('| Home carousel interaction / presentation cadence |')]
assert len(home) == 1
lines[home[0]] = '| Home carousel interaction / presentation cadence | **Active — Build289 + Build290 target-device rejected; handoff for new diagnosis** | Build289 / 0.15.22 native presentation introduced a bottom-Dock downward/offscreen regression. Build290 / 0.15.23 exact source `9e0bb371fe65c29524b92ac1892bab84b6684444` preserved the same native carousel runtime and added only AppIdentity plus one Home-root `.frame(...)` line; CI/package run/job `37325862505 / 111816942719`, artifact `11352810860`, IPA SHA `734e2f40fd3d6c694c79feb060d675128927cd0ff2c9c541791be1b1a5a1cf2e`, MinOS 15.0 remain valid. Latest target-device evidence rejects Build290: user reports no carousel improvement at all, while the Dock moved from down/offscreen to incorrectly upward. The Build290 root-frame line is not an accepted fix and the current native-presentation architecture has not demonstrated a device smoothness gain. Do not guess Dock padding or continue architecture tuning without fresh source/measurement evidence. Shared Poster/image and all Player/Transport/Cache/Session/P0 contracts remain untouched. |'
other = [i for i, line in enumerate(lines) if line.startswith('| Other product modules |')]
assert len(other) == 1
lines[other[0]] = '| Other product modules | Active parallel work | Build216 / 0.14.49 remains the accepted packaged overall runtime identity. Search Build256 is stable/merged. Home Build289 and Build290 are both target-device rejected; PR #289 remains Draft for the active Home task and requires a new diagnosis before another candidate. Detail immersive navigation remains completed/frozen from Build288 acceptance; Poster Build283 remains a separate target-device-positive active task; Aether remains separate. |'
module_status.write_text('\n'.join(lines) + '\n')

text = technical.read_text()
assert '## D033 — Build290 rejects both the root-frame correction and any claim that the current native carousel improved smoothness' not in text
text += '''\n\n## D033 — Build290 rejects both the root-frame correction and any claim that the current native carousel improved smoothness\n\nLater 2026-10-05 target-device evidence supersedes D032's pre-device "accepted correction" wording. Build290 / 0.15.23 kept the Build289 native carousel runtime unchanged and added only AppIdentity plus one Home-root `.frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)` line. The user reports that the carousel problem has **no improvement at all**, while the bottom Dock changed from Build289's downward/offscreen displacement to an incorrect upward displacement. Build290 is therefore real-device tested and rejected.\n\nTwo decisions follow. First, the root `.frame(...)` line is not an accepted Dock fix. Do not continue with guessed Dock padding, safe-area constants or compensating offsets. Re-establish the accepted pre-Build289 root/safe-area/overlay ownership from real source before any next layout patch. Second, the current bounded native-presentation implementation has not demonstrated a target-device smoothness benefit. Resident native pages, direct foreground transforms, separate artwork alpha, prepared lower-Home color, `UIViewPropertyAnimator` settle and presentation-layer takeover may remain useful implementation ingredients, but they are not evidence of a solved architecture and must not be treated as such.\n\nThe next investigation should measure the actual high-frequency path rather than add another presentation rewrite: UIKit gesture delivery → `V3HomeCarouselRuntimeState` / transition state → presentation bridge → `V3HomeCarouselNativeView.applyVisualState` / settle. In the current source, `applyVisualState` still calls `layoutVisiblePages()` and color/indicator work on progress updates, and resident foreground pages are `UIHostingController`-backed. These are concrete call-path facts to inspect/profile, not a proven root cause. Compare against the pre-native Build286/Build288 Home root layout and the retained Build241 interaction contracts before modifying code.\n\nEvidence for Build290 remains: Code written ✅ / exact-source CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / result rejected ❌ / stable-frozen ❌. The 9.17-second second recording is 30 FPS and is used only as qualitative visual evidence; do not derive a numerical 120 Hz cadence from it.\n'''
technical.write_text(text)

text = build_index.read_text()
old_gate = '- Required next gate: iPhone 15 Pro Max / iOS 17.0 real-device verification that the Dock is restored and that carousel slow/rapid/reversal/release/cancel/settle-takeover, visual continuity, tap-to-detail and Home vertical scrolling remain correct.\n- Evidence: **Code written ✅ / exact-scope guarded ✅ / CI passed ✅ / IPA produced+independently verified ✅ / Build289 real-device rejected ✅ / Build290 real-device tested ❌ / stable-frozen ❌**.'
new_gate = '- Later 2026-10-05 target-device result **rejects Build290**: user reports the carousel problem has no improvement at all, while the Dock changed from Build289 down/offscreen to incorrectly upward. A second 9.17-second / 30 FPS recording corroborates the visible Dock misplacement; it is qualitative evidence only and not a numerical 120 Hz trace.\n- Current meaning: Build290\'s one-line Home-root frame change is not an accepted Dock correction, and the otherwise unchanged Build289 native-presentation runtime has not demonstrated a target-device smoothness benefit. Another candidate requires a new source/measurement diagnosis rather than more guessed inset/padding tuning.\n- Evidence: **Code written ✅ / exact-scope guarded ✅ / CI passed ✅ / IPA produced+independently verified ✅ / Build289 real-device rejected ✅ / Build290 real-device tested ✅ / Build290 result rejected ❌ / stable-frozen ❌**.'
assert text.count(old_gate) == 1
build_index.write_text(text.replace(old_gate, new_gate, 1))

task.write_text(r'''# DEV-home-carousel-drag-smoothness — session handoff

- **Status:** Active — Build289 and Build290 are both target-device rejected; no current candidate is accepted or stable.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps / native presentation / Dock
- **Task:** Fix the Home carousel's target-device tactile smoothness/visual continuity without regressing Home layout, Dock, vertical interaction, navigation, or protected playback/transport contracts.
- **Read first:** `HOME_CAROUSEL_DEVELOPMENT_PLAN.md`, `HOME_CAROUSEL_REFACTOR_PLAN.md`, then this checkpoint. Current device evidence below supersedes older plan assumptions where they conflict.

## Latest authoritative real-device result — 2026-10-05

The latest user result is the highest-priority evidence:

> Build290 carousel behavior has no improvement at all; the only visible change is that the bottom Dock moved from Build289's downward/offscreen displacement to an incorrect upward displacement.

A second uploaded iPhone recording was analyzed in the handoff session: 9.17 seconds, 30 FPS, 510×1108 capture. It corroborates the Dock being visibly too high. Use the recording only for qualitative layout/visual evidence; never infer numerical 120 Hz cadence from a 30 FPS capture. The private recording itself was not copied into the public repository; this written result is the durable project evidence.

This result supersedes the prior "Build290 target-device pending" status. **Build290 is real-device tested and rejected.**

## Current exact identity

- Product branch: `perf/home-carousel-progress-scope-build286`
- Draft PR: **#289**, open/unmerged.
- Current PR/product head: **`9e0bb371fe65c29524b92ac1892bab84b6684444`**.
- Current rejected package: **OnePlayer 0.15.23 / Build290**.
- Build290 run/job: `37325862505 / 111816942719` — CI success.
- Artifact: `OnePlayer-0.15.23-build290-home-carousel-dock-fix`, ID `11352810860`, digest `sha256:70806c4d5fed5ef48b3e71dea887f5f0867c55b4a962bde0cb4ff9c4d357904f`.
- IPA SHA-256: `734e2f40fd3d6c694c79feb060d675128927cd0ff2c9c541791be1b1a5a1cf2e`.
- Source ZIP SHA-256: `1a3d3b50abaf3707193da427ed3512d223fb0005e7fe33ef891486916ddf7de4`.
- Bundle / MinOS: `com.embyplayerlab.app`, `0.15.23 (290)`, iOS 15.0.
- Target device: iPhone 15 Pro Max / iOS 17.0.
- Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / result rejected ❌ / stable-frozen ❌.

Do **not** allocate Build291 or a new version until the next session completes the normal Build/candidate collision check.

## Build289 → Build290 facts

Build289 exact source: `0f5a1893988e20e0dcfe21d0395abe194c2340e6`, OnePlayer 0.15.22 / Build289. It introduced the bounded Home-private native presentation runtime and was rejected on device after the bottom Dock moved below/offscreen.

Build290 preserved that entire carousel runtime. Relative to Build289 it changed exactly:

1. `Sources/Core/AppIdentity.swift`: 0.15.22 → 0.15.23.
2. `Sources/UI/EmbyHomeCoreV3.swift`: added one root `.frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)` line.

Build290 device evidence now shows that line did **not** restore the accepted Dock geometry; it moved the Dock too high. Therefore the line is not an accepted fix and D032's earlier pre-device correction wording is superseded by D033.

## What the two rejected builds establish

1. **The current native presentation rewrite has not demonstrated a smoothness win.** Build290 uses the same Build289 carousel runtime, and the latest device test reports no carousel improvement.
2. **The Home layout owner is still wrong.** Build289 let the oversized native surface affect the root layout and pushed the Dock down/offscreen. Build290 constrained the root `ZStack`, but the Dock then moved too high. Do not continue by guessing padding or another compensating offset.
3. **Do not rewrite the Dock component yet.** The Dock owner itself was unchanged when Build289 introduced the regression. First reconcile Home root geometry, safe areas, the native surface's render extent, and the `.overlay(alignment: .bottom)` basis against the accepted pre-native layout.
4. **Native/UIKit is not proven impossible.** The evidence rejects this implementation/result, not the entire framework. Do not claim a generic SwiftUI ceiling or a guaranteed native cure.
5. **No P0/Frozen playback or transport module is implicated.** Shared Poster image infrastructure, Player/MPV/PiP, UnifiedTransport, playback Cache/Session, STRM→302→115/CDN and Seek contracts remain out of scope.

## Exact source areas the next session must inspect before editing

### Home layout / Dock ownership

Current Build290 `Sources/UI/EmbyHomeCoreV3.swift`:

- `GeometryReader` computes `viewportHeight = geometry.size.height + safeArea.top`.
- Native `surfaceHeight = geometry.size.height + safeArea.top + safeArea.bottom`.
- `V3HomeCarouselNativeSurface` is framed to `surfaceHeight` and offset by `-safeArea.top`.
- Root `ZStack` is then constrained to `geometry.size.width × geometry.size.height`.
- Dock remains `.overlay(alignment: .bottom)` with `serverDockBottomInset` in immersive mode.

Accepted pre-native Build286 source `7e7b2ec944f5c0e74bc291e37683f1529e3d46b4` did **not** have the root `.frame(...)`; its backdrop used `geometry.size.height + safeArea.bottom` inside the same root `ZStack` and the same bottom Dock overlay. Compare these real definitions directly before any layout patch. Do not assume that preserving the Build289 native surface's safe-area extent is required if it conflicts with the accepted root/Dock layout contract.

### High-frequency carousel path

Inspect the real call path end-to-end before changing motion code:

- `Sources/UI/EmbyHomeCarouselInteractionV3.swift` — sole UIKit horizontal gesture/input owner.
- `Sources/UI/EmbyHomeCarouselStateV3.swift` — current runtime/transition state and settle token/generation ownership.
- `Sources/UI/EmbyHomeCarouselNativePresentationV3.swift` — presentation bridge, resident pages, `applyVisualState`, `animateVisualState`, `interruptAndReadProgress`, geometry/layout work.
- `Sources/UI/EmbyHomeHeroScrollStateV3.swift` — vertical Home/Hero scroll coupling.
- `Sources/UI/EmbyHomeHeroV3.swift` and `Sources/UI/EmbyHomeCoreV3.swift` — native surface integration and remaining Home shell behavior.

Concrete facts worth measuring, not assuming: resident foreground nodes are `UIHostingController<V3HomeCarouselForegroundStaticView>`; `applyVisualState` performs transforms/alpha and then calls `layoutVisiblePages()`, base-color update and indicator update on progress changes; `layoutVisiblePages()` recalculates artwork/foreground geometry for visible pages. These are inspection/profile leads only — not yet proven causes of the remaining roughness.

## Preserved interaction contracts

Do not regress the retained carousel contracts while investigating:

- one UIKit horizontal interaction owner;
- immediate input response, no debounce accumulation;
- ordinary distance commit `>= 0.28`;
- direction-aware fling commit `>= 500 pt/s`;
- commit/cancel timing 0.22 / 0.18 s;
- auto interval / auto settle 6 s / 0.62 s;
- immediate new-gesture takeover during settle must remain a requirement;
- vertical Home scroll/stretch/crop/refresh behavior;
- tap-to-detail and system navigation ownership;
- iOS 15.0 deployment priority.

## Rejected / do not repeat without new contrary evidence

- Build286 progress-publication-scope narrowing as the final solution.
- Repeating blur-only removal, foreground reduction, generic callback-density/input-cadence changes, display-link frame latching or TREE-only conclusions as if they solved the problem.
- Prediction/interpolation/synthetic finger positions, timer/watchdog/retry/fallback smoothing, hard step caps, duplicate current/progress owners.
- More Dock `padding`, safe-area constants or arbitrary offsets merely to counter the latest visual displacement.
- Treating CI/IPA success as runtime acceptance.
- Treating the current native hierarchy / `UIViewPropertyAnimator` as already validated simply because the code is native.
- Uploading private device recordings to the public repo as part of debugging evidence.

## Next exact action for the new session

1. Read `AGENTS.md`, `docs/automation/CHATGPT_NOTIFY_RULES.md`, `docs/project/START_HERE.md`, `CURRENT_WORK.md`, `CURRENT_WORK_DEV.md`, `MODULE_STATUS.md`, this checkpoint, and the two Home carousel plan/reference docs.
2. Resume identity guard: confirm PR #289 is still Draft/open, branch is `perf/home-carousel-progress-scope-build286`, and head is `9e0bb371fe65c29524b92ac1892bab84b6684444`. If any identity moved, stop and reconcile docs before coding.
3. Compare the exact Build290 Home root/safe-area/native-surface/Dock layout against Build286/Build288 pre-native Home layout. Establish the actual layout owner that preserves accepted Dock position without a compensating offset. Do not patch until that ownership is clear from source.
4. Separately trace/profile the high-frequency horizontal path from UIKit touch delivery through runtime state/bridge to native transforms/layout. Determine whether the current native presentation is actually avoiding high-frequency layout/SwiftUI work or merely moving it behind `UIHostingController`/`layoutVisiblePages()`.
5. Only after one concrete causal issue is established should the next session make the smallest source change. No broad second rewrite.
6. After any important code/CI/device decision, update this checkpoint plus `PROJECT_STATE.md`, `MODULE_STATUS.md`, `TECHNICAL_DECISIONS.md`, and `BUILD_TEST_INDEX.md` in the same cycle.
7. If a new candidate becomes justified, perform fresh Build/version collision checks and continue through CI/IPA to a target-device package before handing it back.

## Handoff state

There is deliberately **no new patch** in this handoff turn. The newest evidence says the current candidate is rejected and the next safe move is diagnosis, not another guessed fix. PR #289 remains the active unmerged Home task container; Build290 remains useful only as a rejected test point and exact source baseline.
''')
