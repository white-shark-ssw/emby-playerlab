from pathlib import Path
import re
import subprocess
import sys

MODE = sys.argv[1]
BRANCH = 'perf/home-carousel-fling-whiteflash-build237'

ci_block = '''### CI / IPA evidence\n\n- branch: `perf/home-carousel-fling-whiteflash-build237`;\n- exact base: cleaned Build236 head `f85333b58980af26af5f28ca842277f22a289347`;\n- exact tested source / CI head: `185df6a9e53387b095f35a60fa5d01b44f5af3db`;\n- dedicated Xcode 16.4 run/job: `33202505078 / 98955194172` — success;\n- artifact: `OnePlayer-0.14.70-build237-fling-whiteflash`, ID `9698408945`;\n- artifact SHA-256: `6c9eb827653eab83d4eb146f602e742d0b124bd8697cb964d7164c188b72b7cd`;\n- IPA SHA-256: `aadc7d05d72d059eadfd166647127acdab0685cc259458795b562b4f1bbb28d9`;\n- source ZIP SHA-256: `022cfe9fab14aba0f902b413ecf903e5e8c807e6be90a82dfd8c6b094c7d75a7`;\n- independent package reopen confirms bundle `com.embyplayerlab.app`, OnePlayer `0.14.70 (237)`, `MinimumOSVersion=15.0`, `CADisableMinimumFrameDurationOnPhone=true`;\n- independent source reopen confirms the only runtime deltas from Build236 are the predicted-distance gate `0.48×width → 0.24×width` and the persistent source-over crossfade correction; Build236 post-acquisition baseline, Build231 foreground `compositingGroup()`, Build226 Hero residency, Build228 0.22/0.18 release tail and exact-max refresh remain.\n\nEvidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device pending ❌ / stable ❌.\n'''

if MODE == 'branch':
    p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
    text = p.read_text()
    text = re.sub(r'^\*\*Active — Build236 is now the retained carousel control foundation.*?\*\*$', '**Active — User explicitly accepts freezing most of the materially positive Build236 carousel foundation rather than over-optimizing the residual 4/53 double-no-predecessor starts. Retain/freeze-for-current-phase: Build236 post-acquisition start-step handling, Build231 foreground `compositingGroup()`, Build226 Hero residency and Build228 max-refresh-through-settle/release-tail behavior. Build237 / 0.14.70 is now CI/IPA verified as the only remaining narrow A/B: predicted-distance fling gate is halved from 0.48×width to 0.24×width while actual-progress threshold stays 0.28, and persistent crossfade keeps outgoing fully opaque while incoming fades over it to prevent `systemBackground` leakage/white flash. Target-device testing is pending; whole carousel remains Active until these two final details are accepted or rejected.**', text, count=1, flags=re.M)
    old = 'Evidence at this checkpoint: code patch prepared on `perf/home-carousel-fling-whiteflash-build237`; CI/IPA pending; target-device pending; stable ❌.'
    if old not in text: raise SystemExit('Build237 pending evidence anchor missing')
    text = text.replace(old, ci_block, 1)
    next_action = '''## Next exact action\n\nTarget-device test OnePlayer 0.14.70 / Build237. Keep the Build236 foundation frozen-for-current-phase and judge only two variables: (1) a short drag plus fling should commit naturally at the new 0.24×width predicted-distance gate without making ordinary slow drags too eager; (2) the previously observed bright/white flash during switching should disappear because persistent outgoing coverage no longer drops below full opacity. Also sanity-check that Build236 first-step fineness, Build231 title stability and Build228 release-tail feel did not regress. Do not reopen the residual 4/53 Build236 double-no-predecessor starts without new regression evidence.\n'''
    if '## Next exact action' not in text: raise SystemExit('Next exact action missing')
    text = text[:text.index('## Next exact action')] + next_action
    p.write_text(text)
    raise SystemExit(0)

if MODE != 'main': raise SystemExit(f'unknown mode {MODE}')

checkpoint = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
checkpoint.write_text(subprocess.check_output(['git','show',f'origin/{BRANCH}:docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'], text=True))

module = Path('docs/project/MODULE_STATUS.md')
lines = module.read_text().splitlines()
row = '| Home carousel interaction | **Active — Build236 foundation frozen-for-current-phase; Build237 CI/IPA verified, target-device pending** | User accepts stopping perfection-chasing on the residual Build236 4/53 double-no-predecessor starts. Retain Build236 post-acquisition baseline, Build231 foreground compositing, Build226 Hero residency and Build228 max-refresh-through-settle/release tail unless new regression evidence appears. Build237 / 0.14.70 changes only the predicted-distance fling gate `0.48×width → 0.24×width` (actual-progress threshold stays 0.28) and persistent source-over crossfade (outgoing stays fully opaque; incoming fades over it) to address the newly reported short-fling mismatch vs EX and transition white flash. Tested source `185df6a9e53387b095f35a60fa5d01b44f5af3db`; run/job `33202505078 / 98955194172`; artifact `9698408945`; IPA SHA-256 `aadc7d05d72d059eadfd166647127acdab0685cc259458795b562b4f1bbb28d9`; MinOS 15.0. Real-device pending; not stable. |'
for i,line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i] = row
        break
else: raise SystemExit('module row missing')
module.write_text('\n'.join(lines)+'\n')

index = Path('docs/project/BUILD_TEST_INDEX.md')
lines = index.read_text().splitlines()
row237 = '| **Carousel Build237 / 0.14.70** | Short-fling gate + persistent white-flash correction | **CI/IPA verified; target-device pending; not stable.** Keeps the accepted/frozen-for-current-phase Build236/231/226/228 foundation. Only predicted-distance fling gate changes `0.48×width → 0.24×width` while actual-progress threshold remains 0.28; persistent source-over crossfade now keeps outgoing fully opaque and fades incoming over it so light `systemBackground` cannot leak through the midpoint. Tested source `185df6a9e53387b095f35a60fa5d01b44f5af3db`; run/job `33202505078 / 98955194172`; artifact `9698408945`; artifact SHA-256 `6c9eb827653eab83d4eb146f602e742d0b124bd8697cb964d7164c188b72b7cd`; IPA SHA-256 `aadc7d05d72d059eadfd166647127acdab0685cc259458795b562b4f1bbb28d9`; source ZIP SHA-256 `022cfe9fab14aba0f902b413ecf903e5e8c807e6be90a82dfd8c6b094c7d75a7`; MinOS 15.0. |'
found = False
for i,line in enumerate(lines):
    if line.startswith('| **Carousel Build237 / 0.14.70** |'):
        lines[i] = row237; found = True; break
if not found:
    insert = None
    for i,line in enumerate(lines):
        if line.startswith('| **Carousel Build236 / 0.14.69** |'): insert = i + 1
    if insert is None: raise SystemExit('Build236 row missing')
    lines.insert(insert, row237)
index.write_text('\n'.join(lines)+'\n')

state = Path('docs/project/PROJECT_STATE.md')
text = state.read_text()
text = re.sub(r'^_Last updated.*?_$', '_Last updated after the user accepted freezing most of the materially positive Build236 carousel foundation and Build237 / 0.14.70 reached CI/IPA verification for the two remaining A/B details: a 50% lower predicted-distance fling gate and a persistent source-over white-flash correction. Build216 remains the accepted overall runtime baseline._', text, count=1, flags=re.M)
addition = '''\n### Carousel Build236 partial freeze + Build237 final-detail A/B\n\nThe user explicitly prefers freezing the materially positive Build236 foundation rather than pursuing perfect elimination of the residual 4/53 double-no-predecessor first-step cases. Treat Build236 post-acquisition real-baseline handling, Build231 foreground `compositingGroup()`, Build226 Hero residency and Build228 max-refresh-through-settle/release-tail behavior as frozen-for-current-phase unless new regression evidence appears. The whole carousel remains Active only for two newly identified details.\n\nBuild237 / 0.14.70 is CI/IPA verified. It halves only the predicted-distance fling commit gate from 0.48×width to 0.24×width while keeping the ordinary actual-progress threshold at 0.28, matching the requested short-drag-plus-fling sensitivity A/B. It also corrects a real source-over compositing flaw in `persistentCarouselBackdrop`: complementary opacity on two opaque persistent images can leave only 75% combined coverage at the midpoint and expose the light `systemBackground`; Build237 keeps outgoing persistent fully opaque and fades incoming over it. This is a code/CI/IPA candidate, not yet a real-device fix.\n'''
anchor = '\n## Active: Poster-heavy scrolling smoothness'
if '### Carousel Build236 partial freeze + Build237 final-detail A/B' not in text:
    if anchor not in text: raise SystemExit('state anchor missing')
    text = text.replace(anchor, addition + anchor, 1)
state.write_text(text)

tech = Path('docs/project/TECHNICAL_DECISIONS.md')
text = tech.read_text()
addition = '''\nBuild236 target-device evidence is now accepted as the **frozen-for-current-phase interaction/presentation foundation**, not a mandate to chase perfect metrics. The user explicitly accepts the remaining 4/53 double-no-predecessor first-step cases and does not want further perfection-driven sampling changes unless a new regression appears. Retain Build236 post-acquisition real-baseline handling, Build231 page-level foreground `compositingGroup()`, Build226 Hero residency and Build228 max-refresh-through-settle/release-tail behavior. This freezes those subcontracts only; the carousel remains Active for newly reported release/presentation details.\n\nBuild237 is a narrow two-variable A/B backed by current source and explicit user request. Release sensitivity changes only the predicted-distance fling gate from `0.48×width` to `0.24×width`; the ordinary actual-progress threshold remains `0.28`, so slow-drag commit behavior is not intentionally made 50% easier. Separately, persistent backdrop crossfade no longer applies complementary opacity to two separate opaque source-over layers. At blend 0.5 that old composition covers only 75% (`0.5 + 0.5×0.5`) and can expose the light `systemBackground`, matching the newly reported white flash. Build237 therefore keeps outgoing persistent fully opaque and fades incoming over it using the unchanged backdrop blend progress. Do not remove the established system-background gradient or image-contrast scrims merely to hide the symptom. CI/IPA are verified; real-device acceptance is pending.\n'''
marker = '\n## D013 — Detail high-rate scroll and warm presentation stay scoped and presentation-only'
if 'Build236 target-device evidence is now accepted as the **frozen-for-current-phase interaction/presentation foundation**' not in text:
    if marker not in text: raise SystemExit('tech marker missing')
    text = text.replace(marker, '\n' + addition + marker, 1)
tech.write_text(text)
