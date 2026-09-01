from pathlib import Path
import re

checkpoint = '''# DEV-home-carousel-drag-smoothness

- **Status:** Active — the previous manual separate-mode / cross-launch system-FPS-HUD A/B is rejected as a component-attribution method. On Build282 the user observed TREE scope modes sustaining 120 FPS in one run, then roughly 90 FPS after force-quit/relaunch under the same package. Build284 replaces that protocol with one in-process REF↔TREE crossover that holds process/session, Home tree, image pair and one device-max `CADisplayLink` constant.
- **Work ID:** `DEV-home-carousel-drag-smoothness`
- **Routing aliases / keywords:** 首页轮播 / 轮播图 / 轮播流畅度 / carousel / rapid swipe / 120fps / crossover
- **Task:** Preserve the Build241 product interaction/presentation behavior while determining whether final-present FPS changes reproducibly with real carousel-tree invalidation load.
- **Base branch:** `main`
- **Current working branch:** `diag/home-carousel-crossover-build284`
- **Current exact product source / branch head:** `942e7b77a0c344dd7b797b9e7a6978c212bf9b03`
- **Current Draft PR:** #288 — diagnostic-only, unmerged
- **Current candidate:** OnePlayer `0.15.17 (284)`
- **Exact-source CI run / job:** `33554542393 / 100012028969` — success
- **Artifact:** `OnePlayer-0.15.17-build284-home-crossover-probe`, ID `9818916696`, digest `sha256:5db87a31508a4b61615403fc8d7dc4aa48ae4d4f9d90b6b4ef6e2ec0c9e55358`
- **IPA SHA-256:** `61c2f566739ff5c95b5ee2de394125ac93ffd99f5c2e8557416e29c1e485a3e0`
- **Source ZIP SHA-256:** `4c4f812e361c99705b1eeaef1e11621ff685b0a2e86f8e8cf7569d0fabc78038`
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment Target / built MinOS:** iOS 15.0

## Controlling product baseline

Build241 remains the product interaction/presentation behavior to preserve: one UIKit interaction owner, acquisition-relative movement, full-width page slots, current/previous/next clear-Hero residency, page-level foreground `compositingGroup()`, max-refresh through settle, persistent white-flash correction, ordinary progress commit `>=0.28`, direction-aware fling commit `>=500 pt/s`, commit `.easeOut(duration: 0.22)` and cancel `.easeOut(duration: 0.18)`.

Build284 is diagnostic only. It does not change HomeCore, Hero implementation, gesture ownership, transition-state ownership, Player/MPV/PiP/Transport/Cache/Emby Session or STRM→302→115/CDN.

## Why the Build282 manual protocol is rejected

Latest target-device evidence is internally inconsistent across app lifetimes. In the same installed Build282 package, TREE scope checks could both sustain 120 FPS in one run, while after force-quit/relaunch the same checks were around 90 FPS. Therefore a result such as `TREE HERO=120` versus `TREE BACKDROP=90` from separate manual runs cannot be treated as causal evidence for a component.

Earlier Build282 evidence remains valid only for narrower claims: `TREE FULL` and `TREE PANLOAD` can both decay, so Pan load alone is not causal; `DISPLAYLINK` and `SWIFTUI` can sustain 120 in a run, so generic device-max display-link/SwiftUI capability exists. It no longer supports cross-launch component attribution.

## Build284 / 0.15.17 — in-process REF↔TREE crossover

Exact Build282→Build284 product diff is two files only:

1. `Sources/Core/AppIdentity.swift` — diagnostic identity.
2. `Sources/UI/EmbyHomeFramePipelineProbeV3.swift` — crossover probe.

The existing `TREE FULL` probe slot is relabeled `CROSSOVER`. One device-max `CADisplayLink` stays alive continuously. The same Home presentation and fixed current/neighbor pair remain mounted. A native CALayer marker moves on every display tick in both phases. The probe alternates automatically every 15 seconds:

- `CROSSOVER REF 1/3`: real carousel progress is frozen at 0.5; reference CALayer continues moving.
- `CROSSOVER TREE 1/3`: the same display link additionally drives real `transitionProgress`.
- then REF/TREE rounds 2 and 3; the six-phase sequence loops.

Phase boundaries log `HomeCarouselCrossover` with round, callback cadence, Low Power Mode and thermal state. Internal display-link cadence remains diagnostic only; the target-device system FPS HUD with screen recording off is the final-present observation.

## Acceptance / falsification rule

Run one uninterrupted crossover cycle without force-quitting, mode switching or finger interaction. Record the sustained HUD value for each label:

`REF1 / TREE1 / REF2 / TREE2 / REF3 / TREE3`

Only a repeatable within-process relationship is actionable. Example: all three TREE phases fall while all three REF phases recover materially. If HUD does not track REF↔TREE repeatedly — for example all phases remain ~90, all remain 120, or changes occur independently of phase — then this HUD/probe method is not reliable enough for component attribution. The next step must change measurement strategy rather than add another carousel visual/gesture patch.

## Rejected / do not repeat without new evidence

- manual separate-mode / cross-launch HUD comparison for component causality;
- blur30 removal as the primary limiter;
- foreground-residency/compositing-count reduction as the primary limiter;
- generic UIKit↔SwiftUI rewrite;
- speculative ProMotion opt-in;
- recognizer replacement or callback-density maximization by itself;
- latest-real-input frame latch as a sufficient fix;
- Pan-load-only attribution;
- interpolation, prediction or synthetic intermediate positions;
- timer/watchdog/retry/fallback smoothing;
- a second transition/progress owner.

## Validation state

- Build284 code written: ✅
- Exact Build282→Build284 two-file scope verified: ✅
- Exact-source CI passed: ✅
- IPA produced + independently verified: ✅
- Bundle/version/build/MinOS verified: ✅ `com.embyplayerlab.app / 0.15.17 (284) / iOS 15.0`
- Target-device crossover: pending ❌
- Stable/frozen reopened performance task: ❌

## Next exact action

Install Build284, keep screen recording off, enter Home, switch `PIPE` until `PIPE CROSSOVER`, then leave the screen untouched for one complete six-phase cycle (~90 seconds). Report the six HUD observations and attach the App log. Do not force-quit/relaunch during the first cycle.
'''
Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md').write_text(checkpoint)

module_path = Path('docs/project/MODULE_STATUS.md')
module = module_path.read_text()
new_row = '| Home carousel interaction / presentation cadence | **Active — Build284 in-process REF↔TREE crossover; target-device pending** | Latest Build282 real-device evidence rejects manual separate-mode/cross-launch HUD component attribution: TREE scope checks could hold 120 in one run and be ~90 after force-quit/relaunch. Build284 / 0.15.17 exact source `942e7b77a0c344dd7b797b9e7a6978c212bf9b03`, run/job `33554542393 / 100012028969`, artifact `9818916696`, IPA SHA `61c2f566739ff5c95b5ee2de394125ac93ffd99f5c2e8557416e29c1e485a3e0`, MinOS 15.0. It alternates REF and real TREE load every 15 s inside one process while holding one device-max DisplayLink and the same Home tree/image pair. Target-device crossover is pending; no product-owner/smoothing contract accepted. |'
module, count = re.subn(r'^\| Home carousel interaction / presentation cadence \|.*$', new_row, module, count=1, flags=re.M)
if count != 1:
    raise SystemExit('Home carousel MODULE_STATUS row not found exactly once')
module_path.write_text(module)

state_path = Path('docs/project/PROJECT_STATE.md')
state = state_path.read_text()
state, count = re.subn(r'^_Last updated .*?_$', '_Last updated 2026-09-02: Home Build282 manual TREE scope HUD comparison is no longer accepted for component attribution because the same installed package produced 120-FPS scope results in one app run and ~90 FPS after force-quit/relaunch. Build284 / 0.15.17 now tests a same-process REF↔TREE crossover with one continuous device-max DisplayLink; exact-source CI/IPA are verified and target-device crossover is pending. Poster Build283 remains a separate active line; Build216 remains the accepted packaged overall baseline; Search Build256 and all P0 playback/transport contracts remain protected._', state, count=1, flags=re.M)
if count != 1:
    raise SystemExit('PROJECT_STATE Last updated line not found exactly once')
start = state.find('## Active: Home carousel input/publication diagnosis — Build282 / 0.15.15')
if start == -1:
    start = state.find('## Active: Home carousel presented-performance diagnosis — Build284 / 0.15.17')
end = state.find('## Completed / frozen: Home carousel interaction — Build241 / 0.14.74')
if start == -1 or end == -1 or end <= start:
    raise SystemExit('PROJECT_STATE Home active section boundaries not found')
home_section = '''## Active: Home carousel presented-performance diagnosis — Build284 / 0.15.17

Latest target-device evidence invalidates the prior manual separate-mode/cross-launch HUD attribution protocol. On the same installed Build282 package, TREE scope checks could both sustain 120 FPS in one run, then after force-quit/relaunch the same checks were around 90 FPS. This session-level variance means a single manual `TREE HERO` / `TREE BACKDROP` observation cannot identify a causal component.

Build284 changes the question rather than adding another visual optimization. Exact product source `942e7b77a0c344dd7b797b9e7a6978c212bf9b03` is one commit ahead of Build282 exact source `58801ef0acc6084c3168e8d7635a1258925cc382` and changes only AppIdentity plus `EmbyHomeFramePipelineProbeV3.swift`. HomeCore, Hero, carousel interaction/state ownership and all playback/transport modules remain unchanged.

Its `CROSSOVER` mode keeps one Home tree, one fixed current/neighbor pair and one device-max `CADisplayLink` alive continuously. A native CALayer reference marker moves in every phase. Real carousel progress is frozen during 15-second REF phases and driven by the same link during 15-second TREE phases, alternating REF/TREE three times before looping. The target-device result is actionable only if final-present HUD changes repeatedly follow those within-process phase changes. If they do not, stop using this HUD/probe family for component attribution instead of adding another carousel patch.

Exact-source Xcode 16.4 run/job `33554542393 / 100012028969` passed. Artifact `OnePlayer-0.15.17-build284-home-crossover-probe`, ID `9818916696`, digest `sha256:5db87a31508a4b61615403fc8d7dc4aa48ae4d4f9d90b6b4ef6e2ec0c9e55358`; independent re-download verifies IPA SHA `61c2f566739ff5c95b5ee2de394125ac93ffd99f5c2e8557416e29c1e485a3e0`, source ZIP SHA `4c4f812e361c99705b1eeaef1e11621ff685b0a2e86f8e8cf7569d0fabc78038`, `com.embyplayerlab.app / 0.15.17 (284)`, and MinOS 15.0. Draft PR #288 remains unmerged.

Evidence: **Code written ✅ / exact scope verified ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device crossover pending ❌ / stable ❌**.

'''
state_path.write_text(state[:start] + home_section + state[end:])

decision_path = Path('docs/project/TECHNICAL_DECISIONS.md')
decisions = decision_path.read_text()
if '## D028 — Cross-launch carousel HUD mode comparisons are not causal evidence' not in decisions:
    decisions += '''\n\n## D028 — Cross-launch carousel HUD mode comparisons are not causal evidence\n\nBuild282 target-device testing showed that the same installed TREE scope probes could both sustain 120 FPS in one app run and present around 90 FPS after force-quit/relaunch. Therefore separate manual mode runs, especially across app lifetimes, are rejected as a component-attribution protocol. A single `TREE HERO=120` or `TREE BACKDROP=90` observation cannot authorize a Hero/backdrop product change.\n\nBuild284 replaces that protocol with a same-process crossover: one continuously alive device-max `CADisplayLink`, same Home tree, same fixed carousel pair, and an always-moving native reference marker. Fifteen-second REF phases freeze real carousel progress while TREE phases let the same link additionally drive the existing real transition owner; REF/TREE repeats three times. Only a repeatable phase-correlated final-present HUD change is actionable. If the HUD does not repeatedly follow the phase, stop this probe family and change measurement strategy rather than adding another visual, gesture, interpolation, timer, fallback or duplicate owner.\n'''
decision_path.write_text(decisions)

index_path = Path('docs/project/BUILD_TEST_INDEX.md')
index = index_path.read_text()
row = '| **Build284 / 0.15.17** | Home in-process REF↔TREE crossover | **Code/CI/IPA verified; target-device pending.** Build282 manual scope-HUD attribution is rejected after same-package runs changed from 120 to ~90 across force-quit/relaunch. Exact source `942e7b77a0c344dd7b797b9e7a6978c212bf9b03` changes only AppIdentity + frame-pipeline probe from Build282. One continuous device-max DisplayLink alternates 15 s REF and real TREE load for three within-process pairs. Run/job `33554542393 / 100012028969`; artifact `9818916696`; IPA SHA `61c2f566739ff5c95b5ee2de394125ac93ffd99f5c2e8557416e29c1e485a3e0`; MinOS 15.0. Stable ❌. |'
if 'Build284 / 0.15.17' not in index:
    lines = index.splitlines()
    inserted = False
    for i, line in enumerate(lines):
        if line.startswith('| **Build282 / 0.15.15**'):
            lines.insert(i + 1, row)
            inserted = True
            break
    if not inserted:
        table_end = next((i for i, line in enumerate(lines) if i > 3 and not line.startswith('|')), len(lines))
        lines.insert(table_end, row)
    index = '\n'.join(lines) + ('\n' if index.endswith('\n') else '')
index_path.write_text(index)
