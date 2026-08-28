from pathlib import Path
import re
import subprocess
import sys

MODE = sys.argv[1]
BRANCH = 'diag/home-carousel-foreground-compositing-build231'

status = '**Active — Build231 / 0.14.64 is the current horizontal foreground-compositing A/B. Build230 target-device slow-drag testing reports the movie-title shimmer is still present, so persistent three-slot residency is rejected as a sufficient title-shimmer fix; no controlling verdict was reported for Build230 overall feel or post-settle behavior. Build231 returns to the cleaned Build228 foundation and adds only one foreground-page `compositingGroup()` before opacity/X offset. Build226 Hero residency and Build228 max-refresh-through-settle remain the accepted-for-now foundation; Build227 pixel rounding remains rejected. Build231 CI/IPA is verified; target-device slow-drag/title-shimmer and overall-feel A/B pending. Build216 remains the accepted overall runtime baseline.**'

build230_result = '''### 2026-08-28 Build230 target-device result — title shimmer unchanged

User feedback on iPhone 15 Pro Max / iOS 17.0: **“慢拖文字还是会有抖动”**. This directly rejects persistent three-slot residency as a sufficient fix for the known slow-drag movie-title shimmer. It does not prove persistent presentation has zero cost, and the user did not provide a controlling Build230 verdict for overall hand feel or post-settle behavior in this report. Do not carry Build230 persistent residency forward merely as the title fix.

This result narrows the next investigation back to foreground presentation/compositing. Build226 frame inspection already showed title, metadata and overview translating as one page with stable relative geometry; Build227 rejected physical-pixel X quantization; Build230 now shows moving target persistent first presentation out of active drag still leaves the title shimmer.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / horizontal real-device title-shimmer A/B tested ✅ / title fix rejected as sufficient / whole Build230 overall-feel verdict incomplete / stable ❌.'''

build231 = '''## Build231 / 0.14.64 — foreground page compositing A/B

Build231 returns to the cleaned carousel Build228 foundation and intentionally does **not** carry Build230 persistent residency or Build227 physical-pixel rounding. Its only runtime presentation change is one SwiftUI `compositingGroup()` boundary on each existing carousel foreground page **before** the unchanged opacity and X offset modifiers.

Purpose: test whether the visible slow-drag title shimmer is caused by foreground child-layer compositing/presentation while the entire page is translated, rather than by title geometry, pixel-grid alignment or target persistent first-mount timing. No second gesture/state owner, timer, interpolation, drawingGroup/Metal rasterization path, retry, watchdog or smoothing layer is added.

Retained contracts: Build226 current+previous+next clear-Hero residency, original current+target persistent crossfade/mount behavior, Build228 device-max refresh through settle/cancel, acquisition-relative foreground X, opaque interactive foreground, 0.28 commit threshold, 0.48×width predicted-distance gate, existing 0.22/0.18 release timing, preload/shared image loader, and all Frozen/P0 playback/transport/session paths. Build227 pixel rounding is absent.

CI / package evidence:

- branch: `diag/home-carousel-foreground-compositing-build231`;
- exact base: cleaned carousel Build228 head `e957a11325e5d605cec794b89b26ffc36cd96c06`;
- exact tested source: `d30092b8354553063c6d96b62a6f2f4387676601`;
- dedicated Xcode 16.4 run/job: `33169864030 / 98844082214` — success;
- artifact: `OnePlayer-0.14.64-build231-foreground-compositing`, ID `9685231197`;
- artifact SHA-256: `6f5c3eed03c170c57cbba315ffc636dbe0ebb829a903fdec7fe5844c92634d74`;
- IPA SHA-256: `b92eb47971c546cfe7044ebdbd94cc27a108f0febead32ec811d55e400df4571`;
- source ZIP SHA-256: `847b1cd13c87b61f0e418a250b4bc6e79f75f970187875a701d9830c5b452f07`;
- independent package reopen confirms OnePlayer `0.14.64 (231)`, bundle `com.embyplayerlab.app`, `MinimumOSVersion=15.0`, `CADisableMinimumFrameDurationOnPhone=true`, and checksum integrity;
- independent source reopen confirms exactly one foreground `.compositingGroup()` before opacity/X offset, Build226 Hero residency retained, original Build228 persistent current+target behavior retained, Build228 release-through-settle retained, and Build227 pixel rounding absent.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device pending ❌ / diagnostic candidate / stable ❌.'''

if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    text = subprocess.check_output(['git', 'show', 'origin/main:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True)
    text = re.sub(r'^\*\*Active — Build230 / 0\.14\.63.*?\*\*$', status, text, count=1, flags=re.M)
    text = re.sub(r'^- Working branch: `[^`]+`$', '- Working branch: `diag/home-carousel-foreground-compositing-build231`', text, count=1, flags=re.M)
    text = re.sub(r'^- Current candidate: OnePlayer `[^`]+`$', '- Current candidate: OnePlayer `0.14.64 (231)`', text, count=1, flags=re.M)
    rejected = '\n## Rejected directions not to repeat'
    if build230_result not in text:
        pos = text.index(rejected)
        text = text[:pos] + '\n' + build230_result + '\n\n' + build231 + text[pos:]
    next_start = text.index('## Next exact action')
    text = text[:next_start] + '''## Next exact action\n\nInstall Build231 on iPhone 15 Pro Max / iOS 17.0. Reproduce the same very-slow horizontal drag on a fallback-title item and compare directly against carousel Build228/Build230 and EX. Primary question: does the large white movie-title shimmer materially decrease without introducing blur, flattening, color/shadow changes or a new hand-feel regression? Also watch rating/year/type and overview because the whole foreground page now shares one compositing boundary. Then test normal-speed drag, rapid reversal and release tail to confirm Build226/228 gains are retained. If title shimmer is essentially unchanged, reject `compositingGroup()` as sufficient and inspect a stronger but still single-variable foreground raster/presentation A/B next; do not stack `drawingGroup`, UIKit text replacement, easing or timers before this result.\n'''
    p.write_text(text)
    raise SystemExit(0)

if MODE != 'main': raise SystemExit(f'unknown mode {MODE}')

checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
checkpoint.write_text(subprocess.check_output(['git', 'show', f'origin/{BRANCH}:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True))

module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
new_row = '| Home carousel interaction | **Active — Build230 title-shimmer A/B negative; Build231 foreground compositing CI/IPA verified, target-device pending** | Build226 three-slot Hero residency remains the materially positive presentation foundation and carousel Build228 max-refresh-through-settle remains accepted-for-now for release tail. Build227 pixel rounding is rejected. Build230 / 0.14.63 target-device slow-drag feedback says movie-title shimmer still remains, so persistent three-slot residency is not a sufficient title fix; no overall-feel/post-settle verdict is inferred from that report. Build231 / 0.14.64 returns to cleaned Build228 and adds only one foreground-page `compositingGroup()` before unchanged opacity/X offset to isolate foreground child-layer presentation. Tested source `d30092b8354553063c6d96b62a6f2f4387676601`; run/job `33169864030 / 98844082214`; artifact `9685231197`; IPA SHA-256 `b92eb47971c546cfe7044ebdbd94cc27a108f0febead32ec811d55e400df4571`; MinOS 15.0 independently verified. Not stable. |'
for i,line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i] = new_row
        break
else: raise SystemExit('module carousel row not found')
module.write_text('\n'.join(lines) + '\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
text = index.read_text()
old_prefix = '| **Carousel Build230 / 0.14.63** |'
lines = text.splitlines()
row230 = '| **Carousel Build230 / 0.14.63** | Home-carousel persistent three-slot residency A/B | **Target-device slow-drag title-shimmer A/B tested; title shimmer remains; persistent residency rejected as sufficient title fix; whole Build230 overall-feel verdict incomplete; not stable.** Starts from cleaned carousel Build228 and pre-resides current+previous+next persistent blur surfaces with normal crossfade. User reports “慢拖文字还是会有抖动”, so this does not solve the known movie-title shimmer. No conclusion is fabricated for Build230 overall hand feel or post-settle behavior from this report. Tested source `6324bb2063bf1631b8b922abc8e11149bd7a86b0`; run/job `33167765310 / 98837170851`; artifact `9684378135`; IPA SHA-256 `6cea81f8e806ec159d9e811871076c18aa41fceb99b3c621516c490cfc339b4e`; MinOS 15.0. |'
row231 = '| **Carousel Build231 / 0.14.64** | Home-carousel foreground compositing A/B | **CI/IPA verified; target-device slow-drag/title-shimmer A/B pending; diagnostic only, not stable.** Returns to cleaned Build228 and adds exactly one `compositingGroup()` to each existing foreground page before unchanged opacity/X offset. Does not carry Build230 persistent residency or Build227 pixel rounding. Build226 Hero residency, Build228 max-refresh-through-settle, original persistent current+target crossfade, acquisition-relative X and 0.28/0.48 release rules remain. Tested source `d30092b8354553063c6d96b62a6f2f4387676601`; run/job `33169864030 / 98844082214`; artifact `9685231197`; artifact SHA-256 `6f5c3eed03c170c57cbba315ffc636dbe0ebb829a903fdec7fe5844c92634d74`; IPA SHA-256 `b92eb47971c546cfe7044ebdbd94cc27a108f0febead32ec811d55e400df4571`; source ZIP SHA-256 `847b1cd13c87b61f0e418a250b4bc6e79f75f970187875a701d9830c5b452f07`; MinOS 15.0. |'
found=False
out=[]
for line in lines:
    if line.startswith(old_prefix):
        out.extend([row230,row231]); found=True
    else: out.append(line)
if not found: raise SystemExit('Build230 index row not found')
index.write_text('\n'.join(out) + '\n')

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(r'^_Last updated.*?_$', '_Last updated after Build230 target-device slow-drag title-shimmer remained and carousel Build231 / 0.14.64 foreground-compositing CI/IPA verification. Build216 remains the accepted overall runtime baseline; Build226 Hero residency + Build228 release-through-settle remain the positive carousel foundation._', text, count=1, flags=re.M)
anchor = '\n## Active: Poster-heavy scrolling smoothness'
addition = '''\n### Build230 target-device result → Build231 foreground compositing A/B\n\nBuild230 target-device slow-drag feedback reports the movie-title shimmer still remains. Therefore pre-residing persistent neighbors is rejected as a sufficient title-shimmer fix; this report does not establish an overall-feel or post-settle verdict for Build230. Build231 returns to cleaned Build228 and isolates foreground child-layer presentation with one page-level `compositingGroup()` before unchanged opacity/X offset. Build231 exact source `d30092b8354553063c6d96b62a6f2f4387676601`, run/job `33169864030 / 98844082214`, artifact `9685231197`, IPA SHA-256 `b92eb47971c546cfe7044ebdbd94cc27a108f0febead32ec811d55e400df4571`, MinOS 15.0. Real-device pending; not stable.\n'''
if '### Build230 target-device result → Build231 foreground compositing A/B' not in text:
    if anchor not in text: raise SystemExit('PROJECT_STATE poster anchor missing')
    text = text.replace(anchor, addition + anchor, 1)
state.write_text(text)

tech = Path('docs/project/TECHNICAL_DECISIONS.md')
text = tech.read_text()
old = 'Build230 is the next diagnostic implementation of the same presentation-lifecycle principle, not yet a frozen contract. The existing derived current+previous+next residency window is reused for the persistent blurred backdrop so the adjacent target persistent surface is mounted before active drag while normal opacity crossfade remains. This is specifically different from rejected Build221: no outgoing-background freeze or visual mismatch is introduced. Accept this only if target-device testing improves active-drag cadence/title stability without moving the hitch to post-settle resident-window rotation or adding unacceptable compositor/memory pressure.'
new = old + '\n\nBuild230 target-device slow-drag testing reports that the movie-title shimmer still remains. Therefore persistent-neighbor residency is rejected as a sufficient title-shimmer fix and must not be promoted to the foreground-stability contract on that basis; no broader Build230 hand-feel/post-settle conclusion is inferred from the limited report. Build231 is the next single-variable diagnostic: return to cleaned Build228 and place one `compositingGroup()` boundary around each existing foreground page before unchanged opacity/X translation. This tests foreground child-layer composition without adding drawingGroup/Metal rasterization, a second state owner, interpolation or timing changes. Build231 is not an accepted contract until target-device evidence exists.'
if old not in text: raise SystemExit('TECH Build230 anchor missing')
text = text.replace(old,new,1)
tech.write_text(text)
