from pathlib import Path


def replace_once(path, old, new, label):
    p = Path(path)
    s = p.read_text()
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, got {count}')
    p.write_text(s.replace(old, new, 1))


def insert_before(path, marker, text, label):
    p = Path(path)
    s = p.read_text()
    if s.count(marker) != 1:
        raise SystemExit(f'{label}: marker count {s.count(marker)}')
    p.write_text(s.replace(marker, text + marker, 1))

# DEV checkpoint
p = 'docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'
replace_once(p,
'''**Active — Build217 / 0.14.50 is real-device diagnostic tested. Build215's acquisition-relative start and opaque foreground remain positively confirmed, but Build217 now supplies a stronger explanation for the remaining “smooth glass vs rough paper” gap: the target device supports 120 Hz and the built IPA unlocks >60 Hz, yet the carousel's delivered touch → progress publication → SwiftUI render-update chain runs at roughly 60 Hz during ordinary motion, while coalesced raw touch samples exist at roughly 4–5 ms cadence. Backdrop timing is no longer the primary lead.**''',
'''**Active — Build219 / 0.14.52 is real-device diagnostic tested. The explicit drag-local 120 Hz frame-rate request materially raised the complete delivered-touch → progress-publication → SwiftUI-render → display chain from roughly 50–60 Hz to roughly 98–110 Hz, proving the frame-rate request is effective and directly relevant to the residual tactile smoothness gap. Build215 motion semantics remain retained and unchanged. The remaining major evidence is now episodic 34–50 ms display gaps, frequently aligned within ~3–25 ms of Hero/persistent 1400px image callbacks.**''',
'DEV status')
replace_once(p,
'''Build217 evidence: **Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device diagnostic tested ✅ / cadence bottleneck strongly indicated / not stable.**

## Next exact action

Do not retune travel/easing/backdrop. The next minimal experiment should isolate whether the system can actually raise this interaction from ~60 Hz to 120 Hz without changing carousel math: request a 120 Hz `preferredFrameRateRange` only for the existing drag-local diagnostic display link, keep the exact Build215 render/owner contracts unchanged, and measure whether `CADisplayLink` cadence and delivered `UITouch` cadence move from ~16.67 ms toward ~8.33 ms. If only the display link rises while delivered touches remain ~60 Hz, the remaining problem is event-delivery/render-input architecture; if delivered touches also rise, the frame-rate request itself becomes a directly evidenced minimal fix candidate. Do not use coalesced/predicted touches to drive movement until this narrower A/B resolves whether a simple refresh-rate request is sufficient.''',
'''Build217 evidence: **Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device diagnostic tested ✅ / ~60 Hz baseline established / not stable.**

## Build219 / 0.14.52 120 Hz request target-device result

Build219 preserves Build215/217 motion, ownership, page-slot, foreground-alpha, release and backdrop contracts. Its only runtime experiment beyond identity is the existing drag-local diagnostic `CADisplayLink` requesting the device maximum frame-rate range when `maximumFramesPerSecond > 60`; coalesced and predicted touches still do not drive interactive movement.

- tested source: `0b894bc37fcd0086aeaf9e1a29de0e85f5b0ee94`;
- durable cleanup head: `a5050075ccceaf46196696bfa3b812293800f340`;
- run/job: `33080240879 / 98545151906` — success;
- artifact ID `9649815558`; artifact SHA-256 `f4303434b3ed1215f122093a02ddc774492c4406b6916876b2e777858a69ca49`;
- IPA SHA-256 `a0b7bad3c563f76e3e560f55da6eec67697a8bf609b70b5a672ee1a0ed1ab85`; source ZIP SHA-256 `85815c74acf37840375e245d15752a40184bf72f3aa76aebbb2091e8b5ec2ec1`;
- independently verified OnePlayer `0.14.52 (219)`, bundle `com.embyplayerlab.app`, MinOS 15.0 and `CADisableMinimumFrameDurationOnPhone=true`.

Target-device log `OnePlayer-App-1787841410.log` contains 11 horizontal drags totaling ~10.76 s. Every record reports `maximum_fps=120 requested_fps=120`.

Compared with Build217's 13-drag diagnostic capture:

- delivered touch throughput rose from ~53.0 Hz to ~102.6 Hz;
- distinct progress publication rose from ~50.7 Hz to ~99.4 Hz;
- SwiftUI render-probe throughput rose from ~50.5 Hz to ~98.2 Hz;
- display-link throughput rose from ~57.2 Hz to ~109.8 Hz;
- coalesced-touch throughput remained broadly similar (~179 → ~187 Hz), as expected because Build219 does not change raw touch sampling;
- Build217 had 1603/1603 display intervals >=12.5 ms; Build219 has 41/1181 (~3.5%), and ordinary moving-drag p95 is now usually 8.34 ms.

The user also supplied a 510×1108@30fps recording with an on-screen FPS meter. It visibly reaches 118–120 FPS repeatedly during drag, while also showing intermittent drops into roughly 60–97 FPS. This independently agrees with the diagnostic log: the high-refresh request works, but runtime cadence is not perfectly stable under all presentation load.

Remaining episodic hitch evidence is now stronger: Build219 still recorded 13 display gaps >=30 ms. Among the 15 recorded worst-gap samples >=25 ms, 11 occurred within 30 ms of the latest Hero/persistent image callback. Multiple drags show a 50 ms gap ~19–25 ms after a persistent 1400px callback; Hero callbacks also precede some ~27–39 ms gaps by ~11 ms. A few large gaps have stale image ages, so image publication is not a universal explanation, but it is now the strongest source-correlated lead for the remaining discrete knocks after the baseline cadence improved.

**Build219 evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device diagnostic tested ✅ / 120 Hz request effectiveness proven ✅ / residual image-presentation hitch lead strengthened / stable ❌.**

## Next exact action

Retain the drag-local maximum-refresh request as an evidence-backed candidate behavior and do not move to coalesced/predicted render authority. Inspect the exact Hero/persistent 1400px image callback → image publication → SwiftUI/presentation path and identify the minimal source-owned work that can explain the repeatable 34–50 ms gaps. Do not defer, suppress or re-order image updates until the real definitions/call sites/state ownership are inspected. Do not retune travel/easing/backdrop or add smoothing/timers.''',
'DEV Build219 result')

# MODULE_STATUS
p = 'docs/project/MODULE_STATUS.md'
replace_once(p,
'''| Home carousel interaction | **Active — Build217 real-device cadence diagnostic tested; ~60 Hz delivered/render cadence is now the primary lead** | Build215 remains the retained behavior baseline: acquisition-relative X and opaque foreground fixed the coarse start/ghosting, but overall tactile smoothness still trails EX. Build217 / 0.14.50 target-device App log captured 13 horizontal drags. `maximum_fps=120`, built IPA has `CADisableMinimumFrameDurationOnPhone=true`, and no repository code requests a 60 Hz cap; however normal delivered touch callbacks average ~17.3 ms, progress publication ~17.8 ms and SwiftUI render-probe updates ~17.8 ms. Across 1603 observed display-link intervals, every interval was >=12.5 ms and moving-path p95 was typically 16.67 ms, while coalesced touch samples arrived at ~4–5 ms cadence. 1421 progress changes produced 1415 render changes, so SwiftUI is not dropping most published updates; the stronger bottleneck is upstream delivery/publication cadence. Occasional 33–45 ms gaps still correlate with some Hero/persistent 1400px image callbacks, but these are secondary episodic hitches rather than a complete explanation for the constant “rough paper” feel. Keep single UIKit owner, `pageStep = width`, acquisition-relative X, opaque foreground and original 0.28/0.48 release contracts. Do not retune easing/backdrop yet. Build217 is real-device diagnostic tested, not stable. Read `DEV-home-carousel-drag-smoothness`. |''',
'''| Home carousel interaction | **Active — Build219 real-device diagnostic tested; 120 Hz request works, residual image-presentation gaps remain** | Build215 motion contracts remain retained: acquisition-relative X, opaque foreground, full-width `pageStep = width`, single UIKit owner and original 0.28/0.48 release semantics. Build219 / 0.14.52 keeps those behaviors and only requests the target device maximum frame-rate range on the existing drag-local diagnostic display link. Target-device evidence shows the delivered touch / progress / SwiftUI render / display chain rose from Build217's ~50–60 Hz to roughly ~98–110 Hz, while ordinary display p95 moved from 16.67 ms to 8.34 ms; the on-screen FPS meter repeatedly reaches 118–120 FPS. Build219 still records episodic 34–50 ms display gaps, frequently within ~3–25 ms of Hero/persistent 1400px image callbacks, so image publication/presentation is now the strongest residual hitch lead. Coalesced/predicted touches still do not drive render motion. Build219 is real-device diagnostic tested, not stable. Read `DEV-home-carousel-drag-smoothness`. |''',
'MODULE carousel row')
replace_once(p,
'''| Other product modules | Active parallel work | Build216 / 0.14.49 remains the latest accepted overall runtime baseline. Home-carousel Build217 / 0.14.50 is a separate real-device diagnostic-tested line; poster-scroll Build220 / 0.14.53 is the independent CI/IPA-verified grid A/B line; target-device grid testing is pending. Build220 does not modify Home carousel owner files. `EmbySharedImageAndNavigation.swift` remains shared infrastructure, so whichever Active task integrates second must resync against then-current `main` and rerun affected validation. |''',
'''| Other product modules | Active parallel work | Build216 / 0.14.49 remains the latest accepted overall runtime baseline. Home-carousel Build219 / 0.14.52 is the separate real-device diagnostic-tested high-refresh line; poster-scroll Build220 / 0.14.53 is the independent CI/IPA-verified grid A/B line with target-device grid testing pending. Build220 does not modify Home carousel owner files. `EmbySharedImageAndNavigation.swift` remains shared infrastructure, so whichever Active task integrates second must resync against then-current `main` and rerun affected validation. |''',
'MODULE parallel row')

# BUILD_TEST_INDEX
p = 'docs/project/BUILD_TEST_INDEX.md'
build216 = '''| **Build216 / 0.14.49** | Detail episode-range inertia interruption | **Target-device accepted; stable and merged.** Range-pill taps synchronously stop active native episode-row deceleration at the current offset before the accepted Build191 range-first selection and existing 0.32 s target scroll. Tested source `dc00cac9f35ee4a3b950e4bb030bb324baf90b18`; run/job `33064051545 / 98489652724`; artifact `9643031850`; IPA SHA-256 `e3054a53398e1df48134fecd8c30671e10ecaa8a93df5483936adcf10e055075`; MinOS 15.0 verified. User accepted on iPhone 15 Pro Max / iOS 17.0 on 2026-08-27; PR #261 merged at `f5ad126b7b47e9713b1949780a6507fb3f0ca50f`. Build182/Build191/Build195/Build178 and P0 playback/transport remain untouched. |\n'''
rows = '''| **Build217 / 0.14.50** | Home-carousel cadence diagnostics | **Target-device diagnostic tested; ~60 Hz baseline established, not stable.** 13 drags showed `maximum_fps=120` but delivered touch / progress / SwiftUI render / display ran near ~50–60 Hz while coalesced samples were much denser. 1421 publishes yielded 1415 render changes, rejecting major SwiftUI publication loss as the primary bottleneck. Run/job `33069670314 / 98508381540`; artifact `9645320748`; IPA SHA-256 `a2cf700b791cc66a60416b0250d501758aec532371dd029272066eaac4722bef`. |\n| **Build219 / 0.14.52** | Home-carousel maximum-refresh A/B | **Target-device diagnostic tested; 120 Hz request effectiveness proven, residual image-presentation gaps remain.** Keeps Build215/217 motion semantics and only requests exact device-max frame rate on the drag-local diagnostic display link. Delivered touch ~53→103 Hz, progress ~51→99 Hz, SwiftUI render ~50→98 Hz, display ~57→110 Hz; ordinary display p95 is usually 8.34 ms and the on-screen FPS meter repeatedly reaches 118–120. Still records episodic 34–50 ms gaps, many within ~3–25 ms of Hero/persistent 1400px callbacks. Tested source `0b894bc37fcd0086aeaf9e1a29de0e85f5b0ee94`; cleanup `a5050075ccceaf46196696bfa3b812293800f340`; run/job `33080240879 / 98545151906`; artifact `9649815558`; IPA SHA-256 `a0b7bad3c563f76e3e560f55da6eec67697a8bf609b70b5a672ee1a0ed1ab85e`; MinOS 15.0. Not stable. |\n'''
insert_before(p, build216 + '| **Build218', build216 + rows, 'BUILD_TEST insert 217/219')

# PROJECT_STATE
p = 'docs/project/PROJECT_STATE.md'
replace_once(p,
'''### Current carousel candidate: Build215 / 0.14.48''',
'''### Retained carousel behavior baseline: Build215 / 0.14.48''',
'PROJECT heading')
replace_once(p,
'''Next action: inspect the post-acquisition touch→state→SwiftUI render/compositing cadence for evidence of sub-frame irregularity. Do not retune travel/easing or change backdrop timing solely from the current subjective residual gap; backdrop timing remains an unproven hypothesis.''',
'''Build217 then measured the unchanged Build215 interaction at roughly 50–60 Hz delivered/publish/render/display cadence despite `maximum_fps=120`; Build219 isolated the frame-rate request and raised the same chain to roughly 98–110 Hz on the target device. The user's on-screen FPS recording repeatedly reaches 118–120 FPS, proving the request is effective. Remaining discrete 34–50 ms gaps frequently occur within ~3–25 ms of Hero/persistent 1400px image callbacks, so the active carousel investigation now shifts to that image publication/presentation path rather than new motion easing or coalesced-touch authority.

Current carousel diagnostic candidate: **Build219 / 0.14.52** — tested source `0b894bc37fcd0086aeaf9e1a29de0e85f5b0ee94`, cleanup head `a5050075ccceaf46196696bfa3b812293800f340`, run/job `33080240879 / 98545151906`, artifact `9649815558`, IPA SHA-256 `a0b7bad3c563f76e3e560f55da6eec67697a8bf609b70b5a672ee1a0ed1ab85e`, MinOS 15.0. Evidence: **CI/IPA verified + real-device diagnostic tested / 120 Hz request effective / residual root cause not yet fixed / not stable**.

Next action: inspect the real Hero/persistent 1400px image callback → publish → presentation chain and correlate/measure the work producing the repeatable long display gaps. Retain the high-refresh request as an evidence-backed candidate and do not yet move interactive motion to coalesced/predicted touches.''',
'PROJECT next')
replace_once(p,
'''Build216 is the accepted overall runtime baseline after the detail episode-range inertia closeout. Home-carousel Build215 and poster-scroll remain independent Active lines with separate branches/evidence.''',
'''Build216 is the accepted overall runtime baseline after the detail episode-range inertia closeout. Home-carousel Build219 and poster-scroll Build220 remain independent Active lines with separate branches/evidence.''',
'PROJECT parallel')

# TECHNICAL_DECISIONS D012
p = 'docs/project/TECHNICAL_DECISIONS.md'
replace_once(p,
'''Retain acquisition-relative X, opaque foreground, page slots and the original release semantics. Do not add another easing/smoothing layer or change the backdrop curve without stronger evidence; investigate the touch→state→SwiftUI render/compositing cadence first.''',
'''Retain acquisition-relative X, opaque foreground, page slots and the original release semantics. Build217/219 now establish that refresh cadence is a first-class part of this interaction contract: Build217's passive diagnostic path ran around 50–60 Hz despite a 120 Hz-capable target device, while Build219's drag-local device-max `preferredFrameRateRange` request raised delivered touch / publication / SwiftUI render / display cadence to roughly 98–110 Hz without changing motion math. Therefore do not revert the evidence-backed high-refresh direction or replace it with another easing/smoothing layer. Coalesced/predicted touches are still not interactive render authority. The remaining source-correlated lead is episodic Hero/persistent 1400px image publication/presentation causing 34–50 ms display gaps; inspect that path before changing image timing or ownership.''',
'TECH D012')

print('Build219 real-device project-doc patch: PASS')
