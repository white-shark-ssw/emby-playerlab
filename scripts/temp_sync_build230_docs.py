from pathlib import Path
import re
import subprocess
import sys

MODE = sys.argv[1]
BRANCH = 'perf/home-carousel-persistent-residency-build230'

build230 = '''## Build230 / 0.14.63 — persistent three-slot residency A/B

Build230 starts from the cleaned carousel Build228 foundation and changes one presentation-lifecycle variable: the full-screen persistent backdrop now reuses the already-derived settled current + previous + next residency window instead of mounting only current plus a newly-created `transitionTargetCarouselItem` during active drag.

Why this variable is evidence-backed:

- Build219's residual 34–50 ms gaps repeatedly correlated with both Hero and persistent 1400px presentation callbacks;
- Build225/226 moved target Hero first presentation out of active finger tracking and produced a large real-device hand-feel improvement;
- Build227 still showed slow-drag title shimmer / cadence variability, while exact source still mounted the target persistent only after `transitionToID` appeared;
- `carouselPersistentImage` remains a full-screen 1400px presentation with `scaleEffect(1.12)` and `blur(radius: 30)`, so target persistent first presentation is the remaining directly evidenced heavyweight mount in the drag path.

Exact runtime change: `persistentCarouselBackdrop(size:)` now iterates `carouselHeroResidentItems` and applies the unchanged `carouselOpacity(for:)` to each persistent image. This keeps normal outgoing→incoming backdrop crossfade and does **not** repeat Build221's frozen-outgoing-backdrop visual mismatch. No new residency state is added; the existing derived current/previous/next window is reused.

Retained contracts: Build226 Hero residency, raw acquisition-relative foreground X, normal foreground opacity, Build228 max-refresh-through-settle, existing 0.22s/0.18s release tail, 0.28 commit threshold, 0.48×width predicted-distance gate, preload, shared `EmbyCachedRemoteImage`, and all P0/Frozen playback/transport/session paths are unchanged. Build227 physical-pixel rounding remains absent.

CI / package evidence:

- branch: `perf/home-carousel-persistent-residency-build230`;
- exact base: cleaned carousel Build228 head `e957a11325e5d605cec794b89b26ffc36cd96c06`;
- exact tested source: `6324bb2063bf1631b8b922abc8e11149bd7a86b0`;
- dedicated Xcode 16.4 run/job: `33167765310 / 98837170851` — success;
- artifact: `OnePlayer-0.14.63-build230-persistent-residency`, ID `9684378135`;
- artifact SHA-256: `7b822dc1e1555705e0a794ea57214da666b6f320813b01b61aacb058f95f1378`;
- IPA SHA-256: `6cea81f8e806ec159d9e811871076c18aa41fceb99b3c621516c490cfc339b4e`;
- source ZIP SHA-256: `f0955926306e502d34e1835d9b5daffd7499c5bdc15abede9b31744eba9ee4ec`;
- independent package reopen confirms OnePlayer `0.14.63 (230)`, bundle `com.embyplayerlab.app`, `MinimumOSVersion=15.0`, `CADisableMinimumFrameDurationOnPhone=true`, and IPA/source checksum integrity;
- independent source reopen confirms two uses of the same three-slot residency window (Hero + persistent), normal persistent opacity crossfade, blur30 retained, Build228 release-through-settle retained, 0.28/0.48 release rules retained, and Build227 pixel rounding absent.

Important target-device risk to watch: after a committed settle, the current/previous/next window rotates and a new far-neighbor persistent presentation becomes resident outside direct finger tracking. If Build230 merely moves a visible hitch to immediately after settle, or the extra resident blurred layers increase compositor/memory pressure, reject this implementation even if active drag improves.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device pending ❌ / diagnostic candidate / stable ❌.'''

if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    text = subprocess.check_output(['git', 'show', 'origin/main:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True)
    text = re.sub(r'^\*\*Active — .*?\*\*$', '**Active — Build230 / 0.14.63 is the current horizontal persistent-residency A/B. Build226 three-slot Hero residency and Build228 max-refresh-through-settle remain the accepted-for-now foundation; Build227 pixel rounding remains rejected. Build230 reuses the same current+previous+next resident window for the full-screen blurred persistent backdrop while preserving normal crossfade, specifically to move target persistent first presentation out of active finger tracking. CI/IPA is verified; target-device slow-drag/title-shimmer + overall-feel + post-settle A/B pending. Build216 remains the accepted overall runtime baseline.**', text, count=1, flags=re.M)
    if '- Working branch:' not in text[:1200]:
        marker = '- Work ID: `DEV-home-carousel-drag-smoothness`\n'
        text = text.replace(marker, marker + '- Working branch: `perf/home-carousel-persistent-residency-build230`\n- Current candidate: OnePlayer `0.14.63 (230)`\n', 1)
    if '## Build230 / 0.14.63 — persistent three-slot residency A/B' not in text:
        anchor = '\n## Rejected directions not to repeat'
        if anchor not in text: raise SystemExit('checkpoint rejected-directions anchor missing')
        text = text.replace(anchor, '\n\n' + build230 + anchor, 1)
    next_start = text.index('## Next exact action')
    text = text[:next_start] + '''## Next exact action\n\nInstall Build230 on iPhone 15 Pro Max / iOS 17.0 and compare directly with carousel Build228/Build226 and EX. First reproduce the known very-slow horizontal drag on a fallback-title item and judge whether the large white movie-title shimmer materially decreases; also judge metadata/overview coherence and the overall sustained finger-tracking fineness. Then test rapid reversal and repeated adjacent transitions. Finally watch the first 200–500 ms **after a committed settle** for any new hitch caused by the resident window rotating a new far-neighbor persistent surface. Export the App log after the test: active-drag `image_roles` should no longer need a newly mounted target persistent callback if residency is behaving as intended. Accept only if active-drag fineness/title stability improves without a new post-settle hitch or visual/memory regression. If essentially unchanged, reject persistent residency as sufficient and return to foreground compositing/presentation investigation; do not stack drawing-group/easing/timer/interpolation on Build230 before this A/B.\n'''
    p.write_text(text)
    raise SystemExit(0)

if MODE != 'main': raise SystemExit(f'unknown mode {MODE}')

checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
checkpoint.write_text(subprocess.check_output(['git', 'show', f'origin/{BRANCH}:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True))

module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
carousel = '| Home carousel interaction | **Active — Build230 persistent-residency CI/IPA verified; target-device pending** | Build226 three-slot Hero residency remains the materially positive presentation foundation and carousel Build228 max-refresh-through-settle is accepted-for-now for the release tail. Build227 physical-pixel X rounding remains rejected because slow-drag title shimmer persisted. Build230 / 0.14.63 reuses the existing current+previous+next resident window for the full-screen blurred persistent backdrop while preserving normal current→target crossfade, moving target persistent first presentation out of active finger tracking without adding state or changing release/input contracts. Tested source `6324bb2063bf1631b8b922abc8e11149bd7a86b0`; run/job `33167765310 / 98837170851`; artifact `9684378135`; IPA SHA-256 `6cea81f8e806ec159d9e811871076c18aa41fceb99b3c621516c490cfc339b4e`; MinOS 15.0 independently verified. Target-device must check slow-drag title shimmer/overall fineness and any new post-settle hitch from resident-window rotation; not stable. |'
other = '| Other product modules | Active parallel work | Build216 / 0.14.49 remains the latest accepted overall runtime baseline. Home-carousel Build230 is the current CI/IPA-verified persistent-residency candidate on top of the positive Build226 residency + accepted-for-now Build228 release-tail foundation. Poster-scroll Build229 remains a separate Active line, and Aether has no Build candidate allocated. Build230 does not touch shared poster-image infrastructure or Player/Transport/Cache/Session/P0/Frozen source. |'
for i,line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'): lines[i] = carousel
    elif line.startswith('| Other product modules |'): lines[i] = other
module.write_text('\n'.join(lines) + '\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
lines = index.read_text().splitlines()
row230 = '| **Carousel Build230 / 0.14.63** | Home-carousel persistent three-slot residency A/B | **CI/IPA verified; target-device slow-drag/title-shimmer + overall-feel + post-settle A/B pending; diagnostic only, not stable.** Starts from cleaned carousel Build228. `persistentCarouselBackdrop` reuses the existing current+previous+next residency window and unchanged `carouselOpacity`, so both adjacent persistent 1400px/blur30 surfaces are mounted before horizontal acquisition while normal backdrop crossfade remains. Build226 Hero residency, Build228 max-refresh-through-settle, acquisition-relative foreground, 0.28/0.48 release rules, preload and shared loader are unchanged; Build227 pixel rounding is absent. Tested source `6324bb2063bf1631b8b922abc8e11149bd7a86b0`; run/job `33167765310 / 98837170851`; artifact `9684378135`; artifact SHA-256 `7b822dc1e1555705e0a794ea57214da666b6f320813b01b61aacb058f95f1378`; IPA SHA-256 `6cea81f8e806ec159d9e811871076c18aa41fceb99b3c621516c490cfc339b4e`; source ZIP SHA-256 `f0955926306e502d34e1835d9b5daffd7499c5bdc15abede9b31744eba9ee4ec`; OnePlayer 0.14.63 (230), MinOS 15.0 independently verified. Watch for a new post-settle hitch when the resident window rotates. |'
if not any(line.startswith('| **Carousel Build230 / 0.14.63**') for line in lines):
    i = next(i for i,line in enumerate(lines) if line.startswith('| **Carousel Build228 / 0.14.61**'))
    lines.insert(i + 1, row230)
else:
    lines = [row230 if line.startswith('| **Carousel Build230 / 0.14.63**') else line for line in lines]
index.write_text('\n'.join(lines) + '\n')

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(r'^_Last updated.*_$', '_Last updated after carousel Build230 / 0.14.63 persistent-residency CI/IPA verification, alongside the existing poster Build229 line. Build216 remains the accepted overall runtime baseline. Carousel Build226 Hero residency + Build228 release-through-settle remain the positive foundation; Build230 moves adjacent persistent first presentation out of active drag and awaits target-device slow-drag/post-settle A/B._', text, count=1, flags=re.M)
section = '''### Carousel Build230 persistent residency — CI/IPA candidate\n\nBuild230 / 0.14.63 starts from the cleaned carousel Build228 foundation and reuses the existing current+previous+next resident window for `persistentCarouselBackdrop`. Normal current→target persistent opacity blending is unchanged; unlike Build221, the outgoing background is not frozen. This moves the adjacent target persistent 1400px + `scaleEffect(1.12)` + `blur(radius: 30)` presentation creation out of active finger tracking without adding another residency owner.\n\nThis candidate follows the remaining evidence after Build226: Hero first presentation was already moved out of active drag and improved hand feel, while Build227 still showed slow-drag title shimmer/cadence variability and exact source still created target persistent only after a drag transition began. Build230 does not claim the title is itself a persistent-layer bug; it tests whether the visible title shimmer is a high-contrast symptom of remaining whole-page cadence stalls.\n\nCI/package: tested source `6324bb2063bf1631b8b922abc8e11149bd7a86b0`; Xcode 16.4 run/job `33167765310 / 98837170851` success; artifact `9684378135`; IPA SHA-256 `6cea81f8e806ec159d9e811871076c18aa41fceb99b3c621516c490cfc339b4e`; source ZIP SHA-256 `f0955926306e502d34e1835d9b5daffd7499c5bdc15abede9b31744eba9ee4ec`; OnePlayer 0.14.63 (230), MinOS 15.0 independently verified. Real-device pending. Acceptance must include both active-drag improvement and absence of a new post-settle hitch when the resident window rotates a new far neighbor.\n\n'''
anchor = '## Active: Poster-heavy scrolling smoothness'
if '### Carousel Build230 persistent residency — CI/IPA candidate' not in text:
    if anchor not in text: raise SystemExit('PROJECT_STATE carousel/poster anchor missing')
    text = text.replace(anchor, section + anchor, 1)
state.write_text(text)

decisions = Path('docs/project/TECHNICAL_DECISIONS.md')
text = decisions.read_text()
paragraph = '''\nBuild230 is the next diagnostic implementation of the same presentation-lifecycle principle, not yet a frozen contract. The existing derived current+previous+next residency window is reused for the persistent blurred backdrop so the adjacent target persistent surface is mounted before active drag while normal opacity crossfade remains. This is specifically different from rejected Build221: no outgoing-background freeze or visual mismatch is introduced. Accept this only if target-device testing improves active-drag cadence/title stability without moving the hitch to post-settle resident-window rotation or adding unacceptable compositor/memory pressure.\n'''
anchor = 'Because an independent poster task also used `Build228 / 0.14.61`, future evidence must attribute the carousel package by branch `perf/home-carousel-release-refresh-build228`, tested source `bdf63c7562fcd1edc1d224872230e988ac462281`, run/job `33156739621 / 98801196041` and artifact `9679963420`, not by build number alone.\n'
if paragraph.strip() not in text:
    if anchor not in text: raise SystemExit('TECHNICAL_DECISIONS Build228 anchor missing')
    text = text.replace(anchor, anchor + paragraph, 1)
decisions.write_text(text)
