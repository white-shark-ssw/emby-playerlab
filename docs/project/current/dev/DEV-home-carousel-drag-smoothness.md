# DEV-home-carousel-drag-smoothness — session handoff

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

## Resumed diagnosis — 2026-10-05 latest recording

User explicitly continues this Work ID and authorizes evidence-backed restructuring. Supplied recording RPReplay_Final1791212395(1).mp4 is 9.17 s / 30 fps / 510×1108. User reports reverse movement during swipes, image-logo/text-title alternation, and Dock too high. Private video remains outside public GitHub.

Resume guard passed: PR #289 Draft/open/unmerged and product branch/head remain perf/home-carousel-progress-scope-build286 / 9e0bb371fe65c29524b92ac1892bab84b6684444. Other Active tasks use distinct branch/candidate identities; no Build291 has yet been allocated.

Concrete source violation: applyVisualState sets foreground transform then calls layoutVisiblePages, which sets that transformed foreground's frame to x=0. This cancels translation by changing its base center, aligns two foreground pages on top of each other, and leaves release animation starting from a displaced center. Apple UIView frame contract explicitly forbids changing frame while transform is nonidentity. Title-resource loss is not established: motion does not change logo resources. First correct overlap before adding logo fallbacks/caches.

Dock source: accepted Build286 persistent backdrop contributed geometry.height + bottomSafeArea to root layout, while Build290 root frame uses geometry.height only and keeps the same Dock bottom inset. The native rendering extent also includes topSafeArea. Restore the accepted layout extent and make native rendering an overlay of that extent so top overscan cannot affect Dock alignment.

Next exact action: fix foreground layout using bounds/center at geometry boundaries, remove page relayout from ordinary progress updates, preserve prepared logo resources; isolate native render extent from accepted Home layout extent. Run native geometry/animation-takeover regressions before final unique candidate allocation and CI/package verification. No new candidate yet; latest valid package remains rejected Build290.
