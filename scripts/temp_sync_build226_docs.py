from pathlib import Path
import re
import subprocess
import sys

MODE = sys.argv[1]
BRANCH = 'perf/home-carousel-hero-residency-build226'

build225_result = '''### 2026-08-28 horizontal real-device result

User feedback on iPhone 15 Pro Max / iOS 17.0: **“这版本感觉明显细腻了一些。”** This is the first direct horizontal real-device evidence that moving target clear-Hero first presentation out of the active finger-tracking phase materially improves tactile fineness.

Controlling conclusion: target `carouselHeroArtwork` 1400px first presentation during active drag is a **material causal contributor** to the remaining rough-paper feel. This does not prove Hero presentation is the only residual source. Build225 itself remains diagnostic rather than final because it intentionally withholds the incoming clear Hero during active drag and restores it only after release.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / horizontal real-device tested ✅ / materially finer feel ✅ / diagnostic visual compromise / stable ❌.'''

build226_section = '''## Build226 / 0.14.59 — three-slot Hero residency

Build226 is the visual-preserving follow-up to Build225's positive horizontal A/B. Instead of hiding the incoming clear Hero during active drag, it keeps at most three full Hero presentations resident for the settled item: current + previous + next. The residency set is derived from the existing `currentCarouselItemID`; no duplicate stored transition state is added.

Because `currentCarouselItemID` does not rotate until `settleCarousel`, both possible horizontal target Heroes are already mounted throughout touch acquisition, drag and release animation. Drag-time current/target Hero blending therefore returns to normal `carouselOpacity(...)` behavior without creating a new 1400px Hero presentation inside the direct finger-tracking phase. After settle, residency rotates and any newly distant neighbor may mount outside active finger tracking.

Retained unchanged: normal persistent current/target crossfade, `EmbyCachedRemoteImage` shared loader/cache implementation, carousel preload, Build215 acquisition-relative motion, Build219 exact device-max refresh request, full-width page slots, opaque foreground, 0.28 commit threshold, 0.48×width predicted release gate, and all Player / MPV / PiP / Transport / Cache / Session / P0/Frozen paths.

CI / package evidence:

- branch: `perf/home-carousel-hero-residency-build226`;
- exact base: cleaned Build225 head `b4b8b76f316a675032f49fa7b616b6692427e96e`;
- exact tested source: `df1c9afce1dc96495dba16aa52e39254f23c7f65`;
- dedicated Xcode 16.4 run/job: `33151618930 / 98784687139` — success;
- artifact: `OnePlayer-0.14.59-build226-hero-residency`, ID `9677979449`;
- artifact SHA-256: `0ac4813d3a7578c52cb419be4402ffa4df14b992bb21ef19823189ba8973af7f`;
- IPA SHA-256: `881638aec2b31bef6b3b6b08bbd31c978eb5f4454683225ad4a212ccad99fe34`;
- source ZIP SHA-256: `5342c7af8145fc32e1b131947f7ce05f3ee8f81c0de39179c92c51c958cfe2b0`;
- independent package reopen confirms bundle `com.embyplayerlab.app`, OnePlayer `0.14.59 (226)`, `MinimumOSVersion=15.0`, runtime Mach-O minOS 15.0, compatibility audit OK and `CADisableMinimumFrameDurationOnPhone=true`;
- exact diff against the cleaned Build225 base changes product source only in `AppIdentity.swift`, `EmbyHomeHeroV3.swift`, and `EmbyHomeCarouselStateV3.swift`; shared image loader, carousel interaction owner and Home core are untouched.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device pending ❌ / stable ❌.'''

if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    text = subprocess.check_output(['git', 'show', 'origin/main:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True)
    text = re.sub(
        r'^\*\*Active — Build225 / 0\.14\.58.*?\*\*$',
        '**Active — Build226 / 0.14.59 is the current visual-preserving horizontal Hero-residency candidate. Build225 is now horizontally real-device tested and materially positive: deferring target clear-Hero first presentation during active drag made the carousel feel noticeably finer, establishing that presentation as a causal contributor, but Build225 itself remains diagnostic because incoming clear Hero is withheld during drag. Build226 keeps current + previous + next clear Heroes resident so both drag targets are already presented before finger tracking while normal Hero/persistent crossfades are preserved. Build226 CI/IPA is verified; target-device horizontal A/B pending. Build216 remains the accepted overall runtime baseline.**',
        text,
        count=1,
        flags=re.M,
    )
    pending225 = 'Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device pending ❌ / stable ❌.'
    if pending225 not in text:
        raise SystemExit('Build225 pending evidence marker not found')
    text = text.replace(pending225, build225_result, 1)
    marker = '\n## Rejected directions not to repeat\n'
    if '## Build226 / 0.14.59 — three-slot Hero residency' not in text:
        text = text.replace(marker, '\n' + build226_section + marker, 1)
    next_start = text.index('## Next exact action')
    text = text[:next_start] + '''## Next exact action

Install Build226 on iPhone 15 Pro Max / iOS 17.0 and test only horizontal carousel interaction. Compare directly with Build225 and EX: slow sustained tracking, quick left/right swipes, rapid direction reversal, repeated adjacent-page changes, and release/settle. Acceptance question: does Build226 retain Build225's noticeably finer tactile feel **while restoring the incoming clear Hero continuously during drag**? Also note any new hitch immediately after a page settles, because residency rotates one neighbor at settle. Do not use Home vertical inertial scrolling as the acceptance gate.
'''
    p.write_text(text)
    raise SystemExit(0)

if MODE != 'main':
    raise SystemExit(f'unknown mode: {MODE}')

checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
checkpoint.write_text(subprocess.check_output(['git', 'show', f'origin/{BRANCH}:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True))

module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
carousel = '| Home carousel interaction | **Active — Build226 Hero residency CI/IPA verified; target-device horizontal A/B pending** | Build225 / 0.14.58 is horizontally real-device tested and materially positive: user reports the carousel feels noticeably finer when target clear-Hero first presentation is deferred out of active drag, proving that presentation is a causal contributor. Build225 is not final because it withholds incoming clear Hero during drag. Build226 / 0.14.59 keeps derived current+previous+next clear Hero presentations resident, restores normal drag-time Hero crossfade, and retains normal persistent crossfade plus Build215/219 input+120Hz contracts. Run/job `33151618930 / 98784687139`; tested source `df1c9afce1dc96495dba16aa52e39254f23c7f65`; artifact `9677979449`; IPA SHA-256 `881638aec2b31bef6b3b6b08bbd31c978eb5f4454683225ad4a212ccad99fe34`; MinOS 15.0 independently verified. Real-device pending; not stable. |'
other = '| Other product modules | Active parallel work | Build216 / 0.14.49 remains the latest accepted overall runtime baseline. Home-carousel Build225 is a positive real-device diagnostic, while Build226 is the current CI/IPA-verified visual-preserving horizontal candidate pending target-device test. Poster-scroll Build220 remains a separate Active line. `EmbySharedImageAndNavigation.swift` remains shared infrastructure and was intentionally not changed by Build226. |'
for i, line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'): lines[i] = carousel
    elif line.startswith('| Other product modules |'): lines[i] = other
module.write_text('\n'.join(lines) + '\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
lines = index.read_text().splitlines()
row225 = '| **Build225 / 0.14.58** | Home-carousel target-Hero drag presentation isolation | **Horizontal real-device tested; materially finer feel; diagnostic visual compromise; not stable.** Based on exact Build219 tested 120Hz source. Normal persistent crossfade retained; during active drag current clear Hero stays visible while target clear-Hero 1400px mount is deferred until drag ends. User reports this version feels noticeably finer on iPhone 15 Pro Max / iOS 17.0, establishing active-drag target-Hero first presentation as a material causal contributor. Tested source `350fd5d07ae2e77907bcf497deb819dfea6a28b1`; run/job `33149313932 / 98777365879`; artifact `9677114082`; IPA SHA-256 `221162e47de335b665cad6e0dd48aa82a8e27bb50cadcc24c2c6888d26db000a`; MinOS 15.0. |'
row226 = '| **Build226 / 0.14.59** | Home-carousel three-slot Hero residency | **CI/IPA verified; target-device horizontal A/B pending; not stable.** Visual-preserving follow-up to positive Build225: derived current+previous+next clear Heroes stay resident so either horizontal target is already presented before active drag; normal Hero and persistent crossfades return while Build215 acquisition-relative motion, Build219 exact max-refresh and 0.28/0.48 release rules remain unchanged. Tested source `df1c9afce1dc96495dba16aa52e39254f23c7f65`; run/job `33151618930 / 98784687139`; artifact `9677979449`; artifact SHA-256 `0ac4813d3a7578c52cb419be4402ffa4df14b992bb21ef19823189ba8973af7f`; IPA SHA-256 `881638aec2b31bef6b3b6b08bbd31c978eb5f4454683225ad4a212ccad99fe34`; source ZIP SHA-256 `5342c7af8145fc32e1b131947f7ce05f3ee8f81c0de39179c92c51c958cfe2b0`; OnePlayer 0.14.59 (226), MinOS 15.0 independently verified. |'
lines = [row225 if line.startswith('| **Build225 / 0.14.58**') else line for line in lines]
if any(line.startswith('| **Build226 / 0.14.59**') for line in lines):
    lines = [row226 if line.startswith('| **Build226 / 0.14.59**') else line for line in lines]
else:
    i = next(i for i,line in enumerate(lines) if line.startswith('| **Build225 / 0.14.58**'))
    lines.insert(i + 1, row226)
index.write_text('\n'.join(lines) + '\n')

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(
    r'^_Last updated.*_$',
    '_Last updated after Build225 positive horizontal real-device feedback and Build226 / 0.14.59 Hero-residency CI/IPA verification. Build216 remains the accepted overall runtime baseline. Build225 materially improves tactile fineness by moving target clear-Hero first presentation out of active drag, establishing that presentation as a causal contributor. Build226 preserves the visual transition by keeping current+previous+next clear Heroes resident; target-device horizontal testing is pending._',
    text,
    count=1,
    flags=re.M,
)
old_heading = '### Build225 horizontal target-Hero A/B'
if old_heading in text:
    start = text.index(old_heading)
    end_marker = '\n## Active: Poster-heavy scrolling smoothness\n'
    end = text.index(end_marker, start)
    replacement = '''### Build225 horizontal target-Hero A/B — positive real-device diagnostic

Build225 / 0.14.58 was tested horizontally on iPhone 15 Pro Max / iOS 17.0. User feedback: **the version feels noticeably finer**. Because the narrow runtime difference was deferring target clear-Hero 1400px first presentation out of active drag while keeping Build219 120Hz input/render contracts and normal persistent crossfade, this is direct evidence that fresh target-Hero presentation during finger tracking is a material causal contributor to the residual rough feel. Build225 remains diagnostic, not stable, because it intentionally withholds incoming clear Hero until release.

### Build226 horizontal three-slot Hero residency

Build226 / 0.14.59 is the visual-preserving follow-up. It derives a resident current+previous+next Hero set from the existing settled `currentCarouselItemID`; there is no new duplicate transition owner. Both possible adjacent clear Heroes are therefore already mounted before horizontal tracking and normal `carouselOpacity(...)` blending can run during drag. Residency rotates after settle, moving any newly required neighbor presentation out of the direct finger-tracking phase. Shared `EmbyCachedRemoteImage`, persistent crossfade, preload, gesture ownership, acquisition-relative movement, exact device-max refresh and release semantics are unchanged. Dedicated Xcode 16.4 run/job `33151618930 / 98784687139` succeeded; tested source `df1c9afce1dc96495dba16aa52e39254f23c7f65`; artifact `9677979449`; IPA SHA-256 `881638aec2b31bef6b3b6b08bbd31c978eb5f4454683225ad4a212ccad99fe34`; source ZIP SHA-256 `5342c7af8145fc32e1b131947f7ce05f3ee8f81c0de39179c92c51c958cfe2b0`; OnePlayer 0.14.59 (226) / MinOS 15.0 independently verified. Evidence: **Code written / scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / not stable**.
'''
    text = text[:start] + replacement + text[end:]
text = text.replace(
    'Home-carousel acceptance is horizontal drag/swipe behavior; Build225 is the current CI/IPA-verified target-Hero horizontal A/B pending target-device testing; Build221 is real-device rejected as final and Build222–224 remain supporting vertical diagnostics only;',
    'Home-carousel acceptance is horizontal drag/swipe behavior; Build225 is now a positive horizontal real-device diagnostic proving target-Hero first presentation contributes materially to roughness; Build226 is the current CI/IPA-verified visual-preserving Hero-residency candidate pending target-device testing; Build221 is rejected as final and Build222–224 remain supporting vertical diagnostics only;'
)
state.write_text(text)

decisions = Path('docs/project/TECHNICAL_DECISIONS.md')
text = decisions.read_text()
old = '''Build225 is the next narrow horizontal diagnostic from the exact Build219 tested 120Hz line: restore normal persistent current/target crossfade, keep the already-visible current Hero opaque during active drag, and defer only target Hero clear 1400px mounting until drag ends. This isolates target-Hero first presentation without changing the one-UIKit-owner input path, acquisition-relative motion, foreground page travel, release semantics, preload or exact device-max refresh request. Build225 passed dedicated CI/IPA but remains diagnostic until target-device horizontal testing.'''
new = '''Build225 is the next narrow horizontal diagnostic from the exact Build219 tested 120Hz line: restore normal persistent current/target crossfade, keep the already-visible current Hero opaque during active drag, and defer only target Hero clear 1400px mounting until drag ends. Target-device horizontal testing reports the version feels **noticeably finer**. Because input ownership, acquisition-relative motion, foreground travel, release semantics, preload, persistent behavior and exact device-max refresh were retained, fresh target-Hero first presentation during active finger tracking is now established as a **material causal contributor** to the residual rough-paper feel. Build225 itself is not the final visual contract because it withholds incoming clear Hero during drag.

The resulting presentation contract is: do not reintroduce a freshly mounted target clear-Hero surface into the active finger-tracking path unless new real-device evidence overturns this result. Build226 tests the visual-preserving implementation of that contract by deriving a current+previous+next Hero residency set from the existing settled current ID. Both adjacent targets remain resident through drag/release; normal Hero opacity blending is restored; after settle the resident window may rotate one new neighbor outside direct finger tracking. No duplicate residency state, timer, retry, shared-loader change or new gesture owner is introduced. Build226 passed dedicated CI/IPA and awaits target-device validation.'''
if old not in text:
    raise SystemExit('Build225 D012 paragraph not found')
text = text.replace(old, new, 1)
text = text.replace(
    '- **Consequence:** do not return to vertical-only carousel candidates. Build221 has now been horizontally tested and rejected as the final frozen-persistent strategy; the current direct horizontal A/B is Build225 target-Hero presentation isolation. Horizontal evaluation must cover first movement, sustained tracking, reversal, backdrop/foreground continuity and release/settle.\n- **Evidence:** latest user target-device feedback outranks the prior diagnostic plan. Build221 now has direct horizontal real-device evidence; Build225 has Code/CI/IPA evidence and awaits horizontal real-device testing.',
    '- **Consequence:** do not return to vertical-only carousel candidates. Build221 is rejected as the final frozen-persistent strategy. Build225 now positively identifies active-drag target-Hero first presentation as a material contributor, and Build226 is the current visual-preserving residency A/B. Horizontal evaluation must cover first movement, sustained tracking, reversal, clear-Hero/backdrop continuity and release/settle.\n- **Evidence:** latest user target-device feedback outranks the prior diagnostic plan. Build225 has direct positive horizontal real-device evidence; Build226 has Code/CI/IPA evidence and awaits horizontal real-device testing.'
)
decisions.write_text(text)
