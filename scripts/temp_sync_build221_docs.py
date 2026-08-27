from pathlib import Path


def replace_once(path, old, new, label):
    p = Path(path)
    s = p.read_text()
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, got {count}')
    p.write_text(s.replace(old, new, 1))

# DEV checkpoint
p = 'docs/project/current/dev/DEV-home-carousel-drag-smoothness.md'
replace_once(p,
'''**Active — Build219 / 0.14.52 is real-device diagnostic tested. The explicit drag-local 120 Hz frame-rate request materially raised the complete delivered-touch → progress-publication → SwiftUI-render → display chain from roughly 50–60 Hz to roughly 98–110 Hz, proving the frame-rate request is effective and directly relevant to the residual tactile smoothness gap. Build215 motion semantics remain retained and unchanged. The remaining major evidence is now episodic 34–50 ms display gaps, frequently aligned within ~3–25 ms of Hero/persistent 1400px image callbacks.**''',
'''**Active — Build221 / 0.14.54 is the current CI/IPA-verified carousel diagnostic A/B; target-device testing is pending. Build219 proved the drag-local maximum-refresh request works and raised the delivered-touch → progress → SwiftUI-render → display chain to roughly 98–110 Hz. Its remaining strongest repeated hitch pattern is a 50 ms display gap about 19.6–25.3 ms after a persistent 1400px callback. Build221 keeps all Build215/219 motion and 120 Hz contracts, but during active drag holds the current blurred persistent backdrop at opacity 1 and does not mount the transition-target persistent image; Hero transition remains unchanged.**''',
'DEV status')
replace_once(p,
'''## Next exact action

Retain the drag-local maximum-refresh request as an evidence-backed candidate behavior and do not move to coalesced/predicted render authority. Inspect the exact Hero/persistent 1400px image callback → image publication → SwiftUI/presentation path and identify the minimal source-owned work that can explain the repeatable 34–50 ms gaps. Do not defer, suppress or re-order image updates until the real definitions/call sites/state ownership are inspected. Do not retune travel/easing/backdrop or add smoothing/timers.''',
'''## Build221 / 0.14.54 persistent-drag isolation candidate

Source inspection after Build219 established that the transition target is first mounted on the first non-zero post-acquisition render sample. Both target Hero and target persistent use their own `EmbyCachedRemoteImage` instances. With preload/render-pool hits, each loader synchronously adopts the already-decoded 1400px `UIImage`, but the target persistent path then presents it as a full-screen layer with `scaleEffect(1.12)` and `blur(radius: 30)`. Build212 already measured the synchronous callback/contrast work at only ~1–3 ms, so the repeatable later 50 ms gap is more consistent with subsequent presentation/compositing than decode or contrast itself.

Build221 makes one diagnostic presentation isolation only:

- branch `diag/home-carousel-persistent-drag-isolation-build221`;
- tested source `26fc82771b6778af14974fdac293ece0685fc76d`; durable cleanup head `1d6df7f2490a5ef5968cafb229a46cba93c622db` (temporary CI workflow/trigger deletion only);
- during `isCarouselDragging`, current persistent stays opacity 1 and transition-target persistent is not mounted;
- on release, the existing persistent transition path resumes; Hero target/crossfade is unchanged;
- Build219 exact device-max refresh request remains unchanged; coalesced/predicted touches still do not drive interactive render;
- Interaction, State, Core, shared image infrastructure and P0/Frozen paths are unchanged;
- run/job `33090175887 / 98580579889` — success;
- artifact ID `9654120029`; artifact SHA-256 `f2d18a723ae769c9ad4a3f396919567afe2a07affe8d47610777d6dd5f7029d4`;
- IPA SHA-256 `d2ee4fb2d40c251399951bc72ba6ad35fbe8ba3bfd72b861274b9b2c38fe0d9c`; source ZIP SHA-256 `aa6b700ab2aec163893c78316f80a09ab8d711797f01380ee3ed3d1e72576e97`;
- OnePlayer `0.14.54 (221)`, bundle, MinOS 15.0, ProMotion key and source contracts independently verified.

**Build221 evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device pending ❌ / diagnostic only / stable ❌.**

## Next exact action

Install Build221 on the target device, repeat the same horizontal-drag cadence test with the on-screen FPS meter if convenient, and export App logs. The decisive comparison is whether active-drag `persistent` callbacks and their repeatable 50 ms gaps disappear while Hero callbacks remain. Also note whether the drag itself improves but release/settle gains a new hitch, because Build221 intentionally resumes the existing persistent transition after touch release. Do not promote persistent suppression to a final design until this A/B is measured.''',
'DEV Build221 section')

# MODULE_STATUS
p = 'docs/project/MODULE_STATUS.md'
old = '''| Home carousel interaction | **Active — Build219 real-device diagnostic tested; 120 Hz request works, residual image-presentation gaps remain** | Build215 motion contracts remain retained: acquisition-relative X, opaque foreground, full-width `pageStep = width`, single UIKit owner and original 0.28/0.48 release semantics. Build219 / 0.14.52 keeps those behaviors and only requests the target device maximum frame-rate range on the existing drag-local diagnostic display link. Target-device evidence shows the delivered touch / progress / SwiftUI render / display chain rose from Build217's ~50–60 Hz to roughly ~98–110 Hz, while ordinary display p95 moved from 16.67 ms to 8.34 ms; the on-screen FPS meter repeatedly reaches 118–120 FPS. Build219 still records episodic 34–50 ms display gaps, frequently within ~3–25 ms of Hero/persistent 1400px image callbacks, so image publication/presentation is now the strongest residual hitch lead. Coalesced/predicted touches still do not drive render motion. Build219 is real-device diagnostic tested, not stable. Read `DEV-home-carousel-drag-smoothness`. |'''
new = '''| Home carousel interaction | **Active — Build221 CI/IPA verified; persistent-drag isolation A/B pending target-device test** | Build215 motion contracts remain retained: acquisition-relative X, opaque foreground, full-width `pageStep = width`, single UIKit owner and original 0.28/0.48 release semantics. Build219 real-device testing proved the drag-local maximum-refresh request raises delivered touch / progress / SwiftUI render / display cadence to roughly 98–110 Hz and repeatedly reaches 118–120 FPS, but retained episodic 34–50 ms gaps; seven drags showed a 50 ms max gap ~19.6–25.3 ms after a persistent 1400px callback. Build221 / 0.14.54 is a diagnostic A/B only: while actively dragging it keeps the current blurred persistent backdrop at opacity 1 and does not mount the target persistent layer; Hero transition and the 120 Hz request are unchanged, and the existing persistent transition resumes on release. Interaction/State/Core/shared image and P0/Frozen paths are unchanged. Build221 is CI/IPA verified, real-device pending, not stable. Read `DEV-home-carousel-drag-smoothness`. |'''
replace_once(p, old, new, 'MODULE carousel')

# BUILD_TEST_INDEX
p = 'docs/project/BUILD_TEST_INDEX.md'
marker = '''| **Build220 / 0.14.53** | Corrected poster grid UIKit display A/B | **Target-device tested; 3×3 smoothness basically unchanged; not accepted.** Exact source `6198466a749a54603a67c6c32bc0efcf9d7e2082`; run/job `33083504023 / 98556783889`; artifact `9651230376`; IPA SHA-256 `a73a33866745418663d1dcc35634f5b21b0a73436a91f40ed8a4f6dc6bbcf574`; MinOS 15.0. User verdict: “基本一样”. App log retains a 33.3 ms grid dragging hitch (`network/display/Primary/378` commit age 35.8 ms; cell/load-ahead age 171.7 ms) and a 74.1 ms moving hitch. Bypassing surrounding SwiftUI poster-cell observation is rejected as a sufficient fix. Next step is measurement-only around MainActor image publish/Combine→UIImageView adoption and pagination/persistent-cache apply; not stable. |\n'''
row = '''| **Build221 / 0.14.54** | Home-carousel persistent-drag presentation isolation | **CI/IPA verified; target-device A/B pending; diagnostic only, not stable.** Retains Build219 120 Hz request and all Build215 motion/release contracts. During active drag only, current persistent stays opacity 1 and target persistent is not mounted; Hero target/crossfade remains unchanged and the existing persistent transition resumes after release. Tested source `26fc82771b6778af14974fdac293ece0685fc76d`; cleanup `1d6df7f2490a5ef5968cafb229a46cba93c622db`; run/job `33090175887 / 98580579889`; artifact `9654120029`; artifact SHA-256 `f2d18a723ae769c9ad4a3f396919567afe2a07affe8d47610777d6dd5f7029d4`; IPA SHA-256 `d2ee4fb2d40c251399951bc72ba6ad35fbe8ba3bfd72b861274b9b2c38fe0d9c`; source ZIP SHA-256 `aa6b700ab2aec163893c78316f80a09ab8d711797f01380ee3ed3d1e72576e97`; MinOS 15.0. |\n'''
replace_once(p, marker, marker + row, 'BUILD_TEST 221')

# PROJECT_STATE
p = 'docs/project/PROJECT_STATE.md'
replace_once(p,
'''Current carousel diagnostic candidate: **Build219 / 0.14.52** — tested source `0b894bc37fcd0086aeaf9e1a29de0e85f5b0ee94`, cleanup head `a5050075ccceaf46196696bfa3b812293800f340`, run/job `33080240879 / 98545151906`, artifact `9649815558`, IPA SHA-256 `a0b7bad3c563f76e3e560f55da6eec67697a8bf609b70b5a672ee1a0ed1ab85e`, MinOS 15.0. Evidence: **CI/IPA verified + real-device diagnostic tested / 120 Hz request effective / residual root cause not yet fixed / not stable**.

Next action: inspect the real Hero/persistent 1400px image callback → publish → presentation chain and correlate/measure the work producing the repeatable long display gaps. Retain the high-refresh request as an evidence-backed candidate and do not yet move interactive motion to coalesced/predicted touches.''',
'''Build219 remains the controlling real-device diagnostic evidence: the 120 Hz request is effective, and its strongest repeatable residual pattern is a 50 ms display gap ~19.6–25.3 ms after target persistent 1400px callbacks. Source inspection shows those callbacks occur after an already-decoded image is adopted by a newly mounted full-screen persistent SwiftUI image that also carries `scaleEffect(1.12)` and `blur(radius: 30)`; Build212 already ruled out the synchronous callback/contrast calculation itself as a 50 ms cost.

Current carousel diagnostic candidate: **Build221 / 0.14.54** — branch `diag/home-carousel-persistent-drag-isolation-build221`; tested source `26fc82771b6778af14974fdac293ece0685fc76d`; cleanup head `1d6df7f2490a5ef5968cafb229a46cba93c622db`; run/job `33090175887 / 98580579889`; artifact `9654120029`; IPA SHA-256 `d2ee4fb2d40c251399951bc72ba6ad35fbe8ba3bfd72b861274b9b2c38fe0d9c`; MinOS 15.0. During active drag it keeps only the current persistent backdrop mounted/opaque while Hero transition remains unchanged; the normal persistent transition resumes after release. Evidence: **Code written / exact scope+Frozen guard / CI passed / IPA produced+verified / real-device pending / diagnostic only / not stable**.

Next action: target-device A/B Build221 with the same cadence log. If drag-time persistent callbacks/50 ms gaps disappear, persistent presentation becomes directly isolated as a causal component; if Hero gaps remain dominant or no improvement occurs, do not retain the isolation. Also check release/settle separately because Build221 intentionally restores persistent transition after release.''',
'PROJECT Build221')
replace_once(p,
'''Build216 is the accepted overall runtime baseline after the detail episode-range inertia closeout. Home-carousel Build219 and poster-scroll Build220 remain independent Active lines with separate branches/evidence.''',
'''Build216 is the accepted overall runtime baseline after the detail episode-range inertia closeout. Home-carousel Build221 and poster-scroll Build220 remain independent Active lines with separate branches/evidence.''',
'PROJECT parallel')

# TECHNICAL_DECISIONS
p = 'docs/project/TECHNICAL_DECISIONS.md'
replace_once(p,
'''Retain acquisition-relative X, opaque foreground, page slots and the original release semantics. Build217/219 now establish that refresh cadence is a first-class part of this interaction contract: Build217's passive diagnostic path ran around 50–60 Hz despite a 120 Hz-capable target device, while Build219's drag-local device-max `preferredFrameRateRange` request raised delivered touch / publication / SwiftUI render / display cadence to roughly 98–110 Hz without changing motion math. Therefore do not revert the evidence-backed high-refresh direction or replace it with another easing/smoothing layer. Coalesced/predicted touches are still not interactive render authority. The remaining source-correlated lead is episodic Hero/persistent 1400px image publication/presentation causing 34–50 ms display gaps; inspect that path before changing image timing or ownership.''',
'''Retain acquisition-relative X, opaque foreground, page slots and the original release semantics. Build217/219 establish that refresh cadence is a first-class part of this interaction contract: Build217's passive diagnostic path ran around 50–60 Hz despite a 120 Hz-capable target device, while Build219's drag-local device-max `preferredFrameRateRange` request raised delivered touch / publication / SwiftUI render / display cadence to roughly 98–110 Hz without changing motion math. Therefore do not revert the evidence-backed high-refresh direction or replace it with another easing/smoothing layer. Coalesced/predicted touches are still not interactive render authority.

Build219's strongest remaining repeatable pattern is a 50 ms display gap about 19.6–25.3 ms after persistent 1400px callbacks. Exact source inspection shows target persistent first presentation is a separate full-screen `EmbyCachedRemoteImage` with `scaleEffect(1.12)` + `blur(radius: 30)`, while Build212 had already measured callback/contrast synchronous work at only ~1–3 ms. Build221 therefore isolates this presentation during active drag only by keeping current persistent opaque and not mounting target persistent; Hero remains unchanged and the normal persistent transition resumes after release. This is a **diagnostic A/B, not an accepted visual contract** until target-device logs prove the causal effect.''',
'TECH D012 Build221')

print('Build221 project docs patch prepared')
