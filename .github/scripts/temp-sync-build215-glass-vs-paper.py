from pathlib import Path
import re

# DEV checkpoint
p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
s = p.read_text()
s = re.sub(r'\*\*Active — Build215 / 0\.14\.48.*?\*\*', '**Active — Build215 / 0.14.48 is real-device tested. The acquisition-relative start and opaque foreground are both positively confirmed: the user reports the initial drag is now about as fine as EX and the foreground no longer looks blurred/ghosted. However the overall drag still lacks EX\'s tactile smoothness — described as EX feeling like sliding on smooth glass while OnePlayer still feels like rough paper. The residual cause is unresolved; backdrop-blend timing is only a hypothesis, not a proven root cause.**', s, count=1, flags=re.S)
marker = '## Next exact action'
if marker not in s:
    raise SystemExit('DEV next-action marker missing')
head = s.split(marker, 1)[0].rstrip()
section = '''

## 2026-08-27 Build215 second real-device result

Latest target-device feedback after testing the acquisition-relative candidate:

- **initial drag is now very fine and feels close to EX**;
- **foreground no longer has the previous blurred / ghosted feel**;
- despite those two fixes, the overall drag still does **not** have EX's refined tactile smoothness;
- the user's best qualitative description is: **EX feels like sliding on smooth glass, while OnePlayer still feels like sliding on rough paper**.

The new 510×1108@30fps recording does not show the old large hold-then-jump foreground failure or a clear stop-one-frame / catch-up-next-frame macro hitch. Early foreground increments are now small and continuous. Therefore Build215 positively validates acquisition-relative render baseline and foreground-alpha decoupling, but it does **not** prove the complete carousel interaction solved.

30fps capture cannot fully resolve the 120Hz device's sub-frame / frame-to-frame tactile cadence. A measured difference in backdrop crossfade timing versus EX exists, but this is currently **only a candidate explanation** for the remaining glass-vs-paper feel. Do not change the backdrop curve merely to complete a patch, and do not add smoothing/interpolation/timers.

Retain from Build215 unless contrary device evidence appears:

- one UIKit interaction owner;
- acquisition-relative foreground X (`currentTranslation - acquisitionTranslation`);
- touch-down authority for 0.28 / 0.48 release semantics;
- foreground opacity held at 1 during interactive transition;
- full-width `pageStep = width` page slots;
- existing reversal/cancel/settle/wrap contracts.
'''
next_action = '''

## Next exact action

Treat the remaining issue as a micro-continuity/cadence investigation, not another travel/easing-tuning task. Inspect the exact post-acquisition pipeline from UIKit touch delivery → recognizer callback → `V3HomeCarouselTransitionState` publication → SwiftUI offset/compositing for evidence of irregular publication, transaction behavior, implicit animation, main-thread contention or rendering/coalescing that could produce a sub-frame "rough paper" feel. Use the Build215/EX recordings as reference, but do not claim the backdrop-blend hypothesis as root cause without stronger evidence. No code change is justified solely by the current subjective residual gap.
'''
p.write_text(head + section + next_action)

# MODULE_STATUS
p = Path('docs/project/MODULE_STATUS.md')
lines = p.read_text().splitlines()
replacement = '| Home carousel interaction | **Active — Build215 real-device tested; start/alpha fixed, residual micro-smoothness gap unresolved** | Build215 / 0.14.48 positively confirms the acquisition-relative baseline and foreground-alpha decoupling: target-device feedback says the initial drag is now about as fine as EX and the foreground no longer looks blurred/ghosted. The overall drag still lacks EX\'s tactile refinement, described as EX = smooth glass vs OnePlayer = rough paper. The 30fps comparison no longer shows the old macro hold/jump, so the residual issue is treated as a micro-continuity/cadence problem; backdrop-blend timing remains an unproven hypothesis. Keep single UIKit owner, `pageStep = width`, acquisition-relative X, opaque foreground and original 0.28/0.48 release contracts. Build215 is real-device tested but not accepted/stable. Read `DEV-home-carousel-drag-smoothness`. |'
for i, line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i] = replacement
        break
else:
    raise SystemExit('MODULE_STATUS carousel row missing')
p.write_text('\n'.join(lines) + '\n')

# BUILD_TEST_INDEX
p = Path('docs/project/BUILD_TEST_INDEX.md')
lines = p.read_text().splitlines()
for i, line in enumerate(lines):
    if line.startswith('| **Build215 / 0.14.48** |'):
        lines[i] = '| **Build215 / 0.14.48** | Acquisition-relative Home-carousel render + foreground-alpha decoupling | **Real-device tested; partial success, not accepted.** Initial drag is now about as fine as EX and foreground blur/ghosting is gone, confirming acquisition-relative render baseline + opaque foreground. Overall tactile smoothness still trails EX (user: EX feels like smooth glass, OnePlayer like rough paper). 30fps video no longer shows the old macro hold/jump; residual micro-continuity/cadence cause remains unresolved and backdrop timing is only a hypothesis. |'
        break
else:
    raise SystemExit('BUILD_TEST_INDEX Build215 row missing')
p.write_text('\n'.join(lines) + '\n')

# PROJECT_STATE: update candidate evidence block in place, preserve poster section.
p = Path('docs/project/PROJECT_STATE.md')
s = p.read_text()
old = '- evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / not stable**.'
if old in s:
    s = s.replace(old, '- real-device result: acquisition-relative start and opaque foreground are positively confirmed; initial drag is now about as fine as EX and foreground blur/ghosting is gone, but overall tactile smoothness still trails EX ("smooth glass" vs "rough paper"). 30fps recording no longer shows the old macro hold/jump; residual micro-continuity/cadence cause remains unresolved and backdrop timing is only a hypothesis.\n- evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device tested / partial success / not stable**.', 1)
else:
    raise SystemExit('PROJECT_STATE Build215 evidence marker missing')
s = s.replace('Next action: target-device A/B Build215 against Build208/EX; do not add another easing/travel-percentage workaround before that evidence.', 'Next action: inspect the post-acquisition touch→state→SwiftUI render/compositing cadence for evidence of sub-frame irregularity. Do not retune travel/easing or change backdrop timing solely from the current subjective residual gap; backdrop timing remains an unproven hypothesis.')
p.write_text(s)

# TECHNICAL_DECISIONS D012 evidence update.
p = Path('docs/project/TECHNICAL_DECISIONS.md')
s = p.read_text()
old = 'Evidence is **Code written / CI passed / IPA produced+verified / real-device pending / not stable**.\n\nDo not call Build215 solved until target-device A/B confirms first-step size, linear feel, foreground solidity, reversal, release and wrapping behavior.'
new = 'Build215 target-device testing positively confirms two parts of this contract: the acquisition-relative start is now about as fine as EX, and keeping interactive foreground pages opaque removes the previous blurred/ghosted feel. The overall tactile smoothness still trails EX, described by the user as smooth glass vs rough paper. The residual cause is not yet established; a backdrop-blend timing difference seen in 30fps analysis is only a hypothesis. Evidence is **Code written / CI passed / IPA produced+verified / real-device tested / partial success / not stable**.\n\nRetain acquisition-relative X, opaque foreground, page slots and the original release semantics. Do not add another easing/smoothing layer or change the backdrop curve without stronger evidence; investigate the touch→state→SwiftUI render/compositing cadence first.'
if old not in s:
    raise SystemExit('TECHNICAL_DECISIONS Build215 evidence text missing')
s = s.replace(old, new, 1)
p.write_text(s)
