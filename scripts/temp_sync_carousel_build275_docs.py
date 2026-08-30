from pathlib import Path
import re

checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
text = checkpoint.read_text()
text = re.sub(r'^- \*\*Status:\*\*.*$', '- **Status:** Active — Build274 target-device result is now `CAROUSEL ≈90 / TREE FULL ≈90` with screen recording off, so steady-state full real carousel-tree invalidation/composition is sufficient to reproduce the presented-FPS ceiling without touch, settle, resident rotation, or new-target loading. Build275 / 0.15.8 is the current exact-source CI/IPA-verified scope-isolation diagnostic: `TREE FULL / TREE HERO / TREE BACKDROP`.', text, count=1, flags=re.M)
text = re.sub(r'^- \*\*Current working branch:\*\*.*$', '- **Current working branch:** `diag/home-carousel-tree-scope-build275`.', text, count=1, flags=re.M)
text = re.sub(r'^- \*\*Current exact product source:\*\*.*$', '- **Current exact product source:** `8c6a882c03e60e9d2f49e9bc95b09f9e3712577b`.', text, count=1, flags=re.M)
text = re.sub(r'^- \*\*Current candidate:\*\*.*$', '- **Current candidate:** OnePlayer `0.15.8 (275)` — full/Hero/backdrop transition-scope 120 Hz A/B; Code written / exact-source CI passed / IPA produced and independently verified; target-device scope HUD results pending.', text, count=1, flags=re.M)

insert = '''## Build274 target-device TREE result — 2026-08-31

The user tested Build274 on iPhone 15 Pro Max / iOS 17.0 with screen recording off and reported **`CAROUSEL ≈90 FPS / TREE FULL ≈90 FPS`**. The supplied TREE screenshot captures 101 FPS at one instant, but the sustained observation remains around 90 and does not approach a stable 120. The sustained target-device result controls.

This closes the Build274 binary split: touch delivery, release/settle, resident-window rotation and new-target image loading are **not necessary** to reproduce the ceiling. A fixed-pair device-max `CADisplayLink` driving the unchanged real `transitionProgress` through the full real Home carousel tree is sufficient. The uploaded `OnePlayer-App-1788121754.log` also continues to show many internal display-link intervals near 8.34 ms during manual carousel sessions while the real HUD is lower, reinforcing that internal callback cadence is not final presented FPS.

Exact source ownership gives a narrow next boundary. `V3HomeCarouselTransitionState.progress` is `@Published`, but the whole Home root is not observing it. The high-frequency progress publication is consumed through exactly two `V3HomeCarouselTransitionScope` observers in the Build274 presentation: (1) the full-screen persistent backdrop; and (2) the Hero subtree containing clear artwork/mask/foreground pages/indicators. Therefore the next A/B splits those two scopes rather than resuming generic SwiftUI/UIKit, blur-only, gesture, timing or ProMotion guesses.

Build274 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device TREE tested ✅ / full steady-state tree sufficient to reproduce ~90 ceiling ✅ / stable ❌**.

## Build275 / 0.15.8 — transition-scope split

Build275 extends exact Build274 source and changes only `Sources/Core/AppIdentity.swift`, `Sources/UI/EmbyHomeCoreV3.swift`, and `Sources/UI/EmbyHomeFramePipelineProbeV3.swift`. The real product files `EmbyHomeHeroV3.swift`, `EmbyHomeCarouselInteractionV3.swift`, and `EmbyHomeCarouselStateV3.swift` remain exact protected blobs `ab2ab5d80a59e174622dca0006c0f3aad4111a54`, `f8df5af61101c0272c5ec378caae617000b8fcea`, and `96f38514cfb09668f11c21a61105ac87a2f26f3d`.

The package keeps the same fixed-pair device-max progress driver and adds three Home-tree modes:

- `TREE FULL`: Build274 control; both persistent-backdrop and Hero transition scopes observe progress.
- `TREE HERO`: only the Hero transition scope observes progress; the persistent backdrop remains mounted but is frozen during the high-frequency stream.
- `TREE BACKDROP`: only the persistent-backdrop transition scope observes progress; the Hero remains mounted but frozen during the high-frequency stream.

This preserves static tree complexity while isolating which `ObservableObject` invalidation scope consumes the per-frame budget. There is still no settle, resident rotation, new target selection, timer/watchdog/retry, second product state owner, gesture change, image-cache change, or Player/Transport/P0 change.

Build275 exact product source `8c6a882c03e60e9d2f49e9bc95b09f9e3712577b`. Xcode 16.4 run/job `33334208681 / 99318066653` passed. Artifact `9738555839`, digest `sha256:16e42660ac53bffcc9d7d222fcf81bcadf692a7ff87cbd4562d791dbd6973c0b`. IPA SHA-256 `26229afe7b1cec29ab2bf2cca18c0348fd3337a2d6f996bd2a6b6b07c5bebe64`; source ZIP SHA-256 `4bf558ce4731fb3813e276f19f43e73450f360c79667c48c0a2122fa4848c0f4`. Independent unpack verifies IPA integrity, `com.embyplayerlab.app / OnePlayer / 0.15.8 (275)`, `MinimumOSVersion=15.0`, and the MinOS audit.

'''
if '## Build274 target-device TREE result — 2026-08-31' not in text:
    text = text.replace('## Scope guard\n', insert + '## Scope guard\n')

text = re.sub(r'## Acceptance / test procedure\n.*?(?=\n## Validation state)', '''## Acceptance / test procedure

1. Use iPhone 15 Pro Max / iOS 17.0 with screen recording **off**.
2. `PIPE CAROUSEL`: rapidly swipe as the normal control and note the real system HUD.
3. Tap once to `PIPE TREE FULL`; stop touching the screen and let the fixed pair oscillate for 5–10 seconds; note HUD.
4. Tap once to `PIPE TREE HERO`; do not touch; note HUD.
5. Tap once to `PIPE TREE BACKDROP`; do not touch; note HUD.
6. Report all four approximate sustained values, e.g. `CAROUSEL 90 / FULL 90 / HERO 120 / BACKDROP 120`.
7. Interpretation: HERO-only ~90 localizes a sufficient Hero-scope cost; BACKDROP-only ~90 localizes a sufficient backdrop-scope cost; both isolated modes ~120 while FULL ~90 indicates combined budget pressure; both isolated modes ~90 means each scope can independently exceed the 120-Hz budget and requires deeper split.
8. CI/IPA evidence is not a performance conclusion; target-device HUD remains authoritative.''', text, flags=re.S)

text = re.sub(r'## Validation state\n.*?(?=\n## Next exact action)', '''## Validation state

- Build265 Code / CI / IPA: ✅. Real-device: ✅ ~90 no-recording ceiling; not stable.
- Build269 Code / CI / IPA: ✅. Real-device: ✅ ~90; blur-primary hypothesis rejected; diagnostic-only.
- Build270 Code / CI / IPA: ✅. Real-device: ✅ ~90; foreground-residency hypothesis rejected; diagnostic-only.
- Build271 Code / CI / IPA: ✅. Real-device pipeline: ✅ `CA 60 / DISPLAYLINK 120 / SWIFTUI 120`; generic display-link/CALayer/SwiftUI 120 capability proven; not stable.
- Carousel Build273: ❌ retired identity collision; poster-grid owns Build273; no valid carousel package attribution.
- Build274 Code / CI / IPA: ✅. Real-device: ✅ `CAROUSEL ≈90 / TREE FULL ≈90`; full steady-state real carousel tree is sufficient to reproduce the ceiling; diagnostic-only.
- Build275 Code written: ✅ exact product source `8c6a882c03e60e9d2f49e9bc95b09f9e3712577b`.
- Build275 exact-source CI passed: ✅ run/job `33334208681 / 99318066653`.
- Build275 IPA produced + independently verified: ✅ artifact `9738555839`; IPA SHA `26229afe7b1cec29ab2bf2cca18c0348fd3337a2d6f996bd2a6b6b07c5bebe64`; source SHA `4bf558ce4731fb3813e276f19f43e73450f360c79667c48c0a2122fa4848c0f4`; MinOS 15.0.
- Build275 target-device scope split: ❌ pending.
- Stable/frozen reopened performance task: ❌.''', text, flags=re.S)

text = re.sub(r'## Next exact action\n.*\Z', '''## Next exact action

Install Build275 and keep screen recording off. Measure `CAROUSEL → TREE FULL → TREE HERO → TREE BACKDROP`, with no screen touch during the three automatic tree modes. The relative real system-HUD values determine whether the next change targets the Hero observer scope, persistent-backdrop observer scope, or their combined per-frame budget. Do not alter product gesture/release timing, image transport/cache, Player/MPV/PiP, or add smoothing/fallback logic before this scope result.''', text, flags=re.S)
checkpoint.write_text(text)

module = Path('docs/project/MODULE_STATUS.md')
text = module.read_text()
row = '| Home carousel interaction / presentation cadence | **Active — Build274 real-device full-tree ceiling reproduced; Build275 CI/IPA verified, scope split pending** | Build274 / 0.15.7 target-device result is `CAROUSEL ≈90 / TREE FULL ≈90` with recording off, proving the unchanged steady-state full carousel tree can reproduce the presented-FPS ceiling without touch, settle, resident rotation or new-target loading. Source inspection localizes high-frequency progress observation to two real scopes: persistent backdrop and Hero. Build275 / 0.15.8 exact source `8c6a882c03e60e9d2f49e9bc95b09f9e3712577b` adds `TREE FULL / TREE HERO / TREE BACKDROP` while preserving Hero/Interaction/State blobs exactly; run/job `33334208681 / 99318066653`, artifact `9738555839`, IPA SHA `26229afe7b1cec29ab2bf2cca18c0348fd3337a2d6f996bd2a6b6b07c5bebe64`, source SHA `4bf558ce4731fb3813e276f19f43e73450f360c79667c48c0a2122fa4848c0f4`, MinOS 15.0. Build241 product behavior/P0 remain protected; Build275 is diagnostic-only, not stable. |'
text = re.sub(r'^\| Home carousel interaction / presentation cadence \|.*$', row, text, count=1, flags=re.M)
module.write_text(text)

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(r'^_Last updated .*?_$', '_Last updated 2026-08-31: Home carousel Build274 is now target-device tested at `CAROUSEL ≈90 / TREE FULL ≈90` with screen recording off, proving the full steady-state real carousel tree itself can reproduce the presented-FPS ceiling. Build275 / 0.15.8 is the current CI/IPA-verified diagnostic and splits the two actual high-frequency transition observers into `TREE HERO` and `TREE BACKDROP`. Poster and Aether remain separate; Search Build256 and all P0 playback/transport contracts stay protected._', text, count=1, flags=re.M)
active = '''## Active: Home carousel presented-FPS diagnosis — Build275 / 0.15.8

Build274 target-device evidence closes the prior pipeline boundary: normal `CAROUSEL` and fixed-pair `TREE FULL` both remain around ~90 FPS in the real system HUD with recording off. Therefore touch/release/settle/resident rotation/new-target loading are not required to reproduce the ceiling; the full real carousel transition tree is sufficient.

Exact source shows `transitionProgress` is `@Published` on `V3HomeCarouselTransitionState`, and the high-frequency publication is observed by two presentation scopes rather than the whole Home root: the persistent full-screen backdrop and the Hero subtree. Build275 isolates those observers without changing the real Hero/Interaction/State product files. `TREE FULL` updates both; `TREE HERO` updates only Hero while backdrop remains mounted/frozen; `TREE BACKDROP` updates only backdrop while Hero remains mounted/frozen. Exact source `8c6a882c03e60e9d2f49e9bc95b09f9e3712577b`; run/job `33334208681 / 99318066653`; artifact `9738555839`; IPA SHA `26229afe7b1cec29ab2bf2cca18c0348fd3337a2d6f996bd2a6b6b07c5bebe64`; MinOS 15.0. Target-device scope split is pending; no stable/fix claim.

'''
marker = '## Completed / frozen: Home carousel interaction — Build241 / 0.14.74\n'
if '## Active: Home carousel presented-FPS diagnosis — Build275 / 0.15.8' not in text:
    text = text.replace(marker, active + marker)
state.write_text(text)

index = Path('docs/project/BUILD_TEST_INDEX.md')
text = index.read_text()
build274 = '| **Build274 / 0.15.7** | Full real carousel-tree device-max progress probe | **Target-device tested; full steady-state tree is sufficient to reproduce the ~90 presented-FPS ceiling; diagnostic-only.** Exact source `6d18ca0cdb02bbce3f8fee13f8b5dc082a43ab63`; run/job `33333236724 / 99315483085`; artifact `9738285110`; IPA SHA `2fc79d5d09aa8e0c2f6384b4a50e933cf79f885c4b8d9fd05932fc1a3cc6295a`; MinOS 15.0. User result with recording off: `CAROUSEL ≈90 / TREE FULL ≈90`; supplied TREE screenshot captured 101 FPS at one instant but sustained observation remained around 90. This rejects interaction/settle/resident-rotation/new-target-loading as necessary causes and moves diagnosis to the two actual transition observer scopes. |'
build275 = '| **Build275 / 0.15.8** | Carousel transition observer-scope split | **Exact-source CI/IPA verified; target-device pending; diagnostic-only.** Exact source `8c6a882c03e60e9d2f49e9bc95b09f9e3712577b` extends Build274 only in AppIdentity/Home diagnostic mounting/frame-pipeline probe. `TREE FULL` updates both transition observers, `TREE HERO` only Hero, `TREE BACKDROP` only persistent backdrop; frozen scope remains mounted. Hero/Interaction/State protected blobs are unchanged. Run/job `33334208681 / 99318066653`; artifact `9738555839`, digest `sha256:16e42660ac53bffcc9d7d222fcf81bcadf692a7ff87cbd4562d791dbd6973c0b`; IPA SHA `26229afe7b1cec29ab2bf2cca18c0348fd3337a2d6f996bd2a6b6b07c5bebe64`; source ZIP SHA `4bf558ce4731fb3813e276f19f43e73450f360c79667c48c0a2122fa4848c0f4`; MinOS 15.0 independently verified. |'
text = re.sub(r'^\| \*\*Build274 / 0\.15\.7\*\* \|.*$', build274, text, count=1, flags=re.M)
if build275 not in text:
    text = text.replace(build274 + '\n', build274 + '\n' + build275 + '\n')
index.write_text(text)

decisions = Path('docs/project/TECHNICAL_DECISIONS.md')
text = decisions.read_text()
d023 = '''\n\n## D023 — Full-tree ceiling reproduced; split the two real transition observer scopes\n\nBuild274 target-device testing with screen recording off reports `CAROUSEL ≈90 / TREE FULL ≈90`. The TREE probe already removes touch delivery, release/settle, resident-window rotation and new-target image selection while driving the exact existing `transitionProgress` owner between a fixed pair. Therefore those interaction-lifecycle events are not necessary to reproduce the presented-FPS ceiling; steady-state full real carousel-tree invalidation/composition is sufficient.\n\nExact source inspection establishes the next boundary without guessing. `V3HomeCarouselTransitionState.progress` is `@Published`, while the high-frequency progress stream is observed through exactly two real `V3HomeCarouselTransitionScope` presentation owners: the persistent full-screen backdrop and the Hero subtree. Do not resume generic ProMotion flags, touch smoothing, easing, timer/watchdog, blur-only removal, foreground-residency tuning or Player/Transport changes before these two observers are separated.\n\nBuild275 / 0.15.8 performs that separation while keeping both static trees mounted. `TREE FULL` observes both, `TREE HERO` observes only Hero with backdrop frozen, and `TREE BACKDROP` observes only backdrop with Hero frozen. The real `EmbyHomeHeroV3.swift`, `EmbyHomeCarouselInteractionV3.swift`, and `EmbyHomeCarouselStateV3.swift` blobs remain unchanged. Exact source `8c6a882c03e60e9d2f49e9bc95b09f9e3712577b`; run/job `33334208681 / 99318066653`; artifact `9738555839`; IPA SHA `26229afe7b1cec29ab2bf2cca18c0348fd3337a2d6f996bd2a6b6b07c5bebe64`; MinOS 15.0. Target-device scope results are still required before any product optimization.\n'''
if '## D023 — Full-tree ceiling reproduced; split the two real transition observer scopes' not in text:
    text = text.rstrip() + d023
decisions.write_text(text)
