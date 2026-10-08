# DEV-home-return-poster-retention

- **Status:** Active — minimal lifecycle fix written; Build306 exact-source CI/IPA pending
- **Work ID:** `DEV-home-return-poster-retention`
- **Routing aliases / keywords:** `首页返回海报刷新` / `返回首页海报重载` / `Home海报闪空` / `home return poster retention`
- **Task:** 从首页进入详情页或 Library 页面再返回时，已经显示的 Home 海报图片必须原位保留，不得先被清空再重新采用；保留现有 Home 数据、滚动位置、系统导航和共享图片缓存所有权。

## Latest target-device evidence

- Target device: iPhone 15 Pro Max / iOS 17.0.
- User tested OnePlayer `0.15.38 / Build305` and explicitly confirmed the prior `DEV-meaningless-detail-routing` issue is fixed.
- In the same Build305 session, every Home → detail → back and Home → Library → back visibly makes already-loaded Home poster artwork blank/reload. Screenshot shows poster/card text remains while artwork surfaces are dark/empty during return, which points to presentation-image teardown rather than a proven Home metadata reload.
- No new runtime log has yet been supplied for this issue; the source lifecycle is sufficiently deterministic to identify the destructive presentation path without inventing a metadata/network refresh.

## Baseline / dependency

- Exact runtime product source under test when the issue was reported: Build305 `3476a3d9a8976ef483bb9d9e2317d0d2e442f8bb`.
- `DEV-meaningless-detail-routing` is now target-device accepted and PR #293 merged at `91b705ca3b62064957169ea8bd2dff71ccc1e180`.
- Durable Build305 project state was closed out on `main` at `1593a548bfcdd9cc9e44938eb7738dfbcd5c447a`.
- Working branch: `fix/home-return-poster-retention-build306`.
- The Build306 branch has been reconciled with that accepted `main`; current branch diff versus `main` is restricted to AppIdentity, shared poster lifecycle, one regression test file and this task documentation/changelog.
- Accepted overall baseline remains Build303 until the Home-return regression is independently built and target-device validated.

## Build candidate

- Reserved candidate: OnePlayer `0.15.39 / Build306`.
- Collision check: repository/current project docs contain no existing `Build306` or `0.15.39` allocation; independent Aether remains Build235.
- Deployment Target remains iOS 15.0.
- Implementation commit: `96c9aa30b3a766011a8b10a207cdf370da3194e3` (`fix: retain Home poster artwork across navigation`).
- Reconciled branch head before candidate docs: `e27e3221fc176a623a4c9d96d7ab65ba24e74efc`.

## Exact source diagnosis

Build305 source inspection identifies one concrete presentation-lifecycle owner:

1. `V3EmbyHomeView` keeps one `@StateObject V3EmbyHomeViewModel`. On return, `.onAppear` performs a full `model.refresh()` only when `hasLoaded == false`; otherwise it only calls `refreshResumeIfNeeded()`, which is a no-op unless an Emby user-data notification previously marked Resume dirty.
2. Home passes `isActive: isHomeActive && posterDetailItem == nil && posterLibrary == nil && !isCarouselDetailPresented` into `EmbyPosterSections`. Selecting either a detail or Library therefore marks the existing Home poster host inactive before/during push.
3. `EmbyPosterSectionsController` handled page-level inactivity / `viewWillDisappear` by calling `EmbyPosterHorizontalRow.deactivate()` for every visible row.
4. `EmbyPosterHorizontalRow.deactivate()` cancelled prefetch and then called `prepareForReuse()` on **every visible child poster cell**.
5. `EmbyPosterCell.prepareForReuse()` and `EmbyPosterWideCell.prepareForReuse()` clear the cell's bound record/card and set `artwork.image = nil`.
6. Returning to Home reactivates/reconfigures those cells and images are adopted again from preparation/render/disk/network ownership. This exactly explains the visible blank/reload cycle while text/metadata ownership remains resident.

This is not evidence of a full Home metadata query refresh. The proven defect is that a **temporary page suspension was incorrectly using the destructive cell-reuse path**.

## Build305 attribution check

- Compare accepted Build303 source `0b5ce25bcec0a4d0240891913ad17114b02cf10e` → Build305 exact product `3476a3d9a8976ef483bb9d9e2317d0d2e442f8bb` does not include `EmbyPosterSections.swift`, `EmbyHomeCoreV3.swift`, `EmbyHomeModelV3.swift`, or shared image-preparation files among product changes.
- Therefore there is no evidence that Build305's Library media-only correction introduced this Home presentation behavior; the user newly exposed an existing shared poster suspension defect.

## Frozen-scope reopening justification

- `Poster 3-column / poster-heavy scroll smoothness` is completed/stable-frozen at Build303, and native navigation is a frozen principle.
- New target-device evidence explicitly reopens only the shared poster **temporary suspension** behavior because it visibly destroys already-present Home artwork on system-owned push/pop.
- Accepted Build303 geometry, pagination, scroll cadence, image request owner, navigation ownership and Home carousel remain protected.
- No change is justified in Home carousel runtime, Home model loading, NavigationLink ownership, image cache architecture, Player/Transport/Cache/Emby Session or P0 playback.

## Implemented minimal correction

- `EmbyPosterHorizontalRow.deactivate()` remains the destructive path for true row removal/reuse/query replacement.
- Added `EmbyPosterHorizontalRow.suspend()` for page-level temporary inactivity. It:
  - marks the row inactive;
  - cancels row prefetch and visible cell image subscriptions using each cell's existing `deactivate()`;
  - saves horizontal offset exactly as before;
  - **does not call `prepareForReuse()` and does not clear the currently displayed UIImage / bound record/card**.
- `EmbyPosterSectionsController.viewWillDisappear`, inactive row configuration, and inactive resource activation now call `suspend()` instead of destructive `deactivate()`.
- True child-cell `didEndDisplaying`, row `didEndDisplaying`, row reuse and query replacement retain existing destructive reuse semantics.
- No second image cache, duplicate state, timer, retry, fallback, watchdog or speculative lifetime owner was added.
- App identity advances to `0.15.39`; packaging will use Build306.

## Regression added

`Tests/PosterWallRegression/SectionTests.swift` adds `testPageSuspensionRetainsVisibleArtworkButRealDeactivationClearsIt` across poster / landscape / library styles:

- seed the existing decoded render pool with a concrete UIImage;
- configure a real horizontal poster row/cell;
- verify the image is displayed;
- temporary `suspend()` must keep the same UIImage;
- `activate()` must keep it resident;
- true `deactivate()` must still clear it.

This directly guards the new lifecycle distinction without changing data/query/navigation semantics.

## Files / modules in scope

- `Sources/UI/EmbyPosterSections.swift` — shared page-vs-reuse presentation lifecycle only.
- `Tests/PosterWallRegression/SectionTests.swift` — temporary suspension retention vs real reuse release regression.
- `Sources/Core/AppIdentity.swift` — Build306 identity.
- `docs/changelog/CHANGELOG_v0_15_39_build306.md` and this checkpoint.
- Narrow exact-source CI control only; no product workflow/runtime abstraction.

## State ownership / contracts

- Home metadata remains owned by `V3EmbyHomeViewModel`.
- Native system `NavigationView` / `NavigationLink` continues to own push/pop; no custom transition state.
- Image preparation/cache remains `EmbyImagePreparation` + `EmbyDecodedImageRenderPool` + disk cache; retained visible UIImage is only the existing cell presentation object, not a new cache.
- Row/card identity and scroll offsets stay in existing `EmbyPosterSectionsController` / `EmbyPosterHorizontalRow` owners.
- True reuse continues to clear images exactly as before.

## Parallel conflict check

- `DEV-aether-multi-engine-comparison` is Active but isolated to Player/Aether/Transport and does not touch these UI files/state owners.
- `DEV-search-page-optimization` is Completed/merged. Search uses shared poster presentation in some routes, so Build306 tests must retain existing shared-section behavior and must not change Search data semantics.
- `DEV-meaningless-detail-routing` is completed, target-device accepted and merged; Build306 now sits cleanly on the accepted main state.

## Validation state

- Code written: ✅.
- Exact diff against latest main inspected: ✅ — runtime/product changes restricted to `Sources/Core/AppIdentity.swift`, `Sources/UI/EmbyPosterSections.swift`, and the regression test file.
- Narrow regression: added; execution pending dedicated CI.
- CI passed: pending.
- IPA produced: pending.
- Real-device tested: Build305 reproduces the issue; Build306 pending.
- Stable/frozen: no.

## Next exact action

1. Freeze an exact Build306 product SHA after this checkpoint/changelog.
2. Open the Build306 PR against current `main`.
3. Run dedicated exact-source PosterWall regression + Release CI; fix only evidence-backed failures.
4. Package and independently verify Build306 IPA, bundle/version/build and MinOS 15.0.
5. Update this checkpoint / changelog / `BUILD_TEST_INDEX.md` with the valid CI/IPA baseline.
6. Target-device acceptance: Home → detail → back and Home → Library → back must keep currently shown poster artwork resident with no blank/reload sweep; Home position/text/data and normal image updates must remain correct.

## Rejected / do-not-repeat

- Do not force a Home refresh or add a delay to hide the blanking.
- Do not add a second image cache or retain an unbounded poster wall outside existing cells.
- Do not disable cell reuse for genuinely offscreen rows.
- Do not modify Home carousel/native navigation to solve a shared poster-row suspension bug.
- Do not claim Build305 introduced this defect without contrary runtime/source evidence.
