# DEV-poster-grid-smoothness

## Status

**Active — Build283 / OnePlayer 0.15.16 is now target-device positive for both intended regression surfaces. The user confirms Library `.items` cover entry to detail has the normal system entrance animation again, accepting the always-mounted hidden `NavigationLink` repair. The accompanying `OnePlayer-App-1788197938.log` also confirms Build280's off-main pagination fix survives unchanged: one continuous 60→660 native Library session runs at 118.34 Hz with p50/p95/p99 8.33/8.70/17.85 ms, max 25.02 ms, exactly one >=25 ms frame and zero >=33.3 ms frames while all persistence remains `main_thread=0` and snapshot total grows to 208.87 ms. The user reports no visible twitch. No additional code change is justified from this log. The broader historical fixed-item/non-pagination poster tail is not globally frozen by this single pagination session, and native interactive swipe-back has not been explicitly rechecked in the latest device report.**

- **Work ID:** `DEV-poster-grid-smoothness`
- **Routing aliases / keywords:** 首页流畅度 / 3×3页面流畅度 / 3列海报流畅度 / 库页流畅度 / 海报网格优化 / poster grid smoothness
- **Working branch:** `perf/poster-grid-offmain-persistence-build280`
- **Draft PR:** #282
- **Current exact product source:** `39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6`
- **Direct parent:** Build280 `531d7f53c55e1e3cff44069e9bce3193ac94749a`
- **Current candidate:** OnePlayer **0.15.16 / Build283**
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment Target / built MinOS:** iOS 15.0
- **Build identity guard:** Build282 / 0.15.15 is occupied by the parallel Home task; Build283 / 0.15.16 is Poster.

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
- Home carousel independent task/branch/candidate.
- Player / MPV / PiP / UnifiedTransport / Range/206 / playback Session Cache / Emby Resume/progress.
- STRM → HTTP 302 → 115/CDN client-direct path; NAS never relays media bytes.
- Deployment Target remains iOS 15.0.
- Never restore `targetTime / duration × fileSize`.
- No timer/debounce/throttle/watchdog/retry/fallback/interpolation or unrelated refactor.

## Next exact action

**No product-code change is justified from the current log.** Leave the accepted pagination-persistence and detail-push repair unchanged. If PR #282 is to leave Draft/merge, explicitly spot-check native interactive edge swipe-back once because that previously stated gate has not been reported in the latest device result. If a distinct visible poster hitch reappears later, capture that exact fixed-item/non-pagination session and resume from its evidence rather than reopening persistence, pagination or scroll physics speculatively.
