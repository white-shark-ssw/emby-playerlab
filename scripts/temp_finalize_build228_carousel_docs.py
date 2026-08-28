from pathlib import Path
import re
import subprocess
import sys

MODE = sys.argv[1]
BRANCH = 'perf/home-carousel-release-refresh-build228'

STATUS = '**Active — Build228 / 0.14.61 release-tail behavior is now target-device accepted for now: the user reports the post-release tail is “差不多了，尾巴这里先这样吧”. Keep Build226 three-slot Hero residency and Build228 max-refresh-through-settle as the current carousel foundation, and stop further release-tail easing/duration/velocity tuning unless new regression evidence appears. Build227 physical-pixel foreground rounding is rejected because movie-title shimmer remained. The carousel task stays Active because slow-drag movie-title shimmer and the remaining overall refinement gap versus EX are still open. Build216 remains the accepted overall runtime baseline.**'

RESULT = '''### 2026-08-28 target-device result — release tail accepted for now

User feedback on iPhone 15 Pro Max / iOS 17.0 after testing the carousel Build228 package: **“差不多了，尾巴这里先这样吧。”** This is acceptance of the release-tail subproblem for the current phase, not acceptance of the entire carousel task.

Controlling conclusion:

- retain Build226 current+previous+next clear-Hero residency as the current presentation foundation;
- retain Build228's extension of the already-proven device-max refresh request through interactive settle/cancel instead of ending it at `touchesEnded`;
- do **not** continue tuning the existing 0.22 s commit / 0.18 s cancel duration, easing or release-velocity mapping without new regression evidence;
- Build227 physical-pixel foreground X rounding remains rejected because the movie-title shimmer was still visible;
- slow-drag movie-title shimmer and the remaining overall feel gap versus EX remain open, so the Home carousel module is still Active and not Stable/frozen as a whole.

Attribution warning: a parallel poster-scroll task also used the identity `Build228 / 0.14.61`. For this carousel result, use branch `perf/home-carousel-release-refresh-build228`, exact tested source `bdf63c7562fcd1edc1d224872230e988ac462281`, run/job `33156739621 / 98801196041`, artifact `9679963420`, and IPA SHA-256 `cda90b62e3cabd3199e1cfbc1b2e1c77b8a84d023a7c7b9c8e2ff66ab9edcf44`; never attribute by build number alone.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / horizontal real-device tested ✅ / release-tail subproblem accepted-for-now ✅ / whole carousel stable ❌.'''


def patch_checkpoint(text: str) -> str:
    text = re.sub(r'^\*\*Active — Build(?:227|228) / 0\.14\.(?:60|61).*?\*\*$', STATUS, text, count=1, flags=re.M)
    marker = '### 2026-08-28 target-device result — release tail accepted for now'
    if marker not in text:
        build228 = text.find('## Build228 / 0.14.61 — release-tail max-refresh lifecycle A/B')
        rejected = text.find('\n## Rejected directions not to repeat')
        if build228 >= 0 and rejected > build228:
            text = text[:rejected] + '\n\n' + RESULT + text[rejected:]
        else:
            raise SystemExit('checkpoint Build228/rejected anchor missing')
    next_start = text.find('## Next exact action')
    if next_start >= 0:
        text = text[:next_start] + '''## Next exact action

Keep the Build228 release-tail behavior unchanged for now. The next carousel investigation, when resumed, must focus on the still-visible slow-drag movie-title shimmer / residual active-drag cadence rather than release-tail easing, duration or velocity. Start from the Build226 residency + Build228 release-refresh foundation, do not reintroduce Build227 pixel quantization, and continue using horizontal target-device comparison against EX as the acceptance path.\n'''
    return text


if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    p.write_text(patch_checkpoint(p.read_text()))
    raise SystemExit(0)

if MODE != 'main':
    raise SystemExit(f'unknown mode: {MODE}')

# Current feature checkpoint is authoritative for this active work item.
checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
checkpoint.write_text(subprocess.check_output(['git', 'show', f'origin/{BRANCH}:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True))

# Module status: update only carousel + summary rows; preserve independent poster lane verbatim.
module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
carousel = '| Home carousel interaction | **Active — Build228 release tail accepted-for-now; title shimmer remains open** | Build226 / 0.14.59 remains the materially positive three-slot Hero-residency foundation. Build227 / 0.14.60 target-device testing showed physical-pixel foreground X rounding did not remove slow-drag movie-title shimmer, so that diagnostic is rejected. Carousel Build228 / 0.14.61 returns to Build226 presentation and keeps the proven device-max refresh request alive through interactive settle/cancel; the user now says the release tail is “差不多了，尾巴这里先这样吧”, so release-tail easing/duration/velocity tuning is paused and this lifecycle is retained unless new regression evidence appears. The overall carousel remains Active because title shimmer and residual refinement versus EX remain. Attribution must use branch `perf/home-carousel-release-refresh-build228`, tested source `bdf63c7562fcd1edc1d224872230e988ac462281`, run/job `33156739621 / 98801196041`, artifact `9679963420`, IPA SHA-256 `cda90b62e3cabd3199e1cfbc1b2e1c77b8a84d023a7c7b9c8e2ff66ab9edcf44`; a parallel poster task also used Build228/0.14.61. |'
other = '| Other product modules | Active parallel work | Build216 / 0.14.49 remains the latest accepted overall runtime baseline. Home-carousel Build226 residency + carousel Build228 release-refresh is the current horizontally tested foundation; release-tail tuning is accepted-for-now, while title shimmer remains open. Poster-scroll Build229 remains a separate Active line. Because carousel and poster work both used Build228/0.14.61 on different branches, never attribute Build228 by number alone. |'
for i, line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'): lines[i] = carousel
    elif line.startswith('| Other product modules |'): lines[i] = other
module.write_text('\n'.join(lines) + '\n')

# Build/test index: preserve poster Build228 row and add a separately named carousel row.
index = Path('docs/project/BUILD_TEST_INDEX.md')
lines = index.read_text().splitlines()
row227 = '| **Build227 / 0.14.60** | Home-carousel foreground physical-pixel alignment A/B | **Horizontal real-device tested; title shimmer remains; pixel-rounding hypothesis rejected as sufficient; not stable.** Only final foreground-page X was rounded to the display pixel grid on top of Build226 residency. User still sees movie-title jitter, so this diagnostic must not be retained as the title fix. Tested source `7ac8de30b76192ee3cd9c9382edca74b9ff5e69d`; run/job `33153825917 / 98791806487`; artifact `9678871748`; IPA SHA-256 `b24d8abcd91f4faa74e06d8485bac3611725c561d9c99144c17def4b8ef26766`; MinOS 15.0. |'
row228 = '| **Carousel Build228 / 0.14.61** | Home-carousel release-tail max-refresh lifecycle | **Horizontal real-device tested; release tail accepted-for-now; whole carousel still Active.** Returns to Build226 presentation, removes Build227 pixel rounding and retains the exact device-max refresh request through interactive settle/cancel instead of ending it at finger release. User verdict: “差不多了，尾巴这里先这样吧”; do not continue release-tail easing/duration/velocity tuning without new evidence. Slow-drag title shimmer remains open. Branch `perf/home-carousel-release-refresh-build228`; tested source `bdf63c7562fcd1edc1d224872230e988ac462281`; run/job `33156739621 / 98801196041`; artifact `9679963420`; artifact SHA-256 `0b3a3a2b4d38f5f0bbff4a406e1523e161f7f6600065b9e5ee9e00cd075938bc`; IPA SHA-256 `cda90b62e3cabd3199e1cfbc1b2e1c77b8a84d023a7c7b9c8e2ff66ab9edcf44`; source ZIP SHA-256 `d91b014486e5fb1c5c9798b2b56bf45f0bad4f9e47f433a9f862c5fa586ecf68`; MinOS 15.0. **Parallel poster work also used Build228/0.14.61; use branch/source/artifact for attribution.** |'
lines = [row227 if line.startswith('| **Build227 / 0.14.60**') else line for line in lines]
if any(line.startswith('| **Carousel Build228 / 0.14.61**') for line in lines):
    lines = [row228 if line.startswith('| **Carousel Build228 / 0.14.61**') else line for line in lines]
else:
    i = next(i for i, line in enumerate(lines) if line.startswith('| **Build227 / 0.14.60**'))
    lines.insert(i + 1, row228)
index.write_text('\n'.join(lines) + '\n')

# Project state: preserve poster status while recording the current carousel conclusion.
state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(r'^_Last updated.*_$', '_Last updated after the carousel Build228 / 0.14.61 target-device release-tail result, alongside the independent poster Build229 line. Build216 remains the accepted overall runtime baseline. Carousel Build226 residency + carousel Build228 max-refresh-through-settle is the current horizontal foundation; the user accepts the release tail for now, while slow-drag movie-title shimmer and residual refinement versus EX remain open. Parallel carousel/poster work both used Build228/0.14.61, so attribution must include branch/source/artifact._', text, count=1, flags=re.M)
marker = '### Carousel Build228 release-tail result — accepted for now'
if marker not in text:
    anchor = text.find('\n## Active: Poster-heavy scrolling smoothness')
    if anchor < 0: raise SystemExit('PROJECT_STATE poster anchor missing')
    block = '''\n### Carousel Build228 release-tail result — accepted for now\n\nCarousel Build228 / 0.14.61 (`perf/home-carousel-release-refresh-build228`) returns to the Build226 visual baseline and extends the already-proven device-max refresh request through interactive settle/cancel. Target-device feedback is **“差不多了，尾巴这里先这样吧”**. Treat this as acceptance of the release-tail subproblem for the current phase: retain max-refresh-through-settle and stop changing the existing 0.22 s commit / 0.18 s cancel easing, duration or velocity mapping unless new regression evidence appears.\n\nThis does **not** close the carousel task. Build227 physical-pixel foreground rounding is rejected because movie-title shimmer remained, and slow-drag title shimmer / residual overall refinement versus EX are still open. Build226 three-slot Hero residency remains the evidence-backed presentation foundation. Carousel Build228 evidence: tested source `bdf63c7562fcd1edc1d224872230e988ac462281`, run/job `33156739621 / 98801196041`, artifact `9679963420`, IPA SHA-256 `cda90b62e3cabd3199e1cfbc1b2e1c77b8a84d023a7c7b9c8e2ff66ab9edcf44`, MinOS 15.0. A separate poster task also used Build228/0.14.61; build number alone is not valid attribution.\n'''
    text = text[:anchor] + block + text[anchor:]
state.write_text(text)

# Technical decision: freeze only the release-tail sub-contract, not the entire carousel module.
decisions = Path('docs/project/TECHNICAL_DECISIONS.md')
text = decisions.read_text()
marker = 'Build228 target-device release-tail acceptance'
if marker not in text:
    anchor = text.find('\n## D013 —')
    if anchor < 0: raise SystemExit('TECHNICAL_DECISIONS D013 anchor missing')
    block = '''\nBuild227 target-device testing rejects physical-pixel foreground X quantization as a sufficient movie-title shimmer fix: the shimmer remains visible, so do not carry pixel-grid rounding forward without new evidence.\n\n**Build228 target-device release-tail acceptance:** exact Build227 source showed the device-max refresh request ended inside `touchesEnded` before the existing commit/cancel animation. Carousel Build228 returns to the Build226 presentation baseline and retains that same proven max-refresh request through interactive settle/cancel. The user now reports the release tail is “差不多了，尾巴这里先这样吧”. Therefore retain max-refresh-through-settle and stop further release-tail easing/duration/velocity tuning unless new regression evidence appears. This freezes only the release-tail sub-contract for the current phase; the Home carousel remains Active because slow-drag title shimmer and residual overall refinement versus EX are still unresolved.\n\nBecause an independent poster task also used `Build228 / 0.14.61`, future evidence must attribute the carousel package by branch `perf/home-carousel-release-refresh-build228`, tested source `bdf63c7562fcd1edc1d224872230e988ac462281`, run/job `33156739621 / 98801196041` and artifact `9679963420`, not by build number alone.\n'''
    text = text[:anchor] + block + text[anchor:]
decisions.write_text(text)
