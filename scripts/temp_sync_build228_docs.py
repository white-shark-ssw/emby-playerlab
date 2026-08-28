from pathlib import Path
import re
import subprocess
import sys

MODE = sys.argv[1]
BRANCH = 'perf/home-carousel-release-refresh-build228'

build227 = '''## Build227 / 0.14.60 — foreground physical-pixel alignment A/B

Build227 rounded only the final foreground-page X offset to the current display physical-pixel grid while retaining Build226 Hero residency, normal Hero/persistent crossfades, Build215 acquisition-relative movement, Build219 device-max refresh request and the existing release rules.

CI / package evidence:

- branch: `diag/home-carousel-foreground-pixel-align-build227`;
- exact tested source: `7ac8de30b76192ee3cd9c9382edca74b9ff5e69d`;
- dedicated Xcode 16.4 run/job: `33153825917 / 98791806487` — success;
- artifact ID: `9678871748`;
- IPA SHA-256: `b24d8abcd91f4faa74e06d8485bac3611725c561d9c99144c17def4b8ef26766`;
- source ZIP SHA-256: `16bc14dd82cae7d2599f23fefaf7b5e4d9c95db6a17dbaa08921e3749f41d278`;
- OnePlayer `0.14.60 (227)`, MinOS 15.0 independently verified.

### 2026-08-28 horizontal real-device result

User feedback on iPhone 15 Pro Max / iOS 17.0: **movie-title text still has a visible jitter/shimmer feel**, so physical-pixel X rounding is rejected as a sufficient title-stability fix and must not be carried forward merely for that purpose. The same recording also exposes a second issue: after the finger is released, the automatic commit/cancel tail does not feel as silky as the active drag.

The accompanying Build227 App log shows that active drag still requests 120 fps, but slow/long drags are not uniformly perfect: one 6175.8 ms drag recorded `display_p95_gap_ms=25.01`, 177 display intervals >=12.5 ms and 41 >=20 ms; another 4642.0 ms drag kept p95 at 8.34 ms but still had a 39.58 ms maximum gap. This means the remaining title symptom cannot be reduced to a title-only geometry jump or solved by 1/3pt quantization alone.

More importantly, exact Build227 source inspection identifies a release-tail lifecycle discontinuity: the UIKit recognizer calls `V3HomeCarouselCadenceDiagnostics.shared.end(reason: "ended")` inside `touchesEnded` **before** `finishNativeCarouselDrag(...)` starts the existing 0.22 s commit / 0.18 s cancel animation. `end(...)` immediately invalidates the exact-max `CADisplayLink`, so Build219's proven high-refresh request covers active finger tracking but not the automatic release tail. The old cadence summary also ends at touch release, so it cannot measure the tail the user is now reporting.

Evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / horizontal real-device tested ✅ / title pixel-alignment hypothesis rejected as sufficient / release-tail cadence lifecycle issue identified in real source / stable ❌.'''

build228 = '''## Build228 / 0.14.61 — release-tail max-refresh lifecycle A/B

Build228 returns to the cleaned Build226 presentation baseline; Build227 physical-pixel rounding is intentionally absent. It changes only the lifetime of the already-proven Build219 device-max carousel refresh request:

- horizontal acquisition still starts the same exact-max `CADisplayLink` request;
- `touchesEnded` / ordinary `touchesCancelled` no longer invalidate that request before release handling;
- an interactive commit keeps the request until the existing 0.22 s animation reaches `settleCarousel`;
- an interactive cancel keeps it until the existing 0.18 s cancel completion;
- horizontal acquisition that ends without any transition releases immediately through explicit no-transition/no-target cleanup;
- no new timer, interpolation, retry, watchdog, fallback, gesture owner or duplicate state is introduced.

Build226 three-slot Hero residency, normal Hero/persistent crossfades, raw acquisition-relative foreground X, 0.28 commit threshold, 0.48×width predicted-distance gate and the existing 0.22/0.18 easing/durations are unchanged. This isolates refresh-request lifetime before changing release animation math.

CI / package evidence:

- branch: `perf/home-carousel-release-refresh-build228`;
- exact base: cleaned Build226 head `f9f1ecf6334c14641dbdf780a5b09a118495b8ec`;
- exact tested source: `bdf63c7562fcd1edc1d224872230e988ac462281`;
- dedicated Xcode 16.4 run/job: `33156739621 / 98801196041` — success;
- artifact: `OnePlayer-0.14.61-build228-release-refresh`, ID `9679963420`;
- artifact SHA-256: `0b3a3a2b4d38f5f0bbff4a406e1523e161f7f6600065b9e5ee9e00cd075938bc`;
- IPA SHA-256: `cda90b62e3cabd3199e1cfbc1b2e1c77b8a84d023a7c7b9c8e2ff66ab9edcf44`;
- source ZIP SHA-256: `d91b014486e5fb1c5c9798b2b56bf45f0bad4f9e47f433a9f862c5fa586ecf68`;
- independent package reopen confirms bundle `com.embyplayerlab.app`, OnePlayer `0.14.61 (228)`, `MinimumOSVersion=15.0` and `CADisableMinimumFrameDurationOnPhone=true`;
- independent source reopen confirms Build227 pixel rounding is absent, Build226 Hero residency remains, exact max-refresh remains, and the request now ends at interactive settle/cancel completion rather than touch release.

Build228 also makes the existing cadence log cover the automatic tail: successful commits should now end with `reason=settled`, and cancels with `reason=cancelled-settled`, so the next target-device log can directly measure tail display cadence.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device pending ❌ / diagnostic candidate / stable ❌.'''

if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    text = subprocess.check_output(['git', 'show', 'origin/main:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True)
    text = re.sub(r'^\*\*Active — Build227 / 0\.14\.60.*?\*\*$', '**Active — Build228 / 0.14.61 is the current horizontal release-tail max-refresh A/B. Build227 is now target-device tested and rejected as a title-shimmer fix: physical-pixel foreground X rounding did not remove the movie-title jitter. The same Build227 recording reveals a separate release-tail smoothness issue, and exact source inspection proves the proven device-max refresh request was invalidated at `touchesEnded` before the existing 0.22s/0.18s automatic settle/cancel animation. Build228 returns to the cleaned Build226 presentation baseline and changes only that refresh-request lifetime through settle/cancel. Build228 CI/IPA is verified; target-device test pending. Build216 remains the accepted overall runtime baseline.**', text, count=1, flags=re.M)
    start = text.index('## Build227 / 0.14.60 — foreground physical-pixel alignment A/B')
    end = text.index('\n## Rejected directions not to repeat', start)
    text = text[:start] + build227 + '\n\n' + build228 + text[end:]
    text = text.replace('- debounce/throttle/timer/interpolator/watchdog/retry smoothing.\n', '- debounce/throttle/timer/interpolator/watchdog/retry smoothing;\n- Build227 physical-pixel foreground X rounding as a sufficient movie-title shimmer fix.\n', 1)
    next_start = text.index('## Next exact action')
    text = text[:next_start] + '''## Next exact action

Install Build228 on iPhone 15 Pro Max / iOS 17.0 and compare directly with Build226/227. Primary acceptance is the **finger-release automatic tail**: test short committed swipes, longer committed drags, partial drags that cancel back, and rapid repeated adjacent-page transitions. Judge whether the moment after finger release now keeps the same fine cadence as active drag. Export the App log after the test; Build228 cadence summaries should end at `reason=settled` / `reason=cancelled-settled` and now include the release animation itself. Do not expect Build228 to directly fix the already-confirmed title shimmer because foreground text presentation during active drag is unchanged. If release tail improves materially, retain the extended high-refresh lifecycle and then return to the remaining title/cadence issue separately. If it does not, keep Build226 residency but inspect release velocity continuity / fixed-duration easing next; do not stack an easing change before this refresh-lifetime A/B is tested.\n'''
    p.write_text(text)
    raise SystemExit(0)

if MODE != 'main': raise SystemExit(f'unknown mode {MODE}')

checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
checkpoint.write_text(subprocess.check_output(['git', 'show', f'origin/{BRANCH}:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True))

module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
carousel = '| Home carousel interaction | **Active — Build226 residency positive; Build227 pixel-rounding rejected; Build228 release-tail max-refresh CI/IPA verified, target-device pending** | Build226 / 0.14.59 remains the materially positive visual-preserving direction: overall horizontal feel is fairly close to EX and much better than original. Build227 / 0.14.60 target-device testing found movie-title shimmer still present, rejecting physical-pixel foreground X rounding as sufficient. The same test reports non-silky automatic release tail; exact source proves the exact-max refresh `CADisplayLink` was invalidated in `touchesEnded` before the 0.22s/0.18s settle/cancel animation. Build228 / 0.14.61 returns to Build226 presentation and keeps that same max-refresh request alive through interactive settle/cancel. Run/job `33156739621 / 98801196041`; tested source `bdf63c7562fcd1edc1d224872230e988ac462281`; artifact `9679963420`; IPA SHA-256 `cda90b62e3cabd3199e1cfbc1b2e1c77b8a84d023a7c7b9c8e2ff66ab9edcf44`; MinOS 15.0 independently verified. Real-device pending; not stable. |'
other = '| Other product modules | Active parallel work | Build216 / 0.14.49 remains the latest accepted overall runtime baseline. Home-carousel Build226 remains the positive residency foundation; Build227 pixel rounding is rejected as sufficient; Build228 is the current CI/IPA-verified release-refresh candidate. Poster-scroll Build220 remains a separate Active line. Build228 does not touch shared poster-image infrastructure or any Player/Transport/Cache/Session/P0/Frozen source. |'
for i,line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'): lines[i] = carousel
    elif line.startswith('| Other product modules |'): lines[i] = other
module.write_text('\n'.join(lines) + '\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
lines = index.read_text().splitlines()
row227 = '| **Build227 / 0.14.60** | Home-carousel foreground physical-pixel alignment A/B | **Horizontal real-device tested; title shimmer remains; pixel-rounding hypothesis rejected as sufficient; release-tail roughness newly reported; not stable.** Only final foreground-page X was rounded to the display pixel grid. User still sees movie-title jitter. Same recording reports automatic post-release tail is not silky. Exact source shows the device-max diagnostic `CADisplayLink` was invalidated at `touchesEnded` before the 0.22s/0.18s release animation, so prior cadence logs did not cover that tail. Tested source `7ac8de30b76192ee3cd9c9382edca74b9ff5e69d`; run/job `33153825917 / 98791806487`; artifact `9678871748`; IPA SHA-256 `b24d8abcd91f4faa74e06d8485bac3611725c561d9c99144c17def4b8ef26766`; MinOS 15.0. |'
row228 = '| **Build228 / 0.14.61** | Home-carousel release-tail max-refresh lifecycle A/B | **CI/IPA verified; target-device release-tail A/B pending; diagnostic candidate, not stable.** Returns to cleaned Build226 presentation (no Build227 pixel rounding) and keeps the existing exact device-max carousel refresh request alive from horizontal acquisition through interactive commit/cancel settle rather than ending it at touch release. Hero residency, foreground math, normal Hero/persistent crossfades, 0.22/0.18 animations and 0.28/0.48 release rules are unchanged. Tested source `bdf63c7562fcd1edc1d224872230e988ac462281`; run/job `33156739621 / 98801196041`; artifact `9679963420`; artifact SHA-256 `0b3a3a2b4d38f5f0bbff4a406e1523e161f7f6600065b9e5ee9e00cd075938bc`; IPA SHA-256 `cda90b62e3cabd3199e1cfbc1b2e1c77b8a84d023a7c7b9c8e2ff66ab9edcf44`; source ZIP SHA-256 `d91b014486e5fb1c5c9798b2b56bf45f0bad4f9e47f433a9f862c5fa586ecf68`; OnePlayer 0.14.61 (228), MinOS 15.0 independently verified. |'
lines = [row227 if line.startswith('| **Build227 / 0.14.60**') else line for line in lines]
if any(line.startswith('| **Build228 / 0.14.61**') for line in lines): lines = [row228 if line.startswith('| **Build228 / 0.14.61**') else line for line in lines]
else:
    i = next(i for i,line in enumerate(lines) if line.startswith('| **Build227 / 0.14.60**'))
    lines.insert(i + 1, row228)
index.write_text('\n'.join(lines) + '\n')

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(r'^_Last updated.*_$', '_Last updated after Build227 / 0.14.60 target-device rejection of foreground pixel rounding and Build228 / 0.14.61 release-tail max-refresh CI/IPA verification. Build216 remains the accepted overall runtime baseline. Build226 residency remains the materially positive carousel foundation; Build227 title shimmer persists and the same test exposes non-silky post-release settling. Exact source shows max-refresh ended at touch release, so Build228 isolates extending that proven request through interactive settle/cancel._', text, count=1, flags=re.M)
start = text.index('### Build225 horizontal target-Hero A/B — positive real-device diagnostic')
end = text.index('\n## Active: Poster-heavy scrolling smoothness', start)
replacement = '''### Build225 horizontal target-Hero A/B — positive real-device diagnostic

Build225 established that deferring target clear-Hero first presentation out of active drag makes the carousel noticeably finer, proving active-drag target-Hero first presentation was a material contributor. Build225 itself remains diagnostic because incoming clear Hero was withheld until release.

### Build226 horizontal three-slot Hero residency — materially positive real-device foundation

Build226 / 0.14.59 keeps current+previous+next clear Heroes resident. Target-device testing reports overall carousel feel fairly close to EX and much better than original, validating residency as the current presentation direction. Slow-drag movie-title shimmer and further refinement remain, so Build226 is not stable/frozen.

### Build227 foreground pixel alignment — target-device rejected as sufficient

Build227 / 0.14.60 rounded only foreground-page X to physical pixels. Target-device feedback says the movie-title text **still jitters/shimmers**, so this hypothesis is rejected as a sufficient title fix. The same recording newly identifies that the automatic transition after finger release is not as silky as the active drag. The accompanying log still records 120-fps requests during active drag but includes long slow-drag cadence variability; the title issue is therefore not safely attributable to a standalone subpixel geometry problem.

Exact Build227 source shows a separate structural cause worth isolating first: `touchesEnded` called cadence `end(reason: "ended")`, and `end(...)` invalidated the exact-max `CADisplayLink` before `finishNativeCarouselDrag` started the existing 0.22s/0.18s commit/cancel animation. Thus Build219's proven high-refresh request ended at finger release and prior cadence summaries did not measure the tail.

### Build228 release-tail max-refresh A/B

Build228 / 0.14.61 returns to cleaned Build226 presentation and changes only that request lifetime: interactive commit/cancel keeps the same exact device-max request until settle/cancel completion. Foreground math, Hero residency, persistent behavior, 0.22/0.18 animation parameters and 0.28/0.48 release semantics remain unchanged. Dedicated Xcode 16.4 run/job `33156739621 / 98801196041` succeeded; tested source `bdf63c7562fcd1edc1d224872230e988ac462281`; artifact `9679963420`; IPA SHA-256 `cda90b62e3cabd3199e1cfbc1b2e1c77b8a84d023a7c7b9c8e2ff66ab9edcf44`; source ZIP SHA-256 `d91b014486e5fb1c5c9798b2b56bf45f0bad4f9e47f433a9f862c5fa586ecf68`; OnePlayer 0.14.61 (228) / MinOS 15.0 independently verified. Evidence: **Code written / scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / not stable**.
'''
text = text[:start] + replacement + text[end:]
state.write_text(text)

decisions = Path('docs/project/TECHNICAL_DECISIONS.md')
text = decisions.read_text()
anchor = 'Build226 tests the visual-preserving implementation of that contract by deriving a current+previous+next Hero residency set from the existing settled current ID. Both adjacent targets remain resident through drag/release; normal Hero opacity blending is restored; after settle the resident window may rotate one new neighbor outside direct finger tracking. No duplicate residency state, timer, retry, shared-loader change or new gesture owner is introduced. Build226 passed dedicated CI/IPA and awaits target-device validation.\n'
addition = '''\nBuild226 target-device testing is materially positive: overall horizontal feel is now fairly close to EX and much better than the original, so three-slot Hero residency remains the current presentation direction. Build227 then tested physical-pixel foreground X rounding for slow-drag title shimmer; the title still visibly jitters, so pixel-grid quantization is rejected as a sufficient fix and should not be carried forward without new evidence.\n\nThe same Build227 target-device test identifies a separate release-tail issue. Exact source proves the Build219 device-max refresh request previously ended inside `touchesEnded` before `finishNativeCarouselDrag` started the existing commit/cancel animation. Build228 therefore tests only extending that same proven max-refresh request through interactive settle/cancel while reverting Build227 pixel rounding and leaving release duration/easing unchanged. This is a diagnostic candidate, not yet an accepted final release-animation contract.\n'''
if addition.strip() not in text:
    if anchor not in text: raise SystemExit('D012 Build226 anchor missing')
    text = text.replace(anchor, anchor + addition, 1)
decisions.write_text(text)
