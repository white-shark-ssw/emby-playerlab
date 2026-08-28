from pathlib import Path

# DEV checkpoint
p = Path('docs/project/current/dev/DEV-home-carousel-drag-smoothness.md')
text = p.read_text()
old_status = '''**Active — Build236 start-step handling + Build231 foreground compositing + Build226 Hero residency + Build228 max-refresh-through-settle/release-tail are frozen-for-current-phase. Build237 persistent source-over correction is now also target-device accepted because the reported white flash is gone. Build237 halving of the predicted-total-distance fling gate to 0.24×width is rejected as sufficient: EX accepts almost-in-place flicks while OnePlayer still feels distance-bound. Build238 / 0.14.71 is the current measurement-only candidate to log real release velocity and predicted extra travel before replacing the distance-based fling gate. Slow-drag commit remains 0.28. Whole carousel remains Active only for fling-intent release behavior; stable ❌.**'''
new_status = '''**Active — Build236 start-step handling + Build231 foreground compositing + Build226 Hero residency + Build228 max-refresh-through-settle/release-tail remain frozen-for-current-phase, and Build237 persistent source-over white-flash correction remains target-device accepted. Build238 target-device data strongly separates intended quick flicks from short slow drags on latest delivered move velocity: quick flicks |v| ≈1139.8–2239.8 pt/s versus slow drags ≈0–160 pt/s, while end velocity overlaps and predicted extra travel is often tiny/missing. Build239 / 0.14.72 is now the CI/IPA-verified velocity-fling A/B: ordinary progress commit remains 0.28, the legacy 0.24×width predicted-total-distance gate is removed, and direction-aware latest delivered move velocity >=600 pt/s can commit. Target-device validation pending; stable ❌.**'''
if text.count(old_status) != 1: raise SystemExit('checkpoint status anchor mismatch')
text = text.replace(old_status, new_status, 1)
text = text.replace('- Working branch: `diag/home-carousel-release-intent-build238`', '- Working branch: `perf/home-carousel-velocity-fling-build239`', 1)
text = text.replace('- Current candidate: OnePlayer `0.14.71 (238)`', '- Current candidate: OnePlayer `0.14.72 (239)`', 1)
old_evidence = 'Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / behavior intentionally unchanged / target-device diagnostic pending ❌ / stable ❌.'
new_evidence = '''Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / behavior intentionally unchanged / target-device diagnostic tested ✅ / velocity-intent hypothesis strongly supported ✅ / stable ❌.

### 2026-08-29 Build238 target-device result — latest delivered move velocity cleanly separates intent

User supplied the Build238 App log after performing the requested gesture families on iPhone 15 Pro Max / iOS 17.0. The 28 `HomeCarouselRelease` samples separate strongly:

- first 19 intended quick flicks: `abs(last_move_delivered_velocity_x)` ≈ **1139.8–2239.8 pt/s**;
- final 9 short slow drags: `abs(last_move_delivered_velocity_x)` ≈ **0–160 pt/s**;
- measured empty interval: roughly **160–1140 pt/s**;
- coalesced velocity shows the same separation: quick ≈1199.6–2319.8 pt/s, slow ≈0–80 pt/s;
- `end_velocity_x` overlaps materially (quick flicks often ~400–480 pt/s; slow releases can also reach ~480 pt/s), so it is not the sole commit signal;
- `predicted_extra_x` is absent for many quick flicks and, when present, can be only ~6–13.3pt despite clear fling intent, directly explaining why predicted-total-distance gating feels like a distance wall.

Controlling conclusion: the next release A/B should use direction-aware **latest delivered move velocity**, not another page-width distance fraction. The threshold may be chosen only inside the measured empty interval and is a OnePlayer tuning value, not an asserted EX constant.'''
if text.count(old_evidence) != 1: raise SystemExit('Build238 evidence anchor mismatch')
text = text.replace(old_evidence, new_evidence, 1)
insert_anchor = '\n## Rejected directions not to repeat\n'
if text.count(insert_anchor) != 1: raise SystemExit('rejected-directions anchor mismatch')
build239 = '''
## Build239 / 0.14.72 — direction-aware velocity fling A/B

Build239 implements the minimum behavior change supported by Build238. Slow/ordinary drag commit remains `actualProgress >= 0.28`. The legacy `max(actualDistance, predictedDistance) >= width * 0.24` path is removed from the commit decision. A release can additionally commit when the latest delivered move velocity is in the already-selected carousel direction and its directional magnitude is at least **600 pt/s**.

`600 pt/s` sits deliberately inside Build238's measured empty interval (~160–1140 pt/s). It is an initial OnePlayer A/B threshold, not an EX-internal parameter. `HomeCarouselRelease` measurement logging remains available and Build239 adds one release-only `HomeCarouselReleaseDecision` line containing progress, raw release velocity, direction-adjusted velocity, velocity-commit and final decision. No timer/interpolation/debounce/throttle/watchdog/retry, no second gesture owner and no release-tail easing/duration change are introduced.

Retained unchanged: Build237 persistent source-over white-flash correction, Build236 post-acquisition real-baseline handling, Build231 foreground `compositingGroup()`, Build226 three-slot Hero residency and Build228 max-refresh-through-settle / accepted 0.22s commit + 0.18s cancel tail. Player / MPV / PiP / Transport / Cache / Emby Session / STRM / 302 / Range paths are untouched.

### CI / IPA evidence

- branch: `perf/home-carousel-velocity-fling-build239`;
- exact base: cleaned Build238 head `c2fdeb070cdb652eb25a96e8ff39edd6e7f6234f`;
- exact tested source / CI head: `ed4e59c2a0e2fac3979d84dad756299659b15387`;
- product-clean head after removing temporary Build239 apply/CI helpers: `57509f1d2693ad8d605cd681778e22080b443747`;
- dedicated Xcode 16.4 run/job: `33208503351 / 98975620229` — success;
- artifact: `OnePlayer-0.14.72-build239-velocity-fling`, ID `9700721145`;
- artifact digest: `sha256:61c4785bba434247039206198cb35700b47cbc2ead2be1178e914229c3814c5f`;
- IPA SHA-256: `b11992aa6b4c87df87600ec38143798aece6df231507a6d13357856318f6196d`;
- source ZIP SHA-256: `55b2977ab1df60bbc154cbd926f2997ca8086f6061394f4c05a4e40028783001`;
- independent artifact reopen confirms source SHA `ed4e59c2a0e2fac3979d84dad756299659b15387`, bundle `com.embyplayerlab.app`, OnePlayer `0.14.72 (239)`, `MinimumOSVersion=15.0`, `CADisableMinimumFrameDurationOnPhone=true`;
- independent source reopen confirms `shouldCommit = actualProgress >= 0.28 || velocityCommit`, `directionalVelocity >= 600`, the legacy 0.24×width predicted-total-distance gate is absent, and retained Build236/231/226/228 markers remain.

Evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device pending ❌ / stable ❌.
'''
text = text.replace(insert_anchor, build239 + insert_anchor, 1)
next_anchor = '## Next exact action\n\n'
if text.count(next_anchor) != 1: raise SystemExit('next-action anchor mismatch')
prefix = text.split(next_anchor, 1)[0]
text = prefix + '''## Next exact action

Install OnePlayer 0.14.72 / Build239 on iPhone 15 Pro Max / iOS 17.0 and compare directly with EX. Focus only on release intent: (A) repeat about 15 almost-in-place quick flicks in both directions that should commit, and (B) about 10 short slow drags/releases that should cancel unless actual progress itself crosses 0.28. The primary pass criterion is that quick flicks no longer feel blocked by a distance wall while slow drags do not become over-sensitive. If any false commit / false cancel occurs, export the App log and inspect `HomeCarouselRelease` + `HomeCarouselReleaseDecision` before changing the 600 pt/s threshold. Do not reopen Build236/231/226/228, Build237 white-flash presentation or release-tail timing without new regression evidence.
'''
p.write_text(text)

# Remove the emergency one-result side checkpoint after folding its evidence into the canonical task checkpoint.
extra = Path('docs/project/current/dev/DEV-home-carousel-build238-release-result.md')
if not extra.exists() or 'Parent work: `DEV-home-carousel-drag-smoothness`' not in extra.read_text(): raise SystemExit('Build238 side checkpoint identity mismatch')
extra.unlink()

# MODULE_STATUS
p = Path('docs/project/MODULE_STATUS.md')
text = p.read_text()
old = '| Home carousel interaction | **Active — Build236/231/226/228 foundation frozen-for-current-phase; Build237 white-flash fix accepted; Build238 release-intent diagnostics CI/IPA verified** | Target device confirms Build237 removes the transition white flash, so retain its persistent source-over crossfade correction. The 0.24×width predicted-total-distance fling gate remains too resistant versus EX and is rejected as sufficient; do not keep lowering distance fractions blindly. Build238 / 0.14.71 changes no release behavior and logs real terminal delivered/coalesced velocity plus predicted extra travel to derive a fling-intent gate from evidence. Slow-drag commit remains 0.28. Build238 tested source `780283bc722e39564240d996ca3c522bc61c6066`; run/job `33204499623 / 98961981208`; artifact `9699150399`; IPA SHA-256 `3539fd2f8c83c56838242a69350c473bd0088a65c273a5a0c0b4f3676878efd4`; MinOS 15.0. Target-device release diagnostic pending; not stable. |'
new = '| Home carousel interaction | **Active — Build236/231/226/228 foundation frozen-for-current-phase; Build237 white-flash fix accepted; Build238 velocity-intent evidence validated; Build239 CI/IPA verified** | Build238 target-device data separates quick flicks (~1139.8–2239.8 pt/s latest delivered velocity) from short slow drags (0–160 pt/s), while end velocity overlaps and predicted extra travel is often tiny/missing. Build239 / 0.14.72 therefore keeps slow-drag progress commit at 0.28, removes the rejected 0.24×width predicted-total-distance fling gate, and adds a direction-aware latest-delivered-move velocity commit at 600 pt/s. Tested source `ed4e59c2a0e2fac3979d84dad756299659b15387`; run/job `33208503351 / 98975620229`; artifact `9700721145`; IPA SHA-256 `b11992aa6b4c87df87600ec38143798aece6df231507a6d13357856318f6196d`; MinOS 15.0. Target-device Build239 A/B pending; not stable. |'
if text.count(old) != 1: raise SystemExit('MODULE_STATUS carousel row mismatch')
text = text.replace(old, new, 1)
old2 = '| Other product modules | Active parallel work | Build216 / 0.14.49 remains the accepted overall runtime baseline. Home-carousel Build238 is an isolated release-intent diagnostic candidate on top of the frozen-for-current-phase Build236/231/226/228 foundation plus accepted Build237 white-flash correction. Poster and Aether remain separate Active tasks with independent checkpoints/branches; do not infer their candidates from this carousel row. |'
new2 = '| Other product modules | Active parallel work | Build216 / 0.14.49 remains the accepted overall runtime baseline. Home-carousel Build239 is an isolated velocity-fling A/B on top of the frozen-for-current-phase Build236/231/226/228 foundation plus accepted Build237 white-flash correction; its CI/IPA success is not a real-device verdict. Poster and Aether remain separate Active tasks with independent checkpoints/branches; do not infer their candidates from this carousel row. |'
if text.count(old2) != 1: raise SystemExit('MODULE_STATUS other row mismatch')
text = text.replace(old2, new2, 1)
p.write_text(text)

# PROJECT_STATE
p = Path('docs/project/PROJECT_STATE.md')
text = p.read_text()
old_header = '_Last updated after Build237 target-device testing accepted the persistent white-flash correction but rejected the lowered predicted-total-distance fling gate as sufficient, and Build238 / 0.14.71 reached CI/IPA verification as a measurement-only release-intent candidate. Build216 remains the accepted overall runtime baseline._'
new_header = '_Last updated after Build238 target-device release diagnostics validated latest-delivered-move velocity as the fling-intent signal and Build239 / 0.14.72 reached CI/IPA verification with a direction-aware 600 pt/s fling gate while preserving the 0.28 slow-drag progress threshold. Build216 remains the accepted overall runtime baseline._'
if text.count(old_header) != 1: raise SystemExit('PROJECT_STATE header mismatch')
text = text.replace(old_header, new_header, 1)
old_release = '- predicted-distance release gate 0.48 × width;'
new_release = '- ordinary slow-drag commit threshold 0.28; Build239 is the current A/B that removes the rejected predicted-total-distance fling gate and tests direction-aware latest-delivered velocity >=600 pt/s for fling intent;'
if text.count(old_release) != 1: raise SystemExit('PROJECT_STATE release bullet mismatch')
text = text.replace(old_release, new_release, 1)
start = '### Carousel Build237 real-device split + Build238 release-intent diagnostics\n\n'
end = '\n## Active: Poster-heavy scrolling smoothness\n'
if text.count(start) != 1 or text.count(end) != 1: raise SystemExit('PROJECT_STATE carousel section anchors mismatch')
before, rest = text.split(start, 1)
_, after = rest.split(end, 1)
section = '''### Carousel Build238 velocity evidence → Build239 direction-aware fling A/B

Build237's persistent source-over correction remains accepted because the target device confirms the transition white flash is gone. Its lowered 0.24×width predicted-total-distance release gate remains rejected as sufficient.

Build238 / 0.14.71 then measured the missing release semantic without changing behavior. The target-device log gives a strong separation on latest delivered move velocity: 19 intended quick flicks are about 1139.8–2239.8 pt/s in magnitude, while 9 short slow drags are about 0–160 pt/s, leaving a wide ~160–1140 pt/s empty interval. Coalesced velocity agrees. Terminal end velocity overlaps materially and predicted extra travel is frequently absent or only ~6–13.3pt for obvious quick flicks, so neither is accepted as the sole fling signal.

Build239 / 0.14.72 is the resulting minimal A/B. It keeps ordinary `actualProgress >= 0.28`, removes the legacy `width * 0.24` predicted-total-distance gate from commit, and adds direction-aware latest delivered move velocity >=600 pt/s. The threshold is deliberately inside the measured empty interval and is a OnePlayer tuning value, not an EX constant. Build237 white-flash presentation, Build236 start-step handling, Build231 foreground compositing, Build226 Hero residency and Build228 max-refresh-through-settle / release tail are unchanged.

Build239 evidence: tested source `ed4e59c2a0e2fac3979d84dad756299659b15387`; run/job `33208503351 / 98975620229` — success; artifact `9700721145` (`sha256:61c4785bba434247039206198cb35700b47cbc2ead2be1178e914229c3814c5f`); IPA SHA-256 `b11992aa6b4c87df87600ec38143798aece6df231507a6d13357856318f6196d`; source ZIP SHA-256 `55b2977ab1df60bbc154cbd926f2997ca8086f6061394f4c05a4e40028783001`; bundle/version/build and MinOS 15.0 independently reopened/verified. Evidence level is **Code written / CI passed / IPA produced+verified / target-device pending / not stable**.
'''
text = before + section + end + after
p.write_text(text)

# TECHNICAL_DECISIONS D012
p = Path('docs/project/TECHNICAL_DECISIONS.md')
text = p.read_text()
old = '''Build237 target-device evidence accepts the persistent source-over white-flash correction but rejects **predicted total displacement as the sole fling-intent model**. Halving the gate from 0.48×width to 0.24×width did not reproduce EX-style almost-in-place flick commits; it only moved the distance boundary. Preserve the 0.28 actual-progress slow-drag rule for now, and do not continue lowering width fractions without evidence. Build238 therefore measures release velocity and predicted **extra** travel while keeping behavior unchanged. A future fling gate may use real release velocity or another measured intent signal only after target-device quick-flick vs short-slow-drag distributions establish a defensible separation. Retain the frozen-for-current-phase Build236 start-step, Build231 foreground compositing, Build226 Hero residency, Build228 max-refresh-through-settle/release-tail behavior and the now-accepted Build237 persistent source-over correction.'''
new = '''Build237 target-device evidence accepts the persistent source-over white-flash correction but rejects **predicted total displacement as the sole fling-intent model**. Halving the gate from 0.48×width to 0.24×width did not reproduce EX-style almost-in-place flick commits; it only moved the distance boundary. Preserve the 0.28 actual-progress slow-drag rule and do not continue lowering width fractions.

Build238 target-device diagnostics supply the missing evidence: intended quick flicks are about 1139.8–2239.8 pt/s in `abs(last_move_delivered_velocity_x)`, while short slow drags are 0–160 pt/s, with a wide empty interval between them. `end_velocity_x` overlaps the two intent families and `predicted_extra_x` is often absent or tiny for clear quick flicks, so neither becomes the sole authority. This validates latest delivered move velocity as the next release-intent signal.

Build239 is the narrow behavioral A/B: keep `actualProgress >= 0.28`; remove the rejected 0.24×width predicted-total-distance commit gate; additionally commit when latest delivered move velocity is direction-compatible and at least 600 pt/s in directional magnitude. `600` is an evidence-bounded OnePlayer tuning value inside the measured gap, not an asserted EX constant. CI/IPA are verified but target-device acceptance is pending, so the velocity threshold is not frozen yet. Retain the frozen-for-current-phase Build236 start-step, Build231 foreground compositing, Build226 Hero residency, Build228 max-refresh-through-settle/release-tail behavior and accepted Build237 persistent source-over correction.'''
if text.count(old) != 1: raise SystemExit('TECHNICAL_DECISIONS D012 anchor mismatch')
text = text.replace(old, new, 1)
p.write_text(text)

# BUILD_TEST_INDEX
p = Path('docs/project/BUILD_TEST_INDEX.md')
text = p.read_text()
old = '| **Carousel Build238 / 0.14.71** | Release-intent measurement only | **CI/IPA verified; target-device diagnostic pending; behavior unchanged.** Logs actual/rendered release displacement, predicted endpoint and predicted extra travel, last-move delivered/coalesced velocity, terminal end velocity and touch duration. Retains Build237 white-flash correction and unchanged 0.28/0.24 release behavior. Tested source `780283bc722e39564240d996ca3c522bc61c6066`; run/job `33204499623 / 98961981208`; artifact `9699150399`; artifact SHA-256 `59baa8223ba6d652cde77cf7e6af286545b12ef6a762df110bc20d18f6524cf3`; IPA SHA-256 `3539fd2f8c83c56838242a69350c473bd0088a65c273a5a0c0b4f3676878efd4`; source ZIP SHA-256 `fefe660a5f578ed4fd3f2a55abbd73dc9fc4e41a1378467335d46989affefd01`; MinOS 15.0. |'
new = '''| **Carousel Build238 / 0.14.71** | Release-intent measurement only | **Target-device diagnostic tested; velocity-intent hypothesis strongly validated; behavior itself unchanged.** 19 intended quick flicks show `abs(last_move_delivered_velocity_x)` ≈1139.8–2239.8 pt/s while 9 short slow drags are ≈0–160 pt/s; coalesced velocity agrees. End velocity overlaps and predicted extra travel is often absent or only ~6–13.3pt for obvious flicks, rejecting those as sole signals. Tested source `780283bc722e39564240d996ca3c522bc61c6066`; run/job `33204499623 / 98961981208`; artifact `9699150399`; artifact SHA-256 `59baa8223ba6d652cde77cf7e6af286545b12ef6a762df110bc20d18f6524cf3`; IPA SHA-256 `3539fd2f8c83c56838242a69350c473bd0088a65c273a5a0c0b4f3676878efd4`; MinOS 15.0. |
| **Carousel Build239 / 0.14.72** | Direction-aware velocity fling A/B | **CI/IPA verified; target-device pending; not stable.** Keeps ordinary `actualProgress >= 0.28`, removes the rejected 0.24×width predicted-total-distance commit gate, and commits a fling when latest delivered move velocity is direction-compatible with magnitude >=600 pt/s. Build237 white-flash correction and Build236/231/226/228 foundation remain unchanged. Tested source `ed4e59c2a0e2fac3979d84dad756299659b15387`; run/job `33208503351 / 98975620229`; artifact `9700721145`; artifact digest `sha256:61c4785bba434247039206198cb35700b47cbc2ead2be1178e914229c3814c5f`; IPA SHA-256 `b11992aa6b4c87df87600ec38143798aece6df231507a6d13357856318f6196d`; source ZIP SHA-256 `55b2977ab1df60bbc154cbd926f2997ca8086f6061394f4c05a4e40028783001`; MinOS 15.0. |'''
if text.count(old) != 1: raise SystemExit('BUILD_TEST_INDEX Build238 row mismatch')
text = text.replace(old, new, 1)
p.write_text(text)
