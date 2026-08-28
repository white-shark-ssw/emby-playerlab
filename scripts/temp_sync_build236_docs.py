from pathlib import Path
import re
import subprocess
import sys

MODE = sys.argv[1]
BRANCH = 'perf/home-carousel-post-acquisition-baseline-build236'

status = '**Active — Build234 target-device diagnostics prove the dominant residual coarse-start fallback is acquisition-event predecessor absence: all 11 fallback cases had `acq_predecessor_status=none` with `acq_coalesced_count=1`, while accepted acquisition-local predecessors were much finer. Build236 / 0.14.69 is now CI/IPA verified as the narrow follow-up: only those one-sample acquisition cases inspect the first post-acquisition UIEvent for a real direction-compatible predecessor after acquisition, use it once as the render baseline while publishing the current delivered touch, then immediately return to ordinary delivered-touch ownership. Build231 foreground `compositingGroup()`, Build226 Hero residency, Build228 max-refresh-through-settle and 0.28/0.48 release semantics remain retained. Build235 remains reserved by Aether. Build236 target-device testing is pending; Build216 remains the accepted overall runtime baseline.**'

build236_evidence = '''### CI / IPA evidence\n\n- branch: `perf/home-carousel-post-acquisition-baseline-build236`;\n- exact base: cleaned Build234 head `b0acb9e6db610341468f039076b77c1910765ad3`;\n- exact tested source: `7811f34104daaea8734e72404bcb2fadb6fa37f7`;\n- dedicated Xcode 16.4 run/job: `33193485825 / 98924631982` — success;\n- artifact: `OnePlayer-0.14.69-build236-post-acquisition-baseline`, ID `9694861946`;\n- artifact SHA-256: `3a45d3400ac396fbc47a38ec6974e8983d90e9a949c0ce37bf68f8e9d7051bd0`;\n- IPA SHA-256: `8e248cb5834be4bcc261e3e1b63db3c334b805a4245aab56c74a5fe5951cd4c5`;\n- source ZIP SHA-256: `256fa108bd8823e9f699036d8e85009b763e5b0bd11e5d357c8c352e0360f454`;\n- independent package reopen confirms bundle `com.embyplayerlab.app`, OnePlayer `0.14.69 (236)`, `MinimumOSVersion=15.0`, and `CADisableMinimumFrameDurationOnPhone=true`;\n- independent source reopen confirms Build236 pending path only for acquisition `none/count=1`, one first-post-acquisition real predecessor check, Build231 foreground `compositingGroup()`, Build226 Hero residency, Build228 settle/cancel max-refresh lifetime, unchanged 0.28/0.48 release rules, and no Build227 pixel rounding / Build230 persistent residency.\n\nEvidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device pending ❌ / stable ❌.'''

if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    text = p.read_text()
    text = re.sub(r'^\*\*Active — Build234 / 0\.14\.67.*?\*\*$', status, text, count=1, flags=re.M)
    text = re.sub(r'^\*\*Active — Build234 target-device diagnostics.*?\*\*$', status, text, count=1, flags=re.M)
    text = re.sub(r'^- Working branch: `[^`]+`$', '- Working branch: `perf/home-carousel-post-acquisition-baseline-build236`', text, count=1, flags=re.M)
    text = re.sub(r'^- Current candidate: OnePlayer `[^`]+`$', '- Current candidate: OnePlayer `0.14.69 (236)`', text, count=1, flags=re.M)
    heading = '## Build236 / 0.14.69 — first post-acquisition real-predecessor A/B'
    if heading not in text: raise SystemExit('Build236 checkpoint section missing')
    section_start = text.index(heading)
    marker = '\n## Rejected directions not to repeat'
    section_end = text.index(marker, section_start)
    section = text[section_start:section_end]
    if '### CI / IPA evidence' not in section:
        section = section.rstrip() + '\n\n' + build236_evidence + '\n'
        text = text[:section_start] + section + text[section_end:]
    next_start = text.index('## Next exact action')
    text = text[:next_start] + '''## Next exact action\n\nInstall Build236 / 0.14.69 on iPhone 15 Pro Max / iOS 17.0. Emphasize repeated immediate touch-and-drag starts (at least 12–15), plus several hold-before-drag comparisons, and export the App log immediately afterwards. Compare three groups: acquisition `accepted` (`post_acq_predecessor_status=not-needed`), acquisition `none/count=1 -> post_acq accepted`, and acquisition `none/count=1 -> post_acq none/direction/zero`. The main acceptance signal is whether the second group materially converges toward the already-fine acquisition-accepted first-step distribution without introducing reversal discontinuity, title regression, release-tail regression or other visual mismatch. If the first post-acquisition event still has no usable real predecessor, do not add synthetic interpolation or a hard step cap; inspect that evidence before another behavior change.\n'''
    p.write_text(text)
    raise SystemExit(0)

if MODE != 'main': raise SystemExit(f'unknown mode {MODE}')

# Feature checkpoint: branch is the sole owner, copy its already-refreshed checkpoint.
checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
checkpoint.write_text(subprocess.check_output(['git', 'show', f'origin/{BRANCH}:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True))

module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
row = '| Home carousel interaction | **Active — Build234 identified one-sample acquisition events as the dominant residual coarse-start fallback; Build236 post-acquisition real-predecessor A/B CI/IPA verified, target-device pending** | Build234 target-device log: 20 acquisition `accepted` starts have median first step 3.0pt and >=5pt 4/20, while all 11 fallback `none` starts have `acq_coalesced_count=1`, median 9.0pt and >=5pt 9/11; zero direction/zero rejections. Build236 / 0.14.69 only for those one-sample cases checks the first post-acquisition UIEvent for a real direction-compatible predecessor after acquisition, uses it once as render baseline while current delivered touch remains publication authority, then clears the pending path. Build231 compositing, Build226 Hero residency, Build228 max-refresh-through-settle and 0.28/0.48 rules retained. Build235 is reserved by Aether. Tested source `7811f34104daaea8734e72404bcb2fadb6fa37f7`; run/job `33193485825 / 98924631982`; artifact `9694861946`; IPA SHA-256 `8e248cb5834be4bcc261e3e1b63db3c334b805a4245aab56c74a5fe5951cd4c5`; MinOS 15.0. Not stable. |'
for i, line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i] = row
        break
else: raise SystemExit('Home carousel MODULE_STATUS row missing')
module.write_text('\n'.join(lines) + '\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
lines = index.read_text().splitlines()
row236 = '| **Carousel Build236 / 0.14.69** | First post-acquisition real-predecessor A/B for one-sample acquisition events | **CI/IPA verified; target-device pending; not stable.** Build234 proved every residual fallback was acquisition `none` with `acq_coalesced_count=1`. Build236 preserves acquisition-accepted Build233 behavior and only for `none/count=1` checks the first post-acquisition UIEvent for a real coalesced predecessor after acquisition; if direction-compatible it becomes the render baseline once while the current delivered touch is published, then ordinary delivered-touch ownership resumes immediately. No timer/interpolation/step cap/easing/second owner. Build231 compositing, Build226 Hero residency, Build228 settle high-refresh and 0.28/0.48 release rules retained. Tested source `7811f34104daaea8734e72404bcb2fadb6fa37f7`; run/job `33193485825 / 98924631982`; artifact `9694861946`; artifact SHA-256 `3a45d3400ac396fbc47a38ec6974e8983d90e9a949c0ce37bf68f8e9d7051bd0`; IPA SHA-256 `8e248cb5834be4bcc261e3e1b63db3c334b805a4245aab56c74a5fe5951cd4c5`; source ZIP SHA-256 `256fa108bd8823e9f699036d8e85009b763e5b0bd11e5d357c8c352e0360f454`; MinOS 15.0. |'
if not any(line.startswith('| **Carousel Build236 / 0.14.69** |') for line in lines):
    out=[]
    inserted=False
    for line in lines:
        out.append(line)
        if line.startswith('| **Carousel Build234 / 0.14.67** |'):
            out.append(row236); inserted=True
    if not inserted: raise SystemExit('Build234 index anchor missing')
    lines=out
index.write_text('\n'.join(lines) + '\n')

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(r'^_Last updated.*?_$', '_Last updated after Home-carousel Build234 target-device acquisition diagnosis and Build236 / 0.14.69 post-acquisition real-predecessor A/B CI/IPA verification. Build216 remains the accepted overall runtime baseline; Build226 Hero residency + Build228 release-through-settle + Build231 foreground compositing remain retained._', text, count=1, flags=re.M)
anchor = '\n## Active: Poster-heavy scrolling smoothness'
addition = '''\n### Build234 diagnosis → Build236 first post-acquisition real-predecessor A/B\n\nBuild234 target-device diagnostics close the remaining Build233 fallback ambiguity: all 11 coarse fallback starts are acquisition `none` with `acq_coalesced_count=1`, while there are zero `direction` and zero `zero` rejections. Those one-sample acquisition events have no earlier same-event real touch available, and the old next-delivered fallback remains coarse.\n\nBuild236 / 0.14.69 is the minimum behavior A/B authorized by that evidence. Acquisition events that already have an accepted predecessor are unchanged. Only `none/count=1` cases inspect the first post-acquisition UIEvent for the last real coalesced predecessor whose timestamp is after acquisition and before the current delivered touch; a direction-compatible predecessor may become the render baseline once, and the current delivered touch remains the publication event. The pending path is cleared immediately after that UIEvent. No synthetic interpolation, hard step cap, timer, easing or second render owner is added. Exact tested source `7811f34104daaea8734e72404bcb2fadb6fa37f7`; run/job `33193485825 / 98924631982`; artifact `9694861946`; IPA SHA-256 `8e248cb5834be4bcc261e3e1b63db3c334b805a4245aab56c74a5fe5951cd4c5`; MinOS 15.0. Target-device pending; not stable.\n'''
if '### Build234 diagnosis → Build236 first post-acquisition real-predecessor A/B' not in text:
    if anchor not in text: raise SystemExit('PROJECT_STATE poster anchor missing')
    text = text.replace(anchor, addition + anchor, 1)
state.write_text(text)

tech = Path('docs/project/TECHNICAL_DECISIONS.md')
text = tech.read_text()
paragraph = '''\nBuild236 implements the Build234-authorized one-event extension without changing the retained owner model. Only when acquisition itself is `none/count=1`, the recognizer may inspect the first post-acquisition UIEvent for a real coalesced predecessor after the acquisition timestamp; if that predecessor continues in the already-selected horizontal direction, it defines the render baseline once while the current delivered touch is still the visual publication. The pending path is then cleared immediately. Acquisition events with an accepted predecessor are unchanged; if the first post-acquisition event has no valid real predecessor, the old fallback remains. This does not authorize continuous coalesced rendering, interpolation, a numeric step cap, timer/easing smoothing, predicted-touch render authority or a second state owner. Build236 is CI/IPA verified but target-device pending, so this one-event extension remains an A/B rather than a frozen acquisition contract. Build235 is reserved by the independent Aether task; carousel uses Build236 / 0.14.69.\n'''
marker = '\n## D013 — Detail high-rate scroll and warm presentation stay scoped and presentation-only'
if 'Build236 implements the Build234-authorized one-event extension' not in text:
    if marker not in text: raise SystemExit('TECHNICAL_DECISIONS D013 anchor missing')
    text = text.replace(marker, paragraph + marker, 1)
tech.write_text(text)
