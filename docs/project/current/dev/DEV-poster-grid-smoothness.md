# DEV-poster-grid-smoothness

## Status

**Active — Build280 target-device pagination A/B is positive and the user has also completed the force-quit/relaunch cached-first regression check without observing a problem. A separate navigation regression was then reported: tapping a Library `.items` cover enters detail without the normal system push entrance animation. Exact source inspection localizes this to the Build273 native UICollectionView path, where `nativePosterNavigationLink` was conditionally created only after `nativePosterSelection` became non-nil, so its `isActive` binding was already true on first mount. Build283 / OnePlayer 0.15.16 is the narrow repair: keep that hidden NavigationLink mounted and let the existing selection binding transition false→true. No custom push or second navigation owner is added. Exact source `39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6` is directly parented by Build280 `531d7f53c55e1e3cff44069e9bce3193ac94749a`; exact Build280→283 scope is four paths. Xcode 16.4 Release CI and independently rechecked IPA/source archives are complete. Target-device push-animation confirmation remains the only gate; stable remains false.**

- **Work ID:** `DEV-poster-grid-smoothness`
- **Routing aliases / keywords:** 首页流畅度 / 3×3页面流畅度 / 3列海报流畅度 / 库页流畅度 / 海报网格优化 / poster grid smoothness
- **Working branch:** `perf/poster-grid-offmain-persistence-build280`
- **Draft PR:** #282
- **Current exact product source:** `39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6`
- **Direct parent:** Build280 `531d7f53c55e1e3cff44069e9bce3193ac94749a`
- **Current candidate:** OnePlayer **0.15.16 / Build283**
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment Target / built MinOS:** iOS 15.0
- **Build identity guard:** Build282 / 0.15.15 is occupied by the parallel Home task; Build283 / 0.15.16 was free when allocated to Poster.

## Build280 accepted evidence within this task

Build278 proved synchronous full-Library persistence caused the pagination-adjacent severe-frame family: snapshot totals 38.31→94.66 ms paired with 49.96→108.33 ms display gaps, correlation ≈0.991.

Build280 moved only full Library snapshot object construction, JSON serialization and atomic write onto one serial `.utility` queue while the MainActor model awaits ordered completion. Target-device log `OnePlayer-App-1788190813.log` shows every persistence record at `main_thread=0`; clean 60→775 pagination no longer reproduces the Build278 50–100 ms persistence-correlated family even though snapshot work grows to 267.76 ms. The user likewise reported no large twitch.

The user then force-quit/relaunched Build280 and reported cached-first Library behavior appeared normal. Follow-up log `OnePlayer-App-1788191685.log` records a fresh app launch at `2026-08-31T15:54:26.621Z`, OnePlayer 0.15.13, and continued ordered `main_thread=0` accepted-state writes. The log has no dedicated cache-load timing marker, so cached-first acceptance is the user's target-device observation. After that fresh launch only two >=25 ms Library display gaps appear (86.94 / 81.65 ms); both have `insert_events=0`, one overlaps a 0.05 ms visible reconfigure, so this does not restore the Build278 pagination-persistence chain.

**Build280 evidence:** Code written ✅ / scope+checker ✅ / CI ✅ / IPA ✅ / target-device pagination A/B positive ✅ / cached-first force-quit/relaunch positive ✅ / universal 3×3 stable claim ❌.

## Navigation regression root cause

The regression is independent of Build280 persistence threading and originated when Library `.items` moved to the native UICollectionView path in Build273.

Build280 source had `nativePosterNavigationLink` only inside `if let item = nativePosterSelection`, while the link's `isActive` binding read `nativePosterSelection != nil`. The native collection tap first sets the selection; SwiftUI then creates the link with the binding already true. That differs from the normal system-owned NavigationLink lifecycle where an already-mounted link transitions inactive→active, and directly matches the user's “direct entry, no entrance animation” report.

Do not solve this with `UINavigationController.pushViewController`, a custom transition, or a second navigation state owner. Native iOS push/pop and interactive pop remain system-owned.

## Build283 implementation / CI / IPA

Build283 retains the native UICollectionView, Build280 persistence, pagination, image policy and existing detail destination. Only the navigation activation lifecycle changes:

- `nativePosterNavigationLink` remains mounted;
- destination derives from the existing `nativePosterSelection`;
- `onSelect` still owns selection;
- the same `isActive` binding now transitions false→true;
- deactivation still clears the selection.

Exact Build280→283 compare is exactly four paths:

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
- independently verified: both ZIP archives pass integrity checks; `com.embyplayerlab.app`; OnePlayer `0.15.16 (283)`; `MinimumOSVersion=15.0`; runtime MinOS audit OK; `CADisableMinimumFrameDurationOnPhone=true`.

**Build283 evidence:** Code written ✅ / exact four-path scope+checker ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device animation pending / stable ❌.

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

Install Build283 on the target device. From Library `.items`, tap several covers and confirm the normal system push entrance animation is restored; then verify native interactive swipe-back still works. Spot-check one Library pagination pass to ensure Build280's large-twitch improvement remains. Do not merge or call the navigation regression fixed until that target-device result is supplied.
