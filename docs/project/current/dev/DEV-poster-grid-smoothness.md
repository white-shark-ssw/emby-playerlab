# DEV-poster-grid-smoothness

## Status and current identity — 2026-10-06

- **Active — P0/P1/P2 code complete; Release/IPA independently verified; awaiting target-device P2 acceptance.**
- User explicitly requested development through a testable Library.items IPA. Read [POSTER_IMPLEMENTATION_PLAN.md](../../POSTER_IMPLEMENTATION_PLAN.md), [POSTER_PRESENTATION_DESIGN.md](../../POSTER_PRESENTATION_DESIGN.md), [POSTER_ENTRY_INDEX.md](../../POSTER_ENTRY_INDEX.md).
- Working branch: `perf/poster-wall-library-build295`; Draft PR [#292](https://github.com/white-shark-ssw/emby-playerlab/pull/292), base main.
- Exact package source: **8ca3de65a8ca2927785bb194b6a3136b6d900e56**. Base: **03d1bad260666c3f38ae3913d6828f393690673e**, accepted overall Build294 Dock / Build293 carousel.
- Candidate: **OnePlayer0.15.28 / Build295 / poster-wall-library / iOS15.0**. Target: iPhone15ProMax / iOS17.0.
- CI control: `ci/build295-poster-wall-library-20261006`, **38689808411cee237bbf56f85d14619b2e07446f**, workflow `.github/workflows/build295-poster-wall-library.yml`, run **37477868307 / job112317946251**. Control source is not package source.
- Historical PR282 / branch `perf/poster-grid-offmain-persistence-build280` / Build283 source39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6 stays untouched/open/unmerged. Extracted ordered Library persistence and persistent navigation activation; no whole-stack merge.
- Aether235 remains separate; Search completed256, carousel293 and Dock294 frozen.

## Completed and validation

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

## Next exact action

Install the unsigned Build295 candidate using the existing signing workflow and perform the P2 target-device matrix above on iPhone15ProMax/iOS17.0 against accepted Build294. Record actual Build/cache/thermal state, frame p50/p95/p99/max and >=16.7/25/33.3ms counts plus memory. Return device log/visual evidence; locate any reproducible regression before G02–G15/Home rollout. No further implementation is blocked on routine approval, but P3–P6 stage gate requires P2 device evidence. Keep task Active/Draft and accepted baseline294; do not mark120FPS/stable or merge historical PR282.

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

