from pathlib import Path
import re

tested = 'f5e3e3eb144578c863b172e3bd3a1aa13e5c2177'
run_job = '33156266871 / 98799654927'
artifact_id = '9679803873'
artifact_sha = '8b301f7644f0dfb7e1fb80dba78069f870123c663ba5b323edc93a1e88f067b2'
ipa_sha = '49efcb8766cc9414a3f35e3d8fe75a04eaf6adf2ba86a40f526a5e53c40acd4c'
source_sha = '1de13e01617a575bf5b204e9dd546af443b8a7fdf79003e3eba1399edfb06e5a'

dev = Path('docs/project/current/dev/DEV-poster-grid-smoothness.md')
s = dev.read_text()
status = ('**Active — Build228 / 0.14.61 is now target-device diagnostic tested and still visibly hitches, sometimes strongly. '
          'Its strongest captured user-drag sample is 55.1 ms; image publish/Combine→UIKit adoption measured 0.0 ms and page apply 0.3 ms, while the synchronous Library persistent snapshot took 39.7 ms and completed about 8 ms before the hitch. '
          'Build229 / 0.14.62 therefore moves only Library snapshot JSON conversion/serialization/atomic write off the MainActor onto one serial utility queue while preserving snapshot order/schema/keys and leaving Favorites persistence unchanged. Build229 is exact-source CI/IPA verified but target-device pending; not stable.**')
s, n = re.subn(r'(?s)(## Status\n\n)\*\*.*?\*\*(\n\n- \*\*Work ID\*\*:)', r'\1' + status + r'\2', s, count=1)
assert n == 1
checkpoint = f'''## Build228 real-device result / Build229 candidate — 2026-08-28

Build228 / OnePlayer 0.14.61 exact source `20f0edaf30c3c9161a79f64fd29dbc79c199473e` was tested on iPhone 15 Pro Max / iOS 17.0. User verdict: **“还是会有抖动感，有的时候还很强烈”**. Build228 is diagnostic-only and is rejected as a smoothness fix.

Uploaded App log `OnePlayer-App-1787905589.log` contains a real **55.1 ms** `scroll_route=grid`, `phase=dragging`, `delta_y=6.0` long frame during the `StartIndex=60` pagination window. Build228's new timing separates the nearby synchronous work:

- image publish / synchronous Combine→UIKit adoption: **0.0 ms** for the latest correlated publish;
- pagination result apply: **0.3 ms**;
- Library persistent snapshot serialization + atomic write: **39.7 ms**, completing about **8 ms** before the hitch.

The supplied 30 fps screen recording confirms the user's visible/tactile jitter report but its file timestamp does not align with that exact logged 55.1 ms event, so the log — not frame matching — controls attribution.

This is direct evidence that Build213's synchronous Library presentation-snapshot persistence can materially block the current pagination-adjacent scroll path. It is **not** evidence that persistence is the universal historical root cause: Build212 captured the same grid-hitch family before Build213 existed.

Build229 / OnePlayer **0.14.62 (229)** is the minimum evidence-supported candidate. Exact source: **`{tested}`**. Exact Build228→Build229 delta is five paths only: `AppIdentity`, `EmbyPagePersistentCache`, `EmbyServerBrowseV3`, Build229 changelog and poster checker. The `@MainActor` Library model still captures one immutable snapshot in current state order; only Library snapshot object→JSON conversion, JSON serialization and `.atomic` disk write run on one serial `.utility` queue, and the async caller awaits completion. Favorites persistence, cache schema/identity/content, image policy, Home carousel owner files, Player/MPV/PiP, Transport, playback Cache/Session and all P0 contracts are unchanged.

Build229 CI / IPA evidence:

- exact-source run/job: **`{run_job}` — success**;
- Xcode 16.4 Release + exact five-path scope/checker: PASS;
- artifact: `OnePlayer-0.14.62-build229-poster-snapshot-off-main`; ID **`{artifact_id}`**;
- artifact ZIP SHA-256: `{artifact_sha}`;
- IPA SHA-256: `{ipa_sha}`;
- source ZIP SHA-256: `{source_sha}`;
- bundle/version/build: `com.embyplayerlab.app`, OnePlayer **0.14.62 (229)**; `MinimumOSVersion=15.0`;
- artifact/IPA/source integrity independently verified; source snapshot contains no temporary Build229 workflow.

**Build229 evidence: Code written ✅ / exact scope+checker ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device pending ❌ / stable or frozen ❌.**

Next target-device A/B should repeat Library 3×3 scrolling through a real pagination boundary. The key question is whether the severe pagination-adjacent hitch disappears or materially shrinks. Do not claim the remaining non-pagination hitch family solved without new device evidence.

'''
anchor = '## Acceptance / protected contracts\n'
assert anchor in s
if '## Build228 real-device result / Build229 candidate — 2026-08-28' not in s:
    s = s.replace(anchor, checkpoint + anchor, 1)
dev.write_text(s)

module = Path('docs/project/MODULE_STATUS.md')
s = module.read_text()
lines = s.splitlines()
replacement = ('| Poster 3-column / poster-heavy scroll smoothness | **Active — Build228 device diagnostic found 39.7 ms synchronous Library snapshot persistence beside a 55.1 ms dragging hitch; Build229 off-main persistence CI/IPA verified, device pending** | '
               'Build228 / 0.14.61 target-device still hitches, sometimes strongly. The strongest captured grid dragging frame was 55.1 ms; latest image publish/Combine→UIKit adoption was 0.0 ms and page apply 0.3 ms, while synchronous Library snapshot persistence took 39.7 ms and ended about 8 ms before the hitch. Build229 / 0.14.62 exact source `f5e3e3eb144578c863b172e3bd3a1aa13e5c2177` keeps Build213 snapshot semantics but moves only Library JSON conversion/serialization/atomic write to one serial utility queue; Favorites, Home carousel owners and Player/Transport/Cache/Session/P0 remain unchanged. Dedicated run/job `33156266871 / 98799654927` passed, artifact `9679803873`, MinOS 15.0; target-device pending, not stable. |')
hits = [i for i, line in enumerate(lines) if line.startswith('| Poster 3-column / poster-heavy scroll smoothness |')]
assert len(hits) == 1
lines[hits[0]] = replacement
module.write_text('\n'.join(lines) + '\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
s = index.read_text()
row228 = ('| **Build228 / 0.14.61** | Poster image-adoption + pagination timing diagnostics | **Target-device diagnostic tested; still hitches, sometimes strongly; not a fix.** Exact source `20f0edaf30c3c9161a79f64fd29dbc79c199473e`; run/job `33154400536 / 98793625194`; artifact `9679088491`; MinOS 15.0. Latest log captures a 55.1 ms real grid dragging frame. Latest image publish/Combine→UIKit adoption measured 0.0 ms and pagination apply 0.3 ms, while synchronous Library presentation-snapshot persistence took 39.7 ms and completed ~8 ms before the hitch. This directly implicates persistence in this severe pagination-adjacent sample, but Build212 predates Build213 so persistence is not the universal historical root cause. |')
row229 = (f'| **Build229 / 0.14.62** | Library presentation snapshot persistence off MainActor | **CI/IPA verified; target-device pending; not stable.** Exact source `{tested}`; exact Build228→229 delta is five paths only. Library state snapshot capture remains MainActor-owned, while object→JSON conversion, JSON serialization and atomic disk write execute on one serial utility queue and are awaited in order. Favorites persistence/cache schema/image policy/Home owners/P0 remain unchanged. Run/job `{run_job}`; artifact `{artifact_id}`; artifact SHA-256 `{artifact_sha}`; IPA SHA-256 `{ipa_sha}`; source ZIP SHA-256 `{source_sha}`; OnePlayer 0.14.62 (229), MinOS 15.0 independently verified. |')
if '| **Build228 / 0.14.61** |' not in s:
    marker = '| **Build227 / 0.14.60** |'
    pos = s.find(marker)
    assert pos >= 0
    eol = s.find('\n', pos)
    assert eol >= 0
    s = s[:eol + 1] + row228 + '\n' + row229 + '\n' + s[eol + 1:]
index.write_text(s)

state = Path('docs/project/PROJECT_STATE.md')
s = state.read_text()
current = f'''### Poster Build228 device evidence → Build229 off-main persistence candidate

Build228 / 0.14.61 is now target-device diagnostic tested and **not** accepted as a smoothness fix; the user reports continued jitter and at times strong jitter. `OnePlayer-App-1787905589.log` captures a 55.1 ms real grid dragging long frame in the `StartIndex=60` pagination window. New Build228 instrumentation reports 0.0 ms latest image publish/Combine→UIKit adoption, 0.3 ms page apply, and 39.7 ms synchronous Library persistent-snapshot serialization/write ending ~8 ms before that hitch. This isolates Build213 Library persistence as a direct current severe-hitch contributor candidate, while Build212 remains the guardrail that it cannot explain the entire historical grid-hitch family.

Build229 / 0.14.62 exact source `{tested}` makes one evidence-supported runtime change: Library snapshot state is still captured on the `@MainActor`, then its JSON conversion/serialization/atomic write is awaited on one serial utility queue. Snapshot identity/schema/content/order are retained; Favorites persistence is unchanged. Exact Build228→229 scope is five paths only. Dedicated Xcode 16.4 run/job `{run_job}` succeeded; artifact `{artifact_id}`; IPA SHA-256 `{ipa_sha}`; source ZIP SHA-256 `{source_sha}`; MinOS 15.0 independently verified. **Evidence: Code written / exact scope+checker / CI passed / IPA produced+verified / target-device pending / not stable.**

'''
heading = '## Active: Poster-heavy scrolling smoothness\n\n'
assert heading in s
if '### Poster Build228 device evidence → Build229 off-main persistence candidate' not in s:
    s = s.replace(heading, heading + current, 1)
state.write_text(s)

decisions = Path('docs/project/TECHNICAL_DECISIONS.md')
s = decisions.read_text()
decision = f'''\n## 2026-08-28 — Library presentation snapshot write must not serialize/write on MainActor during pagination

Build228 target-device diagnostics captured a 55.1 ms real grid dragging frame beside a 39.7 ms synchronous Library persistent-snapshot operation, while image publish/Combine→UIKit adoption measured 0.0 ms and page result apply 0.3 ms. For the Library presentation cache, Build229 therefore retains MainActor-owned immutable state capture and existing Build213 cache identity/schema/content/atomic-write semantics, but moves object→JSON conversion, JSON serialization and disk write onto one serial `.utility` queue and awaits completion to preserve ordering. This decision applies only to the evidenced Library path; Favorites remains unchanged. Build212 predates Build213, so this is not declared the universal poster-hitch root cause. Exact Build229 source `{tested}` is CI/IPA verified and still requires target-device acceptance.
'''
if '## 2026-08-28 — Library presentation snapshot write must not serialize/write on MainActor during pagination' not in s:
    s = s.rstrip() + '\n' + decision
decisions.write_text(s)
