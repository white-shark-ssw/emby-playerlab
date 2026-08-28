from pathlib import Path
import re
import sys

MODE = sys.argv[1]

status = '**Active — Build234 / 0.14.67 target-device diagnostics now explain the remaining Build233 coarse-start fallback: 31 drags contain only `accepted` and `none` predecessor states. All 11 `none` cases have `acq_coalesced_count=1`, so the acquisition UIEvent contains only the current delivered touch and there is literally no earlier same-event real sample to use; none of the 31 cases were rejected by `direction` or `zero`. Those 11 fallback starts remain coarse (median first step 9.0pt; >=5pt 9/11), while 20 accepted same-event starts are much finer (median 3.0pt; >=5pt 4/20) with predecessor age almost always 4.17ms. This proves the Build233 same-event predecessor direction is valid when a predecessor exists, and proves the dominant residual failure is predecessor unavailability on the acquisition event, not the same-direction guard. Build231 foreground `compositingGroup()` remains materially beneficial; this Build234 capture is also cadence-clean (25/31 display p95 ≈8.34ms), consistent with the earlier report that title text is less jittery, but title stability is not frozen complete. Build226 Hero residency + Build228 max-refresh-through-settle remain retained. Build216 remains the accepted overall runtime baseline.**'

result = '''### 2026-08-28 Build234 target-device result — acquisition-event predecessor absence proven\n\nThe uploaded Build234 App log `OnePlayer-App-1787935463.log` contains **31** `HomeCarouselCadence` drags. The new acquisition-decision fields provide a decisive split:\n\n- predecessor status is only **`accepted` 20/31** or **`none` 11/31**; there are **zero `direction`** and **zero `zero`** rejections;\n- every `none` case has **`acq_coalesced_count=1`**, meaning the acquisition UIEvent exposes only the current delivered touch and no earlier same-event real sample exists;\n- those 11 `none` / fallback starts have median `|first_render_x|` **9.0pt**, with **9/11 >=5pt** and **7/11 >=8pt**; median acquisition→first-render delay is **8.34ms**;\n- the 20 `accepted` starts have median first step **3.0pt**, with **4/20 >=5pt** and **1/20 >=8pt**; acquisition→first-render is **0ms**;\n- accepted predecessor age is **4.17ms in 19/20** cases and 8.34ms once, so accepted large starts are primarily large real predecessor deltas, not stale tens-of-milliseconds samples;\n- acquisition-event coalesced counts for accepted starts are 2–5 samples (15/20 have 3), versus exactly 1 sample for every `none` case.\n\nControlling conclusion: Build234 disproves the hypothesis that Build233 fallback is mainly caused by the same-direction guard. The dominant residual failure is **same-event predecessor unavailability**: when UIKit gives only one acquisition-event sample, Build233 has no real earlier sample available and falls back to the next delivered event, recreating the coarse first step. Therefore do **not** remove the direction guard and do not add a synthetic step cap/interpolation. The next behavior A/B, if implemented, should stay within the same single UIKit owner and use only real touch samples to address the one-sample acquisition case.\n\nA directly evidence-backed candidate is to extend the already-proven acquisition-local idea by at most one event: only when acquisition had `status=none` / one sample, inspect the **first post-acquisition UIEvent** for a real immediately preceding coalesced sample and, if present and direction-compatible, use that real predecessor as the one-time render baseline while publishing that event's delivered touch. If that first post-acquisition event also has no predecessor, preserve the existing fallback rather than inventing motion. This exact next-event availability is not yet measured, so treat such a change as an A/B rather than a frozen contract.\n\nCadence/title evidence remains supporting, not causal proof. This Build234 session has **25/31** drags with display p95 around **8.34ms** and only 6/31 above that, consistent with the prior subjective report that title text looks steadier. Build231 `compositingGroup()` remains retained as beneficial but not complete/frozen.\n\nEvidence: Build234 Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device diagnostic tested ✅ / same-event predecessor absence proven ✅ / behavior fix not yet tested ❌ / stable ❌.'''

next_action = '''## Next exact action\n\nBuild234 has answered its diagnostic question. Do not change/remove the same-direction guard: no recorded fallback was caused by `direction` or `zero`; all 11 fallback cases were `status=none` with exactly one acquisition-event sample. Before the next carousel behavior build, perform the normal resume identity/build-collision guard. **Build235 is already reserved by the parallel Aether task on current `main`, so the carousel must not use Build235.** If a new carousel candidate is justified and the next free number remains available after re-check, use the next unreserved identity (currently Build236 is not found in project records, but verify again at allocation time). The narrow behavior A/B should preserve Build233/234 single-owner semantics and all retained Build226/228/231 contracts. For `status=none` only, inspect the first post-acquisition UIEvent for a real immediately preceding same-direction coalesced touch; if such a real predecessor exists, use it as a one-time render baseline and publish that event's delivered touch, then return to normal delivered-touch ownership. If no predecessor exists there either, keep the existing fallback. Add diagnostics sufficient to distinguish acquisition-event vs first-post-acquisition recovery. Do not add interpolation, timer, synthetic step cap, easing, predicted-touch render authority, or a second owner.\n'''

if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    text = p.read_text()
    text = re.sub(r'^\*\*Active — Build233 / 0\.14\.66.*?\*\*$', status, text, count=1, flags=re.M)
    text = re.sub(r'^\*\*Active — Build232 / 0\.14\.65.*?\*\*$', status, text, count=1, flags=re.M)
    anchor = '\n## Rejected directions not to repeat'
    if '### 2026-08-28 Build234 target-device result — acquisition-event predecessor absence proven' not in text:
        if anchor not in text: raise SystemExit('branch rejected anchor missing')
        text = text.replace(anchor, '\n' + result + '\n' + anchor, 1)
    if '## Next exact action' not in text: raise SystemExit('branch next action missing')
    text = text[:text.index('## Next exact action')] + next_action
    p.write_text(text)
    raise SystemExit(0)

if MODE != 'main': raise SystemExit(f'unknown mode {MODE}')

module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
new_row = '| Home carousel interaction | **Active — Build234 target-device proves acquisition-event predecessor absence is the dominant coarse-start fallback; next behavior A/B must skip Aether-reserved Build235** | Build234 log has 31 drags: 20 `accepted` starts (median first step 3.0pt; >=5pt 4/20) and 11 `none` starts (median 9.0pt; >=5pt 9/11). Every `none` case has `acq_coalesced_count=1`; there are zero `direction` and zero `zero` rejections. Thus Build233 same-event predecessor is materially effective when available, while one-sample acquisition events force the old next-delivered fallback and remain coarse. Build231 `compositingGroup()` remains beneficial; Build234 cadence is clean in this capture (25/31 display p95 ≈8.34ms) but title stability is not frozen. Build235 is reserved by parallel Aether work and must not be reused. Build234 tested source `528168da7c6b6df26bf1a907439becdb5cc4c980`; run/job `33189068688 / 98909569541`; artifact `9693038983`; IPA SHA-256 `ddd8b884dd5095a3eb72e47b8a2726ac9bf32e9dc7000aafe9aeef596296a59c`; MinOS 15.0. Not stable. |'
for i, line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i] = new_row
        break
else: raise SystemExit('module carousel row not found')
module.write_text('\n'.join(lines) + '\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
lines = index.read_text().splitlines()
new_index=[]
found=False
for line in lines:
    if line.startswith('| **Carousel Build234 / 0.14.67** |'):
        new_index.append('| **Carousel Build234 / 0.14.67** | Home-carousel acquisition coalesced-decision diagnostics | **Target-device diagnostic tested; acquisition-event predecessor absence proven; measurement-only behavior retained; not stable.** 31 drags: `accepted` 20, `none` 11, `direction` 0, `zero` 0. Every `none` has `acq_coalesced_count=1`; those fallback starts have median first step 9.0pt, >=5pt 9/11 and >=8pt 7/11, versus accepted median 3.0pt and >=5pt 4/20. Accepted predecessor age is 4.17ms in 19/20. Conclusion: residual coarse fallback is same-event predecessor unavailability, not direction guard rejection. Tested source `528168da7c6b6df26bf1a907439becdb5cc4c980`; run/job `33189068688 / 98909569541`; artifact `9693038983`; artifact SHA-256 `d819f7a7ccd02bbc73f8201861c6b4a77b4627832d50e16de3f1e42f524786e8`; IPA SHA-256 `ddd8b884dd5095a3eb72e47b8a2726ac9bf32e9dc7000aafe9aeef596296a59c`; source ZIP SHA-256 `4c2ca8e92eae8449f6aa9e52228b78418c79924e35a5821c978a4046a71d58fb`; MinOS 15.0. |')
        found=True
    else:
        new_index.append(line)
if not found: raise SystemExit('Build234 index row not found')
index.write_text('\n'.join(new_index) + '\n')

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(r'^_Last updated.*?_$', '_Last updated after carousel Build234 / 0.14.67 target-device acquisition coalesced-decision diagnostics. Build234 proves the dominant remaining coarse-start fallback occurs when the acquisition UIEvent has only one sample and therefore no same-event real predecessor. Build216 remains the accepted overall runtime baseline; Build226 Hero residency + Build228 release-through-settle + Build231 foreground compositing remain the positive carousel foundation._', text, count=1, flags=re.M)
anchor='\n## Active: Poster-heavy scrolling smoothness'
addition='''\n### Build234 target-device diagnosis — one-sample acquisition events own the residual coarse fallback\n\nBuild234 target-device log contains 31 drags. Exactly 20 acquisition events report `accepted` and 11 report `none`; there are no `direction` or `zero` rejections. Every `none` event has `acq_coalesced_count=1`, proving UIKit exposed only the current delivered touch and no earlier same-event real sample. Those 11 fallback starts are coarse (median first step 9.0pt; >=5pt 9/11), while accepted same-event starts are materially finer (median 3.0pt; >=5pt 4/20). Accepted predecessor age is almost always 4.17ms. Therefore do not remove the same-direction guard or add synthetic interpolation/step caps. The next carousel behavior A/B should target the one-sample acquisition case using only real touch samples and preserve the single UIKit owner. Build235 is reserved by parallel Aether work and cannot be reused for carousel.\n'''
if '### Build234 target-device diagnosis — one-sample acquisition events own the residual coarse fallback' not in text:
    if anchor not in text: raise SystemExit('state poster anchor missing')
    text = text.replace(anchor, addition + anchor, 1)
state.write_text(text)

tech = Path('docs/project/TECHNICAL_DECISIONS.md')
text = tech.read_text()
anchor='\n## D013 — Detail high-rate scroll and warm presentation stay scoped and presentation-only'
addition='''\nBuild234 resolves the remaining Build233 acquisition-fallback ambiguity. In 31 target-device drags, every fallback is `acq_predecessor_status=none` with `acq_coalesced_count=1`; there are zero `direction` and zero `zero` rejections. When a same-event predecessor exists, the path remains materially finer; when the acquisition event has only the current sample, the recognizer has no real earlier same-event touch and the old next-delivered fallback recreates the coarse start. Therefore do not remove the same-direction guard and do not introduce synthetic interpolation or a hard first-step cap. A future A/B may extend the one-time real-coalesced-baseline rule to the first post-acquisition event only for these one-sample acquisition cases, provided it still uses a real direction-compatible predecessor and returns immediately to delivered-touch ownership; if no such real predecessor exists, preserve the existing fallback.\n'''
if 'Build234 resolves the remaining Build233 acquisition-fallback ambiguity.' not in text:
    if anchor not in text: raise SystemExit('tech D013 anchor missing')
    text = text.replace(anchor, '\n' + addition + anchor, 1)
tech.write_text(text)
