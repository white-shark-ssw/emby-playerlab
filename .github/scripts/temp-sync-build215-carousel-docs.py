from pathlib import Path
import re

# Checkpoint
p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
s = p.read_text()
s = re.sub(r'\*\*Active — Build208 / 0\.14\.41.*?\*\*', '**Active — Build215 / 0.14.48 is the current carousel candidate. Build208 real-device video analysis proved the remaining EX gap was acquisition-origin + foreground-alpha behavior; Build215 implements acquisition-relative 1:1 render motion while preserving touch-down release authority, keeps full-width page slots, and decouples foreground alpha. CI/IPA are verified; real-device A/B is pending.**', s, count=1, flags=re.S)
marker = '## Next exact action'
if marker not in s: raise SystemExit('checkpoint marker missing')
head = s.split(marker, 1)[0].rstrip()
suffix = '''

## Build214 / Build215 implementation evidence

- Carousel Build214 / 0.14.47 was rebuilt cleanly from the Build208 durable source and passed CI/IPA verification, but was retired before distribution when independent poster work claimed that identity. Never use the carousel Build214 package for attribution.
- Current valid carousel identity: **OnePlayer 0.14.48 / Build215**.
- branch `perf/home-carousel-acquisition-relative-build215`.
- tested source / CI head **`d22634ece2f29eba2e60de01182bf15d4ba554a7`**; durable cleanup head **`01a13615fc056fd3b13296d98abfaa7a6aa2b46d`**, with temporary workflow deletion only between them.
- horizontal acquisition establishes the render baseline and does not publish the already accumulated touch-down distance.
- post-acquisition render is exactly `currentTranslation - acquisitionTranslation`; no whole-range easing/interpolator.
- release remains touch-down authoritative with the existing 0.28 commit and 0.48×width predicted-distance gate, including one-sample fast release.
- foreground transition pages stay opaque; backdrop crossfade remains independent; full-width `pageStep = width` and first↔last modulo ownership remain unchanged.
- no new state owner/timer/watchdog/retry/debounce/throttle and no P0/Frozen path change.
- run/job **`33058337107 / 98470624555` — success**; artifact ID **`9640692378`**; digest **`sha256:31a054244bcfbeb39cc5db663aa7580cb4cc742fe88ca998ce9c9ba7a01e2939`**.
- IPA SHA-256 **`6551a5e9e8a28a66bd4f105118387e8fc9378b72bd47778897f013b411c06c97`**; source ZIP SHA-256 **`00d2a0aba071dbbce3554d31dba64f0caa70c22b6e067dedeee0bb3b22ebd694`**.
- independent verification passed for artifact digest, embedded hashes, IPA archive, OnePlayer `0.14.48 (215)`, MinOS 15.0, icons and exact source contracts.
- evidence: **Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending / not stable.**

## Next exact action

Target-device A/B Build215 against the recorded Build208 and EX reference. Focus on first visible movement, post-acquisition 1:1 feel, foreground solidity, page separation, reversal through the acquisition baseline, cancel/commit including one-sample fast release, and first↔last wrapping. Do not retune easing/travel percentages before this device evidence.
'''
p.write_text(head + suffix)

# Module status: carousel row only.
p = Path('docs/project/MODULE_STATUS.md')
lines = p.read_text().splitlines()
row = '| Home carousel interaction | **Active — Build215 CI/IPA verified; real-device A/B pending** | Build208 video A/B isolated acquisition-origin and foreground-alpha behavior. Build215 / 0.14.48 retains the single UIKit lifecycle owner and full-width `pageStep = width`, establishes a horizontal acquisition render baseline, then uses `currentTranslation - acquisitionTranslation` for linear spatial tracking. Touch-down distance still owns 0.28 commit / 0.48×width predicted release, including one-sample fast release. Foreground pages remain opaque while backdrop blend is independent. Run/job `33058337107 / 98470624555`, artifact `9640692378`, IPA SHA `6551a5e9e8a28a66bd4f105118387e8fc9378b72bd47778897f013b411c06c97`; MinOS 15.0 verified. Real-device pending; not stable. Read `DEV-home-carousel-drag-smoothness`. |'
for i, line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i] = row
        break
else: raise SystemExit('module carousel row missing')
p.write_text('\n'.join(lines) + '\n')

# Project state: replace only carousel candidate block.
p = Path('docs/project/PROJECT_STATE.md')
s = p.read_text()
a = s.find('### Current carousel candidate:')
b = s.find('\n## Active: Poster-heavy scrolling smoothness', a)
if a < 0 or b < 0: raise SystemExit('project carousel bounds missing')
block = '''### Current carousel candidate: Build215 / 0.14.48

Build208 is now the real-device video reference rather than the current candidate. A/B versus EX showed a hold-then-jump acquisition and prolonged visual lag from the easing workaround, while EX behaved like a short take-up followed by nearly 1:1 motion and kept foreground substantially more opaque.

Build215 retains Build198 one-UIKit-owner lifecycle and Build208 full-width `pageStep = width`, but horizontal acquisition now establishes a render baseline and does not publish the already accumulated touch-down distance. Post-acquisition spatial motion is `currentTranslation - acquisitionTranslation`, with no whole-range easing. Release/commit remains touch-down based with the original 0.28 and 0.48×width gates, including one-sample fast release. Foreground transition pages remain opaque while backdrop crossfade is independent. Wrapping, cancellation/settle and P0/Frozen paths are unchanged.

Carousel Build214 / 0.14.47 passed CI/IPA but was retired before distribution because parallel poster work claimed that identity. Build215 is the valid carousel attribution package.

- tested source `d22634ece2f29eba2e60de01182bf15d4ba554a7`; durable cleanup head `01a13615fc056fd3b13296d98abfaa7a6aa2b46d` (workflow deletion only).
- run/job `33058337107 / 98470624555` — success.
- artifact ID `9640692378`; digest `sha256:31a054244bcfbeb39cc5db663aa7580cb4cc742fe88ca998ce9c9ba7a01e2939`.
- IPA SHA-256 `6551a5e9e8a28a66bd4f105118387e8fc9378b72bd47778897f013b411c06c97`; source ZIP SHA-256 `00d2a0aba071dbbce3554d31dba64f0caa70c22b6e067dedeee0bb3b22ebd694`.
- independent artifact/IPA/source/identity/MinOS/source-contract verification passed.
- evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / not stable**.

Next action: target-device A/B Build215 against Build208/EX; do not add another easing/travel-percentage workaround before that evidence.
'''
p.write_text(s[:a] + block + s[b:])

# Technical decision D012 only.
p = Path('docs/project/TECHNICAL_DECISIONS.md')
s = p.read_text()
a = s.find('## D012 —')
b = s.find('\n## D013 —', a)
if a < 0 or b < 0: raise SystemExit('D012 bounds missing')
d012 = '''## D012 — Home-carousel keeps one UIKit owner; full-width page slots use acquisition-relative render motion

Retain Build198 lifecycle ownership and Build208 full-width `pageStep = width`. Horizontal acquisition remains UIKit-owned; vertical acquisition yields to the Home `UIScrollView`; predicted touch stays release-only; one `V3HomeCarouselTransitionState` remains the high-frequency owner; first↔last modulo ownership and settle/cancel semantics remain unchanged. Do not add a second SwiftUI owner, timer, watchdog, retry, interpolation, debounce or throttle.

Build208 vs EX real-device video rejected whole-range easing as the remaining fix: OnePlayer published touch-down translation already accumulated before horizontal acquisition, creating a hold-then-jump start, then visually lagged; EX behaved like a short take-up followed by nearly 1:1 motion. EX also kept foreground near opaque while OnePlayer tied foreground fade to the compensating visual progress.

Build215 therefore establishes the current evidence-backed contract: acquisition records `horizontalAcquisitionTranslation` and publishes no acquisition movement; subsequent render is exactly `currentTranslation - acquisitionTranslation`; original touch-down distance still owns 0.28 commit and 0.48×width predicted release, including one-sample fast release; transition foreground pages remain opaque and backdrop crossfade is independent. Whole-range easing/travel-percentage tuning is rejected as the primary solution for first-sample coarseness.

Carousel Build214 / 0.14.47 passed CI/IPA but was retired before distribution due identity collision with parallel poster work. Current carousel candidate is **Build215 / 0.14.48**, tested source `d22634ece2f29eba2e60de01182bf15d4ba554a7`, cleanup head `01a13615fc056fd3b13296d98abfaa7a6aa2b46d`; run/job `33058337107 / 98470624555`; artifact `9640692378`; IPA SHA `6551a5e9e8a28a66bd4f105118387e8fc9378b72bd47778897f013b411c06c97`; MinOS 15.0 verified. Evidence is **Code written / CI passed / IPA produced+verified / real-device pending / not stable**.

Do not call Build215 solved until target-device A/B confirms first-step size, linear feel, foreground solidity, reversal, release and wrapping behavior.
'''
p.write_text(s[:a] + d012 + s[b:])

# Build/Test index: table row plus detailed current candidate section.
p = Path('docs/project/BUILD_TEST_INDEX.md')
s = p.read_text()
lines = s.splitlines()
for i, line in enumerate(lines):
    if line.startswith('| **Build208 / 0.14.41** |'):
        lines[i] = '| **Build208 / 0.14.41** | Full-width carousel foreground page slots | **Real-device video tested; layout retained, final motion mapping rejected.** `pageStep = width` fixed structural overlap, but A/B vs EX showed hold-then-jump acquisition, prolonged easing lag and over-faded foreground. This evidence directly motivated Build215. |'
        break
else: raise SystemExit('Build208 row missing')
if not any(line.startswith('| **Build215 / 0.14.48** |') for line in lines):
    pos = next((i + 1 for i, line in enumerate(lines) if line.startswith('| **Build213 / 0.14.46** |')), None)
    if pos is None: raise SystemExit('Build213 row missing')
    lines.insert(pos, '| **Build215 / 0.14.48** | Acquisition-relative Home-carousel render + foreground-alpha decoupling | **Current carousel candidate.** Full-width page slots + single UIKit owner retained; render starts at horizontal acquisition and tracks `translation - acquisitionTranslation`, while 0.28/0.48 release stays touch-down based. Foreground stays opaque; backdrop blend is independent. CI/IPA verified; real-device pending. Carousel Build214 was retired due identity collision. |')
s = '\n'.join(lines) + '\n'
detail = '''### Build215 current carousel candidate

- identity **0.14.48 / Build215**; branch `perf/home-carousel-acquisition-relative-build215`.
- tested source **`d22634ece2f29eba2e60de01182bf15d4ba554a7`**; cleanup head **`01a13615fc056fd3b13296d98abfaa7a6aa2b46d`** with workflow deletion only.
- render baseline is horizontal acquisition; post-acquisition render is `currentTranslation - acquisitionTranslation`.
- touch-down distance retains 0.28 commit / 0.48×width predicted release, including one-sample fast release.
- foreground transition pages stay opaque; backdrop crossfade is separate; full-width `pageStep = width` retained.
- exact scope/Frozen guard passed; no Player/MPV/PiP/Transport/Cache/Session changes.
- run/job **`33058337107 / 98470624555` — success**; artifact ID **`9640692378`**, digest **`sha256:31a054244bcfbeb39cc5db663aa7580cb4cc742fe88ca998ce9c9ba7a01e2939`**.
- IPA SHA-256 **`6551a5e9e8a28a66bd4f105118387e8fc9378b72bd47778897f013b411c06c97`**; source ZIP SHA-256 **`00d2a0aba071dbbce3554d31dba64f0caa70c22b6e067dedeee0bb3b22ebd694`**.
- independent validation passed for artifact digest, embedded hashes, IPA archive, identity, MinOS 15.0 and exact source contracts.
- carousel Build214 / 0.14.47 also passed CI/IPA but was retired before distribution due identity collision; never use it for carousel attribution.
- evidence **Code written ✅ / scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending / not stable.**

'''
if '### Build215 current carousel candidate' not in s:
    marker = '## Poster-scroll evidence'
    if marker not in s: raise SystemExit('poster evidence marker missing')
    s = s.replace(marker, detail + marker, 1)
p.write_text(s)
