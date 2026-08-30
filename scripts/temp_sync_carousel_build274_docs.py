from pathlib import Path
import re

build271_ipa = "e2c6540e5705f9837dd75db6a41ef7a1ce02d24c3afb3f7abc2160faaa8a963f"
build274_ipa = "2fc79d5d09aa8e0c2f6384b4a50e933cf79f885c4b8d9fd05932fc1a3cc6295a"
build274_source = "ed85b8c7a1d28de8af26ba7124386dfa987b3e83d8c4d38b61e8b5b61c4d5598"
build274_artifact_digest = "0fb0e5f9a07c6eb16eab00cdf516283991b0d5e6d61597ea368497ccb4f320f7"

# Current carousel checkpoint.
path = Path("docs/project/current/dev/DEV-home-carousel-drag-smoothness.md")
text = path.read_text()
text = re.sub(r'^- \*\*Status:\*\*.*$', '- **Status:** Active — Build271 target-device pipeline evidence now proves native `CADisplayLink→CALayer` and `CADisplayLink→@Published→SwiftUI` can both present at a real 120 FPS on the target device with recording off. The Build271 `CA` probe showed 60 FPS only because that diagnostic `CABasicAnimation` omitted `CAAnimation.preferredFrameRateRange`; it is not evidence of a 60 FPS system/compositor ceiling. The remaining boundary is the real Home/carousel render tree versus interaction/settle/residency/image-callback lifecycle. Build274 / 0.15.7 is the current exact-source CI/IPA-verified TREE120 diagnostic.', text, count=1, flags=re.M)
text = re.sub(r'^- \*\*Current working branch:\*\*.*$', '- **Current working branch:** `diag/home-carousel-tree120-build274`.', text, count=1, flags=re.M)
text = re.sub(r'^- \*\*Current exact product source:\*\*.*$', '- **Current exact product source:** `6d18ca0cdb02bbce3f8fee13f8b5dc082a43ab63`.', text, count=1, flags=re.M)
text = re.sub(r'^- \*\*Current candidate:\*\*.*$', '- **Current candidate:** OnePlayer `0.15.7 (274)` — full real carousel-tree 120 Hz progress probe; Code written / exact-source CI passed / IPA produced and independently verified; target-device TREE120 HUD result pending.', text, count=1, flags=re.M)
latest = f'''## Build271 target-device pipeline result — 2026-08-31

The user supplied direct target-device screenshots and explicitly confirmed that the system FPS HUD shown in them is real. With screen recording off, Build271 shows:

- `PIPE CA`: **60 FPS**.
- `PIPE DISPLAYLINK`: **120 FPS**.
- `PIPE SWIFTUI`: **120 FPS**.

The accompanying `OnePlayer-App-1788120204.log` contains 40 normal-carousel cadence sessions. Their internal display-link intervals remain broadly high-refresh (median `display_avg_gap_ms=8.795`), while delivered touch / publish / render state changes are less frequent (median `15.455 / 21.445 / 21.665 ms`). This reinforces the already-established rule that callback cadence is not identical to final presented cadence or to user-driven state publication cadence.

Exact Build271 source explains the 60 FPS CA screenshot: the `CABasicAnimation` probe did **not** set `CAAnimation.preferredFrameRateRange`, while both DISPLAYLINK and SWIFTUI probes explicitly requested `UIScreen.main.maximumFramesPerSecond`. Because the more complex `CADisplayLink→CALayer` and `CADisplayLink→@Published→SwiftUI` paths both reach a real 120 FPS on the same device, Build271 rejects a generic 60/90 FPS ceiling in UIKit/SwiftUI/Combine/CALayer/display-link capability. The next diagnostic must exercise the actual Home carousel render tree.

Build271 evidence is now: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device pipeline tested ✅ / generic pipeline ceiling rejected ✅ / actual carousel bottleneck unresolved / stable ❌**.

## Build274 / 0.15.7 — full carousel-tree 120 Hz probe

Build274 is created from exact Build271 product source `643ff1cbbd24ea06a315c632b08ac1ad162ee43f` and changes exactly three product files: AppIdentity, Home diagnostic-mode mounting, and the frame-pipeline probe. `EmbyHomeHeroV3.swift`, `EmbyHomeCarouselInteractionV3.swift`, and `EmbyHomeCarouselStateV3.swift` remain exact protected blobs `ab2ab5d80a59e174622dca0006c0f3aad4111a54`, `f8df5af61101c0272c5ec378caae617000b8fcea`, and `96f38514cfb09668f11c21a61105ac87a2f26f3d`.

New `TREE120` mode keeps the full real Build265/271 Home presentation mounted — persistent blur backdrop, preload layer, three-slot clear Hero artwork, all foreground pages with retained page-level `compositingGroup()`, indicators, Home rows/header/dock — but replaces finger input with one main-thread `CADisplayLink` requesting device-max refresh. That display link drives the **same existing `transitionProgress` owner** continuously 0→1→0 between one fixed current/neighbor pair. It deliberately does not settle, rotate `currentCarouselItemID`, rotate resident windows, or request a new target image during the measurement.

Interpretation is binary:

- `TREE120` also stays around ~90: steady-state real carousel-tree invalidation/composition/commit cost is sufficient to cap presentation, so the next probe should split the real tree's per-frame layers.
- `TREE120` reaches 120 while manual `CAROUSEL` remains around ~90: the real tree has 120 Hz headroom in steady state; the next target becomes touch delivery / release-settle / resident rotation / image-callback lifecycle rather than static tree cost.

The CA marker probe in Build274 also adds the missing `CAAnimation.preferredFrameRateRange` high-refresh request, correcting the Build271 probe configuration; this is diagnostic hygiene, not a carousel product change.

Build274 exact product source: `6d18ca0cdb02bbce3f8fee13f8b5dc082a43ab63`. Xcode 16.4 run/job `33333236724 / 99315483085` passed. Artifact `9738285110`, digest `sha256:{build274_artifact_digest}`. IPA SHA-256 `{build274_ipa}`; source ZIP SHA-256 `{build274_source}`. Independent re-download verifies both hashes, IPA archive integrity, `com.embyplayerlab.app / OnePlayer / 0.15.7 (274)`, `MinimumOSVersion=15.0`, and `Minimum OS compatibility audit: OK`.

A provisional carousel `Build273 / 0.15.6` identity was retired **before valid carousel compile/package attribution** after discovering the independent poster-grid task already owned Build273 (`perf/poster-grid-native-collection-build273`). Never use carousel Build273 for attribution. Build274 is the first valid identity for this TREE120 diagnostic.

'''
if "## Build271 target-device pipeline result — 2026-08-31" not in text:
    text = text.replace("## Scope guard\n", latest + "## Scope guard\n", 1)
validation = f'''## Validation state

- Build265 Code / CI / IPA: ✅. Real-device: ✅ ~90 no-recording ceiling; not stable.
- Build269 Code / CI / IPA: ✅. Real-device: ✅ ~90; blur-primary hypothesis rejected; diagnostic-only.
- Build270 Code / CI / IPA: ✅. Real-device: ✅ ~90; foreground-residency hypothesis rejected; diagnostic-only.
- Build271 Code / CI / IPA: ✅. Real-device pipeline: ✅ `CA 60 / DISPLAYLINK 120 / SWIFTUI 120`; generic display-link/CALayer/SwiftUI 120 capability proven; CA 60 probe configuration explained; not stable.
- Carousel Build273: ❌ retired identity collision; poster-grid owns Build273; no valid carousel package attribution.
- Build274 Code written: ✅ exact product source `6d18ca0cdb02bbce3f8fee13f8b5dc082a43ab63`.
- Build274 exact-source CI passed: ✅ run/job `33333236724 / 99315483085`.
- Build274 IPA produced + independently verified: ✅ artifact `9738285110`; IPA SHA `{build274_ipa}`; source SHA `{build274_source}`; MinOS 15.0.
- Build274 target-device TREE120 result: ❌ pending.
- Stable/frozen reopened performance task: ❌.

## Next exact action

Install Build274 and keep screen recording off. First observe `PIPE CAROUSEL` under the same rapid-swipe condition, then switch once to `PIPE TREE120` and **do not touch the carousel**; let the fixed pair oscillate for several seconds and report the real system HUD for both modes. `CA` may optionally be rechecked to confirm the corrected 120 Hz animation hint, but the controlling next decision is `CAROUSEL` versus `TREE120`. Do not add another runtime optimization before that result.
'''
text, n = re.subn(r'## Validation state\n\n.*\Z', validation, text, count=1, flags=re.S)
if n != 1:
    raise SystemExit(f"checkpoint validation replacement count={n}")
path.write_text(text)

# Module status matrix.
path = Path("docs/project/MODULE_STATUS.md")
text = path.read_text()
row = f'''| Home carousel interaction / presentation cadence | **Active — Build271 real-device pipeline tested; Build274 CI/IPA verified, TREE120 target-device pending** | Build271 / 0.15.4 target-device screenshots show real system HUD `CA 60 / DISPLAYLINK 120 / SWIFTUI 120` with recording off. Exact source shows only the CA probe omitted `CAAnimation.preferredFrameRateRange`; DISPLAYLINK and SWIFTUI explicitly request device-max and both truly reach 120, rejecting a generic UIKit/SwiftUI/Combine/CALayer/display-link ceiling. Build274 / 0.15.7 exact source `6d18ca0cdb02bbce3f8fee13f8b5dc082a43ab63` keeps the full real carousel tree mounted and drives the same `transitionProgress` at device-max via one `CADisplayLink` between a fixed pair, without settle/resident rotation/new target loading. Run/job `33333236724 / 99315483085`; artifact `9738285110`, digest `sha256:{build274_artifact_digest}`; IPA SHA `{build274_ipa}`; source ZIP SHA `{build274_source}`; independently verified `0.15.7 (274)`, MinOS 15.0. Carousel Build273 was retired before valid package attribution because poster-grid already owns Build273. Build241 behavior/P0 remain protected; Build274 is diagnostic-only, not stable. |'''
text, n = re.subn(r'^\| Home carousel interaction / presentation cadence \|.*$', row, text, count=1, flags=re.M)
if n != 1:
    raise SystemExit(f"module row replacement count={n}")
text = re.sub(r'^\| Other product modules \|.*$', '| Other product modules | Active parallel work | Build216 / 0.14.49 remains the accepted packaged overall runtime identity. Search Build256 is stable/merged. Home Build274 is diagnostic-only and must not replace the accepted overall baseline; Build271 pipeline evidence is target-device tested. Poster Build273 is a separate independent task identity and Aether remains separate. Build242 remains diagnostic-only and excluded from product inheritance. |', text, count=1, flags=re.M)
path.write_text(text)

# Build/test index: upgrade Build271 and add Build274, no carousel Build273 row.
path = Path("docs/project/BUILD_TEST_INDEX.md")
text = path.read_text()
row271 = f'''| **Build271 / 0.15.4** | Home-carousel frame-pipeline boundary benchmark | **Target-device pipeline tested; generic display-link/CALayer/SwiftUI 120 capability proven; diagnostic-only.** Exact product source `643ff1cbbd24ea06a315c632b08ac1ad162ee43f`; run/job `33329047915 / 99304195063`; artifact `9737161622`; IPA SHA `{build271_ipa}`; MinOS 15.0. User-supplied real HUD screenshots with recording off show `CA 60 / DISPLAYLINK 120 / SWIFTUI 120`. Exact source shows the CA `CABasicAnimation` omitted `CAAnimation.preferredFrameRateRange`, while the latter two explicitly requested device-max, so CA=60 is a probe-configuration result rather than evidence of a 60 FPS system ceiling. The actual Home/carousel tree versus interaction lifecycle is the next boundary. |'''
row274 = f'''| **Build274 / 0.15.7** | Full real carousel-tree device-max progress probe | **Exact-source CI/IPA verified; target-device TREE120 pending; diagnostic-only.** Exact source `6d18ca0cdb02bbce3f8fee13f8b5dc082a43ab63` changes Build271 only in AppIdentity, Home diagnostic mounting and frame-pipeline probe. `TREE120` retains the full real Home/carousel tree and drives the same existing `transitionProgress` with one device-max `CADisplayLink` between a fixed pair, without settle/resident rotation/new target image loading. Hero/Interaction/State protected blobs remain exact. Run/job `33333236724 / 99315483085`; artifact `9738285110`, digest `sha256:{build274_artifact_digest}`; IPA SHA `{build274_ipa}`; source ZIP SHA `{build274_source}`; independent package verification confirms `com.embyplayerlab.app / 0.15.7 (274) / MinOS 15.0`, IPA integrity and MinOS audit. A provisional carousel Build273 identity is retired because poster-grid already owns Build273; no carousel Build273 package is valid evidence. |'''
text, n = re.subn(r'^\| \*\*Build271 / 0\.15\.4\*\* \|.*$', row271 + "\n" + row274, text, count=1, flags=re.M)
if n != 1:
    raise SystemExit(f"Build271 row replacement count={n}")
path.write_text(text)

# Project state: preserve poster status while bringing Home current state forward, then append latest carousel checkpoint.
path = Path("docs/project/PROJECT_STATE.md")
text = path.read_text()
summary = "_Last updated 2026-08-31: Home Build271 target-device pipeline evidence now shows real no-recording HUD `CA 60 / DISPLAYLINK 120 / SWIFTUI 120`; because the Build271 CA probe alone omitted `CAAnimation.preferredFrameRateRange`, this rejects a generic 60/90 FPS UIKit/SwiftUI/Combine/CALayer/display-link ceiling and moves the boundary to the actual carousel tree versus interaction lifecycle. Build274 / 0.15.7 is the current CI/IPA-verified full-tree TREE120 diagnostic, target-device pending. Carousel Build273 is retired because poster-grid already owns Build273. Poster Build272 remains target-device rejected with native UICollectionView as its next independent A/B. Build216 remains the accepted packaged overall baseline; Search Build256 and all P0 playback/transport contracts remain protected._"
text, n = re.subn(r'^_Last updated[^\n]*_$', summary, text, count=1, flags=re.M)
if n != 1:
    raise SystemExit(f"PROJECT_STATE summary replacement count={n}")
section = f'''\n\n## Home carousel Build271 device result → Build274 TREE120 — 2026-08-31

Build271 / 0.15.4 is now target-device pipeline tested. User-supplied system-HUD screenshots with recording off show **CA 60 FPS / DISPLAYLINK 120 FPS / SWIFTUI 120 FPS**. The screenshots are controlling device evidence. Exact Build271 source shows the CA mode used a plain `CABasicAnimation` without `CAAnimation.preferredFrameRateRange`, whereas DISPLAYLINK and SWIFTUI both explicitly requested `UIScreen.main.maximumFramesPerSecond`. Since both of those more complex paths really present at 120 FPS, do not diagnose a generic system/window/Core Animation/SwiftUI 60/90 ceiling from the CA screenshot. The actual remaining boundary is the real carousel render tree versus interaction/settle/resident-rotation/image-callback lifecycle.

Build274 / 0.15.7 exact source `6d18ca0cdb02bbce3f8fee13f8b5dc082a43ab63` tests that boundary without deleting another visual component. `TREE120` keeps the full normal Home/carousel presentation mounted and drives the existing `transitionProgress` at device-max refresh between one fixed current/neighbor pair. It does not settle, change `currentCarouselItemID`, rotate Hero residency, or request a new target image while measuring. Build274 also gives the CA marker the missing `CAAnimation.preferredFrameRateRange` hint so that old probe configuration is no longer ambiguous.

Build274 changed exactly three product files from Build271; protected Hero/Interaction/State blobs are unchanged. Xcode 16.4 run/job `33333236724 / 99315483085` passed; artifact `9738285110`, digest `sha256:{build274_artifact_digest}`; IPA SHA `{build274_ipa}`; source ZIP SHA `{build274_source}`; independent re-download confirms IPA integrity, `0.15.7 (274)`, bundle `com.embyplayerlab.app`, MinOS 15.0 and MinOS audit OK. Evidence is **Code written ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device TREE120 pending / stable ❌**.

A provisional carousel Build273 identity was discarded before valid carousel package attribution after repository inspection showed the independent poster-grid task already owned Build273. Do not attribute any carousel result to Build273; Build274 is the unique carousel TREE120 candidate.
'''
if "## Home carousel Build271 device result → Build274 TREE120 — 2026-08-31" not in text:
    text += section
path.write_text(text)

# Technical decision update.
path = Path("docs/project/TECHNICAL_DECISIONS.md")
text = path.read_text()
decision = f'''\n\n## D022 — Native 120 Hz capability is proven; isolate the full carousel tree before interaction lifecycle

Build271 target-device evidence supersedes the earlier pending interpretation in D021. With screen recording off, user-supplied system-HUD screenshots show `PIPE CA = 60 FPS`, `PIPE DISPLAYLINK = 120 FPS`, and `PIPE SWIFTUI = 120 FPS`. Exact Build271 source reveals that only the CA `CABasicAnimation` omitted `CAAnimation.preferredFrameRateRange`; both 120 FPS probes explicitly requested device-max refresh. Therefore the CA=60 result is not evidence of a generic system compositor/window ceiling. The target device demonstrably supports real 120 FPS through main-thread `CADisplayLink→CALayer` and through `CADisplayLink→@Published→SwiftUI`.

Do not resume generic ProMotion flags, SwiftUI-vs-UIKit rewrites, blur removal, foreground-residency reduction, or synthetic CPU/GPU stress from this result. The next evidence boundary is whether the **unchanged full carousel render tree** can sustain a device-max progress stream when touch/settle/resident rotation/new-target loading are removed.

Build274 / 0.15.7 implements exactly that A/B. One `CADisplayLink` drives the existing `transitionProgress` 0→1→0 between a fixed current/neighbor pair while the normal persistent backdrop, preload, clear Hero residency, foreground pages/compositing, indicators, Home scroll content/header/dock remain mounted. It does not create a second product state owner: the diagnostic writes the same transition owner already consumed by the real presentation. It deliberately avoids settle and resident rotation during measurement. If `TREE120` remains ~90, next work may split real per-frame tree layers. If `TREE120` reaches 120 while manual `CAROUSEL` remains ~90, next work must move to touch delivery / release-settle / resident rotation / image-callback lifecycle instead.

Build274 exact source `6d18ca0cdb02bbce3f8fee13f8b5dc082a43ab63`; run/job `33333236724 / 99315483085`; artifact `9738285110`; IPA SHA `{build274_ipa}`; MinOS 15.0 verified. This is CI/IPA evidence only until the target-device TREE120 HUD result exists.

Build-number attribution rule reinforced: carousel Build273 is invalid/retired because poster-grid had already allocated Build273. Never reuse a build identity across parallel tasks; carousel TREE120 begins at Build274.
'''
if "## D022 — Native 120 Hz capability is proven" not in text:
    text += decision
path.write_text(text)
