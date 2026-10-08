# DEV-home-return-poster-retention

- **Status:** Active — exact source owner identified; Build306 reserved; implementation pending
- **Work ID:** `DEV-home-return-poster-retention`
- **Routing aliases / keywords:** `首页返回海报刷新` / `返回首页海报重载` / `Home海报闪空` / `home return poster retention`
- **Task:** 从首页进入详情页或 Library 页面再返回时，已经显示的 Home 海报图片必须原位保留，不得先被清空再重新采用；保留现有 Home 数据、滚动位置、系统导航和共享图片缓存所有权。

## Latest target-device evidence

- Target device: iPhone 15 Pro Max / iOS 17.0.
- User tested OnePlayer `0.15.38 / Build305` and reports the prior `DEV-meaningless-detail-routing` issue is fixed.
- In the same Build305 session, every Home → detail → back and Home → Library → back visibly makes the already-loaded Home poster artwork blank/reload. Screenshot shows poster/card text remains while artwork surfaces are dark/empty during return, which points to presentation-image teardown rather than a proven Home metadata reload.
- No new runtime log has yet been supplied for this issue.

## Baseline / dependency

- Exact runtime product source under test: Build305 `3476a3d9a8976ef483bb9d9e2317d0d2e442f8bb`.
- Parent accepted task branch: `feat/meaningless-detail-routing`; PR #293 is target-device accepted for its own Library Folder/media-only behavior but was still unmerged when this task branch was created.
- Working branch: `fix/home-return-poster-retention-build306`.
- This branch intentionally starts from the accepted Build305 task head so the next IPA preserves the just-accepted Library behavior. It must not be finalized against `main` until PR #293 is reconciled/merged; this stacked dependency is explicit rather than silent parallel overlap.
- Accepted overall baseline remains Build303 until the current integration sequence is completed.

## Build candidate

- Reserved candidate: OnePlayer `0.15.39 / Build306`.
- Collision check: repository/current project docs contain no existing `Build306` or `0.15.39` allocation; independent Aether remains Build235.
- Deployment Target remains iOS 15.0.

## Exact source diagnosis

Build305 source inspection identifies one concrete presentation-lifecycle owner:

1. `V3EmbyHomeView` keeps one `@StateObject V3EmbyHomeViewModel`. On return, `.onAppear` performs a full `model.refresh()` only when `hasLoaded == false`; otherwise it only calls `refreshResumeIfNeeded()`, which is a no-op unless an Emby user-data notification previously marked Resume dirty.
2. Home passes `isActive: isHomeActive && posterDetailItem == nil && posterLibrary == nil && !isCarouselDetailPresented` into `EmbyPosterSections`. Selecting either a detail or Library therefore marks the existing Home poster host inactive before/during push.
3. `EmbyPosterSectionsController` currently handles page-level inactivity / `viewWillDisappear` by calling `EmbyPosterHorizontalRow.deactivate()` for every visible row.
4. `EmbyPosterHorizontalRow.deactivate()` cancels prefetch and then calls `prepareForReuse()` on **every visible child poster cell**.
5. `EmbyPosterCell.prepareForReuse()` and `EmbyPosterWideCell.prepareForReuse()` clear the cell's bound record/card and set `artwork.image = nil`.
6. Returning to Home reactivates/reconfigures those cells and images are adopted again from preparation/render/disk/network ownership. This exactly explains the visible blank/reload cycle while text/metadata ownership remains resident.

This is not evidence of a full Home metadata query refresh. The proven defect is that a **temporary page suspension is incorrectly using the destructive cell-reuse path**.

## Build305 attribution check

- Compare accepted Build303 source `0b5ce25bcec0a4d0240891913ad17114b02cf10e` → Build305 exact product `3476a3d9a8976ef483bb9d9e2317d0d2e442f8bb` does not include `EmbyPosterSections.swift`, `EmbyHomeCoreV3.swift`, `EmbyHomeModelV3.swift`, or shared image-preparation files among product changes.
- Therefore there is no evidence that Build305's Library media-only correction introduced this Home presentation behavior; the user has newly exposed an existing shared poster suspension defect.

## Frozen-scope reopening justification

- `Poster 3-column / poster-heavy scroll smoothness` is completed/stable-frozen at Build303, and native navigation is a frozen principle.
- New target-device evidence explicitly reopens only the shared poster **temporary suspension** behavior because it visibly destroys already-present Home artwork on system-owned push/pop.
- The accepted Build303 geometry, pagination, scroll cadence, image request owner, navigation ownership and Home carousel remain protected.
- No change is justified in Home carousel runtime, Home model loading, NavigationLink ownership, image cache architecture, Player/Transport/Cache/Emby Session or P0 playback.

## Proposed minimal correction

- Keep `EmbyPosterHorizontalRow.deactivate()` as the destructive path for true row removal/reuse/query replacement.
- Add a page-level suspension path that:
  - marks the row inactive;
  - cancels its visible image subscriptions and prefetch demand;
  - saves the horizontal offset as today;
  - **does not call `prepareForReuse()` and does not clear the currently displayed UIImage / bound record/card**.
- Use that non-destructive suspension only when the whole poster page becomes inactive/disappears and in controller inactive configuration.
- True child-cell `didEndDisplaying`, row `didEndDisplaying`, row reuse and query replacement continue using the existing destructive reuse semantics.
- No second image cache, duplicate state, timer, retry, fallback, watchdog or speculative lifetime owner.

## Files / modules in scope

- `Sources/UI/EmbyPosterSections.swift` — shared page-vs-reuse presentation lifecycle only.
- `Tests/PosterWallRegression/SectionTests.swift` — regression proving temporary page inactive/disappear retains already displayed poster + wide artwork while real reuse still clears.
- `Sources/Core/AppIdentity.swift` — Build306 identity.
- Narrow regression guard / CI workflow only if needed for exact-source validation.
- Changelog + this checkpoint + required durable project docs.

## State ownership / contracts

- Home metadata remains owned by `V3EmbyHomeViewModel`.
- Native system `NavigationView` / `NavigationLink` continues to own push/pop; no custom transition state.
- Image preparation/cache remains `EmbyImagePreparation` + `EmbyDecodedImageRenderPool` + disk cache; retained visible UIImage is only the existing cell presentation object, not a new cache.
- Row/card identity and scroll offsets stay in existing `EmbyPosterSectionsController` / `EmbyPosterHorizontalRow` owners.
- True reuse continues to clear images exactly as before.

## Parallel conflict check

- `DEV-aether-multi-engine-comparison` is Active but isolated to Player/Aether/Transport and does not touch these UI files/state owners.
- `DEV-search-page-optimization` is Completed/merged. Search uses shared poster presentation in some routes, so Build306 tests must retain existing shared-section behavior and must not change Search data semantics.
- `DEV-meaningless-detail-routing` is completed behaviorally but PR #293 is not yet merged; Build306 is explicitly stacked on that accepted source until #293 is merged.

## Validation state

- Code written: pending.
- Narrow regression: pending.
- CI passed: pending.
- IPA produced: pending.
- Real-device tested: current Build305 reproduces the issue; Build306 pending.
- Stable/frozen: no.

## Next exact action

1. Implement only the page-level non-destructive suspension path in `EmbyPosterSections.swift`.
2. Add direct poster + wide-cell retention regression and retain true-reuse-clears-image assertions.
3. Update AppIdentity to `0.15.39`, inspect exact diff and run narrow local/source tests.
4. Reconcile/merge accepted PR #293 before final Build306 CI so the final candidate has a clean dependency baseline.
5. Run exact-source Release regression/CI, package and independently verify Build306 IPA/MinOS 15.0.
6. Target-device acceptance: Home → detail → back and Home → Library → back must keep currently shown poster artwork resident with no blank/reload sweep; Home position/text/data and normal image updates must remain correct.

## Rejected / do-not-repeat

- Do not force a Home refresh or add a delay to hide the blanking.
- Do not add a second image cache or retain an unbounded poster wall outside existing cells.
- Do not disable cell reuse for genuinely offscreen rows.
- Do not modify Home carousel/native navigation to solve a shared poster-row suspension bug.
- Do not claim Build305 introduced this defect without contrary runtime/source evidence.
