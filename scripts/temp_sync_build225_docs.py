from pathlib import Path
import re
import subprocess
import sys

MODE = sys.argv[1]
BRANCH = 'diag/home-carousel-hero-drag-isolation-build225'

if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    text = p.read_text()
    text = re.sub(
        r'^\*\*Active — Build225 / 0\.14\.58.*?\*\*$',
        '**Active — Build225 / 0.14.58 is CI/IPA verified as the current horizontal target-Hero presentation A/B and awaits target-device horizontal testing. It uses the exact Build219 120Hz carousel line, restores normal persistent current/target crossfade, and changes only drag-time Hero mounting: the already-visible current Hero stays opaque while target Hero clear 1400px artwork is not mounted until drag ends. Build221 is horizontally real-device tested and rejected as final because overall feel still trails EX and the frozen-persistent experiment caused a pale/white transition regression. Build222–224 remain supporting vertical diagnostics only. Build216 remains the accepted overall runtime baseline.**',
        text,
        count=1,
        flags=re.M,
    )
    old = 'Evidence: Code written ✅ / exact source scope review pending CI checker / CI pending / IPA pending / real-device pending / stable ❌.'
    new = '''CI / package evidence:\n\n- exact tested source: `350fd5d07ae2e77907bcf497deb819dfea6a28b1`;\n- dedicated Xcode 16.4 run/job: `33149313932 / 98777365879` — success;\n- artifact: `OnePlayer-0.14.58-build225-hero-drag-isolation`, ID `9677114082`;\n- artifact SHA-256: `5e6d94602ef2c08ff3611bb8d749c6c9bd69df8a5f5bdeb089677ffa15cf3914`;\n- IPA SHA-256: `221162e47de335b665cad6e0dd48aa82a8e27bb50cadcc24c2c6888d26db000a`;\n- source ZIP SHA-256: `2849308d7a8e8f5c479a17e30ef6645bcf87f5f358065ba8b6dba7608623095e`;\n- independent package reopen confirms bundle `com.embyplayerlab.app`, OnePlayer `0.14.58 (225)`, `MinimumOSVersion=15.0`, `CADisableMinimumFrameDurationOnPhone=true`;\n- independent source reopen confirms target-Hero suppression only during active drag, normal persistent target crossfade retained, Build219 exact max-refresh retained, acquisition-relative render retained, and 0.28/0.48 release gates retained.\n\nThe earlier Build225 Action attempts were CI harness/setup failures before compilation (hard-coded Build219 version assertion and then non-idempotent patch helper) and are superseded by the successful dedicated run above; they are not product runtime evidence.\n\nEvidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device pending ❌ / stable ❌.'''
    if old not in text:
        raise SystemExit('Build225 pending evidence marker not found')
    text = text.replace(old, new, 1)
    text = text.replace(
        'Run the dedicated Build225 Xcode 16.4 CI/IPA and independently verify package identity/MinOS/source scope. If CI/IPA succeeds, test only horizontal carousel interaction on iPhone 15 Pro Max / iOS 17.0. Compare sustained tracking and the “smooth glass vs rough paper” gap against Build221/EX; also note visual continuity during drag and release/settle separately. Do not use Home vertical inertial scrolling as the acceptance gate.',
        'Install the CI/IPA-verified Build225 on iPhone 15 Pro Max / iOS 17.0 and test only horizontal carousel interaction. Compare first movement, sustained tracking, rapid reversal and the “smooth glass vs rough paper” gap against Build221/EX. During active drag the outgoing clear Hero is intentionally held while the incoming clear Hero is deferred until release; persistent background transition is normal again. Evaluate drag-time feel and release/settle separately. Do not use Home vertical inertial scrolling as the acceptance gate.'
    )
    p.write_text(text)
    raise SystemExit(0)

if MODE != 'main':
    raise SystemExit(f'unknown mode: {MODE}')

checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
checkpoint.write_text(subprocess.check_output(['git', 'show', f'origin/{BRANCH}:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True))

module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
carousel = '| Home carousel interaction | **Active — Build225 target-Hero horizontal A/B CI/IPA verified; target-device pending** | Build221 / 0.14.54 is now horizontally real-device tested: initial take-up is acceptable but overall feel still trails EX, and its frozen-persistent drag strategy visibly introduces a pale/white washed intermediate state, so that strategy is rejected as final. Build225 / 0.14.58 returns to the exact Build219 120Hz line, restores normal persistent current/target crossfade, keeps the visible current Hero opaque during active drag and defers only target Hero clear 1400px mounting until release. Run/job `33149313932 / 98777365879` succeeded; tested source `350fd5d07ae2e77907bcf497deb819dfea6a28b1`; artifact `9677114082`; IPA SHA-256 `221162e47de335b665cad6e0dd48aa82a8e27bb50cadcc24c2c6888d26db000a`; MinOS 15.0 independently verified. Horizontal real-device test pending; not stable. |'
other = '| Other product modules | Active parallel work | Build216 / 0.14.49 remains the latest accepted overall runtime baseline. Home-carousel Build225 is the current CI/IPA-verified horizontal A/B pending target-device test; Build221 is horizontally tested and rejected as final, while Build222–224 are supporting vertical diagnostics only. Poster-scroll Build220 remains a separate Active line. `EmbySharedImageAndNavigation.swift` remains shared infrastructure, so whichever Active task integrates second must resync against then-current `main` and rerun affected validation. |'
for i, line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i] = carousel
    elif line.startswith('| Other product modules |'):
        lines[i] = other
module.write_text('\n'.join(lines) + '\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
lines = index.read_text().splitlines()
row = '| **Build225 / 0.14.58** | Home-carousel target-Hero drag presentation isolation | **CI/IPA verified; target-device horizontal A/B pending; diagnostic only, not stable.** Based on exact Build219 tested 120Hz source. Normal persistent current/target crossfade is restored. During active horizontal drag the already-visible current Hero stays opaque and only target `carouselHeroArtwork` 1400px clear-image mounting is deferred until drag ends; foreground motion, acquisition-relative input, 0.28/0.48 release semantics, preload and exact device-max refresh request are unchanged. Tested source `350fd5d07ae2e77907bcf497deb819dfea6a28b1`; run/job `33149313932 / 98777365879`; artifact `9677114082`; artifact SHA-256 `5e6d94602ef2c08ff3611bb8d749c6c9bd69df8a5f5bdeb089677ffa15cf3914`; IPA SHA-256 `221162e47de335b665cad6e0dd48aa82a8e27bb50cadcc24c2c6888d26db000a`; source ZIP SHA-256 `2849308d7a8e8f5c479a17e30ef6645bcf87f5f358065ba8b6dba7608623095e`; OnePlayer 0.14.58 (225), MinOS 15.0 independently verified. |'
if any(line.startswith('| **Build225 / 0.14.58**') for line in lines):
    lines = [row if line.startswith('| **Build225 / 0.14.58**') else line for line in lines]
else:
    insert_at = next(i for i, line in enumerate(lines) if line.startswith('| **Build224 / 0.14.57**')) + 1
    lines.insert(insert_at, row)
index.write_text('\n'.join(lines) + '\n')

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(
    r'^_Last updated.*_$',
    '_Last updated after Build225 / 0.14.58 horizontal target-Hero A/B CI/IPA verification. Build216 remains the accepted overall runtime baseline. Build221 is horizontally real-device tested and rejected as the final frozen-persistent strategy because overall feel still trails EX and a pale/white transition regression is visible. Build225 restores normal persistent crossfade and defers only target Hero clear-image mounting during active horizontal drag; target-device horizontal testing is pending. Build222–224 remain supporting vertical diagnostics only._',
    text,
    count=1,
    flags=re.M,
)
build225 = '''\n### Build225 horizontal target-Hero A/B\n\nBuild225 / 0.14.58 branches from the exact Build219 tested 120Hz carousel source rather than stacking Build221 or the vertical Build222–224 experiments. Normal persistent current/target crossfade is restored. During active horizontal drag the already-visible current Hero remains opaque and target `carouselHeroArtwork` 1400px clear-image mounting is deferred until drag ends; foreground page motion, acquisition-relative input, release gates, preload and exact device-max refresh remain unchanged. Dedicated Xcode 16.4 run/job `33149313932 / 98777365879` succeeded; tested source `350fd5d07ae2e77907bcf497deb819dfea6a28b1`; artifact `9677114082`; artifact SHA-256 `5e6d94602ef2c08ff3611bb8d749c6c9bd69df8a5f5bdeb089677ffa15cf3914`; IPA SHA-256 `221162e47de335b665cad6e0dd48aa82a8e27bb50cadcc24c2c6888d26db000a`; source ZIP SHA-256 `2849308d7a8e8f5c479a17e30ef6645bcf87f5f358065ba8b6dba7608623095e`; OnePlayer 0.14.58 (225) and MinOS 15.0 were independently verified. Evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / diagnostic only / not stable**. Next action is target-device horizontal carousel A/B only.\n'''
marker = '\n## Active: Poster-heavy scrolling smoothness\n'
if '### Build225 horizontal target-Hero A/B' not in text:
    text = text.replace(marker, build225 + marker, 1)
text = text.replace(
    'Home-carousel acceptance is horizontal drag/swipe behavior; Build221 horizontal A/B is now real-device tested and rejected as final, so the next direct carousel A/B should isolate Hero presentation; Build222–224 remain supporting vertical diagnostics only;',
    'Home-carousel acceptance is horizontal drag/swipe behavior; Build225 is the current CI/IPA-verified target-Hero horizontal A/B pending target-device testing; Build221 is real-device rejected as final and Build222–224 remain supporting vertical diagnostics only;'
)
state.write_text(text)

decisions = Path('docs/project/TECHNICAL_DECISIONS.md')
text = decisions.read_text()
old = '''Build219's strongest remaining repeatable pattern is a 50 ms display gap about 19.6–25.3 ms after persistent 1400px callbacks. Exact source inspection shows target persistent first presentation is a separate full-screen `EmbyCachedRemoteImage` with `scaleEffect(1.12)` + `blur(radius: 30)`, while Build212 had already measured callback/contrast synchronous work at only ~1–3 ms. Build221 therefore isolates this presentation during active drag only by keeping current persistent opaque and not mounting target persistent; Hero remains unchanged and the normal persistent transition resumes after release. This is a **diagnostic A/B, not an accepted visual contract** until target-device logs prove the causal effect.'''
new = '''Build219's strongest remaining repeatable pattern is a 50 ms display gap about 19.6–25.3 ms after persistent 1400px callbacks, while other residual gaps also cluster near Hero callbacks. Build221 directly isolated persistent presentation during active horizontal drag by keeping current persistent opaque and not mounting target persistent. Target-device testing found acceptable initial take-up but overall feel still behind EX, and the supplied recording shows a pale/white washed intermediate state because Hero continues crossfading over a frozen outgoing persistent backing. Therefore the whole-drag frozen-persistent strategy is **rejected as the final visual/performance contract**; this does not prove persistent has zero cost, only that freezing it is insufficient and visually wrong.

Build225 is the next narrow horizontal diagnostic from the exact Build219 tested 120Hz line: restore normal persistent current/target crossfade, keep the already-visible current Hero opaque during active drag, and defer only target Hero clear 1400px mounting until drag ends. This isolates target-Hero first presentation without changing the one-UIKit-owner input path, acquisition-relative motion, foreground page travel, release semantics, preload or exact device-max refresh request. Build225 passed dedicated CI/IPA but remains diagnostic until target-device horizontal testing.'''
if old not in text:
    raise SystemExit('D012 Build221 paragraph not found')
text = text.replace(old, new, 1)
text = text.replace(
    '- **Consequence:** do not create another vertical-only carousel candidate before testing the existing Build221 horizontal A/B. Horizontal evaluation must cover first movement, sustained tracking, reversal, backdrop/foreground continuity and release/settle.\n- **Evidence:** latest user target-device feedback outranks the prior diagnostic plan. Build224 has real-device vertical-only evidence but no horizontal carousel verdict.',
    '- **Consequence:** do not return to vertical-only carousel candidates. Build221 has now been horizontally tested and rejected as the final frozen-persistent strategy; the current direct horizontal A/B is Build225 target-Hero presentation isolation. Horizontal evaluation must cover first movement, sustained tracking, reversal, backdrop/foreground continuity and release/settle.\n- **Evidence:** latest user target-device feedback outranks the prior diagnostic plan. Build221 now has direct horizontal real-device evidence; Build225 has Code/CI/IPA evidence and awaits horizontal real-device testing.'
)
decisions.write_text(text)
