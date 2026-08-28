from pathlib import Path
import re
import subprocess
import sys

MODE = sys.argv[1]
BRANCH = 'perf/home-carousel-acquisition-first-frame-build233'

status = '**Active — Build232 / 0.14.65 target-device diagnostics now establish a reproducible dwell-sensitive first-visible-step split: the user reports immediate touch-and-drag has a high probability of the older coarse first step while touch/hold then drag is almost always fine, and the uploaded log records 34 drags split cleanly into 20 small first steps (0.33–2.33pt) and 14 large first steps (8.00–13.67pt), with no samples in between and a median acquisition→first-render interval of 8.34ms. Build231 foreground `compositingGroup()` remains materially positive because the prior test made title text clearly steadier without blur, but it is no longer treated as a complete fix because title jitter reappeared in this Build232 session. Build233 / 0.14.66 is the current single-variable acquisition-first-frame A/B: on the acquisition UIEvent only, use the immediately preceding same-direction coalesced real touch as the render baseline and publish the current delivered touch immediately; subsequent interactive rendering remains delivered-touch owned. Build226 Hero residency + Build228 max-refresh-through-settle remain retained. Build216 remains the accepted overall runtime baseline.**'

build232_result = '''### 2026-08-28 Build232 target-device result — first-step split proven; title compositing remains partial

User feedback on iPhone 15 Pro Max / iOS 17.0 is controlling: **immediate touch-and-drag has a high probability of a large/coarse first visible step, while touching/holding briefly before dragging is almost always a short/fine first step.** The user also reports that movie-title jitter was visible again in this Build232 session.

Uploaded App log `OnePlayer-App-1787924071.log` contains 34 `HomeCarouselCadence` drags. The new first-step measurements are strongly bimodal:

- 20/34 first visible steps are only **0.33–2.33pt**;
- 14/34 are **8.00–13.67pt**;
- there are **zero** first-step samples between 2.33pt and 8.00pt;
- median `acquire_to_first_render_ms` is **8.34ms**, so the split is not explained by some gestures waiting tens of milliseconds longer after acquisition;
- small-step drags have median absolute `acquisition_x` about **13.5pt**, while large-step drags have median absolute `acquisition_x` about **5.17pt**. The acquisition-relative first step therefore depends strongly on which delivered touch becomes the acquisition baseline and how far the next delivered touch travels in the following 120Hz interval.

The log does not encode the user's intended “immediate” vs “hold” label per gesture, so the user's repeated tactile classification remains authority for mapping those two measured populations to the two start patterns. The measured bimodality independently confirms that the first visible motion is not continuously varying noise.

Build231 foreground compositing is **retained as materially beneficial but no longer considered sufficient by itself**. Build232 intentionally kept the same `compositingGroup()` rendering path, yet title jitter was observed again. The same session also contains residual cadence degradation: 16/34 drags have display p95 around 16.67ms and 5/34 have average SwiftUI render intervals at or above 20ms. Because no exact video timestamp maps the visible title jitter to one specific cadence sample, treat this as supporting evidence that residual frame-delivery instability can still expose title shimmer; do not claim a complete causal mapping from this log alone.

Evidence: Build232 Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device first-step diagnostic tested ✅ / immediate-vs-hold symptom confirmed ✅ / title jitter still reproducible ✅ / stable ❌.'''

build233 = '''## Build233 / 0.14.66 — acquisition-local first-frame A/B

Build233 is the minimum behavior change supported by the Build232 first-step measurement. It retains Build231 foreground `compositingGroup()`, Build226 current+previous+next clear-Hero residency, original current+target persistent behavior, Build228 device-max refresh through settle/cancel, the existing 0.28 commit threshold, 0.48×width predicted-distance gate, and unchanged release timing.

At the one UIEvent where horizontal ownership is acquired, the recognizer inspects only the immediately preceding real coalesced touch sample from that same event. If that predecessor exists and its delta continues in the already-selected horizontal direction, it becomes the one-time render baseline and the **current delivered touch is published immediately on the acquisition event**. If no suitable predecessor exists, Build232 acquisition-relative behavior is preserved. After acquisition, every interactive render update remains driven by normal delivered touches; predicted touch stays release-only. There is no timer, interpolation, artificial step cap, easing, debounce/throttle, retry/watchdog, or second state owner.

This is intentionally an A/B, not a frozen replacement for the Build215 acquisition contract. Its purpose is to remove the extra acquisition-frame dead interval without returning to touch-down-relative jump behavior. Build232 cadence fields remain in place: a successful acquisition-local path should often show `acquire_to_first_render_ms≈0` with a short real `first_render_x`, especially for the immediate-drag pattern.

CI / package evidence:

- branch: `perf/home-carousel-acquisition-first-frame-build233`;
- exact base: cleaned Build232 tree at `d4db105b9412cbb3d66a9b351f9ba49d2b1bb742`;
- exact tested source: `4912234b579a2b8eeba7d5e7f5c6159248953efe`;
- cleanup head after temporary build CI removal: `fa3386eea8fbe5476bcfa85a2443ac30b45a5e22`;
- dedicated Xcode 16.4 run/job: `33177534304 / 98869934770` — success;
- artifact: `OnePlayer-0.14.66-build233-acquisition-first-frame`, ID `9688349642`;
- artifact SHA-256: `dbd6ea9767875f39f382180abf890147e3c7b78389637a1138fcae712338a1f6`;
- IPA SHA-256: `717ee926877e9867272f78790e06b3181b4e0f17d7d71d9494ca0540184a019b`;
- source ZIP SHA-256: `e76f5e10738fc820fb2efb5a008c99a9fc9a30841956cdf35e902d2bd2229c21`;
- independent package reopen confirms OnePlayer `0.14.66 (233)`, bundle `com.embyplayerlab.app`, `MinimumOSVersion=15.0`, and `CADisableMinimumFrameDurationOnPhone=true`;
- independent source reopen confirms Build231 `compositingGroup()`, Build226 Hero residency, Build228 settle/cancel refresh lifetime, 0.28/0.48 release rules and the one-event acquisition predecessor logic are present.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device pending ❌ / A/B only / stable ❌.'''

if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    text = subprocess.check_output(['git', 'show', 'origin/main:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True)
    text = re.sub(r'^\*\*Active — Build231 / 0\.14\.64.*?\*\*$', status, text, count=1, flags=re.M)
    text = re.sub(r'^- Working branch: `[^`]+`$', '- Working branch: `perf/home-carousel-acquisition-first-frame-build233`', text, count=1, flags=re.M)
    text = re.sub(r'^- Current candidate: OnePlayer `[^`]+`$', '- Current candidate: OnePlayer `0.14.66 (233)`', text, count=1, flags=re.M)
    anchor = '\n## Rejected directions not to repeat'
    if anchor not in text: raise SystemExit('checkpoint rejected anchor missing')
    if '### 2026-08-28 Build232 target-device result — first-step split proven; title compositing remains partial' not in text:
        text = text.replace(anchor, '\n' + build232_result + '\n\n' + build233 + anchor, 1)
    next_start = text.index('## Next exact action')
    text = text[:next_start] + '''## Next exact action\n\nInstall Build233 on iPhone 15 Pro Max / iOS 17.0. Primary A/B: repeat at least 8–10 “touch and immediately begin a slow horizontal drag” starts, then at least 5 “touch/hold briefly, then slow drag” starts. Judge the **first visible step** first, not overall release tail. Export the App log afterwards and compare `acquire_to_first_render_ms` + `first_render_x` against Build232: the acquisition-local path should commonly move the first render onto the acquisition event (`≈0ms`) with a short real coalesced-to-delivered delta. Also note whether immediate starts still show the old 8–14pt visible jump. Keep Build231 `compositingGroup()` enabled and separately report whether title jitter appears; do not mix another title-rasterization change into Build233. If immediate starts become consistently fine without harming vertical yield/reversal/normal drag, retain this acquisition-local predecessor direction. If large first steps remain or vertical ownership regresses, reject it and return to Build232/231 acquisition semantics before further work. After the start-step verdict, resume residual title/cadence investigation using the Build232 evidence that compositing is beneficial but not sufficient.\n'''
    p.write_text(text)
    raise SystemExit(0)

if MODE != 'main': raise SystemExit(f'unknown mode {MODE}')

checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
checkpoint.write_text(subprocess.check_output(['git', 'show', f'origin/{BRANCH}:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True))

module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
new_row = '| Home carousel interaction | **Active — Build232 first-step split proven on target device; Build233 acquisition-local first-frame CI/IPA verified, target-device pending** | Build231 foreground `compositingGroup()` remains materially positive because it made slow-drag title text clearly steadier without blur, but Build232 reproduced title jitter again, so compositing is beneficial rather than a complete fix. Build232 target-device log has 34 drags split into 20 first steps of 0.33–2.33pt and 14 of 8.00–13.67pt with no middle samples; user reports immediate drag maps to the coarse/high-probability pattern while hold-then-drag is almost always fine. Build233 / 0.14.66 keeps Build226 Hero residency + Build228 max-refresh-through-settle + Build231 compositing and uses only the immediately preceding same-direction coalesced sample as a one-event acquisition render baseline, publishing the current delivered touch immediately; later rendering remains delivered-touch owned. Tested source `4912234b579a2b8eeba7d5e7f5c6159248953efe`; run/job `33177534304 / 98869934770`; artifact `9688349642`; IPA SHA-256 `717ee926877e9867272f78790e06b3181b4e0f17d7d71d9494ca0540184a019b`; MinOS 15.0 independently verified. Not stable. |'
for i, line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i] = new_row
        break
else: raise SystemExit('module carousel row not found')
module.write_text('\n'.join(lines) + '\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
lines = index.read_text().splitlines()
row231 = '| **Carousel Build231 / 0.14.64** | Home-carousel foreground compositing A/B | **Target-device result materially positive but not complete: first test made movie-title text clearly steadier and not blurred; Build232 same rendering path later reproduced title jitter. Retain compositing as beneficial, not a full fix; not stable.** Returns to cleaned Build228 and adds exactly one `compositingGroup()` to each existing foreground page before unchanged opacity/X offset. Initial user verdict “这次文字明显稳下来了，也不糊” proves foreground child-layer compositing materially helps. Later Build232 user testing again saw title jitter, so do not freeze this as complete title stability. Tested source `d30092b8354553063c6d96b62a6f2f4387676601`; run/job `33169864030 / 98844082214`; artifact `9685231197`; IPA SHA-256 `b92eb47971c546cfe7044ebdbd94cc27a108f0febead32ec811d55e400df4571`; MinOS 15.0. |'
row232 = '| **Carousel Build232 / 0.14.65** | Home-carousel start-step timing/translation diagnostics | **Target-device diagnostic tested; immediate-vs-hold first-step split proven; title jitter still reproducible; diagnostic only, not stable.** Behavior unchanged from Build231/226/228. Uploaded log has 34 drags: 20 first visible steps 0.33–2.33pt, 14 first steps 8.00–13.67pt, zero in between, median acquisition→first-render 8.34ms. User reports immediate touch-and-drag has high probability of the coarse large-step pattern while hold-before-drag is almost always fine. Same session again exposes title jitter; 16/34 drags have display p95 ≈16.67ms and 5/34 have render average ≥20ms, supporting residual cadence investigation without exact per-jitter attribution. Tested source `de11d7483075daf7463faaa5519432478463a271`; run/job `33174155718 / 98858347691`; artifact `9686946353`; IPA SHA-256 `0366bffeda255f799621c0b0ffeb2780ef1adaa44c9d7b9f01ce14f0fe84b528`; MinOS 15.0. |'
row233 = '| **Carousel Build233 / 0.14.66** | Home-carousel acquisition-local first-frame A/B | **CI/IPA verified; target-device immediate-start A/B pending; not stable.** Keeps Build231 compositing, Build226 Hero residency, original persistent behavior, Build228 max-refresh-through-settle and 0.28/0.48 release rules. On the horizontal acquisition UIEvent only, a suitable immediately preceding same-direction coalesced real touch becomes the render baseline and the current delivered touch is published immediately; later interactive rendering remains delivered-touch owned and predicted touch remains release-only. No timer/interpolation/step cap/easing/second owner. Tested source `4912234b579a2b8eeba7d5e7f5c6159248953efe`; run/job `33177534304 / 98869934770`; artifact `9688349642`; artifact SHA-256 `dbd6ea9767875f39f382180abf890147e3c7b78389637a1138fcae712338a1f6`; IPA SHA-256 `717ee926877e9867272f78790e06b3181b4e0f17d7d71d9494ca0540184a019b`; source ZIP SHA-256 `e76f5e10738fc820fb2efb5a008c99a9fc9a30841956cdf35e902d2bd2229c21`; MinOS 15.0. |'
out=[]
found231=False
found232=False
for line in lines:
    if line.startswith('| **Carousel Build231 / 0.14.64** |'):
        out.append(row231); found231=True
    elif line.startswith('| **Carousel Build232 / 0.14.65** |'):
        out.extend([row232,row233]); found232=True
    else:
        out.append(line)
if not found231 or not found232: raise SystemExit(f'index rows missing 231={found231} 232={found232}')
index.write_text('\n'.join(out) + '\n')

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(r'^_Last updated.*?_$', '_Last updated after carousel Build232 / 0.14.65 target-device first-step diagnostics and Build233 / 0.14.66 acquisition-first-frame CI/IPA verification. Build216 remains the accepted overall runtime baseline; Build226 Hero residency + Build228 release-through-settle + Build231 foreground compositing remain the positive carousel foundation, with Build231 now classified as beneficial but not a complete title-jitter fix._', text, count=1, flags=re.M)
anchor = '\n## Active: Poster-heavy scrolling smoothness'
addition = '''\n### Build232 first-step evidence → Build233 acquisition-local first frame\n\nBuild232 target-device testing confirms the newly noticed first-step inconsistency. The user reports immediate touch-and-drag frequently starts with the old coarse step, while touch/hold then drag is almost always fine. `OnePlayer-App-1787924071.log` records 34 drags with a clean two-population split: 20 first steps 0.33–2.33pt and 14 first steps 8.00–13.67pt, with median acquisition→first-render 8.34ms and no samples in the middle. This supports changing the acquisition-frame sample usage rather than release/easing.\n\nBuild231 foreground compositing remains materially positive but is downgraded from “complete title fix”: Build232 retained the same render path and title jitter reappeared. The Build232 session also contains residual cadence degradation (16/34 display p95 ≈16.67ms; 5/34 render average ≥20ms), so residual frame delivery remains an open title-shimmer contributor.\n\nBuild233 / 0.14.66 uses one acquisition-local predecessor sample only: if the same acquisition UIEvent contains an immediately preceding coalesced touch continuing in the selected horizontal direction, that real sample becomes the render baseline and the current delivered touch publishes immediately. Subsequent render ownership stays on delivered touch. Exact tested source `4912234b579a2b8eeba7d5e7f5c6159248953efe`, run/job `33177534304 / 98869934770`, artifact `9688349642`, IPA SHA-256 `717ee926877e9867272f78790e06b3181b4e0f17d7d71d9494ca0540184a019b`, MinOS 15.0. Real-device pending; not stable.\n'''
if '### Build232 first-step evidence → Build233 acquisition-local first frame' not in text:
    if anchor not in text: raise SystemExit('PROJECT_STATE poster anchor missing')
    text = text.replace(anchor, addition + anchor, 1)
state.write_text(text)

tech = Path('docs/project/TECHNICAL_DECISIONS.md')
text = tech.read_text()
marker = 'Build232 therefore measures touch-down→acquisition and acquisition→first-render timing/X only. Do not promote coalesced/predicted touch to a second visual owner or add smoothing/easing before this measurement.'
if marker not in text: raise SystemExit('TECH Build232 marker missing')
replacement = marker + '''\n\nBuild232 target-device measurement now provides the missing evidence. The user repeatedly confirms immediate touch-and-drag is very likely to show the coarse first step while hold-before-drag is almost always fine. The log has 34 drags split cleanly into 20 first steps of 0.33–2.33pt and 14 of 8.00–13.67pt, with zero middle samples and a median acquisition→first-render interval of 8.34ms. This validates changing the acquisition-frame sample usage, but does **not** justify a timer, synthetic interpolation or artificial step cap. Build233 is therefore allowed as one narrow exception to the earlier “coalesced is diagnostic only” rule: on the acquisition UIEvent only, the immediately preceding real coalesced touch may define the render baseline if its delta continues in the already-selected horizontal direction; the current delivered touch is then published immediately. After that event, delivered touch remains the sole interactive render authority and predicted touch remains release-only. Treat this as an A/B until target-device evidence confirms it.\n\nBuild231 foreground `compositingGroup()` remains retained because the first target-device A/B made title text clearly steadier without blur, but Build232 reproduced title jitter with the same rendering path. Therefore compositing is a material improvement, not a frozen claim of complete title stability. Residual cadence/frame-delivery investigation remains open after the acquisition-start issue is resolved.''' 
text = text.replace(marker, replacement, 1)
tech.write_text(text)
