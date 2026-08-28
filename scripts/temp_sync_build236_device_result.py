from pathlib import Path
import re
import subprocess
import sys

MODE = sys.argv[1]
BRANCH = 'perf/home-carousel-post-acquisition-baseline-build236'

result = '''### 2026-08-29 Build236 target-device result — post-acquisition real baseline materially reduces coarse starts

User feedback on iPhone 15 Pro Max / iOS 17.0: **“感觉大步长几率是有明显下降，而且标题文字抖动也非常轻微了。”** The uploaded Build236 App log `OnePlayer-App-1787938053.log` contains 53 `HomeCarouselCadence` drags and confirms the first-step improvement:

- overall `|first_render_x| >= 2.5pt`: **11/53 (20.8%)**;
- overall `|first_render_x| >= 5pt`: **10/53 (18.9%)**;
- overall `|first_render_x| >= 8pt`: **3/53 (5.7%)**;
- 28 acquisition-event `accepted` starts: median first step **1.67pt**; `>=5pt` **6/28**; `>=8pt` **1/28**;
- 20 acquisition-event `none` starts entered Build236's one-time post-acquisition path; **16/20** found a real predecessor on the first post-acquisition UIEvent and then had median first step **2.0pt**, `>=5pt` **0/16**, `>=8pt` **0/16**;
- the remaining **4/20** still had only one sample on the first post-acquisition event (`post_acq_predecessor_status=none`); these remain coarse with median first step **7.84pt**, `>=5pt` **4/4**, `>=8pt` **2/4**;
- 4 acquisition `direction` cases and 1 `zero` case were not a practical coarse-start source in this capture: all five first steps stayed below 2.5pt.

This confirms Build236's exact mechanism is effective: when Build234's one-sample acquisition event can obtain one real direction-compatible predecessor on the immediately following UIEvent, the old coarse fallback is removed without synthetic interpolation or a step cap. The residual avoidable coarse-start family is now narrowly the **4/53 cases where both acquisition and the first post-acquisition event expose no predecessor**. Separately, six `>=5pt` acquisition-accepted starts are real 4.17ms predecessor deltas of roughly 5.33–11pt; do not hide those real finger velocities with an artificial first-step cap.

Title/cadence evidence is also positive but not frozen complete. User reports title jitter is now very slight. Display p95 is ≈8.34ms in **44/53** drags, ≈16.67ms in 7/53, with one 10.09ms and one 14.05ms sample. Rare long-tail display gaps still exist (max 50.01ms) and this capture still records one persistent image callback per drag, so residual cadence work remains possible; however Build230 already proved persistent residency alone is not a sufficient title fix, so do not reopen that strategy without new targeted evidence.

Evidence: Build236 Code written ✅ / scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅ / coarse-start probability materially reduced ✅ / title jitter very slight ✅ / residual 4/53 no-predecessor fallback + rare cadence tails remain / stable ❌.'''

if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    text = p.read_text()
    text = re.sub(r'^\*\*Active — Build234 target-device diagnostics.*?\*\*$', '**Active — Build236 / 0.14.69 target-device testing is materially positive: coarse first-step probability is clearly lower and title jitter is now very slight. In 53 drags, overall first step >=5pt is 10/53 (18.9%) and >=8pt is 3/53 (5.7%). Of the 20 acquisition-event `none` cases, Build236 finds a real predecessor on the first post-acquisition UIEvent in 16/20; those 16 have median first step 2.0pt and zero >=5pt starts. The remaining 4/20 still expose only one sample on that first post event and remain coarse (median 7.84pt; >=5pt 4/4). Build231 foreground `compositingGroup()`, Build226 Hero residency and Build228 max-refresh-through-settle remain retained. Build235 remains reserved by Aether. Build216 remains the accepted overall runtime baseline; Build236 is target-device positive but not yet stable.**', text, count=1, flags=re.M)
    if '### 2026-08-29 Build236 target-device result — post-acquisition real baseline materially reduces coarse starts' not in text:
        anchor = '\n## Rejected directions not to repeat'
        if anchor not in text: raise SystemExit('checkpoint anchor missing')
        text = text.replace(anchor, '\n' + result + '\n' + anchor, 1)
    start = text.index('## Next exact action')
    text = text[:start] + '''## Next exact action\n\nRetain Build236 as the current carousel control candidate and do not add a numeric first-step cap, synthetic interpolation or extra easing. If development continues, first measure the **second** post-acquisition UIEvent only for the residual `acq=none` + `post_acq=none` family (4/53 in this capture) before changing behavior again; the current log does not prove that a usable real predecessor exists on that second event. Keep Build231 foreground `compositingGroup()`, Build226 Hero residency and Build228 release-tail contract intact. Treat six >=5pt acquisition-accepted starts with 4.17ms real predecessor deltas of ~5.33–11pt as real finger motion, not sampling failure, unless new EX A/B evidence proves otherwise. Continue to watch title cadence, but do not resurrect Build230 persistent residency merely because rare persistent-adjacent long tails remain.\n'''
    p.write_text(text)
    raise SystemExit(0)

if MODE != 'main': raise SystemExit(f'unknown mode {MODE}')

checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
checkpoint.write_text(subprocess.check_output(['git','show',f'origin/{BRANCH}:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True))

module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
row = '| Home carousel interaction | **Active — Build236 target-device materially positive; coarse starts sharply reduced, title jitter now very slight; residual 4/53 double-no-predecessor starts remain** | Build236 / 0.14.69 target-device log has 53 drags: overall >=5pt first step 10/53 (18.9%), >=8pt 3/53 (5.7%). Of 20 acquisition `none` starts, 16 obtain a real predecessor on the first post-acquisition UIEvent and have median first step 2.0pt with zero >=5pt; the remaining 4 still have `post_acq=none` and remain coarse (median 7.84pt; >=5pt 4/4). User reports title jitter is now very slight; display p95 is ~8.34ms in 44/53 drags, though rare long tails remain. Retain Build231 compositing + Build226 Hero residency + Build228 max-refresh-through-settle. Build235 remains Aether-owned. Build236 tested source `7811f34104daaea8734e72404bcb2fadb6fa37f7`; run/job `33193485825 / 98924631982`; artifact `9694861946`; IPA SHA-256 `8e248cb5834be4bcc261e3e1b63db3c334b805a4245aab56c74a5fe5951cd4c5`; MinOS 15.0. Not stable. |'
for i,line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i]=row
        break
else: raise SystemExit('module row missing')
module.write_text('\n'.join(lines)+'\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
lines = index.read_text().splitlines()
row236 = '| **Carousel Build236 / 0.14.69** | First post-acquisition real-baseline A/B | **Target-device materially positive; coarse-start rate sharply reduced and title jitter very slight; not stable.** 53 drags: overall >=5pt first step 10/53 (18.9%), >=8pt 3/53 (5.7%). Among 20 acquisition-event `none` starts, 16 find a real predecessor on the first post-acquisition event and have median first step 2.0pt with zero >=5pt; 4 remain `post_acq=none` and coarse (median 7.84pt; >=5pt 4/4). Display p95 ~8.34ms in 44/53 drags. Tested source `7811f34104daaea8734e72404bcb2fadb6fa37f7`; run/job `33193485825 / 98924631982`; artifact `9694861946`; IPA SHA-256 `8e248cb5834be4bcc261e3e1b63db3c334b805a4245aab56c74a5fe5951cd4c5`; MinOS 15.0. |'
found=False
for i,line in enumerate(lines):
    if line.startswith('| **Carousel Build236 / 0.14.69** |'):
        lines[i]=row236; found=True; break
if not found:
    insert=None
    for i,line in enumerate(lines):
        if line.startswith('| **Carousel Build234 / 0.14.67** |'): insert=i+1
    if insert is None: raise SystemExit('Build234 row missing')
    lines.insert(insert,row236)
index.write_text('\n'.join(lines)+'\n')

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(r'^_Last updated.*?_$', '_Last updated after carousel Build236 / 0.14.69 target-device testing materially reduced coarse starts and made title jitter very slight. Build216 remains the accepted overall runtime baseline; Build226 Hero residency + Build228 release-through-settle + Build231 foreground compositing + Build236 post-acquisition real-baseline handling are the current positive carousel foundation._', text, count=1, flags=re.M)
anchor='\n## Active: Poster-heavy scrolling smoothness'
addition='''\n### Carousel Build236 target-device result — coarse-start probability materially reduced\n\nBuild236 / 0.14.69 is now target-device positive. The 53-drag App log shows overall >=5pt first steps at 10/53 (18.9%) and >=8pt at 3/53 (5.7%). The key Build236 path worked in 16/20 acquisition-event `none` starts: a real predecessor appeared on the first post-acquisition UIEvent, yielding median first step 2.0pt and zero >=5pt starts. Four starts still had no predecessor on that first post event and remain coarse (median 7.84pt; >=5pt 4/4), so the remaining avoidable family is now very narrow. User also reports title jitter is very slight; display p95 is ~8.34ms in 44/53 drags. Do not add artificial step caps or synthetic interpolation; if continuing, first measure whether the second post-acquisition event exposes a real predecessor for the residual 4/53 family. Build236 is target-device positive but not stable.\n'''
if '### Carousel Build236 target-device result — coarse-start probability materially reduced' not in text:
    if anchor not in text: raise SystemExit('state anchor missing')
    text=text.replace(anchor,addition+anchor,1)
state.write_text(text)

tech = Path('docs/project/TECHNICAL_DECISIONS.md')
text=tech.read_text()
marker='\n## D013 — Detail high-rate scroll and warm presentation stay scoped and presentation-only'
addition='''\nBuild236 target-device evidence accepts the **first post-acquisition real-predecessor extension as materially positive**, but not yet as a frozen final contract. In 53 drags, overall >=5pt first steps fall to 10/53 (18.9%) and >=8pt to 3/53 (5.7%). Of 20 acquisition-event `none` starts, 16 obtain one real direction-compatible predecessor on the first post-acquisition UIEvent and then have median first step 2.0pt with zero >=5pt starts; the remaining 4 expose no predecessor on that event and remain coarse. Therefore retain the Build236 one-event extension. Do not hide residual real motion with a numeric first-step cap: six acquisition-accepted >=5pt starts are real 4.17ms predecessor deltas of roughly 5.33–11pt. If the residual 4/53 family is pursued, measure the second post-acquisition UIEvent first; current evidence does not prove a usable predecessor exists there. Build231 foreground compositing remains materially beneficial and title jitter is now very slight, but rare cadence tails remain and the whole carousel is not frozen.\n'''
if 'Build236 target-device evidence accepts the **first post-acquisition real-predecessor extension as materially positive**' not in text:
    if marker not in text: raise SystemExit('tech marker missing')
    text=text.replace(marker,'\n'+addition+marker,1)
tech.write_text(text)
