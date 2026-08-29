from pathlib import Path

# Current carousel checkpoint
p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
t = p.read_text()
lines = t.splitlines()
for i, line in enumerate(lines):
    if line.startswith('**Frozen-for-current-phase at Build239 / 0.14.72'):
        lines[i] = '**Active — Build239 / 0.14.72 remains the frozen foundation for all already accepted carousel contracts, but a new target-device tactile comparison reopens one narrow question: release-handoff velocity continuity. Keep the accepted 0.28 slow-drag commit, direction-aware latest-delivered velocity >=600 pt/s fling decision, Build237 white-flash correction, Build236 real-sample start handling, Build231 foreground compositing, Build226 Hero residency and Build228 max-refresh-through-settle / 0.22s commit + 0.18s cancel tail unchanged. Matched 30fps evidence still shows OnePlayer and EX have materially similar late ease-out tails; the open difference is the whole-flick handoff immediately after finger release, because Build239 uses release velocity only as a binary commit gate and then always runs the same fixed 0.22s ease-out. Do not retune the accepted tail or velocity threshold without direct evidence.**'
        break
else:
    raise SystemExit('checkpoint frozen status line missing')
t = '\n'.join(lines) + '\n'
marker = '## Rejected directions not to repeat\n'
section = '''### 2026-08-29 new target-device evidence — whole-flick release handoff feels less effortless than EX\n\nAfter the matched recording established that Build239 already has a materially similar **late** ease-out tail, the user gave a more specific tactile verdict: **EX still feels more effortless / natural over the whole single flick**. This does not invalidate the accepted 600 pt/s fling gate or the matched late-tail evidence. It narrows the remaining difference to the release handoff.\n\nExact Build239 source explains a credible mechanism. `finishNativeCarouselDrag` uses `latestMoveDeliveredVelocityX` only to decide `velocityCommit` (`directionalVelocity >= 600`). Once commit is chosen, velocity is discarded and `completeInteractiveTransition` always executes `withAnimation(.easeOut(duration: 0.22)) { transitionProgress = 1 }`, regardless of release speed or remaining distance. Therefore finger-tracking is real-touch 1:1 before release, but the first post-release derivative is owned by a fixed normalized animation rather than by the user's measured release momentum. A 700 pt/s and 2000 pt/s flick, or a flick released at 5% versus 25% progress, enter the same 0.22s settle law. This can create a subtle handoff/impedance change even when the last 3–4 settle frames look nearly identical to EX.\n\nTreat **velocity continuity across release** as the only reopened carousel question. Do not infer EX's private implementation (UIScrollView, spring constants, etc.) from the recording. Do not reopen Build237 white-flash, Build236 start-step, Build231 compositing, Build226 Hero residency, Build228 max-refresh-through-settle, the accepted 600 pt/s commit gate, or the matched 0.22s late tail without new regression evidence. Before any behavior patch, measure/compare release velocity against the first post-release progress/display deltas so a change is evidence-backed rather than a guessed spring/easing parameter.\n\n'''
if '### 2026-08-29 new target-device evidence — whole-flick release handoff feels less effortless than EX' not in t:
    if marker not in t: raise SystemExit('checkpoint insertion marker missing')
    t = t.replace(marker, section + marker, 1)
next_marker = '## Next exact action\n'
if next_marker not in t: raise SystemExit('checkpoint next action marker missing')
t = t.split(next_marker, 1)[0] + next_marker + '''\nKeep every Build239 accepted/frozen sub-contract unchanged. If this last tactile difference is pursued, measure the release-to-settle handoff only: correlate the already available `release_velocity_x` / `actual_progress` with the first 2–3 post-release `transitionProgress` and display-frame deltas. The purpose is to test derivative/momentum continuity, not to retune the late ease-out tail. Do not add a timer, interpolator, spring, arbitrary duration scaling, or another visual owner without measured evidence.\n'''
p.write_text(t)

# Module status
p = Path('docs/project/MODULE_STATUS.md')
t = p.read_text()
lines = t.splitlines()
for i, line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i] = '| Home carousel interaction | **Active — Build239 foundation frozen; release-handoff velocity continuity narrowly reopened** | Build239 / 0.14.72 target-device velocity-fling decision remains accepted, matched OnePlayer-vs-EX 30fps evidence still validates the existing late ease-out tail, and Build237/236/231/226/228 contracts remain frozen-for-current-phase. New user tactile evidence says EX still feels more effortless over the whole single flick. Exact Build239 source uses latest delivered velocity only as a binary >=600 pt/s commit gate, then discards velocity and always settles with the same 0.22s `.easeOut`, so only the finger-release → settle momentum handoff is reopened. Reopen no other carousel behavior without new evidence; Build216 remains the merged overall runtime baseline. |'
        break
else:
    raise SystemExit('module carousel row missing')
p.write_text('\n'.join(lines) + '\n')

# Project state
p = Path('docs/project/PROJECT_STATE.md')
t = p.read_text()
lines = t.splitlines()
for i, line in enumerate(lines):
    if line.startswith('_Last updated after a matched Build239-vs-EX 30fps comparison'):
        lines[i] = '_Last updated after new target-device tactile evidence narrowed the remaining Home-carousel difference to release-handoff momentum continuity: Build239 accepted contracts and matched late ease-out remain frozen, while only the finger-release → fixed-settle handoff is Active for possible measurement. Build216 remains the accepted merged overall runtime baseline._'
        break
else:
    raise SystemExit('project-state header line missing')
t = '\n'.join(lines) + '\n'
marker = '## Active: Poster-heavy scrolling smoothness\n'
section = '''### Home carousel — Build239 foundation retained; release-handoff continuity narrowly reopened\n\nThe matched OnePlayer-vs-EX 30fps comparison remains valid for the **late settle tail** and does not justify changing Build239's 0.22s commit / 0.18s cancel ease-out. The user subsequently clarified that EX still feels more effortless over the **whole single flick**. Build239 source provides a narrower explanation: release velocity is used only as a binary direction-aware >=600 pt/s commit decision, then discarded before a fixed 0.22s ease-out from whatever progress remains. Thus the visual tail may match while the release boundary still lacks momentum/derivative continuity.\n\nKeep the accepted Build239 velocity gate, Build237 white-flash fix, Build236 start-step real sample, Build231 foreground compositing, Build226 Hero residency and Build228 max-refresh-through-settle frozen. The task is Active only for an optional release-handoff measurement; no behavior patch is authorized yet.\n\n'''
if '### Home carousel — Build239 foundation retained; release-handoff continuity narrowly reopened' not in t:
    if marker not in t: raise SystemExit('project-state marker missing')
    t = t.replace(marker, section + marker, 1)
p.write_text(t)

# Technical decisions
p = Path('docs/project/TECHNICAL_DECISIONS.md')
t = p.read_text()
marker = '## D013 — Detail high-rate scroll and warm presentation stay scoped and presentation-only\n'
section = '''New target-device tactile evidence after the matched tail comparison narrows the residual EX gap to **release-handoff momentum continuity**, not the late ease-out shape. Build239's latest-delivered velocity >=600 pt/s remains the accepted binary fling-intent gate; exact source then discards that velocity and always executes the same 0.22s `.easeOut` to progress 1. Therefore the first post-release velocity can be discontinuous from the user's finger velocity even though late-frame decay matches EX. Reopen only this handoff question. Before changing behavior, measure release velocity / remaining progress against the first 2–3 post-release progress/display deltas. Do not infer EX implementation details or introduce guessed spring/easing/duration mapping.\n\n'''
if 'New target-device tactile evidence after the matched tail comparison narrows the residual EX gap' not in t:
    if marker not in t: raise SystemExit('technical decisions marker missing')
    t = t.replace(marker, section + marker, 1)
p.write_text(t)

# Build/test index
p = Path('docs/project/BUILD_TEST_INDEX.md')
t = p.read_text()
lines = t.splitlines()
for i, line in enumerate(lines):
    if line.startswith('| **Carousel Build239 / 0.14.72** |'):
        lines[i] = '| **Carousel Build239 / 0.14.72** | Direction-aware velocity fling + accepted presentation foundation | **Target-device release intent accepted; late settle matched to EX; whole-flick handoff continuity remains a narrow open question.** Keeps 0.28 slow-drag progress commit, removes rejected predicted-total-distance gate, commits direction-aware latest-delivered velocity at >=600 pt/s, and retains Build237 white-flash fix plus Build236/231/226/228 foundation. User first accepted the fling behavior (“没问题了”); matched 30fps tracking then showed materially similar late ease-out decay to EX. Later tactile comparison reports EX still feels more effortless over the whole single flick. Exact source uses release velocity only as a binary gate and then always runs a fixed 0.22s ease-out, so only release-handoff momentum continuity is reopened; do not retune accepted gate/tail without new evidence. Tested source `ed4e59c2a0e2fac3979d84dad756299659b15387`; run/job `33208503351 / 98975620229`; artifact `9700721145`; IPA SHA-256 `b11992aa6b4c87df87600ec38143798aece6df231507a6d13357856318f6196d`; MinOS 15.0. |'
        break
else:
    raise SystemExit('Build239 index row missing')
p.write_text('\n'.join(lines) + '\n')
