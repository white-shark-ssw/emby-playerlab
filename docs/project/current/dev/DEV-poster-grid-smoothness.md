# DEV-poster-grid-smoothness

## Status and current identity — 2026-10-07 (Asia/Shanghai)

- **Active — Build296 exact-source regressions/Release/IPA independently verified; target-device inertia/long-frame retest pending; P2 not accepted.**
- Existing task/plan: [POSTER_IMPLEMENTATION_PLAN.md](../../POSTER_IMPLEMENTATION_PLAN.md). Only G01 Library.items has migrated; other hosts remain gated.
- Working branch: `perf/poster-wall-library-build295`; Draft/open/unmerged [PR292](https://github.com/white-shark-ssw/emby-playerlab/pull/292), base main.
- Current working branch head: **5064d1897ab0e199d53ed59853d5f9b87e95d422** (final project-document synchronization only; exact packaged runtime/test bytes unchanged). Exact package/test source: **bfa5b56ee1e5737cf0fff9a2b7234505e8469dfb**.
- Current candidate: **OnePlayer0.15.29 /Build296 /poster-wall-motion-diagnostics /iOS15.0**. Target iPhone15ProMax/iOS17.0.
- CI control: `ci/build296-poster-wall-motion-20261006`, **b904829dc6e24186e35c5cc595bf2d71893094f3**; workflow `.github/workflows/build296-poster-wall-motion.yml`; **run37490702186 /job112362875963 success**.
- Artifact **11425443691**, digest **efcbbf9ac1de1cd175ba0603e4dcc7f156a4adc46a8cd79ba42caaaac7cfdabd**. Package/MinOS details below.
- Previous Build295/0.15.28 source8ca3de65a8ca2927785bb194b6a3136b6d900e56 and IPA remain historical pilot evidence. User reports high FPS/refactor positive; abrupt stop was not accepted.
- Base03d1bad260666c3f38ae3913d6828f393690673e; accepted overall294/Dock294, inherited accepted293carousel. Historical PR282/39014a03 untouched/open/unmerged; no stack merge. Aether235 separate; Search256 protected.

## Build296 /0.15.29 — Library inactive-refresh inertia correction and bounded tail diagnostics (2026-10-07 Asia/Shanghai)

- Task DEV-poster-grid-smoothness; G01 Library.items only; same perf/poster-wall-library-build295 /Draft PR292. Product exact source **bfa5b56ee1e5737cf0fff9a2b7234505e8469dfb**; baseline03d1bad260666c3f38ae3913d6828f393690673e (accepted overall294/Dock294, inherited carousel293). Main changes before final packaging were project documents only.
- User feedback2026-10-06 23:04: refactor relatively successful, FPS maintains a high level; asks to improve long frames. Qualitative positive Build295 result, not full P2 acceptance or presented120FPS measurement.
- Actual native fast-swipe/controlled metadata test reproduced on iOS18.5: deceleration stays1 through append; inactive endRefreshing synchronously triggers deceleration-end0. Source5187b590e51770f05fd393709cbd66ddddc589b6, run37488102803/job112353349125. Actual count120, content expanded, offset did not jump. This is simulator causal evidence, not independent proof of the earlier video's iOS17 timing/root cause.
- Small owner fix: call existing endRefreshing only when loading finishes AND UIRefreshControl.isRefreshing is true. Real pull-refresh completion preserved. No inertia/offset/footer/page-size/load-ahead/image-budget changes, placeholder-total slots, timers or retries.
- Bound diagnostics:64 numeric frames, including first stationary frame after motion; native drag/deceleration endpoints; count/revision/loading/footer/geometry/legal boundary; append begin/completion; real refresh; model request/response/publication/persistence/finish. Wall4096/model2048 event caps. No per-frame strings. SourceVersion/package Build logged at wall creation; no new source URL/user ID traces.
- Exact-source CI **[run37490702186](https://github.com/white-shark-ssw/emby-playerlab/actions/runs/37490702186) /job112362875963 success**; control **b904829dc6e24186e35c5cc595bf2d71893094f3**, branch ci/build296-poster-wall-motion-20261006, workflow .github/workflows/build296-poster-wall-motion.yml. **12 actual production-source units/0 failures +1 real native-gesture UI test/0 failures**. Actual18 native Dock/carousel tests remain byte-guarded against source20d52f7706d9abf914facf50359df8ccb336fd09/run37474393518/job112306217313; original logs retained. Not described as rerun.
- Release compile, scope/whitespace/Frozen guards, package identity and MinOS audit passed. Artifact **[OnePlayer-0.15.29-build296-poster-wall-motion-diagnostics](https://github.com/white-shark-ssw/emby-playerlab/actions/runs/37490702186/artifacts/11425443691)**, ID **11425443691**, ZIP digest/downloaded SHA256 **efcbbf9ac1de1cd175ba0603e4dcc7f156a4adc46a8cd79ba42caaaac7cfdabd**.
- IPA `OnePlayer-0.15.29-build296-poster-wall-motion-diagnostics-unsigned.ipa`, **18724844 bytes**, SHA256 **c9379f6a592feece2a158f9ee8bf2a29bd60f28409b5c607b0ac56fc4639af1d**. Exact source ZIP SHA256 **d4fc1ab9015750870e013da09cfbc8cf82b7be73d95c6322dcf912c2a68c959b**; git archive comment equals package source.
- Independent verification: ZIP integrity/checksums, bundle **com.embyplayerlab.app**, version **0.15.29**, Build **296**, Info MinOS **15.0**, arm64 Mach-O MinOS **15.0.0**, CADisableMinimumFrameDurationOnPhone=true; embedded compatibility audit **OK**. Downloadable IPA saved separately; no temporary signed URL in project docs.
- Earlier CI: initial named/latest simulator destination failed before tests, corrected to actual iOS18.5 UDID; native UI failures exposed the cause; first refresh/control-request unit fixture failures were corrected by empty unit-host isolation, actual window attachment and bounded10s test-only boundary wait. Same-source run37490079849 was cancelled after12 unit passes when a duplicate same-control push run appeared; final run above completed the entire pipeline. No failed/cancelled run is claimed as success.
- **Code written /12+1 regressions passed /exact-source Release CI passed /IPA independently verified /Build296 target-device pending /task Active /not stable /not merged.** P2 awaits iPhone15ProMax/iOS17 initial-load inertia and long-frame log/video, plus remaining cache/navigation/deep return-top matrix. G02–G15/H01–H04 unstarted and gated; accepted overall baseline294 remains. Protect293carousel/294Dock/Search256/P0.


## Completed and validation — historical Build295 pilot

P1: original Library cache owner performs metadata read/JSON/index construction and ordered snapshot construction/JSON/atomic writes on a serial utility queue. Cached restore publishes once before live requests; refresh failure preserves cache/frontier. Completed restoration future is released; stale sort replies are generation rejected.

P2: G01 Library.items alone uses complete native collection scroll host and fixed UIKit image/title/year/badge/progress cell; suffix-only append, targeted image adoption, original60 paging, refresh/footer, native return-top and always-mounted NavigationLink. Existing disk/decoded/ImageIO remain sole cache authorities. Shared visible/prefetch/first-screen consumers use bounded preparation:4 active operations including cancellation until completion,12 pilot prefetch URLs,24 first-screen URLs across at most2 page demands. Dynamic Type/SF badge/display-scale and clipped progress retained. These are initial budgets, not measured app memory limits.

- Actual production poster cell/preparation/cache/model **8 tests/0 failures** passed sourcefefdcaefa4cacdc04644aed06e2262292727829d, run37476373994/job112312892728.
- Actual Dock/carousel **18 tests/0 failures** passed source20d52f7706d9abf914facf50359df8ccb336fd09, run37474393518/job112306217313.
- Current CI guards all test dependency bytes. Sole change since the eight-test source: existing EmbyPosterDetailDestination private→internal, correcting the full Release compiler visibility error. Full app Release is rerun; no untested unit-input change.
- Source scope/whitespace/MinOS and protected native source guards passed. Earlier whitespace and pixel-width syntax failures corrected; Release visibility failure corrected from actual compiler evidence.
- **IPA produced and independently verified; target-device pending. Simulator tests do not prove120FPS.**
- G02–G15/H01–H04 scroll hosts remain unstarted. Shared image subscriptions do not imply host migration.

## Build295 — Library.items pilot verified handoff (2026-10-06)

- Candidate: **OnePlayer0.15.28 / Build295 / poster-wall-library**; `perf/poster-wall-library-build295` / Draft [PR292](https://github.com/white-shark-ssw/emby-playerlab/pull/292).
- Exact package source: **8ca3de65a8ca2927785bb194b6a3136b6d900e56**; base03d1bad260666c3f38ae3913d6828f393690673e (accepted294/293). Later project-document synchronization is not packaged source.
- Exact-source Release CI: [run37477868307](https://github.com/white-shark-ssw/emby-playerlab/actions/runs/37477868307) / job112317946251 **success**; control branch `ci/build295-poster-wall-library-20261006`, control **38689808411cee237bbf56f85d14619b2e07446f**.
- Actual production poster cell/preparation/cache/model **8 tests /0 failures** passed sourcefefdcaefa4cacdc04644aed06e2262292727829d, run37476373994/job112312892728. Actual native Dock/carousel **18 tests /0 failures** passed source20d52f7706d9abf914facf50359df8ccb336fd09, run37474393518/job112306217313. Final CI byte-guards all dependencies and carries original logs; only private→internal detail-destination access changed since eight-test source, and full Release compile passed.
- Artifact: [OnePlayer-0.15.28-build295-poster-wall-library](https://github.com/white-shark-ssw/emby-playerlab/actions/runs/37477868307/artifacts/11419727577), ID **11419727577**; digest/downloaded ZIP SHA256 **69c1fed42d8172337a27bf48722d6c80214c39134b1df37e9df827a60445588d**.
- IPA: `OnePlayer-0.15.28-build295-poster-wall-library-unsigned.ipa`, **18713591 bytes**; SHA256 **a5bd7e5a23918ee81df47c6fd4ece34b359d56b6c62fbcc89c826abc44461b5c**.
- Exact source ZIP SHA256: **b3ab04d969cd0f58df8f1eafd8673427d0aee222c7e35d6c9e7ec33c18b2742d**; git archive comment equals exact package source.
- Independently verified ZIP integrity/checksums, bundle **com.embyplayerlab.app**, version **0.15.28**, Build **295**, Info.plist MinOS **15.0**, arm64 Mach-O MinOS **15.0.0**, CADisableMinimumFrameDurationOnPhone=true. Embedded runtime compatibility audit **OK**.
- Scope: G01 Library.items complete native scroll host/cell, target-image adoption, shared bounded preparation/first-screen demand, background cached-first metadata restoration and ordered snapshot writes, original60 paging and system navigation activation. G02–G15/H01–H04 hosts unstarted.
- Device matrix pending: both G01 entrances; cold/disk-warm/memory-warm scrolling; paging/failure; warm relaunch;~item2000 return-top; push/pop/interactive back; sort/refresh; Dock; resource/frame-tail sampling. Fixture5000-visit bounds are not a5000-item device acceptance.
- Earlier whitespace/pixel-width syntax failures and full-app destination visibility error were corrected from actual CI evidence.

**Code written /8 poster +18 retained native regressions passed /Release CI passed /IPA independently verified /real-device pending /task Active /not stable /not merged.** Accepted overall baseline remains294;293carousel/294Dock/Search256/P0 preserved. P3–P6 await P2 target-device evidence.

## Build296 exact-source regression pass / Release running — 2026-10-06

Source **bfa5b56ee1e5737cf0fff9a2b7234505e8469dfb** /control **b904829dc6e24186e35c5cc595bf2d71893094f3**, run **37490702186 /job112362875963**: **12 actual-source unit tests/0 failures +1 actual native-gesture UI test/0 failures**, then dependency preparation succeeded and full Release build is in progress. Retained18 Dock/carousel dependencies still byte-identical to passing production-source20d52f7; current scope/whitespace/Frozen checks passed. This verifies the native inactive-refresh fix and real-refresh completion in simulator18.5, not target17 acceptance/FPS. Next: finish Release, audit package/source/MinOS, retrieve/save IPA, update durable docs and hand off. Do not stop at test/CI start; no IPA296 yet.

## Build296 same-source CI continuation — 2026-10-06

Source **bfa5b56ee1e5737cf0fff9a2b7234505e8469dfb** /control **b904829dc6e24186e35c5cc595bf2d71893094f3** unchanged. Run37490079849/job112360189878 completed **12 units/0 failures**, then was cancelled during UI gesture execution after a same-control-SHA push run appeared; do not call this whole pipeline passed. Latest exact-source run **37490702186/job112362875963** already in progress. No new source/Build/candidate, no manual bypass or retained UI-test substitution. Follow latest run through13 total tests/Release/verified IPA.

## Build296 fixture correction / native fix pass — 2026-10-06

Exact runtime source77b292b619b8db77e68f5bfbf3ca49c254840323, run37489099157/job112356775331: **1 real native inertia UI test/0 failures** after the isRefreshing completion guard. This is simulator iOS18.5 evidence only. Unit12 had4 failures: two original controlled-request2s startup deadlines elapsed with the newly active native/DNS/display-link host; new refresh fixture called beginRefreshing on an unattached zero-size scrollview and remained false. Do not call the whole suite passed. Tests now keep the old empty unit host unless explicit UI launch argument selects MotionHost, mount the real refresh controller in a real window, and use a10s bounded request boundary wait (not a latency assertion). Runtime fix/diagnostics unchanged; current exact sourcebfa5b56ee1e5737cf0fff9a2b7234505e8469dfb, controlb904829dc6e24186e35c5cc595bf2d71893094f3. Rerun12 units+1 true UI, full Release and verify IPA. No IPA296 yet.

## Build296 evidenced correction — 2026-10-06

Stage-isolation run37488102803/job112353349125 at source5187b590e51770f05fd393709cbd66ddddc589b6: unit11/0; native UI1/1. Exact sequence: update-before decelerating1 → items-before1 → batch-begin1 → items-after1 → end-refresh-before1 → synchronous deceleration-end0 → end-refresh-after0 → update-after0. Location fixed: original controller called endRefreshing even when UIRefreshControl.isRefreshing was false. Native append/inset did not terminate the captured inertia. Minimal correction gates existing completion on !isLoading && isRefreshing; no inertia/offset/footer/page-size/image-budget change. New actual-control unit verifies real pull-refresh ends, inactive ordinary updates do not call completion. Source **77b292b619b8db77e68f5bfbf3ca49c254840323**, control **7cfdd6ca08c1dfa9e060cbcbf44937dffb851782**, tests now12 units +1 true native UI. Next: exact-source full tests/Release/IPA. Target iOS17 user stop and long-frame tail remain pending; simulator18.5 causality is not target-device acceptance.

## Build296 actual native reproduction — 2026-10-06

Source cc06bba2602608d88f2f4171792f50aeca71f362, run37486519229/job112347834140/control0f003b754c4441fbe8f8348f77af983b453c48d4: **11 actual-source unit tests/0 failures**, but **1 actual native-gesture UI test/1 failure**. Controlled metadata is released asynchronously from the true production deceleration-begin event, with no second touch. Result: before decel=1, after_decel=0, expanded=1, jump=0, count120. This proves this simulator's original native update interrupts inertia; it is not yet proof of the iOS17 device's precise root cause. No guessed production patch yet. Updated test-only host now exposes each production trace stage to isolate the operation; combined unit/UI invocation avoids redundant simulator setup. Exact current source 5187b590e51770f05fd393709cbd66ddddc589b6, CI run37488102803/job112353349125, control175a7dcd3ec1cf62738a8b9e957df89bf08078d7. Next: locate the first true→false deceleration stage, apply only evidence-backed owner correction, rerun actual tests and Release/IPA. No IPA296 yet.

## Build296 implementation milestone

Code written: bounded64 numeric motion ring, terminal-stationary frame sampling,4096 wall-event limit,2048 original-model page-event limit, UIKit drag/deceleration/geometry/append/footer/endRefreshing diagnostics. Only existing behavior is observed; no offset/inertia/page-size/prefetch/refresh semantic patch. Tests:11 actual-source unit regressions (existing8 plus3 diagnostic invariants) and1 real native-gesture UI regression with controlled delayed metadata; Xcode simulator execution pending. Actual AppIdentity is copied into harness. Protected18 Dock/carousel test inputs remain unchanged. Exact source: **cc06bba2602608d88f2f4171792f50aeca71f362**. CI in progress: run **37486519229 /job112347834140**, control **0f003b754c4441fbe8f8348f77af983b453c48d4** on ci/build296-poster-wall-motion-20261006 /workflow .github/workflows/build296-poster-wall-motion.yml. Scope/whitespace/frozen/native18 dependency guards passed. First run37486055578 failed before compiling/tests: OS:latest/name destination resolved no compatible simulator; no product failure was demonstrated. CI control now selects real iOS18.5/iPhone16ProMax UDID as in prior passing tests. Running11 unit +1 real native-gesture UI tests, then full Release/IPA on unchanged exact source. No new IPA yet.

## Next exact action

Install/sign the verified **Build296/0.15.29** IPA and repeat the user's first-loaded Library continuous fast upward swipes. At an abrupt stop, wait briefly then drag again; export App log and matching video from this same Build/session. New trace includes package identity, native motion end, legal boundary/contentSize/count, append/footer/real-refresh state and numeric tail. First compare against Build295; collect no-recording frame p50/p95/p99/max and>=16.7/25/33.3 counts for long-frame work, with cache/thermal/low-power context. Do not infer presented FPS or claim all device stops solved from simulator pass. Keep current P2 cache/deep-return-top/navigation/Dock matrix pending; do not roll out G02–G15/H01–H04, merge/freeze or alter P0 until relevant acceptance. Source/CI/package complete; normal handoff is user runtime testing, not another build/continue request.

### 2026-10-06 23:04 — User positive FPS feedback and continuation authorization

User considers Build295 refactor relatively successful and reports high FPS maintained; requests further long-frame optimization. This is qualitative positive device evidence, not complete acceptance or120Hz presentation measurement. User authorized proceeding; iteration delivered Build296 with the evidenced inactive-refresh correction and bounded attribution above.

### 2026-10-06 22:57 (Asia/Shanghai) — Log/video confirms abrupt visual motion stop, cause still unresolved

Evidence supplied: OnePlayer-App-1791298613.log and RPReplay_Final1791298610.mp4 (9.1s,510×1108,30fps). Observed video end-region: a fast upward content movement abruptly becomes stationary near5.8s, holds until approximately7.2s, then moves on a new visible touch. Frame-to-frame image phase correlation in the poster region supports roughly76px upward movement over the preceding33ms recorded-frame interval, then near-zero for~1.4s. This is recorded-image displacement, not native contentOffset or120Hz presented-FPS measurement; changes in image loading and30fps sampling limit interpretation. It is not ordinary observed smooth decay to zero. Additional content becomes reachable after the new touch, but the video cannot independently prove whether the current metadata edge moved during the stop.

Log: restore180 items at14:56:28.425Z, then live page0 replaces180→60 at28.628Z. This session is not fully cache-empty; do not overrule the user's first-load experience report, but classify the captured cache state accurately. No Build/version header is present in the excerpt, so actual installed identity remains supplied-candidate295 contextual attribution, not an independently verified runtime header.

Metadata HTTP request→native items apply:
- StartIndex60:34.204→34.521Z,317ms,60→120,apply10.59ms.
- StartIndex120:42.682→43.325Z,643ms,120→180,apply2.11ms.
- StartIndex180:45.731→45.862Z,131ms,180→240,apply0.90ms.
These intervals include response/filter/publication, not exact network latency. Snapshot total34.42/86.14/106.87/149.66ms all main_thread=0. No evidence that synchronous persistence caused a main-thread pause in this capture.

Motion-gated CADisplayLink log:950 samples,p50/p95/p99~8.335ms,max20.745ms,one>=16.7ms,zero>=25/33.3ms. This does NOT prove displayed120FPS or rule out a stall at the moment isDecelerating becomes false, because sample logging is conditioned on dragging/decelerating. The video creation tag is14:57:13Z (later than the log's last14:56:51.684Z event), and no shared marker establishes absolute video→log time. Therefore do not assert that the5.8s stop coincides with a specific append/footer/store event.

Narrowed diagnosis: distinguish actual current metadata-end arrival from deceleration termination during native update/layout/refresh-control work. Existing source calls endRefreshing on every nonloading representable update and toggles footer0/52 with invalidateLayout; these are audit candidates, not demonstrated causes. Existing telemetry has no contentSize/maxOffset/deceleration-end trace to decide. Next justified diagnostic should record bounded event snapshots at drag-end/deceleration-end, request/apply/batch completion, footer and real refresh transitions, plus offset/legal max/count/velocity; no per-frame string spam. Test actual inertia under delayed metadata and real native updates. Keep timers/artificial offset/inertia, arbitrary total-count placeholders and unmeasured prefetch changes out. User asked inspection; no runtime patch,Build orCI generated in this review. P2 not accepted; later adapters remain gated.

### 2026-10-06 22:50 (Asia/Shanghai) — First-load Library inertial stop reported

User tested the supplied candidate and reports that a first-loaded Library suddenly stops during inertial scrolling. It feels as if lower content has not loaded and the container has only the current height, without obvious boundary damping; the user explicitly labels that as a description, not a confirmed cause. Supplied candidate is Build295/source8ca3de65a8ca2927785bb194b6a3136b6d900e56; actual installed identity/timing/cache state await the App log. No video/log/offset or frame trace is supplied yet. This is new qualitative target-device issue evidence, not acceptance or a measured offset reversal.

Source audit: fixed cell geometry/record count does not depend on image completion. Collection count equals acquired metadata, not server total; existing60-item sequential paging remains, and willDisplay triggers next page within the last9 items. Thus reaching the current loaded extent before metadata arrives is a plausible boundary-starvation hypothesis, not proven. Append uses performBatchUpdates; loading changes footer0/52 height and invalidateLayout; update also calls endRefreshing on nonloading updates. Their deceleration effect has not been measured, so no causal claim or patch is justified. loadingTabs stays set across awaited ordered persistence; this can delay eligibility for subsequent page requests but does not prove main-thread blocking. Current automated append test checks offset/geometry, not an actual cold/network-delayed inertial trajectory.

Next evidence: reproduce with App log plus matching video; locate stop against last visible row/current loaded count, real offset/max/legal bounds, decelerating state, page request→metadata arrival→append/layout timing and frame gaps. User should note whether immediately dragging can continue below the stop. Existing PosterWall items/gap/frames and Library cache timings can begin correlation; if they cannot separate boundary/deceleration/layout, add only focused event diagnostics in a later explicitly justified iteration. Do not inflate arbitrary total-count slots, guess prefetch constants, add synthetic inertia/offset correction, or reopen carousel/Dock/P0. P2 experience is not accepted; P3–P6 remain gated.

## Historical accepted evidence and protected contracts

## Accepted pagination-persistence result

Build278 proved synchronous full-Library persistence caused the pagination-adjacent severe-frame family: snapshot totals 38.31→94.66 ms paired with 49.96→108.33 ms display gaps, correlation ≈0.991.

Build280 moved full Library snapshot object construction, JSON serialization and atomic write onto one serial `.utility` queue while the MainActor model awaits ordered completion. `OnePlayer-App-1788190813.log` showed every persistence record at `main_thread=0`; clean 60→775 pagination no longer reproduced the Build278 50–100 ms persistence-correlated family even while snapshot work grew to 267.76 ms. The user likewise reported no large twitch.

The user then force-quit/relaunched Build280 and reported cached-first Library behavior normal. `OnePlayer-App-1788191685.log` records the fresh process and continued ordered `main_thread=0` writes. It has no dedicated cache-load timing marker, so cached-first acceptance is the user's target-device observation.

Build283 now provides a second target-device regression pass after the navigation repair. `OnePlayer-App-1788197938.log` captures one continuous native Library session from **60→660 items over 19.62 s**:

- display **118.34 Hz**;
- p50 / p95 / p99 **8.33 / 8.70 / 17.85 ms**;
- max **25.02 ms**;
- **31** frames >=12.5 ms;
- exactly **1** frame >=25 ms;
- **0** frames >=33.3 ms;
- reconfigure: 20 events, 1.91 ms total, max 0.19 ms.

The sole 25.02 ms gap occurs with `insert_active=1`, about 17 ms after the 240-item insert began. It is not a persistence-completion pair: the corresponding off-main store/snapshot completes roughly 64/67 ms later. All 12 recorded Library store/snapshot pairs report `main_thread=0`; snapshot total still scales up to **208.87 ms** at the 660-item state without bringing back the old 50–100 ms display-tail family.

**Accepted sub-contract:** Build280's ordered off-main Library presentation persistence fixes the proven Build278 pagination-persistence tail and remains intact in Build283.

**Not globally claimed:** this one pagination session does not prove every historical fixed-item/non-pagination poster-tail family is permanently absent.

## Navigation regression and Build283 repair

The missing detail entrance animation was independent of persistence threading and originated when Library `.items` moved to the native UICollectionView path in Build273.

Build280 had `nativePosterNavigationLink` only inside `if let item = nativePosterSelection`, while its `isActive` binding read `nativePosterSelection != nil`. The native collection tap first set selection; SwiftUI then mounted the link with the binding already true. Build283 keeps the same hidden link mounted so the existing binding transitions false→true after `onSelect` sets the same `nativePosterSelection` owner.

No direct `UINavigationController.pushViewController`, custom transition or second navigation state owner was added. Native iOS push/pop remains system-owned.

**Target-device result:** the user confirms entering detail is normal again. This accepts the reported push-entrance regression repair. Native interactive swipe-back was part of the prior regression checklist but has not been explicitly reported in the latest device result, so it remains an explicit PR closeout check rather than something inferred as passed.

## Build283 source / CI / IPA identity

Build283 retains the native UICollectionView, Build280 persistence, pagination, image policy and existing detail destination. Exact Build280→283 compare is exactly four paths:

1. `Sources/Core/AppIdentity.swift`
2. `Sources/UI/EmbyServerBrowseV3.swift`
3. `docs/changelog/CHANGELOG_v0_15_16_build283.md`
4. `scripts/check_poster_grid_offmain_persistence.py`

A transient `scripts/__pycache__/*.pyc` generated during materialization validation was caught by exact compare and removed before finalizing the product commit. Final Build283 is one clean commit directly atop Build280 and contains no workflow/materializer/pycache file.

CI / package evidence:

- exact product source: `39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6`
- Xcode 16.4 exact-source run/job: `33412757299 / 99556026814` — success
- artifact: `OnePlayer-0.15.16-build283-poster-navigation`, ID `9765884301`
- artifact digest / downloaded ZIP SHA-256: `555ba6cc5c2859fbc8ad8a20fd1784eaf520ff5e4c4d235b9f10c4273b8f24a0`
- IPA SHA-256: `472b543f679f5db3932195c2abad8d882e78610172ecbe703fc75947c44e5655`
- exact-source ZIP SHA-256: `c364da8ba7c7552feabb2b4375354f42472d7f88249fc77b29485ef9b3dbc40f`
- independently verified: `com.embyplayerlab.app`; OnePlayer `0.15.16 (283)`; `MinimumOSVersion=15.0`; runtime MinOS audit OK; `CADisableMinimumFrameDurationOnPhone=true`.

**Build283 evidence:** Code written ✅ / exact four-path scope+checker ✅ / CI passed ✅ / IPA produced+independently verified ✅ / detail-push real-device positive ✅ / pagination-persistence regression real-device positive ✅ / interactive-pop explicit recheck pending / universal poster stable claim ❌.

## Protected contracts

- Build280 off-main ordered Library persistence and Build213 cached-first/write-through semantics.
- Native iOS push/pop and interactive pop remain system-owned.
- Search Build256 accepted semantics.
- Accepted Build293 Home carousel (completed/frozen) and Build294 Dock; preserve their existing state/layout owners.
- Player / MPV / PiP / UnifiedTransport / Range/206 / playback Session Cache / Emby Resume/progress.
- STRM → HTTP 302 → 115/CDN client-direct path; NAS never relays media bytes.
- Deployment Target remains iOS 15.0.
- Never restore `targetTime / duration × fileSize`.
- No timer/debounce/throttle/watchdog/retry/fallback/interpolation or unrelated refactor.

### 2026-10-06 — Current poster entry inventory completed (source audit)

See [POSTER_ENTRY_INDEX.md](../../POSTER_ENTRY_INDEX.md), audited against main408ccc865262673ab708c01b13f20328aeff8066. The current V3 poster routes contain9 reachable EmbyPosterGrid call sites plus1 legacy V3EmbySearchView call site not referenced by the current root. Inventory adds the Library category-cover wall, recursive mixed folder/media walls, all four Favorite more variants, multiple filter/person entry paths, history/single-server direct search and multi-server more, and the recommendation grid itself. Horizontal Home/Library suggestions/Favorite/Search rows are registered separately. Detail similar/cast rows and episode/still viewers have explicit existing scope boundaries; no speculative Character API, collection-children wall or separate recommendation-more destination is asserted.

This is source reachability and design coverage only: all common-grid migrations and per-entry device checks are pending. No product source, Build, CI, IPA, frozen detail/carousel/Dock behavior or historical PR identity changed.

### 2026-10-06 — Executable implementation/handoff plan completed

User explicitly asks to review remaining gaps and prepare the existing task for a new implementation session. [POSTER_IMPLEMENTATION_PLAN.md](../../POSTER_IMPLEMENTATION_PLAN.md) now defines baseline/branch migration, real source owners, background metadata restoration ordering, image consumer/generation contracts, one vertical host including embedded Search recommendations, active-page status-bar scroll-to-top, native interaction/accessibility, global first-screen memory accounting, P0–P6 deliverables and stage gates, actual-source tests, per-entry device matrix, exact-source packaging and rollback.

Identity audit at maindf4c7bf3cd4b8de51f392e9af930d12c42c26219: PR#282 still Draft/open/unmerged with branch head39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6. Other current task Aether is Active; Search checkpoint is Completed. All new code phases and new performance device checks remain pending. No new product branch, version/Build allocation, merge, CI or IPA.

