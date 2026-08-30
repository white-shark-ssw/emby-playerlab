from pathlib import Path
import re

checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
text = checkpoint.read_text()
text = re.sub(r'^- \*\*Status:\*\*.*$', '- **Status:** Active — Build275 target-device screenshots show `TREE FULL=120 / TREE HERO=120 / TREE BACKDROP=120 / CA=120 / DISPLAYLINK=120 / SWIFTUI=120` with screen recording off. This conflicts with Build274 `TREE FULL≈90`, so the scope split is not yet causal evidence. The next controlling datum is normal `PIPE CAROUSEL` in the same Build275 session; do not modify runtime before that value is known.', text, count=1, flags=re.M)
text = re.sub(r'^- \*\*Current working branch:\*\*.*$', '- **Current working branch:** `diag/home-carousel-tree-scope-build275`.', text, count=1, flags=re.M)
text = re.sub(r'^- \*\*Current exact product source:\*\*.*$', '- **Current exact product source:** `8c6a882c03e60e9d2f49e9bc95b09f9e3712577b`.', text, count=1, flags=re.M)
text = re.sub(r'^- \*\*Current candidate:\*\*.*$', '- **Current candidate:** OnePlayer `0.15.8 (275)` — target-device scope probes all show 120 FPS, but the normal `PIPE CAROUSEL` same-build control is still required before interpreting the Build274→275 difference.', text, count=1, flags=re.M)

result_section = '''## Build275 target-device scope result — 2026-08-31

The user supplied six direct target-device screenshots from Build275 with screen recording off. The system FPS HUD in every supplied probe screenshot reads **120 FPS**:

- `PIPE TREE FULL`: 120 FPS.
- `PIPE TREE HERO`: 120 FPS.
- `PIPE TREE BACKDROP`: 120 FPS.
- `PIPE CA`: 120 FPS.
- `PIPE DISPLAYLINK`: 120 FPS.
- `PIPE SWIFTUI`: 120 FPS.

The uploaded `OnePlayer-App-1788123825.log` contains only two `HomeCarousel settled` lines and no `HomeCarouselPipelineProbe` mode/cadence records, so the screenshots are the controlling evidence for this round.

This result **does not yet prove** that Hero and backdrop are individually cheap and only their combination is expensive, because the Build275 `TREE FULL` control itself changed from Build274's sustained ~90 observation to 120. Exact source comparison confirms Build275 did not change the real Hero/Interaction/State files; relative to Build274 the only runtime-relevant Home change is the conditional structure around the two `V3HomeCarouselTransitionScope` mount points plus additional probe-mode routing. In `.carouselTree`, both observers are still present and the same device-max `CADisplayLink` writes the same `transitionProgress` owner.

Therefore Build274's `TREE FULL≈90` is no longer a reproducible invariant. Possible explanations such as session/image-pair dependence or SwiftUI structural invalidation differences remain hypotheses, not conclusions. The next required control is **normal `PIPE CAROUSEL` inside the same Build275 package/session with recording off**. If it also reaches ~120, the Build274→275 HomeCore structural change becomes the primary A/B target. If it remains ~90 while `TREE FULL=120`, the next boundary returns to real interaction lifecycle versus fixed display-link progress, and Build274's TREE result must be treated as non-reproduced.

Build275 evidence is now: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device probe screenshots ✅ / all supplied automatic/simple modes = 120 ✅ / normal same-build CAROUSEL control pending ❌ / stable ❌**.

'''
if '## Build275 target-device scope result — 2026-08-31' not in text:
    text = text.replace('## Scope guard\n', result_section + '## Scope guard\n')

text = re.sub(r'## Acceptance / test procedure\n.*?(?=\n## Validation state)', '''## Acceptance / test procedure

1. Use the already-installed Build275 on iPhone 15 Pro Max / iOS 17.0 with screen recording **off**.
2. Cycle back to `PIPE CAROUSEL`.
3. Perform the same rapid continuous horizontal swipes used for Build265/269/270 and observe the real system FPS HUD for several seconds.
4. Report the sustained/typical value only, e.g. `Build275 CAROUSEL≈90` or `Build275 CAROUSEL≈120`.
5. Do not create another runtime build until this same-package control is known; Build275 `TREE FULL=120` already invalidates using Build274's ~90 full-tree result as a stable causal premise.''', text, flags=re.S)

text = re.sub(r'- Build275 target-device scope split: .*', '- Build275 target-device probes: ✅ screenshots show `TREE FULL / TREE HERO / TREE BACKDROP / CA / DISPLAYLINK / SWIFTUI = 120`; normal same-build `PIPE CAROUSEL` control still pending.', text)
text = re.sub(r'## Next exact action\n.*\Z', '''## Next exact action

Do **not** change runtime yet. In the already-installed Build275, return to `PIPE CAROUSEL`, keep recording off, rapidly swipe for several seconds, and report the real HUD. That single value determines whether the next A/B targets the Build274→275 HomeCore structural difference or returns to interaction-lifecycle isolation.''', text, flags=re.S)
checkpoint.write_text(text)

module = Path('docs/project/MODULE_STATUS.md')
text = module.read_text()
row = '| Home carousel interaction / presentation cadence | **Active — Build275 probes all 120; same-build normal CAROUSEL control pending** | Build275 / 0.15.8 target-device screenshots with recording off show `TREE FULL=120 / TREE HERO=120 / TREE BACKDROP=120 / CA=120 / DISPLAYLINK=120 / SWIFTUI=120`. Because Build274 previously sustained `TREE FULL≈90`, the scope split cannot yet be interpreted causally: even the FULL control changed. Exact Build274→275 source diff leaves Hero/Interaction/State blobs unchanged and adds only HomeCore probe-mode conditional structure plus probe routing. Next evidence must be normal `PIPE CAROUSEL` in the same Build275 package/session. No runtime modification is justified before that control. Build241 product behavior/P0 remain protected; Build275 is diagnostic-only, not stable. |'
text = re.sub(r'^\| Home carousel interaction / presentation cadence \|.*$', row, text, count=1, flags=re.M)
module.write_text(text)

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(r'^_Last updated .*?_$', '_Last updated 2026-08-31: Home carousel Build275 target-device screenshots show `TREE FULL / TREE HERO / TREE BACKDROP / CA / DISPLAYLINK / SWIFTUI = 120 FPS` with recording off. Because Build274 had `TREE FULL≈90`, the Build275 split is not yet causal evidence; the next controlling datum is normal `PIPE CAROUSEL` in the same Build275 package/session. No additional runtime optimization should be made before that control. Poster/Aether remain isolated and all P0 playback/transport contracts remain protected._', text, count=1, flags=re.M)
insert = '''### Build275 target-device control conflict — 2026-08-31

Build275's supplied target-device screenshots show `TREE FULL=120`, `TREE HERO=120`, `TREE BACKDROP=120`, corrected `CA=120`, `DISPLAYLINK=120` and `SWIFTUI=120` with recording off. This directly conflicts with Build274's earlier sustained `TREE FULL≈90`. Because the FULL control itself changed, Hero-vs-backdrop attribution is not valid yet. Exact source comparison shows the product Hero/Interaction/State blobs are unchanged; the meaningful Build274→275 runtime delta is the conditional HomeCore structure around the two transition-scope mounts and probe-mode routing. The next required evidence is normal `PIPE CAROUSEL` in the same Build275 package/session. Runtime changes are paused until that value is known.

'''
marker = '## Completed / frozen: Home carousel interaction — Build241 / 0.14.74\n'
if '### Build275 target-device control conflict — 2026-08-31' not in text:
    text = text.replace(marker, insert + marker)
state.write_text(text)

index = Path('docs/project/BUILD_TEST_INDEX.md')
text = index.read_text()
new_row = '| **Build275 / 0.15.8** | Carousel transition observer-scope split | **Target-device probe screenshots obtained; all supplied probe modes show 120 FPS, but normal same-build CAROUSEL control is still pending; diagnostic-only.** Exact source `8c6a882c03e60e9d2f49e9bc95b09f9e3712577b`; run/job `33334208681 / 99318066653`; artifact `9738555839`, digest `sha256:16e42660ac53bffcc9d7d222fcf81bcadf692a7ff87cbd4562d791dbd6973c0b`; IPA SHA `26229afe7b1cec29ab2bf2cca18c0348fd3337a2d6f996bd2a6b6b07c5bebe64`; source ZIP SHA `4bf558ce4731fb3813e276f19f43e73450f360c79667c48c0a2122fa4848c0f4`; MinOS 15.0. User screenshots with recording off: `TREE FULL=120 / TREE HERO=120 / TREE BACKDROP=120 / CA=120 / DISPLAYLINK=120 / SWIFTUI=120`. Because Build274 previously showed `TREE FULL≈90`, do not attribute cost to Hero/backdrop yet; obtain Build275 normal `PIPE CAROUSEL` control first. |'
text = re.sub(r'^\| \*\*Build275 / 0\.15\.8\*\* \|.*$', new_row, text, count=1, flags=re.M)
index.write_text(text)

decisions = Path('docs/project/TECHNICAL_DECISIONS.md')
text = decisions.read_text()
d024 = '''\n\n## D024 — Build275 full-control 120 invalidates premature Hero/backdrop attribution\n\nBuild275 target-device screenshots with recording off show `TREE FULL`, `TREE HERO`, `TREE BACKDROP`, corrected `CA`, `DISPLAYLINK` and `SWIFTUI` all at 120 FPS. This supersedes the assumption that Build274's `TREE FULL≈90` was a stable invariant. Because the FULL control itself changed, the Build275 Hero/backdrop split cannot yet prove combined-budget pressure or identify either scope as the limiter.\n\nExact Build274→275 source comparison shows `EmbyHomeHeroV3.swift`, `EmbyHomeCarouselInteractionV3.swift` and `EmbyHomeCarouselStateV3.swift` are unchanged. The runtime-relevant difference is the HomeCore conditional structure around the two `V3HomeCarouselTransitionScope` mount points plus additional diagnostic-mode routing. In `TREE FULL`, both transition observers and the same device-max progress driver remain active. Therefore the next evidence must be the **normal `PIPE CAROUSEL` value in the same Build275 package/session**. Do not add another performance patch before that control. If Build275 CAROUSEL is also ~120, isolate the Build274→275 structural delta; if it remains ~90 while TREE FULL is 120, return to interaction-lifecycle versus fixed-progress diagnosis and treat Build274 TREE≈90 as non-reproduced/session-dependent evidence.\n'''
if '## D024 — Build275 full-control 120 invalidates premature Hero/backdrop attribution' not in text:
    text += d024
decisions.write_text(text)
