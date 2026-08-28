from pathlib import Path
import re
import subprocess
import sys

MODE = sys.argv[1]
BRANCH = 'diag/home-carousel-start-step-diagnostics-build232'

status = '**Active — Build231 / 0.14.64 foreground compositing is now positively target-device validated for title stability: the user reports the slow-drag movie-title text is clearly steadier and not blurred, so the single page-level `compositingGroup()` is retained as the current foreground presentation direction. A new start-step consistency symptom is now under measurement: touching and waiting briefly before dragging yields a much shorter first visible step, while touching and immediately dragging often feels like the older coarse first step. Build232 / 0.14.65 retains Build231 behavior unchanged and adds measurement only for touch-down → acquisition and acquisition → first rendered move. Build226 Hero residency + Build228 max-refresh-through-settle remain retained; Build227 pixel rounding and Build230 persistent residency remain rejected as title fixes. Build216 remains the accepted overall runtime baseline.**'

build231_result = '''### 2026-08-28 Build231 target-device result — foreground compositing validated

User feedback on iPhone 15 Pro Max / iOS 17.0: **“这次文字明显稳下来了，也不糊”**. This directly validates the Build231 page-level `compositingGroup()` as an effective fix for the known slow-drag movie-title shimmer, without the blur regression that would make the approach unacceptable.

The result is narrow but strong: Build231 changed only the foreground compositing boundary on top of the cleaned Build228 foundation, so the prior title shimmer was materially caused by foreground child-layer compositing/presentation rather than title geometry, physical-pixel X rounding, or persistent-neighbor first-mount timing. Retain the Build231 compositing boundary unless new target-device regression evidence overturns it.

The same target-device session exposed a **new/previously-unconfirmed start-step consistency symptom**: if the finger touches the carousel and waits briefly before moving, the first visible drag step is very short; if the finger touches and immediately moves, the first visible step often feels as coarse as older builds. The user explicitly notes uncertainty about whether this existed before Build231. Therefore do not attribute it to Build231 or change acquisition behavior without measurement.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / horizontal target-device title-shimmer tested ✅ / foreground compositing materially positive ✅ / no blur regression ✅ / whole carousel stable ❌.'''

build232 = '''## Build232 / 0.14.65 — start-step timing/translation diagnostics

Build232 starts from the cleaned Build231 branch head and intentionally changes **no carousel behavior**. It keeps the now-positive Build231 foreground `compositingGroup()`, Build226 Hero residency, original current+target persistent behavior, Build228 exact-max refresh through settle/cancel, acquisition-relative render X, 0.28 commit threshold, 0.48×width predicted-distance gate, and existing release timing.

The only runtime delta is measurement inside the existing UIKit recognizer / cadence logger. `HomeCarouselCadence` now records:

- `touch_down_to_acquire_ms`: touch-down timestamp → the delivered move that wins horizontal axis acquisition;
- `acquisition_x`: existing touch-down-relative X at acquisition;
- `acquire_to_first_render_ms`: acquisition delivered touch → first later delivered move that can publish visible render motion;
- `first_render_x`: first acquisition-relative visible X passed to the existing drag owner;
- `first_total_x`: first touch-down-relative delivered X corresponding to that visible move.

No coalesced/predicted sample is promoted to visual authority; no timer, interpolation, smoothing, threshold/easing change or second state owner is added. This diagnostic is specifically meant to compare “touch then immediately drag” against “touch, wait briefly, then drag” before deciding whether the acquisition baseline/sample ownership needs a behavioral change.

CI / package evidence:

- branch: `diag/home-carousel-start-step-diagnostics-build232`;
- exact base: cleaned Build231 head `40a2e26fa16becb6830b400a030e4882300788d4`;
- exact tested source: `de11d7483075daf7463faaa5519432478463a271`;
- cleanup head after temporary CI removal: `01cbe7162b6e4d8882f987204fc585a2eed01284`;
- dedicated Xcode 16.4 run/job: `33174155718 / 98858347691` — success;
- artifact: `OnePlayer-0.14.65-build232-start-step-diagnostics`, ID `9686946353`;
- artifact SHA-256: `4f5286e4d49967d4af9f400b6ec32fe557319f55b15a08bd98f091892e7e86f1`;
- IPA SHA-256: `0366bffeda255f799621c0b0ffeb2780ef1adaa44c9d7b9f01ce14f0fe84b528`;
- source ZIP SHA-256: `9cc292766910f9c5c58b65c22c8ea4fcd2f53bc6e36428cb5c4bc2a12580c3ae`;
- independent package reopen confirms OnePlayer `0.14.65 (232)`, bundle `com.embyplayerlab.app`, `MinimumOSVersion=15.0`, and `CADisableMinimumFrameDurationOnPhone=true`;
- independent source reopen confirms Build231 `compositingGroup()` retained, diagnostic fields present, acquisition-relative X / 0.28 / 0.48 retained, and Build228 `settled` / `cancelled-settled` refresh lifetime retained.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / behavior unchanged by design / target-device diagnostic pending ❌ / stable ❌.'''

if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    text = subprocess.check_output(['git', 'show', 'origin/main:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True)
    text = re.sub(r'^\*\*Active — Build231 / 0\.14\.64.*?\*\*$', status, text, count=1, flags=re.M)
    text = re.sub(r'^- Working branch: `[^`]+`$', '- Working branch: `diag/home-carousel-start-step-diagnostics-build232`', text, count=1, flags=re.M)
    text = re.sub(r'^- Current candidate: OnePlayer `[^`]+`$', '- Current candidate: OnePlayer `0.14.65 (232)`', text, count=1, flags=re.M)
    anchor = '\n## Rejected directions not to repeat'
    if anchor not in text: raise SystemExit('checkpoint rejected anchor missing')
    if '### 2026-08-28 Build231 target-device result — foreground compositing validated' not in text:
        text = text.replace(anchor, '\n' + build231_result + '\n\n' + build232 + anchor, 1)
    next_start = text.index('## Next exact action')
    text = text[:next_start] + '''## Next exact action\n\nInstall Build232 on iPhone 15 Pro Max / iOS 17.0 and perform two clearly separated start patterns on the same carousel item/direction: (A) touch and begin a slow horizontal drag immediately, repeated at least 5 times; (B) touch, hold approximately 0.5–1.0 s without moving, then begin a similarly slow horizontal drag, repeated at least 5 times. Keep the first movement deliberately slow rather than flicking. Export the App log immediately afterwards. Compare `touch_down_to_acquire_ms`, `acquisition_x`, `acquire_to_first_render_ms`, `first_render_x`, and `first_total_x` between A and B. Build232 is measurement-only; do not judge it as a fix. If immediate starts consistently show a materially larger `first_render_x`, inspect delivered/coalesced sampling around acquisition and design one single-owner baseline refinement without changing release authority. If the logged first-render X is similar but the perceived step differs, move the investigation to render/display timing instead of changing input math. Keep Build231 foreground compositing regardless unless a new visual regression appears.\n'''
    p.write_text(text)
    raise SystemExit(0)

if MODE != 'main': raise SystemExit(f'unknown mode {MODE}')

checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
checkpoint.write_text(subprocess.check_output(['git', 'show', f'origin/{BRANCH}:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True))

module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
new_row = '| Home carousel interaction | **Active — Build231 foreground compositing target-device positive; Build232 start-step diagnostics CI/IPA verified, target-device pending** | Build231 / 0.14.64 target-device slow-drag testing reports movie-title text is clearly steadier and not blurred, so the single foreground-page `compositingGroup()` is retained as the evidence-backed title-stability direction. A new start-step consistency symptom is now isolated: wait-before-drag feels very fine while immediate touch-and-drag can feel coarse; user is unsure whether it predated Build231, so no behavioral attribution is made yet. Build232 / 0.14.65 keeps Build231 + Build226 Hero residency + Build228 max-refresh-through-settle unchanged and only logs touch-down→acquisition and acquisition→first-render timing/X. Tested source `de11d7483075daf7463faaa5519432478463a271`; run/job `33174155718 / 98858347691`; artifact `9686946353`; IPA SHA-256 `0366bffeda255f799621c0b0ffeb2780ef1adaa44c9d7b9f01ce14f0fe84b528`; MinOS 15.0 independently verified. Build227 pixel rounding and Build230 persistent residency remain rejected as title fixes. Not stable. |'
for i, line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i] = new_row
        break
else: raise SystemExit('module carousel row not found')
module.write_text('\n'.join(lines) + '\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
lines = index.read_text().splitlines()
row231 = '| **Carousel Build231 / 0.14.64** | Home-carousel foreground compositing A/B | **Target-device slow-drag title-shimmer tested; movie-title text is clearly steadier and not blurred; foreground compositing direction validated; not stable.** Returns to cleaned Build228 and adds exactly one `compositingGroup()` to each existing foreground page before unchanged opacity/X offset. User reports “这次文字明显稳下来了，也不糊”, directly validating foreground child-layer compositing as a material cause of the shimmer. The same session newly reports a dwell-sensitive start-step difference, but the user is unsure whether it predated Build231, so no causal attribution is made to compositing. Tested source `d30092b8354553063c6d96b62a6f2f4387676601`; run/job `33169864030 / 98844082214`; artifact `9685231197`; IPA SHA-256 `b92eb47971c546cfe7044ebdbd94cc27a108f0febead32ec811d55e400df4571`; MinOS 15.0. |'
row232 = '| **Carousel Build232 / 0.14.65** | Home-carousel start-step timing/translation diagnostics | **CI/IPA verified; behavior unchanged by design; target-device immediate-vs-wait start A/B pending; diagnostic only, not stable.** Keeps Build231 foreground compositing, Build226 Hero residency, original persistent current+target behavior, Build228 max-refresh-through-settle, acquisition-relative X and 0.28/0.48 release rules. Adds only existing-owner logging for `touch_down_to_acquire_ms`, `acquisition_x`, `acquire_to_first_render_ms`, `first_render_x`, and `first_total_x`; coalesced/predicted touches remain non-visual authority. Tested source `de11d7483075daf7463faaa5519432478463a271`; run/job `33174155718 / 98858347691`; artifact `9686946353`; artifact SHA-256 `4f5286e4d49967d4af9f400b6ec32fe557319f55b15a08bd98f091892e7e86f1`; IPA SHA-256 `0366bffeda255f799621c0b0ffeb2780ef1adaa44c9d7b9f01ce14f0fe84b528`; source ZIP SHA-256 `9cc292766910f9c5c58b65c22c8ea4fcd2f53bc6e36428cb5c4bc2a12580c3ae`; MinOS 15.0. |'
out = []
found = False
for line in lines:
    if line.startswith('| **Carousel Build231 / 0.14.64** |'):
        out.extend([row231, row232])
        found = True
    else:
        out.append(line)
if not found: raise SystemExit('Build231 index row not found')
index.write_text('\n'.join(out) + '\n')

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(r'^_Last updated.*?_$', '_Last updated after carousel Build231 / 0.14.64 target-device foreground-compositing success and Build232 / 0.14.65 start-step diagnostic CI/IPA verification. Build216 remains the accepted overall runtime baseline; Build226 Hero residency + Build228 release-through-settle + Build231 foreground compositing are the current positive carousel foundation._', text, count=1, flags=re.M)
anchor = '\n## Active: Poster-heavy scrolling smoothness'
addition = '''\n### Build231 target-device success → Build232 start-step diagnostics\n\nBuild231 target-device slow-drag testing reports the movie-title text is clearly steadier and not blurred. Therefore the page-level foreground `compositingGroup()` is retained as the current evidence-backed title-stability direction. The same session exposed a newly noticed but not yet historically attributed start-step difference: wait-before-drag feels very fine, while immediate touch-and-drag can begin with a coarser visible step. Exact recognizer source acquires horizontal ownership on the first delivered move crossing 0.5pt, stores that delivered translation as the render baseline, returns without publishing, then first publishes on the next delivered move. Existing cadence logging does not record the first acquisition-relative step, so a behavior change is not yet justified.\n\nBuild232 / 0.14.65 is measurement-only on top of cleaned Build231. It records touch-down→acquisition time/X and acquisition→first-render time/X while retaining all current motion/release/render contracts. Exact tested source `de11d7483075daf7463faaa5519432478463a271`, run/job `33174155718 / 98858347691`, artifact `9686946353`, IPA SHA-256 `0366bffeda255f799621c0b0ffeb2780ef1adaa44c9d7b9f01ce14f0fe84b528`, MinOS 15.0. Target-device diagnostic pending; not stable.\n'''
if '### Build231 target-device success → Build232 start-step diagnostics' not in text:
    if anchor not in text: raise SystemExit('PROJECT_STATE poster anchor missing')
    text = text.replace(anchor, addition + anchor, 1)
state.write_text(text)

tech = Path('docs/project/TECHNICAL_DECISIONS.md')
text = tech.read_text()
marker = 'Build231 is not an accepted contract until target-device evidence exists.'
if marker not in text: raise SystemExit('TECH Build231 marker missing')
replacement = marker + '''\n\nBuild231 target-device evidence is now positive and supersedes that pending status for the foreground-compositing subproblem: the user reports the slow-drag movie-title text is clearly steadier and not blurred. Retain the single page-level `compositingGroup()` as the current foreground title-stability contract unless new device regression evidence overturns it. This does not freeze the whole carousel.\n\nThe same session newly exposes a dwell-sensitive first-visible-step symptom, but the user is unsure whether it existed before Build231. Exact UIKit recognizer source acquires horizontal ownership on the first delivered move at or beyond 0.5pt, stores that event's translation as `horizontalAcquisitionTranslation`, returns without visual publication, then publishes `currentTranslation - acquisitionTranslation` on the next delivered move. That structure is a plausible explanation for different first-step sizes when immediate motion changes delivered-sample spacing, but plausibility is not enough to alter the retained acquisition contract. Build232 therefore measures touch-down→acquisition and acquisition→first-render timing/X only. Do not promote coalesced/predicted touch to a second visual owner or add smoothing/easing before this measurement.''' 
text = text.replace(marker, replacement, 1)
tech.write_text(text)
