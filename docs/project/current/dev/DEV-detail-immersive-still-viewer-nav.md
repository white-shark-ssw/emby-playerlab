# DEV-detail-immersive-still-viewer-nav

- **Status:** Active — Build286 target-device regression identified; minimal Build287 source patch written; CI/IPA pending.
- **Work ID:** `DEV-detail-immersive-still-viewer-nav`
- **Routing aliases / keywords:** `详情页沉浸修复 / 详情页顶栏 / 剧照返回顶栏 / 沉浸式详情 / still viewer nav / immersive detail`
- **Task:** 修复详情页在进入/退出剧照查看路径后继续向下滚动时，原本透明沉浸式顶部导航区域可能变回不透明系统顶栏、覆盖上半部沉浸背景的问题。

## User intent / acceptance criteria

1. 目标真机仍为 iPhone 15 Pro Max / iOS 17.0。
2. 查看并退出详情页剧照后，详情页继续上下滚动时，顶部状态栏/导航栏区域必须保持现有沉浸式透明外观，不得出现截图中的不透明顶部栏和系统返回标题回归。
3. 不改变正常详情页 Hero、持续背景、滚动手感、剧照浏览视觉或关闭交互。
4. Native iOS push / pop / interactive-pop 继续由系统拥有；不得用自定义 push/pop、第二导航状态所有者或全局 UINavigationController 接管来规避问题。
5. 保留 Build182 详情页高频滚动隔离/冷启动展示缓存、Build184 视觉层级、Build191 选集导航和 Build216 range inertia 合同。
6. 不触碰 Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN P0 路径。
7. Deployment Target 保持 iOS 15.0。

## Baseline / identity

- **Failing runtime confirmed by user:** OnePlayer `0.15.19 / Build286`.
- **Build286 exact product source:** `7e7b2ec944f5c0e74bc291e37683f1529e3d46b4`.
- **Build286 branch / PR:** `perf/home-carousel-progress-scope-build286` / draft PR `#289`.
- **Build286 CI/IPA reference:** run/job `33786964921 / 100753960778`; artifact `OnePlayer-0.15.19-build286-home-progress-scope`, ID `9905942602`; IPA SHA-256 `5c26b36eb70117abbd27885f5b637827020f7fffcc949d79a45e5b9a19bc28b0`; MinOS 15.0.
- **Working branch:** `fix/detail-immersive-still-viewer-nav`.
- **Working branch baseline:** force-moved before code edits to exact Build286 product source `7e7b2ec944f5c0e74bc291e37683f1529e3d46b4` so the detail repair candidate preserves the user-tested Build286 Home runtime.
- **Current branch head:** `5b8806a0de63618e4f520b70f2e353952f327ecc`.
- **PR:** none yet.
- **Build candidate:** OnePlayer `0.15.20 / Build287` — uniquely allocated after checking current project references and PRs; no existing Build287 candidate found.
- **Runtime evidence supplied by user:** screenshot + `OnePlayer-App-1791191453.log`, captured on target device on 2026-10-05.

This task is intentionally **stacked for test packaging on Build286** because that is the failing package the user actually tested. It does not take ownership of Build286's Home carousel work. The Build286→Build287 product delta is currently only `Sources/Core/AppIdentity.swift` and `Sources/UI/EmbyDetailOverlayViews.swift`; no Home file is edited by this task.

## Evidence collected

### Target-device symptom

The screenshot shows the detail content/backdrop remaining visible while the top status/navigation region becomes a light opaque system bar and the native back title reappears. The user reports this occurs after entering/exiting the still viewer and then continuing to scroll.

The supplied Build286 log records the immersive destination bridge applying navigation appearance during the same detail sessions. It does not record a corresponding explicit `destination-nav-restore` at the exact visible failure moment, which is consistent with the appearance being overwritten/re-resolved after modal teardown rather than the bridge intentionally restoring it.

### Exact Build286 source ownership

- `EmbyMediaDetailView` owns `selectedStillIndex`, keeps the system navigation bar alive and attaches `immersiveSystemNavigationAppearance()`.
- `EmbyStillViewerPresenter` owns the UIKit `.overFullScreen` still-viewer host.
- In exact Build286 source, still-viewer dismissal first writes `selectedStillIndex = nil`, then calls `host.dismiss(animated: false)` without waiting for dismissal completion.
- The `selectedStillIndex` write invalidates/rebuilds the detail SwiftUI body and therefore can drive the existing immersive appearance bridge update while the UIKit modal teardown is still in progress.
- `ImmersiveNavigationAppearanceViewController` is already the single destination appearance owner. It reapplies transparent `UINavigationBarAppearance` from `updateUIViewController`, `viewWillAppear` and `viewDidAppear` and restores only on disappearance/teardown.

The violated ordering is therefore concrete: the parent state change that can reapply immersive appearance occurs **before** the UIKit dismissal has completed. UIKit/SwiftUI may finish its navigation-item reconciliation after that early refresh, leaving the detail destination with default opaque appearance until another bridge lifecycle update occurs.

## Implemented Build287 source patch

Exact Build286→current branch diff: two files only.

1. `Sources/UI/EmbyDetailOverlayViews.swift`
   - `Coordinator.dismiss` now accepts an optional completion and keeps the host alive locally through `dismiss(animated:false, completion:)`.
   - The still-viewer close path no longer clears `selectedStillIndex` before dismissal.
   - It dismisses the UIKit host first and clears the existing binding only in the UIKit dismissal completion.
   - That existing state mutation then causes the detail body/immersive appearance bridge update **after** modal teardown, not before it.
2. `Sources/Core/AppIdentity.swift`
   - candidate source version only: `0.15.20`.

No notification channel, retry, timer, watchdog, polling, global navigation appearance, custom pop owner, new navigation state owner or fallback was added.

## Files / modules in scope

- `Sources/UI/EmbyDetailOverlayViews.swift` — modified.
- `Sources/Core/AppIdentity.swift` — candidate identity only.
- `Sources/UI/ImmersiveUIComponents.swift` — inspected, not modified.
- `Sources/UI/EmbyMediaDetailView.swift` — inspected, not modified.
- CI/checker/project docs only as needed for Build287 validation.

Do not touch `Sources/UI/EmbyServerBrowseV3.swift` or poster-grid navigation activation unless new evidence directly implicates that route.

## State owner / shared dependencies

- Detail still-viewer presentation owner: `EmbyStillViewerPresenter`.
- Destination navigation appearance owner: `ImmersiveNavigationAppearanceViewController` / destination `UINavigationItem`.
- Native push/pop/interactive-pop owner: system UIKit navigation controller.
- This patch changes only ordering between the still-viewer presentation owner and the existing parent binding invalidation; it does not create a second appearance owner.

## Frozen / do-not-touch

- D007 native system navigation ownership.
- Build182 detail high-frequency scroll/presentation cache contract.
- Build184 visual hierarchy.
- Build191 detail episode-selection navigation.
- Build216 episode-range inertia interruption.
- Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session and all media-byte routing contracts.
- No timer, watchdog, polling, delayed retry, speculative fallback, global nav appearance takeover or second state owner.

## Parallel conflicts checked against

- `DEV-aether-multi-engine-comparison`: no source/state overlap.
- `DEV-home-carousel-drag-smoothness`: Build287 test package is stacked on exact Build286 to preserve the failing runtime, but this task edits no Home file/state owner. Build286 remains Home task evidence; Build287 does not claim Home acceptance.
- `DEV-poster-grid-smoothness`: shared native-navigation principle and adjacent route lifecycle exist, but this task does not edit Poster-owned `EmbyServerBrowseV3`/grid routing.
- `DEV-search-page-optimization`: no source/state overlap.
- No Build287 collision found before allocation.

## Completed

- New task checkpoint and dedicated branch created.
- Repository rules, routers, module status, project state, navigation decision and notification rules re-read.
- User identified the failing package as Build286.
- Exact Build286 branch/PR/source/CI/IPA identity resolved.
- Working branch moved to exact Build286 product source before code edits.
- Exact Build286 detail/still-viewer/immersive appearance source re-read.
- Minimal dismissal-order patch written.
- Candidate identity advanced to `0.15.20 / Build287`.
- Build286→Build287 source diff checked: exactly `AppIdentity.swift` + `EmbyDetailOverlayViews.swift`.

## Validation state

- User target-device regression report on Build286: ✅
- Screenshot symptom captured: ✅
- App log captured: ✅
- Exact installed runtime identity: ✅ Build286 / `7e7b2ec...`
- Matching source/state owners inspected: ✅
- Code written: ✅
- Narrow source scope compare: ✅ two files only
- CI passed: ❌ pending
- IPA produced: ❌ pending
- Repair real-device tested: ❌
- Stable / frozen: ❌

## Pending

1. Create Build287 validation/packaging path from exact branch head.
2. Validate the two-file scope, source version, iOS 15.0, and frozen/P0 exclusions.
3. Release-build/package an unsigned TrollStore IPA on Xcode 16.4.
4. Verify version `0.15.20`, Build `287`, bundle identity, MinOS 15.0, exact source SHA, artifact integrity and IPA SHA-256.
5. Hand Build287 to the user for the exact still-viewer → dismiss → scroll regression test.

## Next exact action

Create the Build287 CI/package candidate from current head `5b8806a0de63618e4f520b70f2e353952f327ecc`, preserving exact Build286 Home files and changing only the two recorded Build287 paths. Continue through CI and verified IPA unless an external build blocker appears.

## Rejected / do-not-repeat

- Do not hide the native navigation bar or implement custom back navigation.
- Do not add a timer/delayed reapply/watchdog/retry loop to keep the bar transparent.
- Do not globally mutate `UINavigationBar.appearance()`.
- Do not add a notification-based second appearance refresh channel when the existing selected-index invalidation can be correctly ordered after UIKit dismissal completion.
- Do not modify Poster route ownership merely because the affected detail page was entered from a poster grid.
- Do not reopen Build182 scroll/cache behavior without direct evidence.

## Open questions / risks

- Build287 is only a source-level candidate until CI/IPA and target-device testing are complete.
- The patch is deliberately based on the lifecycle ordering proven by exact Build286 source and the observed modal-associated symptom; only real-device testing can prove that this ordering correction removes the visible opaque-bar regression.
- Because the test package is stacked on unmerged Build286 Home work, eventual integration of the detail fix into `main` should carry only the detail patch/identity-neutral runtime change unless Home Build286 is independently accepted/merged.
