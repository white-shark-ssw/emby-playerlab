from pathlib import Path
import re
import subprocess
import sys

MODE = sys.argv[1]
BRANCH = 'diag/home-carousel-release-intent-build238'

build237_result = '''### 2026-08-29 Build237 target-device result — white flash fixed; predicted-total-distance fling gate rejected as sufficient

User target-device feedback on iPhone 15 Pro Max / iOS 17.0: **the transition white flash is gone**, but the carousel still cannot be committed by the very short, almost-in-place fling that EX accepts easily. The user describes OnePlayer as still having a strong resistance/boundary and explicitly questions the distance-based method.

This splits Build237 cleanly:

- **Persistent source-over white-flash correction: accepted.** Keep outgoing persistent fully opaque while incoming fades over it. The user directly confirms the white flash is gone.
- **Predicted-total-distance gate 0.48×width → 0.24×width: rejected as sufficient.** Halving the distance merely moved the boundary; it did not reproduce EX-style fling intent. Current source still commits by `actualProgress >= 0.28` OR `max(actualDistance, predictedDistance) >= width * 0.24`, where `predictedDistance` is the predicted endpoint measured from touch-down origin. A short, fast fling can therefore still fail if its predicted total displacement does not cross the fixed width fraction.

The next release contract must not be chosen by guessing another width fraction. Preserve the ordinary 0.28 slow-drag progress rule for now, retain the accepted Build237 white-flash correction, and measure release intent from real terminal touch velocity plus predicted **extra** travel before selecting a velocity/fling gate.

Evidence: Build237 Code written ✅ / scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅ / white-flash fix accepted ✅ / 0.24 predicted-total-distance fling approach insufficient ❌ / stable ❌.'''

build238 = '''## Build238 / 0.14.71 — release-intent measurement only

Build238 is measurement-only on top of Build237. It does not change `shouldCommit`, slow-drag progress, predicted-total-distance behavior, Build236 start-step handling, Build231 foreground compositing, Build226 Hero residency, Build228 release-tail/max-refresh lifetime or Build237 persistent source-over white-flash correction.

The custom UIKit recognizer now logs one `HomeCarouselRelease` line at horizontal release with:

- `actual_x` and acquisition-relative `rendered_x`;
- latest `predicted_x` and the actual translation at the same prediction event (`prediction_base_x`);
- `predicted_extra_x = predicted_x - prediction_base_x`, which measures forecast extra travel rather than total displacement from touch-down;
- `last_move_delivered_velocity_x` from consecutive delivered move samples;
- `last_move_coalesced_velocity_x` from the latest two real coalesced samples in the move UIEvent;
- `end_velocity_x` from the final delivered end sample relative to the last move;
- `touch_duration_ms`.

No velocity threshold is applied in Build238. This avoids guessing a numeric fling gate before target-device data separates intended short flicks from short slow drags.

### CI / IPA evidence

- branch: `diag/home-carousel-release-intent-build238`;
- exact base: cleaned Build237 head `6d9243395f273dec224ba695e14d433405345c11`;
- exact tested source / CI head: `780283bc722e39564240d996ca3c522bc61c6066`;
- dedicated Xcode 16.4 run/job: `33204499623 / 98961981208` — success;
- artifact: `OnePlayer-0.14.71-build238-release-diagnostics`, ID `9699150399`;
- artifact SHA-256: `59baa8223ba6d652cde77cf7e6af286545b12ef6a762df110bc20d18f6524cf3`;
- IPA SHA-256: `3539fd2f8c83c56838242a69350c473bd0088a65c273a5a0c0b4f3676878efd4`;
- source ZIP SHA-256: `fefe660a5f578ed4fd3f2a55abbd73dc9fc4e41a1378467335d46989affefd01`;
- independent package reopen confirms bundle `com.embyplayerlab.app`, OnePlayer `0.14.71 (238)`, `MinimumOSVersion=15.0`;
- independent source reopen confirms Build237 white-flash correction and unchanged `0.28 / 0.24` release behavior are retained, with only release-intent measurements added.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / behavior intentionally unchanged / target-device diagnostic pending ❌ / stable ❌.'''

if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    text = p.read_text()
    text = re.sub(r'^\*\*Active — User explicitly accepts freezing most.*?\*\*$', '**Active — Build236 start-step handling + Build231 foreground compositing + Build226 Hero residency + Build228 max-refresh-through-settle/release-tail are frozen-for-current-phase. Build237 persistent source-over correction is now also target-device accepted because the reported white flash is gone. Build237 halving of the predicted-total-distance fling gate to 0.24×width is rejected as sufficient: EX accepts almost-in-place flicks while OnePlayer still feels distance-bound. Build238 / 0.14.71 is the current measurement-only candidate to log real release velocity and predicted extra travel before replacing the distance-based fling gate. Slow-drag commit remains 0.28. Whole carousel remains Active only for fling-intent release behavior; stable ❌.**', text, count=1, flags=re.M)
    text = text.replace('- Working branch: `perf/home-carousel-fling-whiteflash-build237`', '- Working branch: `diag/home-carousel-release-intent-build238`', 1)
    text = text.replace('- Current candidate: OnePlayer `0.14.70 (237)`', '- Current candidate: OnePlayer `0.14.71 (238)`', 1)
    text = text.replace('- predicted-distance release gate remains 0.48 × width;', '- ordinary slow-drag commit threshold remains 0.28; the legacy predicted-total-distance fling gate is no longer a frozen contract and Build237 proved that simply lowering its width fraction is insufficient;', 1)
    if '### 2026-08-29 Build237 target-device result — white flash fixed; predicted-total-distance fling gate rejected as sufficient' not in text:
        anchor = '\n## Build237 / 0.14.70 — shorter fling gate + persistent white-flash correction'
        if anchor not in text: raise SystemExit('Build237 section anchor missing')
        text = text.replace(anchor, '\n' + build237_result + '\n' + anchor, 1)
    if '## Build238 / 0.14.71 — release-intent measurement only' not in text:
        anchor = '\n## Rejected directions not to repeat'
        if anchor not in text: raise SystemExit('rejected anchor missing')
        text = text.replace(anchor, '\n' + build238 + '\n' + anchor, 1)
    next_action = '''## Next exact action\n\nTarget-device test OnePlayer 0.14.71 / Build238 and export the App log. Perform two clearly labeled gesture families on the same carousel: (A) about 12–15 **almost-in-place quick flicks** that should feel like EX-style commits, and (B) about 8–10 **short slow drags/releases** that should remain cancellations. Build238 intentionally keeps Build237 release behavior, so judge the gestures by intent rather than whether OnePlayer currently commits. Compare `last_move_delivered_velocity_x`, `last_move_coalesced_velocity_x`, `end_velocity_x` and `predicted_extra_x` between the two families. Only if the target-device distributions separate should Build239 replace the predicted-total-distance fling gate with a velocity/fling-intent gate. Do not guess another width fraction and do not reopen the frozen-for-current-phase Build236/231/226/228 foundation or the accepted Build237 white-flash correction without regression evidence.\n'''
    if '## Next exact action' not in text: raise SystemExit('next action missing')
    text = text[:text.index('## Next exact action')] + next_action
    p.write_text(text)
    raise SystemExit(0)

if MODE != 'main': raise SystemExit(f'unknown mode {MODE}')

checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
checkpoint.write_text(subprocess.check_output(['git','show',f'origin/{BRANCH}:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True))

module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
row = '| Home carousel interaction | **Active — Build236/231/226/228 foundation frozen-for-current-phase; Build237 white-flash fix accepted; Build238 release-intent diagnostics CI/IPA verified** | Target device confirms Build237 removes the transition white flash, so retain its persistent source-over crossfade correction. The 0.24×width predicted-total-distance fling gate remains too resistant versus EX and is rejected as sufficient; do not keep lowering distance fractions blindly. Build238 / 0.14.71 changes no release behavior and logs real terminal delivered/coalesced velocity plus predicted extra travel to derive a fling-intent gate from evidence. Slow-drag commit remains 0.28. Build238 tested source `780283bc722e39564240d996ca3c522bc61c6066`; run/job `33204499623 / 98961981208`; artifact `9699150399`; IPA SHA-256 `3539fd2f8c83c56838242a69350c473bd0088a65c273a5a0c0b4f3676878efd4`; MinOS 15.0. Target-device release diagnostic pending; not stable. |'
for i,line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i] = row
        break
else: raise SystemExit('carousel module row missing')
for i,line in enumerate(lines):
    if line.startswith('| Other product modules |'):
        lines[i] = '| Other product modules | Active parallel work | Build216 / 0.14.49 remains the accepted overall runtime baseline. Home-carousel Build238 is an isolated release-intent diagnostic candidate on top of the frozen-for-current-phase Build236/231/226/228 foundation plus accepted Build237 white-flash correction. Poster and Aether remain separate Active tasks with independent checkpoints/branches; do not infer their candidates from this carousel row. |'
        break
module.write_text('\n'.join(lines)+'\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
lines = index.read_text().splitlines()
row238 = '| **Carousel Build238 / 0.14.71** | Release-intent measurement only | **CI/IPA verified; target-device diagnostic pending; behavior unchanged.** Logs actual/rendered release displacement, predicted endpoint and predicted extra travel, last-move delivered/coalesced velocity, terminal end velocity and touch duration. Retains Build237 white-flash correction and unchanged 0.28/0.24 release behavior. Tested source `780283bc722e39564240d996ca3c522bc61c6066`; run/job `33204499623 / 98961981208`; artifact `9699150399`; artifact SHA-256 `59baa8223ba6d652cde77cf7e6af286545b12ef6a762df110bc20d18f6524cf3`; IPA SHA-256 `3539fd2f8c83c56838242a69350c473bd0088a65c273a5a0c0b4f3676878efd4`; source ZIP SHA-256 `fefe660a5f578ed4fd3f2a55abbd73dc9fc4e41a1378467335d46989affefd01`; MinOS 15.0. |'
found=False
for i,line in enumerate(lines):
    if line.startswith('| **Carousel Build238 / 0.14.71** |'):
        lines[i]=row238; found=True; break
if not found:
    insert=None
    for i,line in enumerate(lines):
        if line.startswith('| **Carousel Build237 / 0.14.70** |'): insert=i+1
    if insert is None: raise SystemExit('Build237 index row missing')
    lines.insert(insert,row238)
index.write_text('\n'.join(lines)+'\n')

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(r'^_Last updated.*?_$', '_Last updated after Build237 target-device testing accepted the persistent white-flash correction but rejected the lowered predicted-total-distance fling gate as sufficient, and Build238 / 0.14.71 reached CI/IPA verification as a measurement-only release-intent candidate. Build216 remains the accepted overall runtime baseline._', text, count=1, flags=re.M)
addition = '''\n### Carousel Build237 real-device split + Build238 release-intent diagnostics\n\nBuild237 target-device testing cleanly splits its two changes. The persistent source-over correction is accepted: the user confirms the transition white flash is gone. The lowered predicted-total-distance fling gate is not accepted as sufficient: even at 0.24×width, OnePlayer still feels strongly distance-bound while EX accepts an almost-in-place flick. Therefore stop tuning width fractions. Keep the ordinary 0.28 slow-drag threshold for now and treat fling as a separate release-intent problem.\n\nBuild238 / 0.14.71 is CI/IPA verified and intentionally leaves Build237 behavior unchanged. It logs real delivered/coalesced terminal velocity, end velocity, predicted endpoint, predicted extra travel and touch duration so the next target-device session can compare intended quick flicks against short slow drags. Only after those distributions are known should the predicted-total-distance gate be replaced. The Build236/231/226/228 foundation remains frozen-for-current-phase and the Build237 white-flash correction is retained.\n'''
anchor = '\n## Active: Poster-heavy scrolling smoothness'
if '### Carousel Build237 real-device split + Build238 release-intent diagnostics' not in text:
    if anchor not in text: raise SystemExit('state anchor missing')
    text = text.replace(anchor, addition + anchor, 1)
state.write_text(text)

tech = Path('docs/project/TECHNICAL_DECISIONS.md')
text = tech.read_text()
addition = '''\nBuild237 target-device evidence accepts the persistent source-over white-flash correction but rejects **predicted total displacement as the sole fling-intent model**. Halving the gate from 0.48×width to 0.24×width did not reproduce EX-style almost-in-place flick commits; it only moved the distance boundary. Preserve the 0.28 actual-progress slow-drag rule for now, and do not continue lowering width fractions without evidence. Build238 therefore measures release velocity and predicted **extra** travel while keeping behavior unchanged. A future fling gate may use real release velocity or another measured intent signal only after target-device quick-flick vs short-slow-drag distributions establish a defensible separation. Retain the frozen-for-current-phase Build236 start-step, Build231 foreground compositing, Build226 Hero residency, Build228 max-refresh-through-settle/release-tail behavior and the now-accepted Build237 persistent source-over correction.\n'''
marker='\n## D013 — Detail high-rate scroll and warm presentation stay scoped and presentation-only'
if 'Build237 target-device evidence accepts the persistent source-over white-flash correction but rejects **predicted total displacement as the sole fling-intent model**' not in text:
    if marker not in text: raise SystemExit('tech marker missing')
    text=text.replace(marker,'\n'+addition+marker,1)
tech.write_text(text)
