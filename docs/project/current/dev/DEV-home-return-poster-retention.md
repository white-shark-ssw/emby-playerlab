# DEV-home-return-poster-retention

- **Status:** Active — Build306 CI/IPA verified; target-device validation pending
- **Work ID:** `DEV-home-return-poster-retention`
- **Routing aliases / keywords:** `首页返回海报刷新` / `返回首页海报重载` / `Home海报闪空` / `home return poster retention`
- **Task:** 从首页进入详情页或 Library 页面再返回时，已经显示的 Home 海报图片必须原位保留，不得先被清空再重新采用；保留现有 Home 数据、滚动位置、系统导航和共享图片缓存所有权。

## Latest target-device evidence

- Target device: iPhone 15 Pro Max / iOS 17.0.
- User tested OnePlayer `0.15.38 / Build305` and explicitly confirmed the prior `DEV-meaningless-detail-routing` issue is fixed.
- In the same Build305 session, every Home → detail → back and Home → Library → back visibly makes already-loaded Home poster artwork blank/reload. Screenshot shows poster/card text remains while artwork surfaces are dark/empty during return, which points to presentation-image teardown rather than a proven Home metadata reload.
- Build306 has not yet been target-device tested. Do not describe this regression as solved on device until the user confirms both return paths.

## Baseline / dependency

- Exact runtime product source under test when the issue was reported: Build305 `3476a3d9a8976ef483bb9d9e2317d0d2e442f8bb`.
- `DEV-meaningless-detail-routing` is target-device accepted and PR #293 merged at `91b705ca3b62064957169ea8bd2dff71ccc1e180`.
- Durable Build305 project state was closed out on `main` at `1593a548bfcdd9cc9e44938eb7738dfbcd5c447a`.
- Working branch: `fix/home-return-poster-retention-build306`.
- Accepted overall baseline remains Build303 until the Home-return regression is independently target-device validated.

## Build306 verified candidate

- Product: OnePlayer `0.15.39 / Build306`.
- Exact tested product source: `20dac5ce21e7d3261794dc62827b90fa07b048fb`.
- Implementation commit: `96c9aa30b3a766011a8b10a207cdf370da3194e3`.
- PR: `#294`, open / unmerged.
- Dedicated CI control branch: `ci/build306-home-return-poster-retention-20261009`.
- CI run/job: `37839047724 / 113523454935` — success.
- Actual-source PosterWall regression: **54 tests / 0 failures**.
- Release generic-iOS build: success on Xcode 16.4.
- Artifact: `OnePlayer-0.15.39-build306-home-return-poster-retention`, ID `11577437579`, digest `sha256:dce68eb07b7f8dc469051e68fdae3eb33b28e6e4cd835739b9404034a92fa8cc`.
- IPA: `OnePlayer-0.15.39-build306-home-return-poster-retention-unsigned.ipa`, SHA-256 `414dac7cfb8026bd42219251b6f700d53733bb6680540d4b1b58e822368f2b15`.
- Source ZIP SHA-256: `443c44566e0e3a33bdcbec8e4a4a9b4ba2a5437d51238f3d304fd28dc7189111`; archive comment equals exact product source `20dac5ce21e7d3261794dc62827b90fa07b048fb`.
- Bundle identity: `com.embyplayerlab.app`, `0.15.39 / 306`, display name `OnePlayer`.
- Info.plist MinOS `15.0`; CI embedded runtime Mach-O minimum-OS audit passed.
- Downloaded artifact ZIP digest, packaged IPA/source checksums and ZIP integrity were independently reverified after CI.

## Exact source diagnosis

Build305 source inspection identifies one concrete presentation-lifecycle owner:

1. `V3EmbyHomeView` keeps one `@StateObject V3EmbyHomeViewModel`. On return, `.onAppear` performs a full `model.refresh()` only when `hasLoaded == false`; otherwise it only calls `refreshResumeIfNeeded()`, which is a no-op unless an Emby user-data notification previously marked Resume dirty.
2. Home passes `isActive: isHomeActive && posterDetailItem == nil && posterLibrary == nil && !isCarouselDetailPresented` into `EmbyPosterSections`. Selecting either a detail or Library therefore marks the existing Home poster host inactive before/during push.
3. `EmbyPosterSectionsController` handled page-level inactivity / `viewWillDisappear` by calling `EmbyPosterHorizontalRow.deactivate()` for every visible row.
4. `EmbyPosterHorizontalRow.deactivate()` cancelled prefetch and then called `prepareForReuse()` on **every visible child poster cell**.
5. `EmbyPosterCell.prepareForReuse()` and `EmbyPosterWideCell.prepareForReuse()` clear the cell's bound record/card and set `artwork.image = nil`.
6. Returning to Home reactivates/reconfigures those cells and images are adopted again from the existing preparation/render/disk/network owner. This explains the visible blank/reload cycle while text/metadata ownership remains resident.

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
- `EmbyPosterSectionsController.viewWillDisappear`, inactive row configuration, and inactive resource state now call `suspend()` instead of destructive `deactivate()`.
- True child-cell `didEndDisplaying`, row `didEndDisplaying`, row reuse, changed-query replacement and real cell reuse retain existing destructive semantics.
- No second image cache, duplicate state, timer, retry, fallback, watchdog or speculative lifetime owner was added.

## Regression coverage

`Tests/PosterWallRegression/SectionTests.swift` adds `testPageSuspensionRetainsVisibleArtworkButRealDeactivationClearsIt` across poster / landscape / library styles:

- seed the existing decoded render pool with a concrete UIImage;
- configure a real horizontal poster row/cell;
- verify the image is displayed;
- temporary `suspend()` must keep the same UIImage;
- `activate()` must keep it resident;
- true `deactivate()` must still clear it.

The full actual-source PosterWall regression now executes **54 tests / 0 failures** in the dedicated Build306 CI.

## Files / modules in scope

- `Sources/UI/EmbyPosterSections.swift` — shared page-vs-reuse presentation lifecycle only.
- `Tests/PosterWallRegression/SectionTests.swift` — temporary suspension retention vs real reuse release regression.
- `Sources/Core/AppIdentity.swift` — Build306 identity.
- `docs/changelog/CHANGELOG_v0_15_39_build306.md` and this checkpoint.
- Dedicated exact-source CI control only.

## State ownership / protected contracts

- Home metadata remains owned by `V3EmbyHomeViewModel`.
- Native system `NavigationView` / `NavigationLink` continues to own push/pop; no custom transition state.
- Image preparation/cache remains `EmbyImagePreparation` + `EmbyDecodedImageRenderPool` + disk cache; retained visible UIImage is only the existing cell presentation object, not a new cache.
- Row/card identity and scroll offsets stay in existing `EmbyPosterSectionsController` / `EmbyPosterHorizontalRow` owners.
- True reuse continues to clear images exactly as before.
- No Player/MPV/PiP, UnifiedTransport, playback Session Cache, Emby Session, STRM→302→115/CDN, Home carousel or Deployment Target contract changes.

## Validation state

- Code written: ✅.
- Exact-source guard / diff inspection: ✅.
- Poster regression: **54 / 0** ✅.
- CI passed: ✅.
- IPA produced + independently verified: ✅.
- Real-device tested on Build306: ❌ pending.
- Stable/frozen: ❌ pending target-device acceptance.

## Next exact action

1. Deliver the independently verified Build306 IPA to the user.
2. Target-device acceptance must cover both:
   - Home → detail → back;
   - Home → Library → back.
3. In both cases already-present Home artwork must stay resident with no black/blank reload sweep; Home text, position, navigation and normal later image updates must remain correct.
4. Only after target-device acceptance update durable project state and merge PR #294. Do not merge on CI/IPA evidence alone.

## Rejected / do-not-repeat

- Do not force a Home refresh or add a delay to hide the blanking.
- Do not add a second image cache or retain an unbounded poster wall outside existing cells.
- Do not disable cell reuse for genuinely offscreen rows.
- Do not modify Home carousel/native navigation to solve a shared poster-row suspension bug.
- Do not claim Build305 introduced this defect without contrary runtime/source evidence.
