from pathlib import Path
import re
import subprocess
import sys

MODE = sys.argv[1]
BRANCH = 'diag/home-carousel-acquisition-coalesced-diagnostics-build234'

status = '**Active — Build233 / 0.14.66 target-device testing shows the acquisition-local predecessor direction is partially effective but not sufficient: in 67 drags, 42 acquisition-local same-event renders reduce coarse starts substantially, while 25 fallback starts still retain the old next-delivered-move behavior and are much coarser. Overall 28/67 first visible steps are ≥5pt and 32/67 are ≥2.5pt; the user still perceives roughly half or more starts as large. The same session reports movie-title text seems less jittery; Build231 `compositingGroup()` remains retained as materially beneficial, while the log cadence is cleaner than Build232 but not perfectly uniform. Build234 / 0.14.67 preserves Build233 behavior exactly and adds acquisition-event coalesced count / predecessor status / predecessor delta / predecessor age diagnostics so the remaining fallback and large accepted steps can be explained before another behavior change. Build226 Hero residency + Build228 max-refresh-through-settle remain retained. Build216 remains the accepted overall runtime baseline.**'

build233_result = '''### 2026-08-28 Build233 target-device result — acquisition-local path helps, but fallback remains coarse

User feedback on iPhone 15 Pro Max / iOS 17.0: **the large first-step symptom still occurs at roughly half-or-more subjective frequency, while movie-title text seems less jittery in this build.** The uploaded Build233 App log `OnePlayer-App-1787932695.log` contains 67 `HomeCarouselCadence` drags and gives a more precise split:

- overall `|first_render_x| >= 2.5pt`: **32/67 (47.8%)**;
- overall `|first_render_x| >= 5pt`: **28/67 (41.8%)**;
- overall `|first_render_x| >= 8pt`: **15/67 (22.4%)**;
- 42/67 drags used the Build233 acquisition-local same-event path (`acquire_to_first_render_ms≈0`): median first step **2.0pt**, `>=5pt` **12/42 (28.6%)**, `>=8pt` **2/42**;
- 25/67 drags fell back to the prior next-delivered-move path: median first step **8.33pt**, `>=5pt` **16/25 (64%)**, `>=8pt` **13/25**.

Controlling conclusion: Build233 proves that using a real acquisition-local predecessor can materially reduce first-step coarseness **when that path is available**, but it does not solve the start-step problem because roughly 37% of recorded starts still fall back and some accepted predecessor deltas are themselves large. Build233 is therefore not accepted as the final acquisition contract.

The current Build233 logger cannot tell whether fallback happened because no predecessor existed, because a predecessor had zero delta, or because the same-direction guard rejected it. It also does not record predecessor age/delta for accepted cases. Therefore changing/removing the guard, choosing a different coalesced sample, or imposing an artificial step cap would be speculative. Measure those facts first.

Title/cadence evidence remains separate. The user reports the text looks less jittery. This session has 42/67 drags with display p95 ≈8.34ms and 18/67 at ≈16.67ms, a cleaner distribution than the prior Build232 session. This supports the observed improvement but does not timestamp-match a particular visible title event, so do not claim complete title stability or a one-to-one cadence cause. Retain Build231 foreground `compositingGroup()` as beneficial, not fully sufficient.

Evidence: Build233 Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅ / acquisition-local path partially positive ✅ / overall start-step fix insufficient ❌ / title subjectively improved but not frozen / stable ❌.'''

build234 = '''## Build234 / 0.14.67 — acquisition coalesced-decision diagnostics

Build234 is measurement-only on top of Build233. It does **not** change which coalesced predecessor Build233 accepts, when the acquisition event publishes, the fallback path, post-acquisition delivered-touch ownership, Hero/persistent presentation, foreground compositing, release timing/thresholds, or refresh-rate lifetime.

The existing acquisition helper now reports to `HomeCarouselCadence`:

- `acq_coalesced_count`: number of real coalesced samples available on the acquisition UIEvent;
- `acq_predecessor_status`: `accepted`, `none`, `zero`, or `direction`;
- `acq_predecessor_delta_x`: current delivered acquisition X minus the immediately preceding real coalesced sample X when one exists;
- `acq_predecessor_age_ms`: predecessor timestamp age relative to the current delivered acquisition touch.

These fields directly answer why Build233 produced 25/67 fallback starts and why a subset of the 42 accepted same-event starts still had a >=5pt first step. No timer, interpolation, step cap, easing, debounce/throttle, retry/watchdog, predicted-touch render authority, or second state owner is added.

CI / package evidence:

- branch: `diag/home-carousel-acquisition-coalesced-diagnostics-build234`;
- exact base: cleaned Build233 branch head `4f2dd8832c66e10d8d48e95fcf757d40f9efb80c`;
- exact tested source: `528168da7c6b6df26bf1a907439becdb5cc4c980`;
- cleanup head after temporary build/apply CI removal: `f07a46b52e96cd1d363293c046d9d614047c7e47`;
- dedicated Xcode 16.4 run/job: `33189068688 / 98909569541` — success;
- artifact: `OnePlayer-0.14.67-build234-acquisition-diagnostics`, ID `9693038983`;
- artifact SHA-256: `d819f7a7ccd02bbc73f8201861c6b4a77b4627832d50e16de3f1e42f524786e8`;
- IPA SHA-256: `ddd8b884dd5095a3eb72e47b8a2726ac9bf32e9dc7000aafe9aeef596296a59c`;
- source ZIP SHA-256: `4c2ca8e92eae8449f6aa9e52228b78418c79924e35a5821c978a4046a71d58fb`;
- independent package reopen confirms OnePlayer `0.14.67 (234)`, bundle `com.embyplayerlab.app`, `MinimumOSVersion=15.0`, and `CADisableMinimumFrameDurationOnPhone=true`;
- independent source reopen confirms Build233 acquisition behavior retained, Build231 `compositingGroup()`, Build226 Hero residency, Build228 settle/cancel refresh lifetime and 0.28/0.48 release rules retained.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / behavior unchanged by design / target-device diagnostic pending ❌ / stable ❌.'''

if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    text = subprocess.check_output(['git', 'show', 'origin/main:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True)
    text = re.sub(r'^\*\*Active — Build232 / 0\.14\.65.*?\*\*$', status, text, count=1, flags=re.M)
    text = re.sub(r'^- Working branch: `[^`]+`$', '- Working branch: `diag/home-carousel-acquisition-coalesced-diagnostics-build234`', text, count=1, flags=re.M)
    text = re.sub(r'^- Current candidate: OnePlayer `[^`]+`$', '- Current candidate: OnePlayer `0.14.67 (234)`', text, count=1, flags=re.M)
    anchor = '\n## Rejected directions not to repeat'
    if anchor not in text: raise SystemExit('checkpoint rejected anchor missing')
    if '### 2026-08-28 Build233 target-device result — acquisition-local path helps, but fallback remains coarse' not in text:
        text = text.replace(anchor, '\n' + build233_result + '\n\n' + build234 + anchor, 1)
    next_start = text.index('## Next exact action')
    text = text[:next_start] + '''## Next exact action\n\nInstall Build234 on iPhone 15 Pro Max / iOS 17.0 and repeat at least 12–15 starts, emphasizing the known high-risk “touch and immediately begin dragging” pattern; a smaller hold-before-drag comparison set is useful but not required to label each log event manually. Export the App log immediately afterwards. Group `HomeCarouselCadence` records by `acq_predecessor_status` and compare `acq_coalesced_count`, `acq_predecessor_delta_x`, `acq_predecessor_age_ms`, `acquire_to_first_render_ms`, and `first_render_x`. If most fallback cases are `none`, the next design must address missing acquisition-event predecessor availability without inventing interpolation. If fallback is mostly `direction`, inspect whether the immediately preceding real sample reflects legitimate sub-threshold/reversal noise before changing that guard. If accepted cases with large first steps simply have large predecessor deltas/ages, sample selection rather than fallback is the next variable. Keep Build231 compositing, Build226 Hero residency and Build228 release-tail contract intact. Build234 is diagnostic-only and must not be described as a start-step fix.\n'''
    p.write_text(text)
    raise SystemExit(0)

if MODE != 'main': raise SystemExit(f'unknown mode {MODE}')

checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
checkpoint.write_text(subprocess.check_output(['git', 'show', f'origin/{BRANCH}:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True))

module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
new_row = '| Home carousel interaction | **Active — Build233 target-device partial positive but insufficient; Build234 acquisition coalesced-decision diagnostics CI/IPA verified, target-device pending** | Build233 target-device log has 67 drags: 42 acquisition-local same-event starts (median first step 2.0pt; >=5pt 28.6%) versus 25 fallback starts (median 8.33pt; >=5pt 64%); overall >=5pt 28/67 (41.8%) and >=2.5pt 32/67 (47.8%). User still perceives roughly half-or-more coarse starts, so Build233 is not accepted as final, though the acquisition-local predecessor direction is materially helpful when available. User also reports title seems less jittery; Build231 `compositingGroup()` remains beneficial but not frozen complete. Build234 / 0.14.67 preserves Build233 behavior and only logs acquisition coalesced count, predecessor status/delta/age. Tested source `528168da7c6b6df26bf1a907439becdb5cc4c980`; run/job `33189068688 / 98909569541`; artifact `9693038983`; IPA SHA-256 `ddd8b884dd5095a3eb72e47b8a2726ac9bf32e9dc7000aafe9aeef596296a59c`; MinOS 15.0 independently verified. Not stable. |'
for i, line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i] = new_row
        break
else: raise SystemExit('module carousel row not found')
module.write_text('\n'.join(lines) + '\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
lines = index.read_text().splitlines()
row233 = '| **Carousel Build233 / 0.14.66** | Home-carousel acquisition-local first-frame A/B | **Target-device tested; acquisition-local path materially helps covered starts but overall fix insufficient; title subjectively less jittery; not stable.** 67 drags: 42 same-event acquisition-local starts have median first step 2.0pt and >=5pt 12/42 (28.6%); 25 fallback starts have median 8.33pt and >=5pt 16/25 (64%); overall >=5pt 28/67 (41.8%), >=2.5pt 32/67 (47.8%). User still perceives about half-or-more starts as large, so do not accept Build233 as final. Same session reports title less jittery; cadence distribution is cleaner than Build232 but not perfect. Tested source `4912234b579a2b8eeba7d5e7f5c6159248953efe`; run/job `33177534304 / 98869934770`; artifact `9688349642`; IPA SHA-256 `717ee926877e9867272f78790e06b3181b4e0f17d7d71d9494ca0540184a019b`; MinOS 15.0. |'
row234 = '| **Carousel Build234 / 0.14.67** | Home-carousel acquisition coalesced-decision diagnostics | **CI/IPA verified; measurement-only; target-device pending; not stable.** Preserves Build233 behavior exactly and adds `acq_coalesced_count`, `acq_predecessor_status`, `acq_predecessor_delta_x`, and `acq_predecessor_age_ms` to explain remaining fallback/large accepted first steps before changing sample selection or guards. Build231 compositing, Build226 Hero residency, Build228 max-refresh-through-settle and 0.28/0.48 release rules retained. Tested source `528168da7c6b6df26bf1a907439becdb5cc4c980`; run/job `33189068688 / 98909569541`; artifact `9693038983`; artifact SHA-256 `d819f7a7ccd02bbc73f8201861c6b4a77b4627832d50e16de3f1e42f524786e8`; IPA SHA-256 `ddd8b884dd5095a3eb72e47b8a2726ac9bf32e9dc7000aafe9aeef596296a59c`; source ZIP SHA-256 `4c2ca8e92eae8449f6aa9e52228b78418c79924e35a5821c978a4046a71d58fb`; MinOS 15.0. |'
out=[]
found=False
for line in lines:
    if line.startswith('| **Carousel Build233 / 0.14.66** |'):
        out.extend([row233,row234]); found=True
    else:
        out.append(line)
if not found: raise SystemExit('Build233 index row not found')
index.write_text('\n'.join(out) + '\n')

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(r'^_Last updated.*?_$', '_Last updated after carousel Build233 / 0.14.66 target-device first-frame A/B and Build234 / 0.14.67 acquisition coalesced-decision diagnostic CI/IPA verification. Build216 remains the accepted overall runtime baseline; Build226 Hero residency + Build228 release-through-settle + Build231 foreground compositing remain the positive carousel foundation._', text, count=1, flags=re.M)
anchor = '\n## Active: Poster-heavy scrolling smoothness'
addition = '''\n### Build233 partial first-frame improvement → Build234 coalesced-decision diagnostics\n\nBuild233 target-device evidence is mixed but useful. In 67 drags, the acquisition-local same-event predecessor path fired 42 times and materially reduced first-step size (median 2.0pt, >=5pt 28.6%), while 25 fallback starts retained a median 8.33pt first step and >=5pt rate of 64%. Overall 28/67 starts were >=5pt and the user still perceives roughly half-or-more starts as coarse, so Build233 is not the final acquisition contract. The user also reports title text seems less jittery; 42/67 display p95 samples are ~8.34ms versus 18/67 at ~16.67ms, supporting but not proving a cadence-related improvement.\n\nBuild234 / 0.14.67 changes no behavior. It records the acquisition UIEvent coalesced sample count, predecessor accept/reject status, predecessor delta X and predecessor age so the 25 fallback starts and remaining large accepted starts can be attributed before another input change. Exact tested source `528168da7c6b6df26bf1a907439becdb5cc4c980`, run/job `33189068688 / 98909569541`, artifact `9693038983`, IPA SHA-256 `ddd8b884dd5095a3eb72e47b8a2726ac9bf32e9dc7000aafe9aeef596296a59c`, MinOS 15.0. Target-device diagnostic pending; not stable.\n'''
if '### Build233 partial first-frame improvement → Build234 coalesced-decision diagnostics' not in text:
    if anchor not in text: raise SystemExit('PROJECT_STATE poster anchor missing')
    text = text.replace(anchor, addition + anchor, 1)
state.write_text(text)

tech = Path('docs/project/TECHNICAL_DECISIONS.md')
text = tech.read_text()
marker='\n## D013 — Detail high-rate scroll and warm presentation stay scoped and presentation-only'
addition = '''\nBuild233 target-device evidence refines but does not replace the acquisition-relative contract. A real acquisition-local coalesced predecessor is useful when present: 42/67 same-event starts materially reduce first-step size versus 25 fallback starts. However the user still perceives frequent coarse starts and the overall >=5pt rate remains 41.8%, so the Build233 one-event predecessor implementation is **not yet accepted as a final contract**. Do not hide the residual with a numeric step cap, easing, timer or interpolation. Build234 first measures whether residual starts are caused by missing predecessor availability, zero/direction guard rejection, or a legitimately large predecessor delta/age. Only one of those evidence-backed causes should drive the next behavioral A/B. Build231 foreground compositing remains retained as beneficial; Build226 Hero residency and Build228 max-refresh-through-settle remain unchanged.\n'''
if 'Build233 target-device evidence refines but does not replace the acquisition-relative contract.' not in text:
    if marker not in text: raise SystemExit('TECH D013 anchor missing')
    text = text.replace(marker, '\n' + addition + marker, 1)
tech.write_text(text)
