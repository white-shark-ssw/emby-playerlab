from pathlib import Path
import re
import subprocess
import sys

MODE = sys.argv[1]
BRANCH = 'diag/home-carousel-foreground-pixel-align-build227'

build226 = '''## Build226 / 0.14.59 — three-slot Hero residency

Build226 is the visual-preserving follow-up to Build225's positive target-Hero isolation. It keeps at most three clear Hero presentations resident for the settled item: current + previous + next, derived from the existing `currentCarouselItemID`. Both possible horizontal targets are therefore already mounted before active finger tracking, while normal Hero and persistent crossfades remain intact.

CI / package evidence:

- branch: `perf/home-carousel-hero-residency-build226`;
- exact tested source: `df1c9afce1dc96495dba16aa52e39254f23c7f65`;
- dedicated Xcode 16.4 run/job: `33151618930 / 98784687139` — success;
- artifact ID: `9677979449`;
- IPA SHA-256: `881638aec2b31bef6b3b6b08bbd31c978eb5f4454683225ad4a212ccad99fe34`;
- source ZIP SHA-256: `5342c7af8145fc32e1b131947f7ce05f3ee8f81c0de39179c92c51c958cfe2b0`;
- OnePlayer `0.14.59 (226)`, MinOS 15.0 independently verified.

### 2026-08-28 horizontal real-device result

User feedback on iPhone 15 Pro Max / iOS 17.0 after testing Build226:

- the first recording shows the **overall carousel is now fairly close to EX**;
- hand feel is **much better than the original OnePlayer carousel**, confirming the Hero-residency direction is correct;
- the user still feels there is room for further refinement, so Build226 is not yet stable/frozen;
- a second slow-drag recording exposes a separate visible issue: the large white movie-title text appears to shimmer/jitter while moving horizontally.

Both supplied recordings are `510×1108 @ 30 fps`. They are useful for visual/presentation evidence but cannot by themselves prove 120 Hz cadence parity. Frame-by-frame inspection of the slow-drag recording shows the title, rating/year/type row and overview translate together as one foreground page with stable relative geometry. The most visible instability is the high-contrast title glyph edge/clarity changing during slow horizontal movement, which supports a foreground text rasterization/compositing hypothesis rather than a title-only state or layout jump. This is not yet proof that physical-pixel alignment is the final fix.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / horizontal real-device tested ✅ / overall materially positive and fairly close to EX ✅ / residual slow-drag title shimmer observed / stable ❌.'''

build227 = '''## Build227 / 0.14.60 — foreground physical-pixel alignment A/B

Build227 stacks only one diagnostic presentation change on the cleaned Build226 branch. `carouselForegroundOffset(...)` keeps the same acquisition-relative/full-width page math, but the final foreground-page X presentation offset is rounded to the current display's physical-pixel grid using `UIScreen.main.scale`. On the target 3× display this is 1/3pt granularity.

Purpose: isolate whether the slow-drag title shimmer is caused by high-contrast SwiftUI text/shadow presentation at continuously changing subpixel X positions. The entire foreground page remains internally intact; no title-only position owner is introduced. Hero residency, normal Hero/persistent crossfade, one UIKit gesture owner, Build219 exact max-refresh request, 0.28 commit gate, 0.48×width predicted release gate, preload and all P0/Frozen paths are unchanged. No timer, interpolation, retry, watchdog, fallback, drawing-group layer, shared-image-loader change or duplicate state is added.

CI / package evidence:

- branch: `diag/home-carousel-foreground-pixel-align-build227`;
- exact base: cleaned Build226 head `f9f1ecf6334c14641dbdf780a5b09a118495b8ec`;
- exact tested source: `7ac8de30b76192ee3cd9c9382edca74b9ff5e69d`;
- dedicated Xcode 16.4 run/job: `33153825917 / 98791806487` — success;
- artifact: `OnePlayer-0.14.60-build227-foreground-pixel-align`, ID `9678871748`;
- artifact SHA-256: `58b232db9cb96d92afb6676bdcb48f1ae4d05eb57949f97d6ebfba338009ef9f`;
- IPA SHA-256: `b24d8abcd91f4faa74e06d8485bac3611725c561d9c99144c17def4b8ef26766`;
- source ZIP SHA-256: `16bc14dd82cae7d2599f23fefaf7b5e4d9c95db6a17dbaa08921e3749f41d278`;
- independent package reopen confirms bundle `com.embyplayerlab.app`, OnePlayer `0.14.60 (227)`, `MinimumOSVersion=15.0`, runtime Mach-O minOS 15.0, compatibility audit OK and `CADisableMinimumFrameDurationOnPhone=true`;
- independent source reopen confirms only the foreground X presentation alignment is new on top of Build226 product behavior; Hero residency, normal persistent target crossfade, acquisition-relative motion and 0.28/0.48 release rules remain present.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device pending ❌ / diagnostic only / stable ❌.'''

if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    text = subprocess.check_output(['git', 'show', 'origin/main:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True)
    text = re.sub(
        r'^\*\*Active — Build226 / 0\.14\.59.*?\*\*$',
        '**Active — Build227 / 0.14.60 is the current narrow foreground physical-pixel A/B. Build226 is now horizontally real-device tested and materially positive: overall carousel feel is fairly close to EX and much better than the original, validating three-slot Hero residency as the current presentation direction, but slow dragging exposes visible movie-title text shimmer and the overall feel still has room for refinement. Frame analysis shows the title/metadata/overview move together rather than the title owning a separate geometry jump. Build227 changes only final foreground-page X presentation to the physical-pixel grid while retaining Build226 Hero residency and all input/120Hz/release contracts. Build227 CI/IPA is verified; target-device test pending. Build216 remains the accepted overall runtime baseline.**',
        text,
        count=1,
        flags=re.M,
    )
    start = text.index('## Build226 / 0.14.59 — three-slot Hero residency')
    end = text.index('\n## Rejected directions not to repeat', start)
    text = text[:start] + build226 + '\n\n' + build227 + text[end:]
    next_start = text.index('## Next exact action')
    text = text[:next_start] + '''## Next exact action

Install Build227 on iPhone 15 Pro Max / iOS 17.0 and compare directly with Build226. First reproduce the second recording: very slow horizontal drag on an item that uses the large white fallback movie title. Judge whether the title edge/shimmer is materially reduced and whether rating/year/type + overview remain visually coherent. Then test overall horizontal feel with slow tracking, quick swipes, rapid reversal and repeated adjacent-page changes. The acceptance gate is two-sided: title stability must improve **without introducing pixel-step/staircase hand feel** or losing Build226's near-EX overall improvement. If title shimmer remains, reject physical-pixel alignment and inspect a precomposed foreground presentation path separately; do not stack another smoothing layer on Build227 before this A/B is tested.
'''
    p.write_text(text)
    raise SystemExit(0)

if MODE != 'main':
    raise SystemExit(f'unknown mode: {MODE}')

checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
checkpoint.write_text(subprocess.check_output(['git', 'show', f'origin/{BRANCH}:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True))

module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
carousel = '| Home carousel interaction | **Active — Build226 real-device materially positive; Build227 title-shimmer A/B CI/IPA verified, target-device pending** | Build226 / 0.14.59 is horizontally real-device tested: overall carousel feel is now fairly close to EX and much better than the original OnePlayer behavior, validating three-slot current+previous+next Hero residency as the current direction. Slow dragging still exposes visible large-title text shimmer and the user wants further refinement, so Build226 is not stable. Build227 / 0.14.60 retains Build226 Hero residency, normal Hero/persistent crossfades, Build215 acquisition-relative motion and Build219 exact max-refresh, and changes only final foreground-page X presentation to the physical-pixel grid. Run/job `33153825917 / 98791806487`; tested source `7ac8de30b76192ee3cd9c9382edca74b9ff5e69d`; artifact `9678871748`; IPA SHA-256 `b24d8abcd91f4faa74e06d8485bac3611725c561d9c99144c17def4b8ef26766`; MinOS 15.0 independently verified. Real-device pending; diagnostic only; not stable. |'
other = '| Other product modules | Active parallel work | Build216 / 0.14.49 remains the latest accepted overall runtime baseline. Home-carousel Build226 is now a materially positive real-device candidate and Build227 is the current CI/IPA-verified foreground text-presentation A/B pending target-device test. Poster-scroll Build220 remains a separate Active line. Build227 does not touch `EmbySharedImageAndNavigation.swift` or any Player/Transport/Cache/Session/P0/Frozen source. |'
for i, line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'): lines[i] = carousel
    elif line.startswith('| Other product modules |'): lines[i] = other
module.write_text('\n'.join(lines) + '\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
lines = index.read_text().splitlines()
row226 = '| **Build226 / 0.14.59** | Home-carousel three-slot Hero residency | **Horizontal real-device tested; overall fairly close to EX and much better than original; direction validated; residual slow-drag title shimmer; not stable.** Keeps derived current+previous+next clear Heroes resident so either horizontal target is already presented before active drag; normal Hero/persistent crossfades, Build215 acquisition-relative motion, Build219 exact max-refresh and 0.28/0.48 release rules remain. User reports major overall hand-feel improvement but still wants refinement; second slow-drag recording shows visible large movie-title shimmer. Tested source `df1c9afce1dc96495dba16aa52e39254f23c7f65`; run/job `33151618930 / 98784687139`; artifact `9677979449`; IPA SHA-256 `881638aec2b31bef6b3b6b08bbd31c978eb5f4454683225ad4a212ccad99fe34`; MinOS 15.0. |'
row227 = '| **Build227 / 0.14.60** | Home-carousel foreground physical-pixel alignment A/B | **CI/IPA verified; target-device title-shimmer + hand-feel A/B pending; diagnostic only, not stable.** Stacks on cleaned Build226 and changes only final foreground-page X presentation: raw full-width acquisition-relative offset is rounded to `UIScreen.main.scale` physical-pixel grid. Hero residency, normal persistent/Hero crossfade, input owner, 120Hz request and release gates remain unchanged. Tested source `7ac8de30b76192ee3cd9c9382edca74b9ff5e69d`; run/job `33153825917 / 98791806487`; artifact `9678871748`; artifact SHA-256 `58b232db9cb96d92afb6676bdcb48f1ae4d05eb57949f97d6ebfba338009ef9f`; IPA SHA-256 `b24d8abcd91f4faa74e06d8485bac3611725c561d9c99144c17def4b8ef26766`; source ZIP SHA-256 `16bc14dd82cae7d2599f23fefaf7b5e4d9c95db6a17dbaa08921e3749f41d278`; OnePlayer 0.14.60 (227), MinOS 15.0 independently verified. |'
lines = [row226 if line.startswith('| **Build226 / 0.14.59**') else line for line in lines]
if any(line.startswith('| **Build227 / 0.14.60**') for line in lines):
    lines = [row227 if line.startswith('| **Build227 / 0.14.60**') else line for line in lines]
else:
    i = next(i for i,line in enumerate(lines) if line.startswith('| **Build226 / 0.14.59**'))
    lines.insert(i + 1, row227)
index.write_text('\n'.join(lines) + '\n')

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(
    r'^_Last updated.*_$',
    '_Last updated after Build226 / 0.14.59 positive horizontal real-device recordings and Build227 / 0.14.60 foreground physical-pixel A/B CI/IPA verification. Build216 remains the accepted overall runtime baseline. Build226 is now fairly close to EX and much better than the original carousel, validating three-slot Hero residency, but slow-drag movie-title shimmer and residual refinement remain. Build227 isolates foreground subpixel presentation and awaits target-device testing._',
    text,
    count=1,
    flags=re.M,
)
start = text.index('### Build225 horizontal target-Hero A/B — positive real-device diagnostic')
end = text.index('\n## Active: Poster-heavy scrolling smoothness', start)
replacement = '''### Build225 horizontal target-Hero A/B — positive real-device diagnostic

Build225 / 0.14.58 established that deferring target clear-Hero first presentation out of active drag makes the carousel noticeably finer. This remains direct evidence that active-drag target-Hero first presentation was a material contributor, but Build225 itself is diagnostic because incoming clear Hero is withheld until release.

### Build226 horizontal three-slot Hero residency — materially positive real-device direction

Build226 / 0.14.59 keeps current+previous+next clear Heroes resident so both adjacent targets are already presented before finger tracking while normal Hero and persistent crossfades are restored. The user now reports the overall carousel is **fairly close to EX and much better than the original OnePlayer carousel**, validating residency as the current presentation direction. The user still wants further refinement, and the supplied slow-drag recording exposes visible large white movie-title shimmer. Both recordings are 510×1108@30fps; they support visual findings but do not independently prove 120Hz parity. Frame inspection shows title, metadata and overview moving as one foreground page rather than a title-only geometry jump. Build226 is real-device materially positive but not stable/frozen.

### Build227 horizontal foreground physical-pixel A/B

Build227 / 0.14.60 isolates the new title-shimmer finding. It keeps Build226 behavior and rounds only the final foreground page X presentation to the current display physical-pixel grid. No new owner/state/timer/interpolation/offscreen-compositing layer is added. Dedicated Xcode 16.4 run/job `33153825917 / 98791806487` succeeded; tested source `7ac8de30b76192ee3cd9c9382edca74b9ff5e69d`; artifact `9678871748`; IPA SHA-256 `b24d8abcd91f4faa74e06d8485bac3611725c561d9c99144c17def4b8ef26766`; source ZIP SHA-256 `16bc14dd82cae7d2599f23fefaf7b5e4d9c95db6a17dbaa08921e3749f41d278`; OnePlayer 0.14.60 (227) / MinOS 15.0 independently verified. Evidence: **Code written / scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / diagnostic only / not stable**.
'''
text = text[:start] + replacement + text[end:]
text = text.replace(
    'Home-carousel acceptance is horizontal drag/swipe behavior; Build225 is now a positive horizontal real-device diagnostic proving target-Hero first presentation contributes materially to roughness; Build226 is the current CI/IPA-verified visual-preserving Hero-residency candidate pending target-device testing; Build221 is rejected as final and Build222–224 remain supporting vertical diagnostics only;',
    'Home-carousel acceptance is horizontal drag/swipe behavior; Build225 proved target-Hero first presentation contributes materially to roughness; Build226 now has materially positive horizontal real-device evidence and validates three-slot Hero residency as the current presentation direction; Build227 is the current CI/IPA-verified foreground title-shimmer A/B pending target-device testing; Build221 is rejected as final and Build222–224 remain supporting vertical diagnostics only;'
)
state.write_text(text)

decisions = Path('docs/project/TECHNICAL_DECISIONS.md')
text = decisions.read_text()
old = '''The resulting presentation contract is: do not reintroduce a freshly mounted target clear-Hero surface into the active finger-tracking path unless new real-device evidence overturns this result. Build226 tests the visual-preserving implementation of that contract by deriving a current+previous+next Hero residency set from the existing settled current ID. Both adjacent targets remain resident through drag/release; normal Hero opacity blending is restored; after settle the resident window may rotate one new neighbor outside direct finger tracking. No duplicate residency state, timer, retry, shared-loader change or new gesture owner is introduced. Build226 passed dedicated CI/IPA and awaits target-device validation.'''
new = '''The resulting presentation contract is: do not reintroduce a freshly mounted target clear-Hero surface into the active finger-tracking path unless new real-device evidence overturns this result. Build226 implements this visually by deriving a current+previous+next Hero residency set from the existing settled current ID. Both adjacent targets remain resident through drag/release; normal Hero opacity blending is restored; after settle the resident window may rotate one new neighbor outside direct finger tracking. Target-device testing is materially positive: the user reports the overall carousel is now fairly close to EX and much better than the original OnePlayer carousel. Therefore three-slot Hero residency is retained as the current evidence-backed presentation direction, while the carousel remains Active because the final hand-feel gap is not closed.

The Build226 slow-drag recording also establishes a separate visual symptom: large fallback movie-title text visibly shimmers while the foreground page moves. Frame-by-frame inspection shows title, rating/year/type and overview translate together with stable relative geometry, so there is no evidence for a title-specific state/layout owner bug. Build227 is a narrow diagnostic of subpixel foreground presentation: it rounds only final page X presentation to `UIScreen.main.scale` physical pixels. This is not yet an accepted motion contract; reject it if target-device testing produces staircase feel or fails to reduce text shimmer. Do not stack drawing-group/offscreen compositing, interpolation or another smoothing owner before this A/B is resolved.'''
if old not in text:
    raise SystemExit('Build226 pending decision paragraph not found')
text = text.replace(old, new, 1)
text = text.replace(
    '- **Consequence:** do not return to vertical-only carousel candidates. Build221 is rejected as the final frozen-persistent strategy. Build225 now positively identifies active-drag target-Hero first presentation as a material contributor, and Build226 is the current visual-preserving residency A/B. Horizontal evaluation must cover first movement, sustained tracking, reversal, clear-Hero/backdrop continuity and release/settle.\n- **Evidence:** latest user target-device feedback outranks the prior diagnostic plan. Build225 has direct positive horizontal real-device evidence; Build226 has Code/CI/IPA evidence and awaits horizontal real-device testing.',
    '- **Consequence:** do not return to vertical-only carousel candidates. Build221 is rejected as the final frozen-persistent strategy. Build225 positively identifies active-drag target-Hero first presentation as a material contributor; Build226 now validates three-slot Hero residency with materially positive horizontal real-device evidence; Build227 isolates the remaining slow-drag foreground-title shimmer. Horizontal evaluation still covers first movement, sustained tracking, reversal, clear-Hero/backdrop continuity and release/settle.\n- **Evidence:** latest user target-device feedback outranks the prior diagnostic plan. Build225 and Build226 now both have direct positive horizontal real-device evidence; Build227 has Code/CI/IPA evidence and awaits target-device A/B.'
)
decisions.write_text(text)
