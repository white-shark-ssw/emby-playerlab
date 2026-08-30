# DEV-poster-grid-smoothness

## Status

**Active — Build272 / 0.15.5 is now target-device tested and rejected as a sufficient fixed-row solution. Library still runs roughly 110–120 FPS and the user still observes an occasional whole-content up/down twitch during scrolling. `OnePlayer-App-1788117273.log` captures a fixed `775→775` 5.36 s session at display 118.50 Hz / offset 110.85 Hz with `item_count_changes=0`, `load_ahead=0`, and a visible-scale native reverse maximum of 33.00 pt while content height and adjusted top/bottom insets each change by 0.00 pt. Explicit standard poster-row height therefore did not remove the symptom and dynamic row-height/contentSize/inset correction is not supported as the sufficient root cause. The reverse aggregate still lacks edge-distance context, so normal top/bottom bounce must not be misclassified as the visible twitch. Stop further SwiftUI Grid/LazyStack variants; next architecture A/B is Library-only native UICollectionView 3×3 with edge-distance-aware native offset diagnostics.**

- **Work ID**: `DEV-poster-grid-smoothness`
- **Routing aliases / keywords**: 首页流畅度 / 3×3页面流畅度 / 3列海报流畅度 / 库页流畅度 / 海报网格优化 / poster grid smoothness
- **Working branch**: next candidate not yet written; Build272 branch `perf/poster-grid-fixed-row-build272` is closed/rejected evidence only
- **Draft PR**: none current; #278 Build272 closed without merge after target-device rejection
- **Superseded PRs**: #278 Build272 fixed-row target-device rejected/closed; #277 Poster Build269 row-stack target-device rejected/closed; #276 Build268 lean-diagnostic target-device rejected/closed; #275 Build267 diagnostic reference-session target-device tested/superseded; earlier poster diagnostics remain historical evidence only
- **Current branch / PR head**: no active implementation branch after Build272 rejection; last tested source `75b479476c043ebf3010dba1ebf4136280e98a6c`
- **Current candidate**: none packaged after Build272. Next permitted implementation is a Library-only native UICollectionView 3×3 A/B preserving existing data/pagination/card/image/navigation contracts; Search Build256 semantics and all P0/Frozen playback/transport remain protected.
- **Target device**: iPhone 15 Pro Max / iOS 17.0
- **Accepted carousel foundation**: Build241 manual interaction/presentation remains frozen; only automatic-transition scheduling during Home vertical motion is reopened by new device evidence
- **Accepted overall baseline**: OnePlayer **0.14.49 / Build216**, PR #261, merge `f5ad126b7b47e9713b1949780a6507fb3f0ca50f`

## Build272 target-device result — fixed-row rejected; native collection-view gate — 2026-08-31

Build272 / OnePlayer **0.15.5 (272)** exact source `75b479476c043ebf3010dba1ebf4136280e98a6c`, Draft PR #278, is target-device tested using `OnePlayer-App-1788117273.log`. User result: Library still reports roughly **110–120 FPS** and the previously identified **whole-content up/down twitch** still occurs during scrolling. The fixed-known-row-height A/B is therefore rejected as a sufficient fix and PR #278 is closed without merge.

The strongest clean sample is fixed `775→775` for **5358.60 ms**: display **118.50 Hz**, offset **110.85 Hz**, p50/p95/p99 **8.34/8.34/8.34 ms**, max **65.18 ms**, only one gap >=25 ms and one >=33.3 ms, `item_count_changes=0`, `load_ahead=0`, yet `decel_display_reverse=1`, `decel_reverse_ge1=1`, `decel_reverse_max_pt=33.00`. At that largest reverse, `contentSize.height` delta is **0.00 pt** and adjusted top/bottom inset deltas are **0.00 / 0.00 pt**. Two short fixed `775→775` sessions also retain 1.00 pt / 0.67 pt reverse signals with zero content-height/inset changes.

This is enough to reject the hypothesis that dynamic standard-poster row height or contentSize/inset change is the sufficient cause of the visible twitch. It is **not** enough to equate every logged reverse with the visible twitch, because Build272 does not record the reverse offset's distance from legal top/bottom bounds and normal UIScrollView edge bounce can legitimately reverse direction. Do not overclaim mid-scroll native correction from the aggregate counter alone.

Build272 CI/IPA evidence remains valid: Xcode 16.4 run/job `33329786724 / 99306181023`, cleanup `99306539929`, artifact `9737328849`, artifact digest `sha256:1f03bfe049762d1cd36547358e7172a26f9aaf685360eba742188ffe8e1fda6d`, IPA SHA `c5e562272375ef816bc584e1e6331986c5eaa5fc1462b485a00745d4a0612b42`, source ZIP SHA `9064a826a47c04b2d194df32071509d3f8e25409877020432d41767a0ddd24f7`, MinOS 15.0.

**Evidence:** Code written ✅ / exact scope+checker ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅ / fixed-row sufficient fix ❌ / stable ❌.

**Next exact action:** stop further SwiftUI `LazyVGrid` / `LazyVStack` container variants for this symptom. The next implementation A/B is **Library-only native UICollectionView 3×3**, reusing the current Library item source/pagination behavior and preserving card visuals/navigation plus existing image cache/loading contracts. In the same native scroll owner, record reverse event offset and distance to legal top/bottom bounds so normal boundary bounce can be separated from a true mid-scroll reversal. Do not alter Search Build256 semantics, Home carousel runtime, scroll deceleration physics, Player/MPV/PiP, UnifiedTransport, playback Cache/Session, STRM/302/115/CDN, or Deployment Target.

## Build266 target-device result → Build267 diagnostic self-overhead A/B — 2026-08-30

Build266 / OnePlayer **0.14.99 (266)** exact source `957e88dcdc408e537d63b083d0f30e4b1157b1dc` is now target-device tested using `OnePlayer-App-1788105516.log`. User result: Home vertical scrolling is **clearly smoother** and the on-screen FPS can reach **120**, but the user still wants manual/inertial Home motion to hold 120 more consistently. Shared 3×3 remains visibly affected by long frames and the on-screen FPS did not reach 120 during the reported Library/Search test.

The log separates these paths. Home has three captured motion sessions; all report `maximum_fps=120`, `refresh_request=1`, and display p50/p95/p99 **8.34 ms**. The remaining Home tail is sparse: max gaps are `33.34 / 23.21 / 27.72 ms`. The two sessions overlapping carousel `settled` events contain the >=25 ms tail, while the 3.33 s session with no carousel settle contains zero >=25 ms gaps. This is supportive correlation, not exact per-frame proof; it reinforces testing the separate Build265 / PR #274 carousel image-analysis-dedupe candidate rather than mixing another Home change into the poster package.

Library remains materially worse. Across 15 `library-items` sessions / **9,576 display samples**, Build266 records **52 gaps >=25 ms**, **33 >=33.3 ms**, max **130.12 ms**. In 11 fixed-item sessions, 21 severe25 and 12 severe33 remain; **20/21 severe25 overlap cell churn, 18/21 overlap image publication, and all 12/12 severe33 overlap both cell churn and image publication**. Thus Build266 does **not** prove unused `isLoading` publication is a sufficient 3×3 fix; PR #273 is closed without merge. Search Build256 semantics remain protected.

Source inspection then identified measurement self-overhead that must be removed before another product rewrite: `EmbyPosterGridCadenceDiagnostics.MotionSession` was a value-type `struct` holding multiple growing arrays, while high-frequency `contentOffset` KVO and `CADisplayLink` paths repeatedly read the optional session into a local value, append to arrays, and assign it back. With the owner retaining the prior value during mutation, Swift Array copy-on-write can repeatedly copy growing buffers and contaminate the measured main-thread path. Build266 includes sessions with more than 1,500 offset and 1,500 display samples, so this risk is material enough for a narrow A/B.

Build267 / OnePlayer **0.15.0 (267)**, branch `perf/poster-grid-diagnostic-refstate-build267`, Draft PR **#275**, exact source `dbe1b7c13dde68e52039cb7ae22fc5177fdd886f`, changes exactly four paths. `MotionSession` becomes a `final class` with the same fields and an explicit initializer; all KVO samples, display-link samples, long/severe thresholds, cell/image/load-ahead/item-count counters, run-loop evidence, deceleration metrics, 80→device-max refresh request and end-of-session logs remain unchanged. No `EmbyPosterGrid.swift`, image loading/quality/cache/decode/network/publication, pagination, Search semantics, scroll physics, Home carousel, Player/MPV/PiP, UnifiedTransport, playback Cache/Session, STRM/302/115/CDN or Deployment Target behavior changes.

Build267 exact-source Xcode 16.4 run/job `33321883421 / 99285172527` succeeded; cleanup `99285673130` succeeded. Artifact `OnePlayer-0.15.0-build267-grid-diagnostic-refstate`, ID `9735159629`, digest `sha256:bbabd6c84752a8437a9c23c02b6bdecc60915b9d6403d96d203745b8b9589661`; IPA SHA-256 `54c2b8851d54aee126ff12f5c4f1a54f6fa62ca0293517fc137fc25b94ef3d3c`; source ZIP SHA-256 `0ae52e34cc4aafb383ec7a7c4ca8adf1846df51c038b5a8f44fd7bc6ea9dad3d`; bundle/version/build/MinOS independently verified as `com.embyplayerlab.app / 0.15.0 / 267 / 15.0`.

**Evidence:** Build266 Code/CI/IPA/target-device tested ✅ / Build266 3×3 sufficient fix ❌ / Build267 Code written ✅ / exact four-path scope+checker ✅ / CI passed ✅ / IPA produced+independently verified ✅ / Build267 target-device tested ❌ / stable ❌.

**Next exact action:** test Build267 on Library 3×3 and Search 3×3 with repeated long fast drags/inertial flings and return the App log. If both on-screen FPS and severe-tail counts materially improve while the same diagnostics remain available, diagnostic copy-on-write self-overhead is confirmed. If not, keep the lighter diagnostics and isolate actual cell realization/layout versus real image publication/adoption; do not guess `decelerationRate` or stack more loader-state changes. Home should be tested separately with Build265 / PR #274.

## Build257 containment result → Build258 shared cadence evidence → Build259 A/B — 2026-08-30

Build257 / OnePlayer 0.14.90 was target-device tested. Its vertical-motion gate behaves as designed: while Home is actively dragged or decelerating, a new carousel automatic transition does not begin, so the previously repeatable auto-advance-overlap large hitch is contained. The user explicitly does **not** accept this as the preferred final smoothness architecture; it is retained only as a fallback if the actual scrolling/transition cost cannot be made acceptable. PR #265 is closed without merge. Build241 remains the frozen manual-carousel interaction/presentation authority.

Build258 / OnePlayer 0.14.91 exact source `165dffac8690c85283e7a53f4a0b7a20eeb52f8c` was then target-device diagnostic tested using `OnePlayer-App-1788082165.log`. The shared `EmbyPosterGrid` cadence evidence is cross-route:

- Library `library-items`, fixed `60→60`, 9.56 s motion: display p50/p95 `16.67 ms`, p99 `16.68 ms`; 12 cell appears / 12 disappears; no load-ahead and no item-count change.
- Detail filter, fixed `60→60`, 14.1 s motion: display p50/p95/p99 `16.67 ms`; no item-count change.
- Search full-results `global-search-results`, fixed `18→18`: valid sessions repeatedly report display p50/p95 about `16.67 ms` while `maximum_fps=120`; item count is stable and cell churn is small.
- Search `global-search-recommendations`: one 5.93 s motion grows `15→39` through four accepted +6 append events and adds a separate tail (`display_p99=34.84 ms`, `max=52.39 ms`, item-count changes 4). This can contribute append-adjacent roughness but cannot explain the shared fixed-item 16.67 ms baseline.

The Search route here is the already-final Build256 implementation: PR #264 merged at `647c1f66e5836fcd20a23a57600211488eeafb3d`, and Build258 base `aba2a4a8ddf388ffdec5d90e34aad0a8b32ae9eb` is its descendant. Search's accepted initial-9/+6 Random Items + `ExcludeItemIds`, detail-return lifetime and Dock-away reset are protected functional contracts. Poster smoothness work may optimize the shared presentation path but must not reopen those semantics without new regression evidence.

Build258 therefore rejects several universal-root hypotheses: the mild baseline is not Library-only; not universally pagination/load-ahead driven; not explained by large cell lifecycle churn; and, together with Build243, active poster background disk/decode/network/cache-write is not supported as a universal direct trigger. The `>=16.7 ms` counter is not authoritative for nominal 16.67 ms samples; p50/p95 distributions control this cadence comparison.

Build259 / OnePlayer **0.14.92 (259)** is the minimum next A/B, branch `perf/poster-grid-high-refresh-build259`, Draft PR #267, exact source `39168e560d7e626557de8ebde6a88a5d38b3478b`, directly parented from Build258. It changes exactly four paths: AppIdentity, the existing cadence diagnostics owner, Build259 changelog and its checker. The existing single Build258 `CADisplayLink` requests `CAFrameRateRange(minimum: 80, maximum: deviceMaximum, preferred: deviceMaximum)` only while any observed shared 3×3 real scroll owner has an active drag/deceleration session; it returns to `.default` when no grid motion remains. No second display link, timer, watchdog, retry, fallback, interpolation, Grid geometry, image policy, paging, Search source, Home carousel runtime or Player/Transport code is changed.

Build259 exact-source Xcode 16.4 run/job **`33304743577 / 99239168487`** succeeded. Artifact `OnePlayer-0.14.92-build259-poster-grid-high-refresh-ab`, ID **`9730129850`**, digest `sha256:ac44fcb213597b8ea8cc536c35dc21a157bb2832b869fac33cf5c17633085a1a`; IPA SHA-256 `6d257396ba7a77178e62535c5dd04db58621ea25cf4a30e7e9bf415c7628a18a`; source ZIP SHA-256 `dd121c94b7392abf647ec5471506a6dec903652c7f7f68a19f29ac567660710a`; package `com.embyplayerlab.app`, `0.14.92 (259)`, MinOS 15.0, `CADisableMinimumFrameDurationOnPhone=true`. Downloaded artifact hashes and IPA integrity were independently reproduced.

**Historical Build259 gate result:** completed on target device. The high-refresh request proved effective and moved shared display cadence toward ~8.34 ms, but did not close the finer EX-vs-OnePlayer hand-feel gap. The controlling current result and next action are recorded in the Build259→Build260 section immediately below.

## Build259 target-device high-refresh result → Build260 curve-continuity diagnostic — 2026-08-30

Build259 / OnePlayer 0.14.92 exact source `39168e560d7e626557de8ebde6a88a5d38b3478b` is now target-device tested using `OnePlayer-App-1788087127.log`. The shared device-max refresh request is effective: fixed-item Library and Search full-results sessions that were ~16.67 ms display p50/p95 under Build258 now normally report **8.34 ms** display p50/p95 on iPhone 15 Pro Max / iOS 17.0. Search recommendations likewise normally run at 8.34 ms display p50/p95. The user's matching tactile result is that obvious jitter is now difficult to see.

Build259 is nevertheless **not** the final smoothness solution. In direct comparison, EX still feels more silky/fine-grained: the user describes EX as one smooth motion curve while OnePlayer feels slightly coarse or wave-like. Build259 logs retain a relevant but not yet causal signal: across fixed-item Library and Search grids, real `UIScrollView.contentOffset` KVO cadence often has `offset_p50≈8.4 ms` but `offset_p95≈16.8 ms` while display cadence remains 8.34 ms. Because KVO delivery can be coalesced, this does not prove that the visible native scroll position advances every other display frame and does not justify changing `decelerationRate` by guess.

Search recommendation +6 appends remain a separate secondary tail layer: append-heavy sessions can still produce larger p99/max display gaps. This does not explain the fixed-item residual hand-feel gap and does not reopen the accepted Build256 Search functional contract. Initial 9 + incremental +6 Random Items/`ExcludeItemIds`, detail-return lifetime, Dock-away reset and Dock/keyboard behavior remain protected.

Build260 / OnePlayer **0.14.93 (260)** is the minimum next diagnostic, branch `perf/poster-grid-curve-diagnostics-build260`, Draft PR #268, exact source `b9a5de5255650f04e312e117f47453122de56adc`, directly parented from Build259. Exact Build259→260 delta is four paths: AppIdentity, the existing cadence diagnostics owner, Build260 changelog and checker. Build260 preserves the existing single cadence `CADisplayLink` and Build259 80→device-max refresh request unchanged. It adds only passive per-display-frame sampling of the real ancestor `UIScrollView.contentOffset.y` during native deceleration and logs `decel_display_frames`, `decel_display_zero`, `decel_display_catchup`, direction reversals, movement-delta percentiles and consecutive movement-step ratio percentiles. No ScrollView physics/deceleration rate, Grid layout, pagination, image/cache policy, Search implementation, Home carousel runtime, Player/MPV/PiP, UnifiedTransport, playback Cache/Session, STRM/302/115/CDN or Deployment Target behavior changes.

Build260 Xcode 16.4 run/job **`33307963917 / 99247767453`** succeeded. Artifact `OnePlayer-0.14.93-build260-poster-curve-diagnostics`, ID **`9731113592`**, digest `sha256:293055cff1d8524a19ac4e21b39bb2b90afc7451fb1311c4760efc53d08739f8`; IPA SHA-256 `1434d2b31c7ced4f344b2e946c5311d2c287774cfe72bbcbd527a24a1ccbffe8`; source ZIP SHA-256 `875ea8a22e4aca0924c58e70faf250a891a8b97ce980a300bc6bcf1ee16998db`; package `com.embyplayerlab.app`, `0.14.93 (260)`, MinOS 15.0, `CADisableMinimumFrameDurationOnPhone=true`. Downloaded artifact digest, IPA/source hashes, archive integrity and MinOS audit were independently reproduced.

**Evidence:** Build259 target-device tested ✅ / Build259 high-refresh effectiveness proven ✅ / Build259 obvious jitter substantially reduced ✅ / residual EX-vs-OnePlayer hand-feel gap remains ✅ / Build259 final/stable ❌ / Build260 Code written ✅ / exact scope+checker ✅ / CI passed ✅ / IPA produced+independently verified ✅ / Build260 target-device tested ❌ / physics fix claimed ❌ / stable ❌.

**Next exact action:** install Build260 and perform normal long inertial flings on Library 3×3 and Search full-results 3×3; Search recommendations are secondary and do not need deliberate repeated +6 appends for the first pass. Return the App log. If `decel_display_zero` + `decel_display_catchup` are frequent while display cadence stays ~8.34 ms, investigate native scroll-motion/physics ownership next. If per-display deceleration deltas are already continuous with few/no zero→catch-up pairs, do **not** tune `decelerationRate` by guess; shift the next investigation toward shared SwiftUI Grid presentation/compositing.

## Build261 target-device long-frame attribution — 2026-08-30

Build261 / OnePlayer **0.14.94 (261)** exact source `e552bebd072a915e6cb10d591d704a5a3c342406`, branch `perf/poster-grid-long-frame-build261`, Draft PR #270, directly extends Build260 with two narrowly-scoped changes: Home reuses its existing real ancestor vertical `UIScrollView` observer to request `CAFrameRateRange(minimum: 80, maximum: deviceMaximum, preferred: deviceMaximum)` only during real drag/deceleration and logs `HomeScrollCadence`; Library preserves Build260 cadence sampling and attributes every `>=12.5 ms` display gap to same-frame cell appear/disappear churn, load-ahead, item-count change, offset-update count, or `untracked`. Exact Build260→261 delta is five paths: AppIdentity, Home scroll observer, poster cadence diagnostics, Build261 changelog and cadence checker. No `decelerationRate`, Home carousel interaction/presentation, `EmbyHomeCoreV3`, `EmbyPosterGrid.swift`, Grid geometry, Search semantics, image/cache policy, Player/MPV/PiP, UnifiedTransport, STRM/302/115/CDN or Deployment Target behavior changes.

Build261 Xcode 16.4 run/job **`33310546942 / 99254688579`** succeeded. Artifact `OnePlayer-0.14.94-build261-long-frame`, ID **`9731868664`**, digest `sha256:bf9dab2b5acab5befc5516ce7bb5e920e9e01277caa757f137173c9c8b33c14d`; IPA SHA-256 `d5f719c2cbcd8df4908f9f7ecfd9b5c5db88288cdf16cd45b09a263966511724`; package `com.embyplayerlab.app`, `0.14.94 (261)`, MinOS 15.0. Exact five-path scope, dedicated checker, `git diff --check`, Release compile, package identity, MinOS and artifact upload all passed.

Target-device result from `OnePlayer-App-1788093610.log` on iPhone 15 Pro Max / iOS 17.0:

- **Home improved:** user reports Home is better than before. Across 12 Home motion sessions / 3,309 display samples, every session reports display p50/p95 `8.34 ms`; 9/12 sessions never exceed `16.67 ms`. Remaining long tails are max `50.31 / 36.24 / 76.94 ms`. The first two occur immediately after Home refresh / a burst of HTTP requests; the 76.94 ms sample has no current Home attribution. High refresh is effective but Home is not stable.
- **Library aggregate:** 49 sessions / 9,573 display samples; `356` gaps `>=12.5 ms`, `94` gaps `>=25 ms`, `57` gaps `>=33.3 ms`, max `175.79 ms`. `193` long gaps overlap cell lifecycle churn; `162` (`45.5%`) are completely `untracked` by current cell/load-ahead/item-count categories. Tracked categories can overlap, so do not sum them as exclusive percentages.
- **Fixed-count evidence:** sessions with no item-count changes still contain `170` long gaps, `41 >=25 ms`, `23 >=33.3 ms`, max `112.97 ms`. Pagination/item-count diff is therefore not sufficient.
- **Cell-churn proof:** one fixed `600→600`, 4.74 s fast-scroll session records `73` long gaps; `67` overlap cell churn, with `33 >=25 ms`, `16 >=33.3 ms`, max `70.70 ms`, and up to 12 cell appears + 12 disappears within one long-gap interval. High-speed SwiftUI cell lifecycle churn is a proven contributor.
- **Second-source proof:** fixed `60→60` pure scrolling can still produce a `33.82 ms` long gap with zero cell churn/load-ahead/item-count changes in that gap. A separate main-thread/rendering source remains.

**Controlling interpretation:** the EX comparison should now be framed as long-frame-tail elimination, not merely requesting 120 Hz. Library has at least two layers: high-speed cell lifecycle churn plus an untracked long-frame source. Do not claim pagination is the root cause, do not tune native scroll physics by guess, and do not wholesale-replace the Grid before the severe `untracked` gaps are isolated. Home's 120 Hz request is a real improvement but its remaining occasional tails also need attribution.

**Evidence:** Build261 Code written ✅ / CI passed ✅ / IPA produced ✅ / target-device tested ✅ / Home improvement confirmed ✅ / Home stable ❌ / Library cell-churn contribution proven ✅ / separate untracked long-frame source proven ✅ / overall smoothness stable ❌.

**Next exact action:** before a behavioral Grid rewrite, extend severe-gap attribution so `>=25 ms` / `>=33.3 ms` gaps can distinguish cell lifecycle work from image-main-thread publication / SwiftUI update-layout-presentation work and other current owners. Use the same exact Build261 lineage; do not add delay/debounce/timer/watchdog or change scroll physics. For Home, correlate the remaining long gaps with refresh/model/image publication rather than changing the now-effective refresh request.

## Build263 severe-gap attribution candidate — 2026-08-30

Build263 / OnePlayer **0.14.96 (263)** exact source `bff02ea8e76217b1fe07c298d8b9058b2db1fd08`, branch `perf/poster-grid-severe-attribution-build263`, Draft PR #271, directly extends the target-device-tested Build261 source without changing scroll behavior. Exact Build261→263 delta is six paths: AppIdentity; `EmbyPosterGrid.swift` diagnostic owner propagation; `EmbyServerSharedV3.swift` reuse of the existing `EmbyCachedRemoteImage.onImageLoaded` callback for poster publish attribution; `EmbyPosterGridCadenceDiagnostics.swift`; Build263 changelog; and the existing cadence checker.

Build263 preserves the existing single Grid `CADisplayLink` and Build259/261 high-refresh request. It adds `>=25 ms` / `>=33.3 ms` severe-gap counters split by cell lifecycle churn, poster image publication, load-ahead, item-count change and untracked work, plus one passive main-RunLoop `beforeWaiting` observer to distinguish severe gaps where the main loop did or did not reach a wait point between display ticks. No second display link, timer, watchdog, retry, debounce, Grid geometry/LazyVGrid behavior, `decelerationRate`, Search Build256 semantics, image cache/decode/network policy, Home carousel runtime, Player/MPV/PiP, UnifiedTransport, playback Cache/Session, STRM/302/115/CDN or Deployment Target behavior changes.

Exact-source Xcode 16.4 run/job **`33313884881 / 99263646157`** succeeded. Artifact `OnePlayer-0.14.96-build263-severe-attribution`, ID **`9732862198`**, digest `sha256:6e96b83b78bd8bd37b6e0e3dd2d3f820a328f3810ffc07faf86ea9526f4363bd`; IPA SHA-256 `b8e15a1ac49582ec0dc519c316222d3944b6622cd8afb1afa22ab4d7bbf9d659`; exact-source ZIP SHA-256 `327444119b0b15f894c8a3d8012f195d79ceb77a7ef4b0af16abc3052893424c`. Downloaded artifact ZIP digest, embedded hash files, independently recomputed IPA/source hashes, archive integrity, package identity `com.embyplayerlab.app`, version `0.14.96 (263)` and executable MinOS 15.0 were independently verified.

Target-device result from `OnePlayer-App-1788098393.log` on iPhone 15 Pro Max / iOS 17.0:

- 26 Library motion sessions / 5,557 display samples contain `40` severe `>=25 ms` gaps and `27` severe `>=33.3 ms` gaps.
- Overall severe25 overlap: cell churn `32/40` (80%), image publish `24/40` (60%), untracked `6/40`; severe33 overlap: cell churn `22/27`, image publish `16/27`, untracked `3/27`. Categories overlap and must not be summed as exclusive percentages.
- Fixed-item sessions are stronger: 19 sessions / 2,860 display samples contain `28` severe25 and `16` severe33 gaps. Cell churn overlaps `26/28` severe25 and **all `16/16` severe33**; image publication overlaps `23/28` severe25 and `15/16` severe33; only `2` fixed-item severe25 gaps are untracked and **zero** fixed-item severe33 gaps are untracked.
- The heaviest fixed `775→775` 7.11 s pass has `24` severe25 / `15` severe33, with `22/24` severe25 overlapping cell churn and `20/24` overlapping image publish; all `15/15` severe33 overlap cell churn and `14/15` image publish. A long-gap interval reaches 18 cell appears + 18 disappears and 27 image publications.
- A second fixed `775→775` 5.37 s pass still performs 309 cell appears + 306 disappears and 309 image publications but has **zero** severe25 gaps. Therefore raw cell/image activity alone is not sufficient; the dangerous condition is burst concentration during high-speed realization/publication.
- RunLoop `beforeWaiting` occurred between display ticks for `35/40` severe25 and `25/27` severe33 gaps. This rejects only continuous full-interval main-thread occupation; it does **not** exclude a late main-thread cell/layout/presentation burst after wake that misses the next vsync. Do not over-attribute this result to Core Animation/compositor yet.

Exact-source inspection supports the current narrow hypothesis: every `V3PosterCard` mounts `EmbyCachedRemoteImage`; on cell appearance its loader starts work, memory-cache hits synchronously assign `@Published image` on main, and disk/network decode completions also publish `image` on MainActor. Cell disappearance cancels the loader. The Build263 `image_publish` counter is delivered from that image publication path. This matches the severe burst correlation but still does not distinguish cell realization cost from image state/presentation cost.

**Evidence:** Build263 Code written ✅ / exact six-path scope+checker ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device diagnostic tested ✅ / fixed-item severe-gap cell-burst correlation proven ✅ / image-publication overlap proven ✅ / exact causal owner not yet isolated ❌ / stable ❌.

**Next exact action:** do not tune pagination or scroll physics. The next behavioral A/B should be narrowly aimed at the shared poster-cell realization/image-publication path and preserve exact rendered image quality, Search Build256 semantics and the 3-column contract. Prefer a single-variable experiment that removes one source of per-cell image state publication during fast virtualization before considering a wholesale Grid rewrite.

## Build266 3×3 loading-state publication A/B — 2026-08-30

Build263 target-device evidence supports one narrowly-scoped behavioral A/B before any Grid rewrite: fixed-item severe gaps strongly overlap high-speed cell churn and image publication, but another 775→775 pass can perform hundreds of the same events with no severe gap, pointing to concentrated publication/realization bursts rather than raw event count. Exact source inspection shows every shared `V3PosterCard` uses `EmbyCachedRemoteImage`; the loader exposes both `@Published image` and `@Published isLoading`. The shared 3×3 card renders no loading spinner (`showsLoadingIndicator=false`), yet loader begin/end/cancel still published `isLoading` changes.

Build266 / OnePlayer **0.14.99 (266)**, branch `perf/poster-grid-loading-state-build266`, exact source `957e88dcdc408e537d63b083d0f30e4b1157b1dc`, directly extends Build263 exact source `bff02ea8e76217b1fe07c298d8b9058b2db1fd08`. Exact net scope is five paths: `AppIdentity.swift`, `EmbySharedImageAndNavigation.swift`, `EmbyServerSharedV3.swift`, Build266 changelog and `check_poster_grid_cadence.py`. The loader now has a default-true `publishesLoadingState` flag; only `V3PosterCard(width == nil)` passes false. Therefore Library/Search/other shared 3-column poster cells stop emitting `isLoading` object-change publications they do not render, while actual `image` loading/cache/decode/network/publication remains unchanged. Horizontal poster cards (`width != nil`) and all other `EmbyCachedRemoteImage` callers retain prior loading-state behavior.

No image dimensions/quality, cache/decode/network policy, LazyVGrid layout, pagination, Search Build256 semantics, scroll physics, Home-carousel runtime, Player/MPV/PiP, UnifiedTransport, playback cache/session, STRM/302/115/CDN or Deployment Target changes. Dedicated source checker and `git diff --check` pass; GitHub exact Build263→266 comparison confirms only the five intended paths. Exact-source Xcode 16.4 Release run/job `33320334963 / 99281058534` passed; cleanup job `99281458852` passed. Artifact `9734732730`, digest `sha256:eddba76a1829492720a77107938f5b4b23ef2c2854ac3605e5f3a5f812d13db0`; IPA SHA-256 `8130bed5dc90f51f257343e24e24a82a902582ecf4c41c9bcb858f1fdaa83901`; exact-source ZIP SHA-256 `cb1b2fe1e85ffc4f61c75c126e094d210ee47e91161db53836e291898338b876`; bundle `com.embyplayerlab.app`, version `0.14.99`, build `266`, built MinOS `15.0` independently verified.

Identity guard note: a parallel Home-carousel session allocated **Build265 / 0.14.98** on `perf/home-carousel-image-analysis-dedupe-build265` while the poster implementation was being prepared. The poster `perf/poster-grid-loading-state-build265` attempt contains no committed product patch and is retired; Build266 is the poster candidate.

**Evidence:** Build266 Code written ✅ / exact five-path scope+source checker ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device tested ❌ / stable ❌.

**Next exact action:** target-device A/B Library and Search 3×3 against Build263. If severe25/33 materially fall and the tactile result improves, loading-state publication is a proven contributor; if not, do not stack more loader changes and shift the next isolation toward cell realization/layout versus actual image publication.

## Build229 latest target-device result / candidate identity guard — 2026-08-29

Build229 / OnePlayer 0.14.62 was exercised again on the target device and the user still reports visible jitter. The latest App-log evidence contains a **77.2 ms** `PosterScrollHitch` on the Library grid. At that hitch, the latest Library page apply and awaited snapshot completion were already about **7.3 s** old, while the latest image publish was about **0.77 s** old. The captured sample is `phase=moving`, `velocity_y=0`, `delta_y=1.33`, so it is a real long-frame/catch-up sample but not pagination-adjacent.

Controlling interpretation: Build228’s 39.7 ms synchronous Library snapshot write remains a valid contributor to the earlier severe pagination-adjacent sample, but Build229 proves that removing that main-thread write is **not sufficient** to remove the broader 3×3 hitch family. This 77.2 ms sample does not support direct attribution to page apply, snapshot persistence, or the latest image publication because all three are far outside the hitch window. Pagination-specific improvement from Build229 is still not established by this sample.

Resume identity guard on 2026-08-29 also found a hard candidate collision:

- checkpoint branch remains `perf/poster-grid-smoothness`, Draft PR #259;
- real branch / PR head is `deba1534e55bfc73f4d3cf43f2682c854a04cb39`, commit `Add Build233 poster background-work diagnostics`, directly parented by Build229 exact source `f5e3e3eb144578c863b172e3bd3a1aa13e5c2177`;
- that head changes poster diagnostics/version/changelog to **0.14.66 / Build233** but has no valid poster CI/IPA attribution;
- independent Active task `DEV-home-carousel-drag-smoothness` already owns OnePlayer **0.14.66 (233)** and has CI/IPA evidence for that identity;
- Home subsequently advanced through Build242; Aether currently reserves Build235. Fresh checks on 2026-08-29 find no Build243 branch, commit or current checkpoint allocation.
- The user explicitly said to continue the current poster task after the timeout, satisfying the checkpoint’s required decision to release/reallocate the invalid poster Build233 identity.

**Identity guard result after explicit continuation: PASSED for relabel only.** Poster Build233 is retired for attribution; Build243 / 0.14.76 is reserved for the exact already-written diagnostic logic. This does not authorize any additional optimization or behavior change.

**Evidence:** Build229 remains target-device tested and still hitches. Build243 exact source `53a704c2ed752adf023ea3c7f08d7f90f7559133`: Code written ✅ / exact Build229→243 4-path scope+checker ✅ / Xcode 16.4 CI passed ✅ / IPA produced+independently verified ✅ / target-device tested ❌ / smoothness fix claimed ❌ / stable ❌.

**Historical pending at that point:** subsequently completed by the Build243/Build258 device evidence summarized in the current section above.

**Historical next action:** completed. The controlling current action is the Build258 vs Build259 shared-3×3 A/B above.

## Build243 target-device A/B → Build257 current-main candidate — 2026-08-30

The user repeatedly compared Build243 on iPhone 15 Pro Max / iOS 17.0 and established a stronger two-layer result than the earlier sparse hitch logs:

1. **Large Home hitch:** when the top carousel begins an automatic transition while the Home vertical scroll is still in inertial deceleration, one very large visible/tactile hitch occurs.
2. **Residual baseline:** disabling the carousel removes that large hitch, but mild scrolling jitter remains, so the entire smoothness problem is not a single carousel-only cause.

Uploaded `OnePlayer-App-1788077140.log` adds one useful negative result. The captured 33.3 ms Library `PosterScrollHitch` is `phase=decelerating`; at the paired `PosterScrollTiming`, `image_bg_disk_read_active=0`, `image_bg_decode_active=0`, `image_bg_network_active=0`, and `image_bg_disk_write_active=0`. The last completed decode was about 5.39 s old. Therefore this sample does **not** support active poster background disk/decode/network/cache-write work as its direct trigger. It also does not identify the separate mild baseline root cause.

Because Build243's poster branch predates the final Build241 integration, the Home behavior fix was not made on that stale branch. Current `main` was re-read and confirmed to retain the exact accepted Build241 carousel runtime. Its existing `autoAdvanceCarouselIfNeeded()` gated horizontal carousel activity but did not inspect Home vertical `UIScrollView.isDragging` / `isDecelerating`; the existing `V3HomeScrollOffsetObserver` already owns the real ancestor vertical `UIScrollView`.

Build257 / OnePlayer **0.14.90 (257)** is therefore based on current-main commit `44937df8b80424a8c618abb290e9f832793f4120`, branch `perf/home-library-smoothness-build257`, Draft PR #265, exact source `a524d7a56c308a2ed52c5a41b55d061050176e8b`. The only behavior change is: keep a weak reference to that existing real Home vertical `UIScrollView`, and when an auto-advance tick is due, return while `isDragging || isDecelerating`. The already-existing one-second carousel timer naturally checks again later. No new timer, debounce, throttle, watchdog, retry, fallback, interpolation or duplicate vertical-motion boolean state was added. Manual Build241 carousel interaction, release thresholds/timings, Hero residency, persistent backdrop, preload and the 0.62 s automatic transition itself are unchanged.

Build257 exact delta versus its current-main base is seven paths: `AppIdentity.swift`, four Home scroll/carousel files, Build257 changelog and one dedicated inertia-contract checker. Xcode 16.4 run/job **`33301432703 / 99230262134`** succeeded; exact scope + dedicated checker + `git diff --check` passed. Artifact `OnePlayer-0.14.90-build257-home-inertia-gate`, ID **`9729097648`**, digest `sha256:a3d02846d772d940ace45310aa56b094c2f90a18d18ad5912e167f1fcb58cd0a`; IPA SHA-256 `2223cb989201d6477069740faef4c0ed42d9e1937df4a0561d15b0de289a1018`; source ZIP SHA-256 `8b50dac32663484e8e7486b3381b2e781a88b15fd03e613275913673a50276d9`; package `com.embyplayerlab.app`, `0.14.90 (257)`, MinOS 15.0. Independent artifact download reproduced the hashes and IPA archive integrity passed.

**Historical Build257 evidence updated by later device test:** user Build243 A/B real-device tested ✅ / large-overlap scheduling condition established ✅ / Build257 Code written ✅ / exact scope+checker ✅ / CI passed ✅ / IPA produced+verified ✅ / Build257 target-device containment behavior tested ✅ / preferred final architecture ❌ / stable ❌.

**Historical next action:** completed. Build257 contained the overlap hitch but is fallback-only; the mild baseline is now controlled by the Build258 cadence evidence and Build259 A/B above.

## Build243 CI / IPA diagnostic baseline — 2026-08-30

OnePlayer **0.14.76 / Build243** is now materialized from exact poster source `53a704c2ed752adf023ea3c7f08d7f90f7559133`, directly parented by the invalid Build233 diagnostic head `deba1534e55bfc73f4d3cf43f2682c854a04cb39`. The relabel commit changes only `Sources/Core/AppIdentity.swift` and the changelog identity. Against Build229 exact source `f5e3e3eb144578c863b172e3bd3a1aa13e5c2177`, Build243 changes exactly four paths: `AppIdentity.swift`, `EmbySharedImageAndNavigation.swift`, Build243 changelog and `check_poster_grid_smoothness.py`. No Player/MPV/PiP, Transport, playback Cache/Session or Home-carousel owner file is in scope.

The diagnostic runtime addition only records active poster-image `disk_read`, detached `decode`, `network` and image-cache `disk_write` counts plus the latest completed background stage/age/duration in the existing `PosterScrollTiming` line emitted with an existing `PosterScrollHitch`. Image request size, decode policy, cache policy, pagination, Library persistence semantics and scroll behavior are unchanged.

Dedicated Xcode 16.4 Release evidence:

- run/job: **`33300155220 / 99226651825` — success**;
- exact Build229→Build243 four-path scope, poster checker and `git diff --check`: PASS;
- artifact: `OnePlayer-0.14.76-build243-poster-background-work-diagnostics`; ID **`9728697893`**; digest / downloaded ZIP SHA-256 `33ebe84f2864ba4494c4b6c164f77730d2eb383a969e2e0d9c98aac8cc0b9cf1`;
- IPA SHA-256: `f8a7d792f70c970314080a56ef78a9f5734697e7a27373bf67b44dd3d4871d75`;
- exact-source ZIP SHA-256: `641a720cae3550b160fce7cf223d0ec397df0c3aac6041b0a17f60c8ee37c2f9`;
- bundle/version/build: `com.embyplayerlab.app`, OnePlayer **0.14.76 (243)**; `MinimumOSVersion=15.0`;
- downloaded artifact hashes were independently recomputed; IPA archive integrity passed; temporary CI branch was deleted after the run.

**Build243 evidence: Code written ✅ / exact scope+checker ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device tested ❌ / stable/frozen ❌.** This is a diagnostic package, not a claimed smoothness fix.

## Build228 real-device result / Build229 candidate — 2026-08-28

Build228 / OnePlayer 0.14.61 exact source `20f0edaf30c3c9161a79f64fd29dbc79c199473e` was tested on iPhone 15 Pro Max / iOS 17.0. User verdict: **“还是会有抖动感，有的时候还很强烈”**. Build228 is diagnostic-only and is rejected as a smoothness fix.

Uploaded App log `OnePlayer-App-1787905589.log` contains a real **55.1 ms** `scroll_route=grid`, `phase=dragging`, `delta_y=6.0` long frame during the `StartIndex=60` pagination window. Build228's new timing separates the nearby synchronous work:

- image publish / synchronous Combine→UIKit adoption: **0.0 ms** for the latest correlated publish;
- pagination result apply: **0.3 ms**;
- Library persistent snapshot serialization + atomic write: **39.7 ms**, completing about **8 ms** before the hitch.

The supplied 30 fps screen recording confirms the user's visible/tactile jitter report but its file timestamp does not align with that exact logged 55.1 ms event, so the log — not frame matching — controls attribution.

This is direct evidence that Build213's synchronous Library presentation-snapshot persistence can materially block the current pagination-adjacent scroll path. It is **not** evidence that persistence is the universal historical root cause: Build212 captured the same grid-hitch family before Build213 existed.

Build229 / OnePlayer **0.14.62 (229)** is the minimum evidence-supported candidate. Exact source: **`f5e3e3eb144578c863b172e3bd3a1aa13e5c2177`**. Exact Build228→Build229 delta is five paths only: `AppIdentity`, `EmbyPagePersistentCache`, `EmbyServerBrowseV3`, Build229 changelog and poster checker. The `@MainActor` Library model still captures one immutable snapshot in current state order; only Library snapshot object→JSON conversion, JSON serialization and `.atomic` disk write run on one serial `.utility` queue, and the async caller awaits completion. Favorites persistence, cache schema/identity/content, image policy, Home carousel owner files, Player/MPV/PiP, Transport, playback Cache/Session and all P0 contracts are unchanged.

Build229 CI / IPA evidence:

- exact-source run/job: **`33156266871 / 98799654927` — success**;
- Xcode 16.4 Release + exact five-path scope/checker: PASS;
- artifact: `OnePlayer-0.14.62-build229-poster-snapshot-off-main`; ID **`9679803873`**;
- artifact ZIP SHA-256: `8b301f7644f0dfb7e1fb80dba78069f870123c663ba5b323edc93a1e88f067b2`;
- IPA SHA-256: `49efcb8766cc9414a3f35e3d8fe75a04eaf6adf2ba86a40f526a5e53c40acd4c`;
- source ZIP SHA-256: `1de13e01617a575bf5b204e9dd546af443b8a7fdf79003e3eba1399edfb06e5a`;
- bundle/version/build: `com.embyplayerlab.app`, OnePlayer **0.14.62 (229)**; `MinimumOSVersion=15.0`;
- artifact/IPA/source integrity independently verified; source snapshot contains no temporary Build229 workflow.

**Build229 evidence: Code written ✅ / exact scope+checker ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device tested ✅ / overall hitch still present ❌ / pagination-specific improvement unproven / stable or frozen ❌.**

Next target-device A/B should repeat Library 3×3 scrolling through a real pagination boundary. The key question is whether the severe pagination-adjacent hitch disappears or materially shrinks. Do not claim the remaining non-pagination hitch family solved without new device evidence.

## Build229 Home-only supporting capture — 2026-08-28

The user immediately supplied a second target-device recording/log after Build229, but this capture is **Home vertical scrolling**, not the intended Library 3×3 pagination A/B. It therefore does **not** promote Build229 to target-device-tested for its Library persistence change. At this historical point the intended Build229 Library test was still pending; the later 2026-08-29 Library result above supersedes that status.

Uploaded files: `OnePlayer-App-1787907572.log` and `RPReplay_Final1787907569.mp4`. The App log contains only five `HomeCarousel settled` records and no `PosterScrollHitch`, pagination, Library snapshot read/write, or page-apply records. The 15.47 s / 30 fps recording spans approximately 08:59:13.53Z–08:59:29.00Z by filename time. Two carousel settles fall inside that span at approximately +5.214 s (`item=143014`) and +12.211 s (`item=143013`). Frame-motion inspection shows near-zero/duplicate-frame → catch-up patterns shortly after both settle points, with the cleaner second sequence around +12.30–12.37 s. Because the recording itself is only 30 fps and the App log emitted no `PosterScrollHitch`, this is **supporting correlation, not proof of a 60–70 ms app-main-thread stall**.

Exact Build229 source keeps the normal Home carousel timer on `.main`; `autoAdvanceCarouselIfNeeded()` starts a 0.62 s transition and schedules `settleCarousel` after 0.63 s. `settleCarousel` synchronously mutates `currentCarouselItemID`, transition IDs/progress/direction, drag state and `carouselLastSettledAt`, then logs `HomeCarousel settled`. Those state changes can invalidate Home presentation, so the approximately 7 s recurring settle cadence is a plausible contributor to a periodic “sudden twitch” subtype. However Build222 already blocked new automatic carousel transitions after Home left the top and the user still perceived Home vertical hitching, so offscreen auto-advance/settle is already rejected as the **sole or sufficient** explanation for Home vertical jitter. Do not repeat Build222 as a blind fix.

Current interpretation: Build228's 39.7 ms synchronous Library write remains a valid contributor to the severe **Library pagination-adjacent** sample, while this new Home-only capture points to a separate periodic Home presentation/state-update correlation. The two paths must remain separate until route-specific device evidence proves otherwise.

## Acceptance / protected contracts

- Home, library 3×3, favorites/more, search, tag and person/actor poster-heavy vertical scrolling must not show the visible “停一帧 → 下一帧追位” hitch.
- Keep poster count, 3-column layout, metadata, native navigation semantics and rendered image quality.
- Do not hide the problem with list truncation, lower-than-rendered image quality, debounce/throttle/timer/watchdog/retry/fallback.
- Deployment Target remains iOS 15.0.
- Player / MPV / PiP / UnifiedTransport / Range/206 / playback Cache / Emby Resume/Session / STRM→302→115/CDN client-direct are do-not-touch. NAS must never relay media bytes.

## Real-device history controlling the direction

### Build202 / 0.14.35 — rejected

CI/IPA passed, but the target-device recording still showed the stop/catch-up signature. Around 4.067 s the recorded vertical movement was approximately **-6.36 px → 0 px → -26.19 px**. Image-loading-state/request-size reductions therefore did not solve the user-visible hitch.

### Build204 / 0.14.37 — rejected

CI/IPA passed. Target device still visibly hitched on both Home and library 3×3. Recorded examples included approximately **-1.56 → 0 → -10.33 px** and **-1.99 → 0 → -20.27 px**. Removing ordinary no-op image subscriptions and warm-cache second invalidation is not the main cross-page cause.

### Build206 / 0.14.39 — first diagnostic capture

Exact source `351c62694ac25404c2bd4eb36a03314dd58ffed2`; run/job `33000992493 / 98282482225`; artifact ID `9618646972`; IPA SHA-256 `ee981133777c316305c4890aaa1a99b8906792783cad1496d880bf786611e18c`.

Target-device App log contained **17** `PosterScrollHitch` records: Home/row 7, grid 10, grid max 118.7 ms. All 17 had `load_ahead=none`; 8/10 grid entries were >1 s after both latest recorded cell appearance and image commit. This ruled out immediate cell entry / image commit / load-ahead as a universal trigger, but Build206 did not record whether vertical content was actually moving, so attribution remained incomplete.

## Build209 / 0.14.42 — target-device result

Exact source: **`e95d73b75938ad92f2c4d7f06a3ba2d441bb92f4`**.

Build209 added transparent Home/grid motion probes and gated the existing single poster `CADisplayLink` by actual `contentOffset.y` change. It logged `scroll_route`, drag/deceleration phase, offset, delta and velocity without changing scroll behavior.

CI / IPA evidence:

- run/job: **`33006881819 / 98302809290` — success**
- artifact ID: **`9621031556`**
- artifact ZIP SHA-256: `dc9d9aec4b266543fd894f8e6cdc6a5e811f88113c4a5fc7e1da83f1545dae7e`
- IPA SHA-256: `85f6649352718a8cac2b269ee090e19bfbb173881845462ed1493e1d90129572`
- source ZIP SHA-256: `4437f8e1c7af4f28ac4682c6eea05cbfdd86f2f2a806a793ec81f91353cb716b`
- bundle/version/build/MinOS: `com.embyplayerlab.app`, **0.14.42 (209)**, iOS 15.0

Latest target-device App log: `OnePlayer-App-1787774511.log`.

Verified `PosterScrollHitch` entries that already passed `delta_y != 0`:

1. **78.8 ms**, `scroll_route=home`, `phase=dragging`, `offset_y=1129.67`, `delta_y=5.33`, `velocity_y=0.0`.
2. **38.1 ms**, `scroll_route=home`, `phase=dragging`, `offset_y=1240.33`, `delta_y=1.33`, `velocity_y=0.0`.
3. **67.2 ms**, `scroll_route=home`, `phase=dragging`, `offset_y=2602.00`, `delta_y=-61.33`, `velocity_y=1012.3`.

The 67.2 ms sample is direct evidence of a long frame while Home content was materially moving. Build209 therefore confirms real Home motion stalls rather than only idle/ProMotion cadence.

However, the same session clearly scrolled shared grid content far enough to trigger pagination: the diagnostic `load_ahead_age_ms=15376.1` at 20:01:45.018 back-calculates to about **20:01:29.642**, matching the grid `StartIndex=60` request at **20:01:29.650**. Despite that, the log contains **zero `scroll_route=grid` hitch records**.

Exact-source inspection explains why: Build209 stores only one global `observedScrollView / observedScrollOwnerID / observedScrollRoute / lastScrollOffsetY`. Home remains in the navigation hierarchy while pushed grid pages can exist, and either transparent probe can re-attach during layout, overwriting the other diagnostic owner. Therefore **Build209 grid attribution is not reliable**. Do not infer “grid has no stalls” from its zero grid records.

**Build209 evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device diagnostic tested ✅ / Home motion stalls verified ✅ / grid attribution incomplete ❌ / performance root cause unresolved / not stable.**

## Build210 / 0.14.43 — current multi-owner diagnostic candidate

Build210 keeps the same 30 ms threshold and exactly one shared poster `CADisplayLink`. It changes only diagnostic owner registration so Home and pushed grid pages cannot overwrite each other.

Exact source: **`9d8fd6a62e6e7d281d4fae5ab8442754a6362f47`**.

Exact Build209→Build210 delta is four files only:

- `Sources/Core/AppIdentity.swift`
- `Sources/UI/EmbySharedImageAndNavigation.swift`
- `docs/changelog/CHANGELOG_v0_14_43_build210.md`
- `scripts/check_poster_grid_smoothness.py`

Diagnostic implementation:

- each probe owner has an independent weak `UIScrollView`, route and previous `contentOffset.y` in `scrollObservations[UUID]`;
- each display tick samples all registered vertical scroll views;
- only owners whose real offset changed become moving samples;
- if more than one moves, dragging is preferred over decelerating over programmatic moving, then larger absolute `delta_y` wins;
- log adds `registered_scrolls` and `moving_scrolls` so arbitration is observable;
- the old single-owner fields are absent;
- no Home/grid probe placement changed from Build209;
- no scroll physics, image policy, navigation behavior, lazy-container behavior or carousel owner changed.

During implementation an initial contents-API whole-file write truncated the shared file. **It was detected by exact diff before Build210 CI and never became a tested package.** One-shot repair run/job `33009161632 / 98310624611` restored the exact Build209 full source then applied only the multi-owner patch; checker, `git diff --check`, single-file repair scope and source-length guard passed. The repaired exact CI source is the SHA above.

Build210 CI / IPA evidence:

- exact-source run/job: **`33009322419 / 98311176681` — success**
- source checker, exact four-file scope, Frozen/P0 guard and carousel-owner/adjacency guard: PASS
- Xcode 16.4 Release build: PASS
- artifact: `OnePlayer-0.14.43-build210-poster-multi-owner-diagnostics`
- artifact ID: **`9621956333`**
- GitHub artifact digest / independently downloaded artifact ZIP SHA-256: **`d6ba61a5a2f6f635e316db81e3d6d520ae4710b972d652f3df579818f7cc7c32`**
- IPA SHA-256: **`813811fe0301cd8c942511e3e7786c184a80966960bf029ed3366d6edaa23701`**
- source ZIP SHA-256: **`ba59a91128e1b2b1730942966f19fdb364f52552a552c1cf60b8b19ce128a775`**
- IPA/source ZIP integrity: PASS
- bundle/version/build: `com.embyplayerlab.app`, OnePlayer **0.14.43 (210)**
- `MinimumOSVersion=15.0`; MinOS audit PASS
- source snapshot independently confirms multi-owner observations, `registered_scrolls/moving_scrolls`, exactly one poster `CADisplayLink`, no legacy single-owner fields, and complete shared source.

**Build210 evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device diagnostic tested ✅ / multi-owner route attribution validated ✅ / Home image-commit correlation strong but not yet causal / user-drag grid root cause unresolved / performance fix not claimed / not stable.**

## Build210 target-device result — 2026-08-27

Latest App log: `OnePlayer-App-1787807430.log`.

Build210 emitted five motion-gated `PosterScrollHitch` records:

- Home: **68.9 ms**, `phase=dragging`, `delta_y=16.00`, `image_age_ms=11.0`, `cell_age_ms=6644.2`.
- Home: **34.9 ms**, `phase=dragging`, `delta_y=3.00`, `image_age_ms=6.2`, `cell_age_ms=7277.1`.
- Home: **74.5 ms**, `phase=dragging`, `delta_y=2.33`, `image_age_ms=8.8`, `cell_age_ms=13651.4`.
- Home: **39.8 ms**, `phase=dragging`, `delta_y=11.00`, `velocity_y=-503.8`, `image_age_ms=9.0`, `cell_age_ms=14291.9`.
- Grid: **70.4 ms**, `scroll_route=grid`, `phase=moving`, `delta_y=0.33`, `velocity_y=0.0`, `registered_scrolls=2`, `moving_scrolls=1`, `image_age_ms=855.4`, `cell_age_ms=1151.0`.

This validates the Build210 multi-owner diagnostic model: Home and grid owners coexist and only the actually moving owner is selected. Build209's zero-grid result was therefore a diagnostic ownership defect, not proof of a smooth grid.

The four Home dragging hitches all occurred only **6.2–11.0 ms** after the most recent shared image commit while the latest poster cell appearance was already **6.6–14.3 s** old. Exact Build210 source shows decode already occurs in detached utility work; `imageDidCommit()` is timestamped immediately after `@Published image` assignment on MainActor. Home carousel `onImageLoaded` callbacks then synchronously run `updateCarouselImageMetrics`, including `EmbyImageContrastAnalyzer.prefersLightForeground` → `CIAreaAverage` → `CIContext.render`, and may mutate root Home `@State` dictionaries. This is the strongest Home-specific source/device correlation so far.

However, `imageDidCommit` is global and does not identify item/route/cache source, so the 4/4 correlation is not yet enough to change image policy. The one grid record is also not a user-drag sample and has no near-image correlation. Do not claim a cross-page root cause yet.

## Build212 / 0.14.45 — source-aware diagnostic candidate

Build212 is a **diagnostic-only** successor to Build210. Build211 / 0.14.44 is owned by the independent Home-carousel task; the poster task retired its temporary 211 identity before distribution and uses the unique Build212 identity.

Exact source: **`4f0a89ab026cd2103f66e5854a1f352d34852e45`**.

Exact Build210→Build212 product delta is four files only:

- `Sources/Core/AppIdentity.swift`
- `Sources/UI/EmbySharedImageAndNavigation.swift`
- `docs/changelog/CHANGELOG_v0_14_45_build212.md`
- `scripts/check_poster_grid_smoothness.py`

Build212 retains Build210's one shared motion-gated poster `CADisplayLink` and multi-owner Home/grid attribution, then adds only source-aware correlation in shared image infrastructure:

- image publish context: Emby item ID, image type, requested `MaxWidth`, `source=memory/disk/network`, and `role=display/callback`;
- synchronous `onImageLoaded` callback duration measured around the existing callback invocation;
- synchronous `CIContext.render` duration in `EmbyImageContrastAnalyzer`;
- existing hitch log keeps route/phase/offset/delta/velocity/cell/image/load-ahead timing and adds the new image/callback/contrast fields;
- authentication query data is not logged;
- no timer, debounce, throttle, watchdog, retry, fallback, second display link, image-policy change, scroll-physics change, navigation change or carousel-owner change.

CI / IPA evidence:

- exact-source run/job: **`33045869471 / 98429601490` — success**
- source checker, exact four-file scope, Frozen/P0 and carousel-owner guard: PASS
- Xcode 16.4 dependency resolution + Release build: PASS
- artifact: `OnePlayer-0.14.45-build212-poster-source-aware-diagnostics`
- artifact ID: **`9635696107`**
- GitHub artifact digest / independently downloaded artifact ZIP SHA-256: **`eb53a4b88564165b399edfd9085fcc888718cfa62141725d1f24cc539d598615`**
- IPA SHA-256: **`dcdec181dd16e9b3b666882de8347a76671c743ab8392aa27791d40599eec7a1`**
- source ZIP SHA-256: **`9a618698a71ba45074ae915d859afdf9173f312e989e9a646717ed8c6ba60459`**
- IPA/source ZIP integrity and embedded checksum verification: PASS
- bundle/version/build: `com.embyplayerlab.app`, OnePlayer **0.14.45 (212)**
- `MinimumOSVersion=15.0`; MinOS audit PASS
- source snapshot independently confirms source-aware image fields, callback/contrast timing and the unchanged single poster `CADisplayLink`.

**Build212 evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device diagnostic pending ❌ / performance fix not claimed / not stable.**

## Build212 target-device result — 2026-08-27

Latest App log: `OnePlayer-App-1787813666.log`.

Build212 emitted **18** motion-gated `PosterScrollHitch` records: 6 Home and 12 grid. The useful user-drag samples split cleanly by route.

### Home

- **5 real `phase=dragging` hitches**, frame gaps **43.6–73.8 ms**.
- All 5 latest image publishes were `image_source=memory`, `image_role=callback`, `image_type=Primary`, `image_max_width=1400`.
- Image publish age at the hitch was only **8.3–12.2 ms**.
- The measured synchronous callback duration was only **1.0–3.2 ms**; measured Core Image contrast render was only **1.0–3.0 ms**.
- Latest ordinary poster-cell appearance was already **7.3–21.9 s** old.
- The log also shows `HomeCarousel settled` events around the same repeating transition cadence. Some image items produce a hitch before settle and another shortly after settle, consistent with more than one carousel image consumer publishing the same memory-resident 1400px artwork during a transition.

Conclusion: the previous suspicion that `CIContext.render` / `onImageLoaded` synchronous work itself explains the 40–70 ms Home stall is **rejected**. Their measured duration is too small. The stronger Home lead is the carousel's 1400px memory-hit image publication / SwiftUI presentation work while the user is vertically scrolling, including when the Hero is far above the visible scroll position. This is Home-specific and overlaps the independent carousel owner.

### Grid

- **11 real `phase=dragging` hitches**, frame gaps **31.0–37.3 ms**.
- All 11 latest image publishes were `image_source=network`, `image_role=display`, `image_type=Primary`, `image_max_width=378`.
- Image publish age at the hitch was **0.0–20.1 ms**.
- Latest grid-cell appearance was only **118.8–177.8 ms** old.
- Carousel callback/contrast events were stale by **13.6–39.9 s** and therefore unrelated to these grid stalls.
- Pagination/load-ahead timing is not the common trigger; the repeated pattern is newly visible grid cells plus display-image publication during active dragging.

Conclusion: Build212 finally proves the user's library/grid hitch during actual dragging and ties it to the display-only poster image publish/render path, not to the Home carousel callback path.

### Architectural consequence

The earlier assumption that Home and all 3×3 routes require one universal root cause is no longer supported. Treat them as two independent runtime fixes:

1. **Home**: reconcile with `DEV-home-carousel-drag-smoothness` before touching carousel owner files; investigate suppressing unnecessary offscreen carousel image presentation work rather than contrast-analysis optimization.
2. **Grid**: inspect the shared display-only poster publish/render path for the smallest change that avoids 31–37 ms main-thread presentation stalls while preserving exact rendered pixel width, image count, navigation and no throttle/debounce/timer behavior.

**Build212 evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device diagnostic tested ✅ / Home callback/contrast as primary cost rejected ✅ / real grid dragging stalls captured ✅ / two-route cause split established ✅ / runtime fix not yet tested / not stable.**

## Build218 / 0.14.51 — target-device result

Exact tested source: **`ccc3a69f3b77c56a730593f072a2c7dfde599073`**. CI run/job **`33066739271 / 98498551491`** succeeded; artifact ID **`9644109849`**; artifact ZIP SHA-256 `16096a2c3a1b4dcb4ed3bcfa8524e3839f9114eb040e7ee419279555c1e71c4e`; IPA SHA-256 `104eb5266c304102c912eaa2b9e95a4f0ae6183b0bf071fd377b3a52ea8d57bc`; source ZIP SHA-256 `41dfb97a0bfd38cb65ed000b3f9fc2679dc7bf471abe7635020895a5f4f12b90`; OnePlayer 0.14.51 (218), MinOS 15.0 independently verified.

Target-device evidence supplied 2026-08-27:

- User report: **Home still has obvious vertical jitter**. This is the highest-priority evidence and Build218 must not be described as a Home fix.
- Recording `RPReplay_Final1787833032.mp4`: 510×1108, 30fps, 691 frames, ~23.03s. Frame-to-frame crop translation retains clear stop/catch-up examples: around 6.50s movement is ~2.85 recorded px, 6.53s ~0, 6.57s ~11.98px; around 20.13s ~1.14px, 20.17–20.20s ~0, then 20.23s ~9.07px. 30fps remains only a lower-bound observation of the 120Hz device.
- This test only establishes the Home result. The user did not provide a 3×3 grid A/B result in this turn, so Build218 grid effectiveness remains pending.
- Screenshot shows a rectangular background behind the carousel movie Logo. Exact source proves `Sources/UI/EmbyHomeHeroV3.swift` is byte-identical between accepted Build216 main and Build218 (`8a2d5ec00cdd2daa3ef116930e388f18791b580b`). The Logo call uses `EmbyCachedRemoteImage(... contentMode: .fit, showsLoadingIndicator: false)` with no callback, so Build218 routed it through the new poster-task UIKit display surface. That surface kept `backgroundColor = .secondarySystemBackground` even after a transparent Logo loaded, unlike the prior SwiftUI path where that background existed only while no image was present. Therefore the white rectangle **is a Build218 shared-image regression**, not a carousel-owner change.
- Minimal correction now written on poster branch head **`ac8a8cd0b87c4ee544c8817fec13edeea226826b`**: when the UIKit surface has an image, its background becomes `.clear`; when image is nil it keeps `.secondarySystemBackground`. No Home carousel owner source is touched.

**Evidence now: Build218 code/CI/IPA ✅ / Build218 Home target-device tested and still hitches ❌ / Build218 grid A/B pending / Build218 distributed package has a confirmed transparent-Logo regression ❌ / transparency correction code written ✅ / corrected source CI/IPA pending / not stable.**

## Build220 / 0.14.53 — corrected grid UIKit A/B candidate

Build220 is the Build218 grid/display-only UIKit experiment resynchronized onto the accepted Build216 overall runtime baseline, plus the one-line transparent-image presentation correction. Poster Build219 was retired before distribution when the independent carousel task claimed that identity.

- exact tested source: **`6198466a749a54603a67c6c32bc0efcf9d7e2082`**
- accepted-main comparison base used for exact scope: `6a3f52bd8b91995a01f0c908887ffb375d8ec737`
- exact product/check delta: seven poster paths only (`AppIdentity`, person poster policy, `EmbyPosterGrid`, shared poster sizing, shared image/diagnostics, Build220 changelog, poster checker)
- no `EmbyHomeCoreV3.swift`, `EmbyHomeHeroV3.swift`, `EmbyHomeCarouselStateV3.swift`, `EmbyHomeCarouselInteractionV3.swift`, Player or Transport changes
- shared UIKit display surface preserves `secondarySystemBackground` only while image is nil and switches to `.clear` once an image is present, restoring transparent Logo semantics without modifying carousel owner code
- run/job: **`33083504023 / 98556783889` — success**
- artifact: `OnePlayer-0.14.53-build220-poster-grid-uikit-transparent`; ID **`9651230376`**
- GitHub artifact digest / independently downloaded ZIP SHA-256: **`fc1cd17fe974b6e35b2eda03eb32718ca3fca6fa4034406016385a9aa5c1f729`**
- IPA SHA-256: **`a73a33866745418663d1dcc35634f5b21b0a73436a91f40ed8a4f6dc6bbcf574`**
- source ZIP SHA-256: **`7c222973433e8e94608946fc5ffda4e5ec4442a9c6200be4b98e84d680695fad`**
- artifact ZIP, IPA and source ZIP integrity: PASS; embedded SHA files match independent calculation
- built identity: `com.embyplayerlab.app`, OnePlayer **0.14.53 (220)**, `MinimumOSVersion=15.0`; primary/alternate icon metadata present
- exact source snapshot contains the clear-background regression fix and no Build220 temporary workflow
- one-shot Build220 build helper self-cleaned successfully

**Evidence: Code written ✅ / synchronized exact 7-path scope + checker ✅ / CI passed ✅ / IPA produced + independently verified ✅ / target-device tested ✅ / user reports 3×3 basically unchanged ❌ / stable or frozen ❌.**

Target-device test must explicitly cover Library 3×3, Favorites, Favorites → More, Search, Tag and Person/Actor grids. Home may be checked only for regression; Build218 already proved this poster candidate does not solve the separate Home hitch path.

### Build220 target-device result — 2026-08-27

User verdict on the intended 3×3 scrolling A/B: **“体感来说：基本一样”**. This is the controlling real-device result; Build220 must not be described as a grid smoothness improvement.

Uploaded App log: `OnePlayer-App-1787845216.log`. It is short but contains two `PosterScrollHitch` records on the grid route:

1. **33.3 ms**, `phase=dragging`, `offset_y=3506.00`, `delta_y=5.33`, `visible=12`. The latest poster event was item `29670` only **171.7 ms** earlier and is also the load-ahead trigger. The latest image commit was item `29668`, `Primary`, `MaxWidth=378`, `source=network`, `role=display`, **35.8 ms** before the hitch. The `StartIndex=60` page request began about **164 ms** before the hitch.
2. **74.1 ms**, `phase=moving`, `offset_y=3639.33`, `delta_y=1.00`, `velocity_y=0.0`. The latest image commit was already **1010.1 ms** old and the latest cell/load-ahead event **1146.1 ms** old, so this second sample is not evidence of an immediate image-publish trigger and is weaker than the dragging sample for user-touch attribution.

Exact Build220 source matters for interpretation. The display-only path no longer makes the surrounding SwiftUI poster cell observe loader image changes, but `EmbyCachedImageLoader` still performs `self.image = loaded` on the MainActor. That `@Published` assignment synchronously delivers to the UIKit surface's Combine sink, which then calls `UIImageView.image = image`. Current diagnostics timestamp `imageDidCommit` only **after** the assignment; they do not measure the assignment/publisher/sink/UI image-adoption duration or bursts of several commits. Therefore Build220 falsifies “SwiftUI poster-cell observation is the primary sufficient cause”, but does **not** yet isolate whether the remaining cost is the MainActor publish/Combine→UIImageView adoption/compositor path.

The first hitch also occurs immediately after grid load-ahead starts `StartIndex=60`. On the accepted Build216 baseline, library pagination applies new items on a `@MainActor` model and then synchronously serializes/writes the persistent page snapshot. That path is worth measuring for this pagination-adjacent sample. However it cannot be the universal historical cause: Build212 captured the same 3×3 hitch family before the Build213 persistent-page-cache milestone existed. Do not replace the image-path evidence with a cache-only theory.

**Build220 evidence now: Code written ✅ / synchronized exact scope+checker ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅ / user reports 3×3 basically unchanged ❌ / grid UIKit observation-bypass hypothesis rejected as sufficient ✅ / root cause still unresolved / not stable.**

Next diagnostic should be measurement-only: time the MainActor `@Published image` assignment including synchronous Combine delivery to the UIKit surface, record image-publish bursts around long frames, and separately time pagination result application plus persistent snapshot serialization/write. Do not add another smoothing patch until those costs are separated.

## Parallel safety

- Build211 / 0.14.44 identity is owned by the independent Home-carousel task; poster Build212 does not reuse that identity.
- Build210 does **not** modify `EmbyHomeCoreV3.swift`, `EmbyHomeCarouselInteractionV3.swift`, `EmbyHomeCarouselStateV3.swift` or `EmbyHomeHeroV3.swift`; it reuses Build209's already-present transparent Home/grid probes.
- `EmbySharedImageAndNavigation.swift` is shared infrastructure. Whichever Active task integrates second must resync to then-current `main` and rerun affected validation; old CI cannot prove combined source.

## Next exact action

1. Treat Build220 as a real-device ineffective grid candidate; do not merge or tune the UIKit surface blindly.
2. Add measurement-only diagnostics for MainActor `image` publication / synchronous Combine→`UIImageView` adoption duration and nearby publish bursts.
3. Add separate timing for pagination result application and Build213 page-persistent snapshot serialization/write, because the first Build220 dragging hitch is pagination-adjacent.
4. Preserve Build212 as the historical guardrail: persistent page cache cannot be the universal cause because the grid hitch family predates Build213.
5. Keep Home-carousel ownership separate and do not touch Player / Transport / Cache / Session P0 contracts.

## Do not repeat

- Treating Build202/204 as performance successes because CI/IPA passed.
- Treating Build209 zero grid hitches as evidence the library grid is smooth.
- Replacing `LazyVGrid` without trace evidence.
- Adding another image cache/decoder or lowering images below rendered device pixels.
- timer/debounce/throttle/watchdog/retry/fallback.
- Refactoring NavigationLink or carousel gesture ownership without direct evidence.
- Touching Player / MPV / PiP / Transport / Cache / Session contracts.
