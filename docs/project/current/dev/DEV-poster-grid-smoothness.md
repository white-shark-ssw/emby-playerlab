# DEV-poster-grid-smoothness

## Status

**Active — Build280 target-device pagination A/B is positive and the user has now also completed the force-quit/relaunch cached-first regression check without observing a problem. A separate small navigation regression was then reported: tapping a Library `.items` cover enters detail without the normal system push entrance animation. Exact source inspection localizes this regression to the Build273 native UICollectionView path: `nativePosterNavigationLink` was conditionally created only after `nativePosterSelection` became non-nil, so its `isActive` binding was already true on first mount. Build283 / OnePlayer 0.15.16 is the narrow repair: keep the hidden NavigationLink mounted and let the existing selection binding transition false→true. No custom push or second navigation owner is added. Exact product source `39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6` is directly parented by Build280 `531d7f53c55e1e3cff44069e9bce3193ac94749a`; exact Build280→283 scope is four paths. Code/checker scope is complete; Xcode/IPA and target-device animation confirmation remain pending.**

- **Work ID:** `DEV-poster-grid-smoothness`
- **Routing aliases / keywords:** 首页流畅度 / 3×3页面流畅度 / 3列海报流畅度 / 库页流畅度 / 海报网格优化 / poster grid smoothness
- **Working branch:** `perf/poster-grid-offmain-persistence-build280`
- **Draft PR:** #282
- **Current exact product source:** `39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6`
- **Direct parent:** Build280 exact source `531d7f53c55e1e3cff44069e9bce3193ac94749a`
- **Current candidate:** OnePlayer **0.15.16 / Build283**
- **Target device:** iPhone 15 Pro Max / iOS 17.0
- **Deployment Target:** iOS 15.0
- **Build identity guard:** Build282 / 0.15.15 is occupied by the parallel Home task; Build283 / 0.15.16 was free when allocated to Poster.

## Build280 accepted evidence within this task

Build278 proved synchronous full-Library persistence caused the pagination-adjacent severe-frame family: snapshot totals 38.31→94.66 ms paired with 49.96→108.33 ms display gaps at correlation ≈0.991.

Build280 moved only full Library snapshot object construction, JSON serialization and atomic write onto one serial `.utility` queue while the MainActor model awaits ordered completion. Target-device log `OnePlayer-App-1788190813.log` shows every persistence record at `main_thread=0`; clean 60→775 pagination no longer reproduces the Build278 50–100 ms persistence-correlated family even though snapshot work grows as high as 267.76 ms. The user likewise reported no large twitch during that test.

The user then force-quit/relaunched Build280 and reported cached-first Library behavior appeared normal. The follow-up log `OnePlayer-App-1788191685.log` confirms a fresh app launch at OnePlayer 0.15.13 and continued ordered `main_thread=0` accepted-state writes; it does not itself contain a dedicated cache-load timing marker, so the cached-first acceptance is the user's target-device observation rather than a log-derived timing claim.

**Build280 evidence:** Code written ✅ / exact scope+checker ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device pagination A/B positive ✅ / cached-first force-quit/relaunch user check positive ✅ / universal 3×3 stable claim ❌.

## Navigation regression root cause

The regression is independent of Build280 persistence threading and originated when Library `.items` moved to the native UICollectionView path in Build273.

Build280 exact source had:

- `@State private var nativePosterSelection: LibraryItem?`;
- native collection `onSelect` sets that selection;
- `nativePosterNavigationLink` existed only inside `if let item = nativePosterSelection`;
- the link's `isActive` binding reads `nativePosterSelection != nil`.

Therefore the link was absent before the tap and first mounted only after the binding was already true. This differs from the earlier/system-owned NavigationLink pattern where a mounted link transitions inactive→active, and directly matches the user's “direct entry, no entrance animation” report.

Do not solve this by calling `UINavigationController.pushViewController`, installing a custom transition, or adding a second navigation state owner. Native iOS push/pop and interactive pop remain system-owned.

## Build283 implementation checkpoint

Build283 keeps the native UICollectionView, Build280 off-main persistence, pagination, image/loading policy and detail destination unchanged. The only runtime navigation change is:

- keep `nativePosterNavigationLink` mounted at all times;
- its destination uses the existing `nativePosterSelection` when present;
- the same binding transitions false→true after `onSelect` sets selection;
- clearing `isActive` still clears `nativePosterSelection`.

Exact Build280→283 compare contains only:

1. `Sources/Core/AppIdentity.swift`
2. `Sources/UI/EmbyServerBrowseV3.swift`
3. `docs/changelog/CHANGELOG_v0_15_16_build283.md`
4. `scripts/check_poster_grid_offmain_persistence.py`

The dedicated checker retains all Build280 off-main persistence assertions and adds the navigation regression guard. Materialization checker passed before the exact product tree was finalized. A transient `__pycache__` artifact generated by `py_compile` was detected during exact compare and removed; the final exact product commit is directly parented by Build280 and contains no workflow/materializer/pycache files.

**Build283 evidence now:** Code written ✅ / exact four-path scope ✅ / navigation + Build280 persistence checker ✅ / CI pending / IPA pending / target-device animation test pending / stable ❌.

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

Run exact-source Xcode 16.4 Release CI for `39014a03e2681aed3647bdd6d7d7b1c82b8cc4f6`, verify package identity `0.15.16 (283)` / MinOS 15.0 and produce an independently checked IPA. Then target-device check only the regression surface: Library `.items` cover tap should restore the normal system push entrance animation and native interactive swipe-back; spot-check pagination to ensure Build280's large-twitch fix remains intact. Do not merge or call the navigation regression fixed until that device result is supplied.
