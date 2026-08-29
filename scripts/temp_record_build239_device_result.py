from pathlib import Path

CHECKPOINT = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')


def update_checkpoint():
    p = CHECKPOINT
    text = p.read_text()
    old = '**Active — Build236 start-step handling + Build231 foreground compositing + Build226 Hero residency + Build228 max-refresh-through-settle/release-tail remain frozen-for-current-phase, and Build237 persistent source-over white-flash correction remains target-device accepted. Build238 target-device data strongly separates intended quick flicks from short slow drags on latest delivered move velocity: quick flicks |v| ≈1139.8–2239.8 pt/s versus slow drags ≈0–160 pt/s, while end velocity overlaps and predicted extra travel is often tiny/missing. Build239 / 0.14.72 is now the CI/IPA-verified velocity-fling A/B: ordinary progress commit remains 0.28, the legacy 0.24×width predicted-total-distance gate is removed, and direction-aware latest delivered move velocity >=600 pt/s can commit. Target-device validation pending; stable ❌.**'
    new = '**Active — Build239 / 0.14.72 velocity-fling behavior is now target-device accepted: the user reports no issue after replacing the rejected predicted-total-distance wall with direction-aware latest-delivered velocity >=600 pt/s while retaining the 0.28 slow-drag rule. Freeze Build239 fling intent together with the already frozen-for-current-phase Build236/231/226/228 foundation and accepted Build237 white-flash correction. A new EX-only 5.0s / 510×1108 / 30fps reference recording shows a visibly decelerating ease-out tail over roughly the last 0.15–0.25s of several transitions, without obvious rebound. Build239 already uses `.easeOut(duration: 0.22)` for commit and `.easeOut(duration: 0.18)` for cancel, so the EX recording alone does not justify changing duration/curve. Whole carousel remains Active only for optional matched tail-curve comparison; stable ❌.**'
    if old not in text: raise SystemExit('checkpoint status anchor missing')
    text = text.replace(old, new, 1)
    marker = '## Rejected directions not to repeat\n'
    section = '''### 2026-08-29 Build239 target-device result — velocity fling accepted; EX tail reference observed\n\nUser target-device verdict for OnePlayer 0.14.72 / Build239: **“没问题了”**. This accepts the release-intent change for the current phase: keep ordinary slow-drag commit at `actualProgress >= 0.28`, keep direction-aware latest-delivered-move velocity commit at `>=600 pt/s`, and do not restore the rejected predicted-total-distance width gate. No false-commit/false-cancel regression was reported.\n\nThe user then supplied EX reference recording `RPReplay_Final1787973831.mp4` (5.0s, 510×1108, 30fps). Frame analysis of multiple transitions shows a clearly decelerating visual tail: late-frame progress increments shrink toward settle over roughly 0.15–0.25s, with no obvious rebound. This is consistent with an ease-out tail. Current Build239 source already uses `withAnimation(.easeOut(duration: 0.22))` for commit and `.easeOut(duration: 0.18)` for cancel. Therefore the EX-only recording does **not** yet prove that OnePlayer's duration or timing curve should change. Do not reopen the accepted release-tail contract by guessing a stronger curve without a matched OnePlayer recording or direct user regression verdict.\n\nEvidence: Build239 Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device velocity-fling tested and accepted ✅ / whole-carousel stable/frozen ❌.\n\n'''
    if '### 2026-08-29 Build239 target-device result' not in text:
        if marker not in text: raise SystemExit('checkpoint section marker missing')
        text = text.replace(marker, section + marker, 1)
    next_marker = '## Next exact action\n'
    if next_marker not in text: raise SystemExit('next action marker missing')
    text = text.split(next_marker,1)[0] + next_marker + '''\nKeep Build239 release intent frozen-for-current-phase; do not tune the 600 pt/s velocity threshold or restore a width-distance gate without new regression evidence. The EX reference confirms a visible ease-out tail, but Build239 already uses 0.22s/0.18s `.easeOut`. If tail matching is pursued, first compare a matched OnePlayer recording using the same short-flick gesture against the supplied EX clip; only then isolate duration versus timing-curve strength. Do not modify Build236/231/226/228, Build237 white-flash presentation, or the accepted Build239 velocity gate merely from the EX-only clip.\n'''
    p.write_text(text)


def update_main_docs():
    update_checkpoint()

    p = Path('docs/project/MODULE_STATUS.md')
    text = p.read_text()
    old = '| Home carousel interaction | **Active — Build236/231/226/228 foundation frozen-for-current-phase; Build237 white-flash fix accepted; Build238 velocity-intent evidence validated; Build239 CI/IPA verified** | Build238 target-device data separates quick flicks (~1139.8–2239.8 pt/s latest delivered velocity) from short slow drags (0–160 pt/s), while end velocity overlaps and predicted extra travel is often tiny/missing. Build239 / 0.14.72 therefore keeps slow-drag progress commit at 0.28, removes the rejected 0.24×width predicted-total-distance fling gate, and adds a direction-aware latest-delivered-move velocity commit at 600 pt/s. Tested source `ed4e59c2a0e2fac3979d84dad756299659b15387`; run/job `33208503351 / 98975620229`; artifact `9700721145`; IPA SHA-256 `b11992aa6b4c87df87600ec38143798aece6df231507a6d13357856318f6196d`; MinOS 15.0. Target-device Build239 A/B pending; not stable. |'
    new = '| Home carousel interaction | **Active — Build239 velocity fling target-device accepted; Build236/231/226/228 foundation + Build237 white-flash fix frozen-for-current-phase** | User reports Build239 / 0.14.72 has no issue: retain 0.28 slow-drag commit plus direction-aware latest-delivered velocity >=600 pt/s and keep the rejected predicted-total-distance gate removed. Tested source `ed4e59c2a0e2fac3979d84dad756299659b15387`; run/job `33208503351 / 98975620229`; artifact `9700721145`; IPA SHA-256 `b11992aa6b4c87df87600ec38143798aece6df231507a6d13357856318f6196d`; MinOS 15.0. New EX 30fps reference visibly shows a decelerating tail, but Build239 already uses 0.22s commit / 0.18s cancel `.easeOut`; no curve change is justified without matched OnePlayer evidence. Whole carousel not yet Stable. |'
    if old not in text: raise SystemExit('module row anchor missing')
    p.write_text(text.replace(old,new,1))

    p = Path('docs/project/PROJECT_STATE.md')
    text = p.read_text()
    old = '_Last updated after Build238 target-device release diagnostics validated latest-delivered-move velocity as the fling-intent signal and Build239 / 0.14.72 reached CI/IPA verification with a direction-aware 600 pt/s fling gate while preserving the 0.28 slow-drag progress threshold. Build216 remains the accepted overall runtime baseline._'
    new = '_Last updated after Build239 / 0.14.72 target-device testing accepted direction-aware 600 pt/s velocity fling behavior, while a new EX reference confirmed a visibly decelerating transition tail that does not yet justify changing OnePlayer\'s existing 0.22s/0.18s ease-out curve without matched evidence. Build216 remains the accepted overall runtime baseline._'
    if old not in text: raise SystemExit('project-state header anchor missing')
    text = text.replace(old,new,1)
    marker = '## Active: Poster-heavy scrolling smoothness\n'
    sec = '''### Carousel Build239 target-device acceptance + EX tail reference\n\nBuild239 / 0.14.72 is now target-device accepted for release intent: the user reports no issue with the direction-aware latest-delivered velocity gate at 600 pt/s, while the ordinary 0.28 slow-drag commit remains. Keep the rejected predicted-total-distance width gate removed. The Build236/231/226/228 foundation and Build237 white-flash correction remain frozen-for-current-phase.\n\nA new EX screen recording (5.0s, 510×1108, 30fps) shows a clearly decelerating final transition segment over roughly 0.15–0.25s and no obvious rebound. Current Build239 already has `.easeOut(duration: 0.22)` commit and `.easeOut(duration: 0.18)` cancel. Treat the clip as reference evidence only; do not guess a stronger/longer curve without a matched OnePlayer capture or direct regression evidence.\n\n'''
    if '### Carousel Build239 target-device acceptance + EX tail reference' not in text:
        if marker not in text: raise SystemExit('project-state insertion marker missing')
        text = text.replace(marker, sec+marker,1)
    p.write_text(text)

    p = Path('docs/project/TECHNICAL_DECISIONS.md')
    text = p.read_text()
    marker = '## D013 — Detail high-rate scroll and warm presentation stay scoped and presentation-only\n'
    sec = '''Build239 target-device testing accepts the velocity-intent release contract for the current phase: keep `actualProgress >= 0.28` for ordinary drag and allow commit when direction-aware latest delivered move velocity is `>=600 pt/s`; keep the rejected predicted-total-distance width gate removed. The user reports no issue with Build239. Freeze this release-intent behavior unless new false-commit/false-cancel evidence appears.\n\nA subsequent EX-only 30fps reference clip visibly decelerates into settle over roughly the final 0.15–0.25s, without obvious rebound. OnePlayer Build239 already uses `.easeOut(duration: 0.22)` for commit and `.easeOut(duration: 0.18)` for cancel. Therefore this reference does not by itself authorize another release-tail tuning build; compare a matched OnePlayer capture first if tail matching is reopened.\n\n'''
    if 'Build239 target-device testing accepts the velocity-intent release contract' not in text:
        if marker not in text: raise SystemExit('technical-decision marker missing')
        text = text.replace(marker, sec+marker,1)
    p.write_text(text)

    p = Path('docs/project/BUILD_TEST_INDEX.md')
    text = p.read_text()
    old = '| **Carousel Build239 / 0.14.72** | Direction-aware velocity fling A/B | **CI/IPA verified; target-device pending; not stable.** Keeps ordinary `actualProgress >= 0.28`, removes the rejected 0.24×width predicted-total-distance commit gate, and commits a fling when latest delivered move velocity is direction-compatible with magnitude >=600 pt/s. Build237 white-flash correction and Build236/231/226/228 foundation remain unchanged. Tested source `ed4e59c2a0e2fac3979d84dad756299659b15387`; run/job `33208503351 / 98975620229`; artifact `9700721145`; artifact digest `sha256:61c4785bba434247039206198cb35700b47cbc2ead2be1178e914229c3814c5f`; IPA SHA-256 `b11992aa6b4c87df87600ec38143798aece6df231507a6d13357856318f6196d`; source ZIP SHA-256 `55b2977ab1df60bbc154cbd926f2997ca8086f6061394f4c05a4e40028783001`; MinOS 15.0. |'
    new = '| **Carousel Build239 / 0.14.72** | Direction-aware velocity fling A/B | **Target-device accepted for release intent; whole carousel not yet Stable.** Keeps 0.28 slow-drag progress commit, removes rejected 0.24×width predicted-total-distance fling gate, and commits direction-aware latest-delivered velocity at >=600 pt/s. User verdict: “没问题了”. Tested source `ed4e59c2a0e2fac3979d84dad756299659b15387`; run/job `33208503351 / 98975620229`; artifact `9700721145`; artifact digest `sha256:61c4785bba434247039206198cb35700b47cbc2ead2be1178e914229c3814c5f`; IPA SHA-256 `b11992aa6b4c87df87600ec38143798aece6df231507a6d13357856318f6196d`; source ZIP SHA-256 `55b2977ab1df60bbc154cbd926f2997ca8086f6061394f4c05a4e40028783001`; MinOS 15.0. New EX 30fps reference shows visible ease-out tail, but no OnePlayer curve change is yet justified because Build239 already uses 0.22s/0.18s `.easeOut`. |'
    if old not in text: raise SystemExit('build-index Build239 row anchor missing')
    p.write_text(text.replace(old,new,1))

if __name__ == '__main__':
    update_main_docs()
