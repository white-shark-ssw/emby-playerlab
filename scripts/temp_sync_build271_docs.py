from pathlib import Path
import re
import sys

root = Path(sys.argv[1])

state_path = root / 'docs/project/PROJECT_STATE.md'
state = state_path.read_text()
summary = "_Last updated 2026-08-31: Home carousel presentation-cadence work is active. Build269 blur-off and Build270 foreground-residency target-device A/Bs both leave the no-recording system FPS HUD ceiling around ~90 FPS, rejecting both primary-cause hypotheses. Build271 / 0.15.4 is the current diagnostic-only four-mode frame-pipeline benchmark; exact-source CI/IPA and independent package verification passed, target-device `CAROUSEL → CA → DISPLAYLINK → SWIFTUI` HUD testing is pending. Build216 / 0.14.49 remains the accepted packaged overall baseline; Search Build256 remains stable/merged; poster Build267 and Aether remain separate active work; P0 playback/transport contracts remain protected._"
state, count = re.subn(r'^_Last updated[^\n]*_$', summary, state, count=1, flags=re.M)
if count != 1:
    raise SystemExit(f'PROJECT_STATE summary replacement count={count}')

active = """## Active correction: Home carousel presented performance — Build269 / Build270 / Build271

The Home-carousel presentation-performance task is active even though Build241 remains the merged product behavior foundation. The controlling measurement is the target-device system FPS HUD **without screen recording**. Build265 peaks around ~90 FPS in that condition while screen recording can lift the HUD toward 120, so recording-state 120 and raw `CADisplayLink` callback cadence are not acceptance evidence for final presented FPS.

Build269 / 0.15.2 removed only persistent full-screen blur30 and still peaked around ~90 FPS without recording, rejecting blur30 as the primary limiter. Build270 / 0.15.3 exact source `cee2031aa7dc2abb59fb371196e22fbce56e32ee` instead reduced foreground title/logo/metadata residency from all up-to-6 carousel pages to current/previous/next while retaining Build231 per-page `compositingGroup()`, normal blur30 and all Build265 rapid-swipe/image behavior. It also remained around ~90 FPS on the target device without recording, rejecting foreground-residency/offscreen-compositing count as the primary limiter. Build269/270 remain diagnostic-only and their presentation changes must not be inherited as product behavior.

Build271 / 0.15.4 changes direction from component-removal guesses to a code-driven pipeline boundary test. Exact product source `643ff1cbbd24ea06a315c632b08ac1ad162ee43f` is created directly from Build265, not Build269/270, and changes only AppIdentity, Home diagnostic-mode wiring, and new `EmbyHomeFramePipelineProbeV3.swift`; `EmbyHomeHeroV3.swift` remains the exact Build265 blob. The one package cycles `CAROUSEL → CA → DISPLAYLINK → SWIFTUI`, unloading normal Home/carousel presentation in the three probe modes. Dedicated exact-source run/job `33329047915 / 99304195063` passed; artifact `9737161622`, digest `sha256:56ae2d35b3fc8598c1db02f5cc8cc23cc7153d8a6079d27b54e0e2fde00fab47`; IPA SHA `e2c6540e5705f9837dd75db6a41ef7a1ce02d24c3afb3f7abc2160faaa8a963f`; source ZIP SHA `df4b09881cab1ff955b830c6dc821eaf8d6bc4ef377898978af1ee24f194ef22`; independent re-download/unpack confirms `com.embyplayerlab.app`, OnePlayer `0.15.4 (271)`, MinOS 15.0, IPA integrity and MinOS audit. Diagnostic prerelease `build271-frame-pipeline-test` was published from that fixed verified artifact by run `33330204282`. Evidence: **Code written ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device tested ❌ / stable ❌**.

Next carousel action is only the target-device four-mode no-screen-recording system-HUD comparison. Do not add another runtime optimization or synthetic stress load before that boundary is known.
"""
state, count = re.subn(r'## Active correction: Home carousel presented performance — Build269 / Build270\n\n.*\Z', active, state, count=1, flags=re.S)
if count != 1:
    raise SystemExit(f'PROJECT_STATE active-section replacement count={count}')
state_path.write_text(state)

index_path = root / 'docs/project/BUILD_TEST_INDEX.md'
index = index_path.read_text()
new_rows = """| **Build270 / 0.15.3** | Carousel foreground residency A/B | **Target-device tested; foreground-residency/compositing-count primary-cause hypothesis rejected; diagnostic-only.** Exact product source `cee2031aa7dc2abb59fb371196e22fbce56e32ee`; relative Build265 only AppIdentity and one foreground enumeration change: up-to-6 mounted foreground pages → existing current/previous/next resident window. Build231 `.compositingGroup()`, blur30, rapid-swipe ownership, 500/0.28 gates and all P0/Frozen paths remain unchanged. Run/job `33327653253 / 99300535892`; artifact `9736735731`; artifact digest `sha256:3a8ab81ccce3b4e6fc10928b829bad053a5060c3130c5ceced9398f85af4ad2b`; IPA SHA `169fb53bd3012c7b864912638f9f627e68282b3f6fb2dd18be58e48edca56b8d`; source ZIP SHA `f586270e852d09623cf5af38d6cd3b8bbaea85d4b8475bc4512e6a816f4ef98a`; MinOS 15.0. User result on 2026-08-31: without screen recording the system FPS HUD maximum remains around ~90, same as Build265/269. Do not inherit the residency change as product behavior. |
| **Build271 / 0.15.4** | Home-carousel frame-pipeline boundary benchmark | **Exact-source CI/IPA verified; target-device four-mode HUD test pending; diagnostic-only.** Exact product source `643ff1cbbd24ea06a315c632b08ac1ad162ee43f` branches directly from Build265 and changes only AppIdentity, Home diagnostic mode wiring, and new frame-pipeline probe code. `EmbyHomeHeroV3.swift` remains the exact Build265 blob. Modes: normal `CAROUSEL`, pure Core Animation `CA`, main-thread `CADisplayLink→CALayer` `DISPLAYLINK`, and `CADisplayLink→@Published→SwiftUI` `SWIFTUI`; normal Home/carousel presentation is unmounted in the three probe modes. Dedicated successful run/job `33329047915 / 99304195063`; artifact `9737161622`, digest `sha256:56ae2d35b3fc8598c1db02f5cc8cc23cc7153d8a6079d27b54e0e2fde00fab47`; IPA SHA `e2c6540e5705f9837dd75db6a41ef7a1ce02d24c3afb3f7abc2160faaa8a963f`; source ZIP SHA `df4b09881cab1ff955b830c6dc821eaf8d6bc4ef377898978af1ee24f194ef22`; independent artifact re-download/unpack confirms `0.15.4 (271)`, bundle `com.embyplayerlab.app`, MinOS 15.0, IPA integrity and MinOS audit. Prerelease `build271-frame-pipeline-test`; publish run `33330204282`. First CI run `33328917736` failed only in a macOS Bash source-guard script before compilation; product source remained unchanged. |"""
index, count = re.subn(r'^\| \*\*Build270 / 0\.15\.3\*\* \|.*$', new_rows, index, count=1, flags=re.M)
if count != 1:
    raise SystemExit(f'BUILD_TEST_INDEX Build270 replacement count={count}')
index_path.write_text(index)
