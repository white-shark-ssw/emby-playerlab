from pathlib import Path
import re

# Carousel checkpoint
p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
s = p.read_text()
s = re.sub(r'\*\*Active — Build215 / 0\.14\.48.*?\*\*', '**Active — Build215 / 0.14.48 is now real-device tested with a materially positive partial result: acquisition-relative render motion makes the initial drag as fine as EX and opaque foreground removes the prior ghosted look. The remaining perceived lack of finesse is not supported as a foreground-X stutter by the 30 fps recording; the strongest new visual mismatch is backdrop crossfade timing. Build215 remains not stable while that remaining feel is unresolved.**', s, count=1, flags=re.S)
s = s.replace('- evidence: **Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending / not stable.**', '- evidence: **Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / initial-motion + foreground-alpha direction accepted / overall finesse still unresolved / not stable.**')
marker = '\n## Next exact action\n'
if marker not in s:
    raise SystemExit('DEV next-action marker missing')
analysis = '''
## 2026-08-27 Build215 vs EX second recording analysis

User target-device feedback for Build215:

> “这把起滑很细了，跟ex差不多了，前景也没有虚糊感了”

The same feedback still reports that the later drag does not feel as fine/delicate as EX. A new Build215 screen recording (`510 × 1108 @ 30 fps`) was compared against the previously supplied EX recording, which is also `510 × 1108 @ 30 fps`. Both video streams have fixed ~33.333 ms frame timestamps, so this comparison is not explained by capture-frame pacing differences.

### Foreground spatial motion

Frame-by-frame feature tracking of the outgoing foreground title shows Build215 no longer has the old ~6-recording-pixel first render jump. The first post-acquisition rendered steps in the sampled slow drag are approximately **1.9 / 1.5 / 1.6 / 1.2 / 0.7 px**, then continue through small subpixel/1–2 px increments. No independent stop-one-frame / catch-up-next-frame foreground-X pattern comparable to the old defect is visible in this recording.

In a comparable mid-drag sample, foreground-only trajectory residual around a smooth local trend is not worse than EX. Paired touch-indicator/foreground tracking does show slightly looser low-frequency coupling in OnePlayer (roughly subpixel to ~1 px wander), but the high-frequency frame-to-frame residual is not materially worse than EX. At 30 fps this is insufficient evidence to rewrite the acquisition-relative input/render ownership again; a 120 Hz micro-cadence difference may not survive the screen-recording downsample.

### Stronger remaining difference: backdrop blend timing

The recording exposes a much clearer source-backed mismatch in the **background/backdrop crossfade**. Build215 deliberately made foreground X linear and foreground alpha opaque, but `carouselBackdropBlendProgress` still uses the inherited early-suppression mapping:

`p × (1 - 0.85 × (1-p)^6)`

Estimating backdrop alpha from a background-only image region and pairing it with foreground spatial progress gives approximately:

| Foreground spatial progress | Build215 backdrop blend | EX backdrop blend |
|---:|---:|---:|
| 2% | ~0.7% | ~5.3% |
| 5% | ~2.2% | ~12.0% |
| 10% | ~7.0% | ~20.0% |
| 15% | ~12.7% | ~28.6% |
| 20% | ~20.3% | ~36.4% |
| 25% | ~27.5% | ~43.3% |
| 28% | ~33.2% | ~47.6% |

The Build215 measured sequence follows the current source curve extremely closely. The EX sequence is instead very close to a simple quadratic ease-out:

`1 - (1-p)^2`

A best-fit exponent over the measured 3–28% range is about **2.04**, so quadratic ease-out is a good first-order description of EX's backdrop timing.

Interpretation: Build215 foreground now moves immediately and linearly, but the backdrop initially remains visually dominated by the old item, then catches up later. EX changes the backdrop much earlier while the foreground page is moving. This temporal mismatch is a stronger explanation for the remaining “not quite as fine” overall feel than another foreground travel/easing change.

### Current evidence-backed conclusion

Retain from Build215 unless new direct device evidence contradicts it:

- acquisition-relative render baseline;
- post-acquisition linear foreground X;
- opaque transition foreground pages;
- full-width page slots;
- existing release/commit ownership and thresholds.

Do **not** add another foreground easing/travel percentage or change the UIKit owner based on this recording. The next minimal A/B candidate should change only the backdrop blend mapping toward the EX-like early-response curve, with the foreground/input contracts untouched.
'''
head, tail = s.split(marker, 1)
# avoid duplicate section if rerun
if '## 2026-08-27 Build215 vs EX second recording analysis' not in head:
    head = head.rstrip() + '\n\n' + analysis.strip() + '\n'
next_action = '''## Next exact action

Build one minimal carousel A/B candidate that changes **only** `carouselBackdropBlendProgress` from the old early-suppression curve toward the EX-like quadratic ease-out `1 - (1-p)^2`. Keep acquisition-relative foreground X, opaque foreground pages, full-width page slots, UIKit ownership, 0.28 commit, 0.48×width predicted release, reversal/cancel/settle and first↔last wrapping unchanged. Do not add interpolation/timers or another state owner. The target-device test should compare overall drag feel and backdrop timing against Build215 and EX before any further change.
'''
p.write_text(head + '\n' + next_action)

# Module status
p = Path('docs/project/MODULE_STATUS.md')
lines = p.read_text().splitlines()
replacement = '| Home carousel interaction | **Active — Build215 real-device tested; start/foreground fixes retained; backdrop timing is next lead** | Build215 / 0.14.48 target-device result is materially positive: user reports the initial drag is now very fine and approximately EX-level, and foreground no longer looks ghosted/blurred. New 510×1108@30fps A/B shows no clear independent foreground-X stop/catch-up jitter; the strongest remaining mismatch is backdrop timing. Build215 still uses early-suppressed `p × (1 - 0.85 × (1-p)^6)`, while measured EX backdrop progression closely matches `1 - (1-p)^2` (best-fit exponent ~2.04). Retain acquisition-relative linear foreground motion, opaque foreground, pageStep=width and original release contracts. Overall feel is not yet accepted/stable; next candidate should change only backdrop blend. |'
for i, line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i] = replacement
        break
else:
    raise SystemExit('MODULE_STATUS carousel row missing')
p.write_text('\n'.join(lines) + '\n')

# Project state
p = Path('docs/project/PROJECT_STATE.md')
s = p.read_text()
old = '- evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / not stable**.'
if old in s:
    s = s.replace(old, '- evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device tested / initial-motion + foreground-alpha result accepted / overall carousel finesse still unresolved / not stable**.', 1)
needle = 'Next action: target-device A/B Build215 against Build208/EX; do not add another easing/travel-percentage workaround before that evidence.'
replacement_state = '''Latest Build215 target-device/video result: the user reports the initial motion is now very fine and approximately matches EX, while foreground ghost/blur is gone. Frame tracking does not show a renewed coarse foreground-X jump or a clear stop/catch-up pattern during the sampled later drag. The stronger residual mismatch is backdrop timing: Build215's inherited early-suppression crossfade stays far behind foreground progress early, while measured EX backdrop blend is close to `1 - (1-p)^2` (best-fit exponent ~2.04 over the measured 3–28% range). This makes the old backdrop remain visually dominant while the foreground is already moving linearly, then forces the background transition to catch up later.

Next action: retain Build215 acquisition-relative foreground/input contracts and build a minimal backdrop-only A/B using an EX-like early-response blend. Do not change gesture ownership, foreground travel/easing, page slots or release thresholds before that device test.'''
if needle not in s:
    raise SystemExit('PROJECT_STATE Build215 next action missing')
s = s.replace(needle, replacement_state, 1)
p.write_text(s)

# Technical decision D012
p = Path('docs/project/TECHNICAL_DECISIONS.md')
s = p.read_text()
s = s.replace('Evidence is **Code written / CI passed / IPA produced+verified / real-device pending / not stable**.', 'Build215 is now **real-device tested**. The acquisition-relative start and opaque-foreground changes are directly supported by the user: initial drag is now very fine / approximately EX-level and the foreground no longer looks ghosted. Overall carousel finesse is still not accepted/stable.', 1)
s = s.replace('Do not call Build215 solved until target-device A/B confirms first-step size, linear feel, foreground solidity, reversal, release and wrapping behavior.', '''The second Build215-vs-EX recording does not show a clear renewed foreground-X stop/catch-up defect. Instead it isolates backdrop timing as the stronger remaining visual mismatch: Build215 retains early-suppressed `p × (1 - 0.85 × (1-p)^6)`, while measured EX backdrop progression closely follows `1 - (1-p)^2` (best-fit exponent ~2.04). Therefore retain acquisition-relative linear foreground motion and opaque foreground as the current contract; the next minimal A/B may change only backdrop blend timing. Do not reopen travel/easing or UIKit ownership without new direct evidence.''', 1)
p.write_text(s)

# Build/Test index milestone row
p = Path('docs/project/BUILD_TEST_INDEX.md')
s = p.read_text()
old_row = '| **Build215 / 0.14.48** | Acquisition-relative Home-carousel render + foreground-alpha decoupling | **Current carousel candidate.** Full-width page slots + single UIKit owner retained; render starts at horizontal acquisition and tracks `translation - acquisitionTranslation`, while 0.28/0.48 release stays touch-down based. Foreground stays opaque; backdrop blend is independent. CI/IPA verified; real-device pending. Carousel Build214 was retired due identity collision. |'
new_row = '| **Build215 / 0.14.48** | Acquisition-relative Home-carousel render + foreground-alpha decoupling | **Real-device tested; materially positive but not final.** User reports initial drag is now very fine / approximately EX-level and foreground ghost/blur is gone. New 30fps A/B shows no clear renewed foreground-X stop/catch-up defect; strongest remaining mismatch is backdrop timing: Build215 early-suppresses blend while EX measures close to quadratic ease-out `1-(1-p)^2`. Retain input/foreground/page-slot contracts; overall finesse still unresolved. |'
if old_row not in s:
    raise SystemExit('BUILD_TEST_INDEX Build215 row missing')
s = s.replace(old_row, new_row, 1)
p.write_text(s)
