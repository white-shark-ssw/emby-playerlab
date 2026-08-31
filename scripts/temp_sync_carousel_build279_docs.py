from pathlib import Path
import re

ROOT = Path('.')


def read(path):
    return (ROOT / path).read_text()


def write(path, text):
    (ROOT / path).write_text(text)


def replace_line_prefix(text, prefix, replacement):
    lines = text.splitlines()
    found = False
    for index, line in enumerate(lines):
        if line.startswith(prefix):
            lines[index] = replacement
            found = True
            break
    if not found:
        raise RuntimeError(f'missing line prefix: {prefix}')
    return '\n'.join(lines) + ('\n' if text.endswith('\n') else '')


checkpoint_path = 'docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'
checkpoint = read(checkpoint_path)
checkpoint = replace_line_prefix(checkpoint, '- **Status:**', '- **Status:** Active — Build277 target-device input benchmark is complete: normal `CAROUSEL≈90`, valid `PAN≈110`, valid `SCROLLVIEW≈110`; the reported `TOUCH≈110` is invalid because the raw-touch recognizer was not installed by the Build277 first-entry guard. Logs show standard Pan/Scroll callbacks near 120 Hz while normal carousel delivered-touch/publication remains materially sparser. Build279 / 0.15.12 is the current CI/IPA-verified real-carousel `UIPanGestureRecognizer` A/B.')
checkpoint = replace_line_prefix(checkpoint, '- **Current working branch:**', '- **Current working branch:** `diag/home-carousel-real-pan-build279`.')
checkpoint = replace_line_prefix(checkpoint, '- **Current exact product source:**', '- **Current exact product source:** `94f7a4ba5aa5bfdd3beb724e216015141dfc50b7`.')
checkpoint = replace_line_prefix(checkpoint, '- **Current candidate:**', '- **Current candidate:** OnePlayer `0.15.12 (279)` — diagnostic-only normal `CAROUSEL` vs real-tree `CAROUSEL PAN`, plus corrected raw-touch probe; exact-source CI/IPA independently verified; target-device pending.')
marker = '## Build277 target-device input result — 2026-08-31'
section = '''## Build277 target-device input result — 2026-08-31

The user tested Build277 on iPhone 15 Pro Max / iOS 17.0 with screen recording off and reported **`CAROUSEL≈90 / TOUCH≈110 / PAN≈110 / SCROLLVIEW≈110`**. Source/log correlation changes the meaning of the TOUCH value: Build277's initial `setMode` guard failed to install `V3HomeRawTouchRecognizer` on first entry. All 35 log records labeled `mode=rawTouch` end with `scroll-drag-ended` / `scroll-deceleration-ended`, proving that reported TOUCH HUD value is **invalid for raw-touch attribution**.

The PAN and SCROLLVIEW results are valid. The uploaded `OnePlayer-App-1788167172.log` shows a long native-Pan run with 1,257 samples averaging **8.79 ms** callback spacing; native ScrollView callbacks are similarly near device-max cadence (weighted about **8.60 ms**). In the same log normal carousel sessions have delivered-touch median about **13.54 ms**, coalesced-touch median about **4.17 ms**, progress-publication median about **21.75 ms**, render-change median about **21.09 ms**, while the diagnostic display-link median remains high-refresh. This is evidence that the current delivered-move/product-publication path is materially sparser than standard Pan/Scroll input delivery; it is not yet evidence that replacing the product owner is sufficient.

Build277 evidence is now: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device PAN+SCROLL benchmark tested ✅ / raw TOUCH probe invalid ❌ / product fix unproven / stable ❌**.

## Build279 / 0.15.12 — real-carousel UIPan A/B

Build279 starts from exact Build275/277 diagnostic lineage and preserves the normal `CAROUSEL` owner unchanged. It adds `CAROUSEL PAN`, where a standard `UIPanGestureRecognizer` drives the existing `shouldBeginNativeCarouselDrag → handleNativeCarouselDrag → finishNativeCarouselDrag` callbacks and therefore the same real `V3HomeCarouselTransitionState` and full Hero/backdrop presentation. This is diagnostic-only: Pan release distance is acquisition-relative and is not promoted as the final product gesture contract.

Build279 also fixes the Build277 raw-touch probe initialization with an explicit configured-mode sentinel, so future `TOUCH LAYER` data is real. No interpolation, DisplayLink latch, predicted smoothing, timer/watchdog/retry/fallback, duplicate transition state, Player/MPV/PiP/Transport/Cache/Emby Session change, or Build241 `>=500 / >=0.28` contract change is included.

- Exact product source: `94f7a4ba5aa5bfdd3beb724e216015141dfc50b7`.
- Exact-source Xcode 16.4 CI run/job: `33377860245 / 99443301805` — success.
- Artifact: `OnePlayer-0.15.12-build279-carousel-real-pan-probe`, ID `9752649942`.
- Artifact digest: `sha256:8cf341ff3cc3706e6fb4ab8036eea8c0928e7cd90e6fafc2cdd33ad74fbb2143`.
- IPA SHA-256: `36f17a02a0deddbae593f137d455cba3d22849bf28f00c0fafeb755b620abf9b`.
- Source ZIP SHA-256: `9e3f149fed7426db36d5d32669b2ebc3c049661b80b7dc560f3b6834cf8038b9`.
- Independent IPA identity: `com.embyplayerlab.app / OnePlayer / 0.15.12 (279)`; `MinimumOSVersion=15.0`; MinOS audit OK.
- Evidence: **Code written ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device pending ❌ / stable ❌**.

'''
if marker not in checkpoint:
    if '## Scope guard' not in checkpoint:
        raise RuntimeError('checkpoint scope marker missing')
    checkpoint = checkpoint.replace('## Scope guard', section + '## Scope guard', 1)
checkpoint = checkpoint.replace('- Build277 target-device input benchmark: ❌ pending.', '- Build277 target-device input benchmark: ✅ completed; PAN≈110 and SCROLLVIEW≈110 are valid, TOUCH result invalid due probe initialization bug.')
if '- Build279 exact-source CI passed:' not in checkpoint:
    checkpoint = checkpoint.replace('- Stable/frozen reopened performance task: ❌.', '- Build279 Code written: ✅ exact source `94f7a4ba5aa5bfdd3beb724e216015141dfc50b7`.\n- Build279 exact-source CI passed: ✅ run/job `33377860245 / 99443301805`.\n- Build279 IPA produced + independently verified: ✅ artifact `9752649942`; IPA SHA `36f17a02a0deddbae593f137d455cba3d22849bf28f00c0fafeb755b620abf9b`; source SHA `9e3f149fed7426db36d5d32669b2ebc3c049661b80b7dc560f3b6834cf8038b9`; MinOS 15.0.\n- Build279 target-device real-carousel PAN A/B: ❌ pending.\n- Stable/frozen reopened performance task: ❌.')
checkpoint = re.sub(r'## Next exact action\n\n.*\Z', '''## Next exact action\n\nInstall Build279 with screen recording off. Compare sustained system HUD under **normal `PIPE CAROUSEL`** and **`PIPE CAROUSEL PAN`** using long continuous horizontal drags; then briefly retest corrected `PIPE TOUCH LAYER` and provide the App log. The decisive control is whether `CAROUSEL PAN` materially lifts the same real carousel tree above the normal ~90 FPS ceiling. Do not replace the product owner or add DisplayLink interpolation before that target-device result.\n''', checkpoint, flags=re.S)
write(checkpoint_path, checkpoint)

module_path = 'docs/project/MODULE_STATUS.md'
module = read(module_path)
module_lines = module.splitlines()
for i, line in enumerate(module_lines):
    if line.startswith('| Home carousel interaction / presentation cadence |'):
        module_lines[i] = '| Home carousel interaction / presentation cadence | **Active — Build277 input result narrows delivery cadence; Build279 real-carousel Pan A/B CI/IPA verified** | Build275 same-package control remains `CAROUSEL≈90` while fixed device-max TREE/simple probes reach 120. Build277 target-device: valid `PAN≈110` and `SCROLLVIEW≈110`; its reported `TOUCH≈110` is invalid because a first-entry guard failed to install the raw-touch recognizer. App log shows long Pan callback avg 8.79 ms and ScrollView ~8.60 ms while normal carousel delivered-touch median ~13.54 ms and progress/render publication ~21 ms. Build279 / 0.15.12 exact source `94f7a4ba5aa5bfdd3beb724e216015141dfc50b7` keeps normal owner as control and adds diagnostic `CAROUSEL PAN` driving the same real transition state/tree; run/job `33377860245 / 99443301805`; artifact `9752649942`; IPA SHA `36f17a02a0deddbae593f137d455cba3d22849bf28f00c0fafeb755b620abf9b`; source SHA `9e3f149fed7426db36d5d32669b2ebc3c049661b80b7dc560f3b6834cf8038b9`; MinOS 15.0. Product owner replacement is not authorized until real-device A/B. |'
        break
else:
    raise RuntimeError('module carousel row missing')
module = '\n'.join(module_lines) + ('\n' if module.endswith('\n') else '')
module = module.replace('Home Build274 is diagnostic-only and must not replace the accepted overall baseline;', 'Home Build279 is diagnostic-only and must not replace the accepted overall baseline;')
write(module_path, module)

project_path = 'docs/project/PROJECT_STATE.md'
project = read(project_path)
project = project.replace('Home Build277 remains separate;', 'Home Build279 remains separate;')
active_pattern = r'## Active: Home carousel input/publication diagnosis — Build277 / 0\.15\.10\n.*?(?=\n## Completed / frozen: Home carousel interaction — Build241 / 0\.14\.74)'
active_replacement = '''## Active: Home carousel input/publication diagnosis — Build279 / 0.15.12

Build275 remains the decisive same-package control: with recording off, normal finger-driven `CAROUSEL≈90`, while fixed device-max `TREE FULL/HERO/BACKDROP`, corrected CA, DISPLAYLINK and SWIFTUI reach 120. The steady-state presentation tree therefore has demonstrated 120 Hz headroom; the active boundary is real input delivery → progress publication.

Build277 target-device input testing reports `CAROUSEL≈90 / TOUCH≈110 / PAN≈110 / SCROLLVIEW≈110`, but source/log inspection invalidates the TOUCH attribution: the first-entry mode guard did not install `V3HomeRawTouchRecognizer`, and all 35 `mode=rawTouch` log sessions actually end as ScrollView drag/deceleration. PAN and SCROLLVIEW remain valid. `OnePlayer-App-1788167172.log` shows a 1,257-sample Pan drag averaging 8.79 ms callbacks and ScrollView near 8.60 ms, versus normal carousel delivered-touch median ~13.54 ms and progress/render publication around ~21 ms. This supports a narrower input-delivery hypothesis but does **not** yet authorize a product-owner replacement.

Build279 is the next exact real-tree A/B. Normal `CAROUSEL` keeps the existing Build275/241 owner; `CAROUSEL PAN` uses standard `UIPanGestureRecognizer` to drive the same existing drag/finish callbacks, transition state and full carousel presentation. The Build277 raw-touch initialization bug is also corrected. Exact source `94f7a4ba5aa5bfdd3beb724e216015141dfc50b7`; Xcode 16.4 run/job `33377860245 / 99443301805` success; artifact `9752649942`, digest `sha256:8cf341ff3cc3706e6fb4ab8036eea8c0928e7cd90e6fafc2cdd33ad74fbb2143`; IPA SHA `36f17a02a0deddbae593f137d455cba3d22849bf28f00c0fafeb755b620abf9b`; source ZIP SHA `9e3f149fed7426db36d5d32669b2ebc3c049661b80b7dc560f3b6834cf8038b9`; `0.15.12 (279)` / MinOS 15.0 independently verified. **Code/CI/IPA ✅ / real-device Build279 pending / stable ❌**.
'''
project, count = re.subn(active_pattern, active_replacement, project, flags=re.S)
if count != 1:
    raise RuntimeError(f'project active carousel section replace count={count}')
write(project_path, project)

index_path = 'docs/project/BUILD_TEST_INDEX.md'
index = read(index_path)
rows = [
    '| **Build277 / 0.15.10** | Carousel input-pipeline benchmark | **Target-device partially valid diagnostic; not stable.** User HUD: `CAROUSEL≈90 / TOUCH≈110 / PAN≈110 / SCROLLVIEW≈110`. Source/log inspection invalidates TOUCH because the first-entry guard failed to install raw recognizer; all 35 `mode=rawTouch` records are actually ScrollView endings. PAN/SCROLLVIEW are valid; long Pan callback avg 8.79 ms, ScrollView ~8.60 ms, while normal carousel delivered-touch median ~13.54 ms and publication/render ~21 ms. Exact source `1446640b0d9cec5cb2f39d36cff0bfeca4efd31d`; run/job `33336619261 / 99324579844`; artifact `9739256003`; IPA SHA `e27c86b5084db257174d3afd5cc33e147be6868ef6262245f8a3361ed63f097c`. |',
    '| **Build279 / 0.15.12** | Real-carousel standard-Pan input A/B | **Code/CI/IPA verified; target-device pending; diagnostic-only.** Normal `CAROUSEL` remains existing owner; `CAROUSEL PAN` uses standard `UIPanGestureRecognizer` to drive the same real carousel state/tree, and raw TOUCH probe initialization is corrected. Exact source `94f7a4ba5aa5bfdd3beb724e216015141dfc50b7`; run/job `33377860245 / 99443301805`; artifact `9752649942`, digest `sha256:8cf341ff3cc3706e6fb4ab8036eea8c0928e7cd90e6fafc2cdd33ad74fbb2143`; IPA SHA `36f17a02a0deddbae593f137d455cba3d22849bf28f00c0fafeb755b620abf9b`; source SHA `9e3f149fed7426db36d5d32669b2ebc3c049661b80b7dc560f3b6834cf8038b9`; MinOS 15.0. |'
]
if '**Build277 / 0.15.10**' not in index:
    lines = index.splitlines()
    header = next(i for i, line in enumerate(lines) if line.startswith('| Milestone |'))
    insert_at = header + 2
    while insert_at < len(lines) and lines[insert_at].startswith('|'):
        insert_at += 1
    lines[insert_at:insert_at] = rows
    index = '\n'.join(lines) + ('\n' if index.endswith('\n') else '')
else:
    lines = index.splitlines()
    for row in rows:
        key = row.split('|')[1].strip()
        for i, line in enumerate(lines):
            if key in line:
                lines[i] = row
                break
        else:
            header = next(j for j, line in enumerate(lines) if line.startswith('| Milestone |'))
            insert_at = header + 2
            while insert_at < len(lines) and lines[insert_at].startswith('|'):
                insert_at += 1
            lines.insert(insert_at, row)
    index = '\n'.join(lines) + ('\n' if index.endswith('\n') else '')
write(index_path, index)

tech_path = 'docs/project/TECHNICAL_DECISIONS.md'
tech = read(tech_path)
tech_marker = '## D025 — Carousel Build277 validates denser standard input delivery; test real-tree Pan before owner change'
tech_section = '''\n\n## D025 — Carousel Build277 validates denser standard input delivery; test real-tree Pan before owner change\n\nBuild277 target-device HUD reports normal `CAROUSEL≈90`, `PAN≈110` and native `SCROLLVIEW≈110` with recording off. The reported `TOUCH≈110` is **not valid raw-touch evidence**: source/log correlation shows the first-entry `setMode` guard failed to install `V3HomeRawTouchRecognizer`, and every logged `mode=rawTouch` session ends through ScrollView drag/deceleration callbacks. Do not use that mislabeled value in architecture decisions.\n\nThe valid log evidence is narrower and sufficient for one next A/B. A long standard-Pan drag delivered 1,257 callbacks at 8.79 ms average spacing; ScrollView delivery is similarly near device-max cadence, while normal carousel delivered-touch median is ~13.54 ms and progress/render publication is ~21 ms. This establishes that the custom product delivered-move path is materially sparser than standard UIKit Pan/Scroll delivery under the same device, but it does not prove recognizer replacement will raise the full carousel presentation.\n\nBuild279 therefore keeps the normal product owner unchanged as `CAROUSEL` control and adds diagnostic `CAROUSEL PAN`: standard `UIPanGestureRecognizer` drives the existing `shouldBeginNativeCarouselDrag`, `handleNativeCarouselDrag`, `finishNativeCarouselDrag` and the same real transition state/presentation tree. It also corrects the raw-touch probe initializer. No DisplayLink interpolation/latch, coalesced continuous render authority, timer/watchdog/retry/fallback, duplicate state owner or playback/transport change is authorized. Replace the product owner only if Build279 target-device `CAROUSEL PAN` materially and repeatably outperforms normal `CAROUSEL`. Exact source `94f7a4ba5aa5bfdd3beb724e216015141dfc50b7`; run/job `33377860245 / 99443301805`; artifact `9752649942`; IPA SHA `36f17a02a0deddbae593f137d455cba3d22849bf28f00c0fafeb755b620abf9b`; MinOS 15.0.\n'''
if tech_marker not in tech:
    tech = tech.rstrip() + tech_section + '\n'
write(tech_path, tech)
