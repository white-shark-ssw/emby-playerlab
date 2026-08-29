from pathlib import Path

# Checkpoint
p=Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
t=p.read_text()
old='**Active — Build239 / 0.14.72 velocity-fling behavior is now target-device accepted: the user reports no issue after replacing the rejected predicted-total-distance wall with direction-aware latest-delivered velocity >=600 pt/s while retaining the 0.28 slow-drag rule. Freeze Build239 fling intent together with the already frozen-for-current-phase Build236/231/226/228 foundation and accepted Build237 white-flash correction. A new EX-only 5.0s / 510×1108 / 30fps reference recording shows a visibly decelerating ease-out tail over roughly the last 0.15–0.25s of several transitions, without obvious rebound. Build239 already uses `.easeOut(duration: 0.22)` for commit and `.easeOut(duration: 0.18)` for cancel, so the EX recording alone does not justify changing duration/curve. Whole carousel remains Active only for optional matched tail-curve comparison; stable ❌.**'
new='**Frozen-for-current-phase at Build239 / 0.14.72 — target-device velocity-fling behavior is accepted, the Build237 white-flash correction remains accepted, and a matched OnePlayer vs EX 30fps comparison shows the existing Build239 commit ease-out tail is already materially aligned with EX. Keep 0.28 slow-drag commit, direction-aware latest-delivered velocity >=600 pt/s, Build236 real-sample start handling, Build231 foreground compositing, Build226 Hero residency and Build228 max-refresh-through-settle / 0.22s commit + 0.18s cancel tail. No further carousel tuning is justified without a new real-device regression. Whole-product accepted baseline remains Build216 on main; Build239 is a feature freeze point, not yet a merged overall product baseline.**'
if old not in t: raise SystemExit('checkpoint anchor missing')
t=t.replace(old,new,1)
marker='## Rejected directions not to repeat\n'
sec='''### 2026-08-29 matched OnePlayer vs EX tail comparison — no tail change justified\n\nUser supplied OnePlayer recording `RPReplay_Final1787975158.mp4` (5.23s, 510×1108, 30fps) after the earlier EX reference. Tracking incoming foreground/title position over final settle frames gives materially similar normalized remaining-distance curves: representative sample **OnePlayer 100% → 47% → 11% → 0** versus **EX 100% → 43% → 11% → 0**; second sample **OnePlayer 100% → 42% → 6% → 0** versus **EX 100% → 49% → 17% → 0**. At 30fps this cannot identify an exact cubic timing function, but it directly disproves the idea that OnePlayer lacks an ease-out tail.\n\nBuild239 already uses `.easeOut(duration: 0.22)` for commit and `.easeOut(duration: 0.18)` for cancel. Together with the user's Build239 verdict “没问题了”, this closes the optional tail-comparison question for the current phase. Do not change duration/curve merely to chase a subjective EX difference; reopen only for a new target-device regression.\n\nEvidence: Build239 Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device release intent accepted ✅ / matched OnePlayer-vs-EX tail comparison completed ✅ / feature frozen-for-current-phase ✅ / merged overall product baseline ❌.\n\n'''
if '### 2026-08-29 matched OnePlayer vs EX tail comparison' not in t:
    if marker not in t: raise SystemExit('checkpoint section marker missing')
    t=t.replace(marker,sec+marker,1)
next_marker='## Next exact action\n'
if next_marker not in t: raise SystemExit('next action marker missing')
t=t.split(next_marker,1)[0]+next_marker+'\nNo further Home-carousel tuning is planned. Keep Build239 as the frozen-for-current-phase feature baseline and reopen only for a new real-device regression. Do not tune the 600 pt/s threshold, 0.28 slow-drag threshold, 0.22s/0.18s ease-out tail, Build236 start-step path, Build231 compositing, Build226 Hero residency or Build237 white-flash correction without new evidence.\n'
p.write_text(t)

# Module status
p=Path('docs/project/MODULE_STATUS.md'); t=p.read_text(); lines=t.splitlines()
found=False
for i,line in enumerate(lines):
    if line.startswith('| Home carousel interaction |'):
        lines[i]='| Home carousel interaction | **Frozen-for-current-phase at Build239 / 0.14.72** | Target-device Build239 release intent is accepted; matched OnePlayer-vs-EX 30fps analysis confirms the existing ease-out tail is materially aligned, so no further curve tuning is justified. Retain 0.28 slow-drag commit, direction-aware latest-delivered velocity >=600 pt/s, Build237 white-flash correction, Build236 start-step handling, Build231 foreground compositing, Build226 Hero residency and Build228 max-refresh-through-settle / 0.22s commit + 0.18s cancel tail. Tested source `ed4e59c2a0e2fac3979d84dad756299659b15387`; run/job `33208503351 / 98975620229`; artifact `9700721145`; IPA SHA-256 `b11992aa6b4c87df87600ec38143798aece6df231507a6d13357856318f6196d`; MinOS 15.0. Reopen only for new target-device regression; Build216 remains the merged overall runtime baseline. |'; found=True; break
if not found: raise SystemExit('module row missing')
p.write_text('\n'.join(lines)+'\n')

# Project state
p=Path('docs/project/PROJECT_STATE.md'); t=p.read_text()
old="_Last updated after Build239 / 0.14.72 target-device testing accepted direction-aware 600 pt/s velocity fling behavior, while a new EX reference confirmed a visibly decelerating transition tail that does not yet justify changing OnePlayer's existing 0.22s/0.18s ease-out curve without matched evidence. Build216 remains the accepted overall runtime baseline._"
new="_Last updated after a matched Build239-vs-EX 30fps comparison confirmed OnePlayer already has a materially similar ease-out settle tail. Home-carousel interaction/presentation is frozen-for-current-phase at Build239 / 0.14.72; Build216 remains the accepted merged overall runtime baseline._"
if old not in t: raise SystemExit('project header missing')
t=t.replace(old,new,1)
marker='## Active: Poster-heavy scrolling smoothness\n'
sec='''### Home carousel Build239 frozen-for-current-phase after matched tail comparison\n\nBuild239 / 0.14.72 is the current feature freeze point for Home carousel interaction/presentation. Target-device release intent is accepted with 0.28 slow-drag commit plus direction-aware latest-delivered velocity >=600 pt/s; the predicted-total-distance wall remains removed. Build237 white-flash correction, Build236 first-post-acquisition real baseline, Build231 foreground compositing, Build226 Hero residency and Build228 max-refresh-through-settle/release tail are retained.\n\nThe matched OnePlayer 30fps recording shows materially similar normalized late settle decay to EX (representative OnePlayer ~100→47→11→0 vs EX ~100→43→11→0; second sample OnePlayer ~100→42→6→0 vs EX ~100→49→17→0). This removes the remaining evidence basis for another tail-tuning build. Reopen only for a new target-device regression. This is a feature freeze point, not a replacement for the merged overall Build216 baseline.\n\n'''
if '### Home carousel Build239 frozen-for-current-phase after matched tail comparison' not in t:
    if marker not in t: raise SystemExit('project marker missing')
    t=t.replace(marker,sec+marker,1)
p.write_text(t)

# Technical decisions
p=Path('docs/project/TECHNICAL_DECISIONS.md'); t=p.read_text(); marker='## D013 — Detail high-rate scroll and warm presentation stay scoped and presentation-only\n'
sec='''Matched OnePlayer-vs-EX 30fps tail evidence closes the remaining carousel release-tail comparison for the current phase. Build239's existing `.easeOut(duration: 0.22)` commit tail produces materially similar normalized late-frame settle decay to EX, while cancel remains `.easeOut(duration: 0.18)`. Do not change release duration/curve, 600 pt/s fling threshold, 0.28 slow-drag threshold, Build236 start-step handling, Build231 foreground compositing, Build226 Hero residency or Build237 persistent white-flash correction without a new target-device regression. Home carousel is frozen-for-current-phase at Build239 / 0.14.72; this does not change the merged overall product baseline from Build216.\n\n'''
if 'Matched OnePlayer-vs-EX 30fps tail evidence closes' not in t:
    if marker not in t: raise SystemExit('technical marker missing')
    t=t.replace(marker,sec+marker,1)
p.write_text(t)

# Build/test index: replace row by prefix, avoiding brittle exact-text matching.
p=Path('docs/project/BUILD_TEST_INDEX.md'); t=p.read_text(); lines=t.splitlines(); found=False
for i,line in enumerate(lines):
    if line.startswith('| **Carousel Build239 / 0.14.72** |'):
        lines[i]='| **Carousel Build239 / 0.14.72** | Direction-aware velocity fling + finalized carousel settle/presentation contract | **Target-device accepted and frozen-for-current-phase.** Keeps 0.28 slow-drag progress commit, removes rejected predicted-total-distance gate, commits direction-aware latest-delivered velocity at >=600 pt/s, and retains Build237 white-flash fix plus Build236/231/226/228 foundation. User verdict: “没问题了”. Matched OnePlayer-vs-EX 30fps tracking shows materially similar late ease-out decay, so no additional tail-curve build is justified. Tested source `ed4e59c2a0e2fac3979d84dad756299659b15387`; run/job `33208503351 / 98975620229`; artifact `9700721145`; artifact digest `sha256:61c4785bba434247039206198cb35700b47cbc2ead2be1178e914229c3814c5f`; IPA SHA-256 `b11992aa6b4c87df87600ec38143798aece6df231507a6d13357856318f6196d`; MinOS 15.0. Feature freeze point only; merged overall product baseline remains Build216. |'; found=True; break
if not found: raise SystemExit('build index row missing')
p.write_text('\n'.join(lines)+'\n')
