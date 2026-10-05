# DEV-detail-immersive-still-viewer-nav

- **Status:** Active — target-device regression reported; investigation baseline established; product code not changed yet because the supplied runtime log does not expose an exact version / Build / branch / commit identity.
- **Work ID:** `DEV-detail-immersive-still-viewer-nav`
- **Routing aliases / keywords:** `详情页沉浸修复 / 详情页顶栏 / 剧照返回顶栏 / 沉浸式详情 / still viewer nav / immersive detail`
- **Task:** 修复详情页在进入/退出剧照查看路径后继续向下滚动时，原本透明沉浸式顶部导航区域可能变回不透明系统顶栏、覆盖上半部沉浸背景的问题。

## User intent / acceptance criteria

1. 目标真机仍为 iPhone 15 Pro Max / iOS 17.0。
2. 查看并退出详情页剧照后，详情页继续上下滚动时，顶部状态栏/导航栏区域必须保持现有沉浸式透明外观，不得出现截图中的不透明顶部栏。
3. 不改变正常详情页的 Hero、持续背景、滚动手感、剧照浏览视觉或关闭交互，除非真实证据证明其中某一项就是故障所有者。
4. Native iOS push / pop / interactive-pop 继续由系统拥有；不得用自定义 push/pop、第二导航状态所有者或全局 UINavigationController 接管来规避问题。
5. 保留 Build182 详情页高频滚动隔离/冷启动展示缓存、Build184 视觉层级、Build191 选集导航和 Build216 range inertia 合同。
6. 不触碰 Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN P0 路径。
7. Deployment Target 优先保持 iOS 15.0；本任务没有提高最低系统版本的依据。

## Baseline / identity

- **Repository investigation base:** `main` at `91223978caf31c1de4c8e6cd38f9c2c07d0cee2f`.
- **Working branch:** `fix/detail-immersive-still-viewer-nav`.
- **Branch creation base/head:** `91223978caf31c1de4c8e6cd38f9c2c07d0cee2f`.
- **PR:** none yet.
- **Build candidate:** not allocated yet.
- **Runtime evidence supplied by user:** screenshot + `OnePlayer-App-1791191453.log`, captured on target device on 2026-10-05.
- **Runtime version / Build / branch / commit:** unresolved from the supplied file; do not assume `main` is the tested package.
- **Relevant source identity at investigation base:** `Sources/UI/EmbyMediaDetailView.swift` blob `63c55d252da2d2402adfe898c410c9f3f1eddcf1`; `Sources/UI/EmbyDetailOverlayViews.swift` blob `55f48a9f7bcc3eb99610d73268a7a98a595bc50b`; `Sources/UI/ImmersiveUIComponents.swift` blob `7d6d04d6dcfc95dcff8b54888196229e3468e005`.
- **Parallel Poster note:** Build283 branch has a different `EmbyMediaDetailView.swift` blob (`dd6d6b57819bd9bccab6390cc5876435c59c949b`) but the same `ImmersiveUIComponents.swift` blob (`7d6d04d6dcfc95dcff8b54888196229e3468e005`). Exact runtime attribution therefore still matters before any product patch.

## Evidence collected

### Target-device symptom

The screenshot shows the detail page content/backdrop remaining visible below, while the top status/navigation region has become a light opaque bar with the system back title. The user reports this appears after viewing stills and then scrolling down.

The supplied log contains normal detail entry followed by repeated immersive navigation appearance events and later restoration/disappearance events. For example, item `179373` records detail appear, `destination-nav-appearance stack=3`, source snapshot install, later additional appearance events, then `destination-nav-restore stack=0` and detail disappear. The log proves the immersive navigation bridge is active in the affected session, but it does not identify the exact installed Build and does not itself log the moment the opaque bar becomes visible.

### Real source ownership

- `EmbyMediaDetailView` owns `selectedStillIndex`, mounts `EmbyStillViewerPresenter` as a background representable, keeps the navigation bar visible, and applies `immersiveSystemNavigationAppearance()`.
- `EmbyStillViewerPresenter` owns the UIKit modal presentation of the still viewer through an `UIHostingController` with `.overFullScreen` presentation.
- `ImmersiveNavigationAppearanceViewController` owns the destination `UINavigationItem` appearance snapshot/apply/restore lifecycle. It applies a transparent `UINavigationBarAppearance` in `viewWillAppear` / `viewDidAppear` and restores the previous item appearances in `viewDidDisappear` / teardown.
- Native navigation ownership remains UIKit/system-owned; the immersive bridge is appearance-only.

This establishes a concrete interaction surface between still-viewer UIKit presentation lifecycle and destination navigation-item appearance lifecycle. It is a justified investigation target, but the current evidence is not yet sufficient to claim which lifecycle callback is wrong or to add a recovery mechanism.

## Files / modules in scope

Primary investigation scope:

- `Sources/UI/EmbyDetailOverlayViews.swift`
- `Sources/UI/ImmersiveUIComponents.swift`
- `Sources/UI/EmbyMediaDetailView.swift`
- narrow diagnostics/static checker only if needed to prove the lifecycle defect

Do not touch `Sources/UI/EmbyServerBrowseV3.swift` or poster-grid navigation activation merely because the affected detail page was entered from a poster route; the parallel Poster task owns that route repair unless new evidence directly implicates it.

## State owner / shared dependencies

- Detail still-viewer presentation owner: `EmbyStillViewerPresenter`.
- Destination navigation appearance owner: `ImmersiveNavigationAppearanceViewController` / destination `UINavigationItem`.
- Native push/pop/interactive-pop owner: system UIKit navigation controller.
- Detail page scroll owner and Build182 performance state remain unchanged unless evidence directly contradicts that assumption.

## Frozen / do-not-touch

- D007 native system navigation ownership.
- Build182 detail high-frequency scroll/presentation cache contract.
- Build184 visual hierarchy.
- Build191 detail episode-selection navigation.
- Build216 episode-range inertia interruption.
- Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session and all media-byte routing contracts.
- No timer, watchdog, polling, delayed retry, speculative fallback, global nav appearance takeover or second state owner.

## Parallel conflicts checked against

- `DEV-aether-multi-engine-comparison`: no source/state overlap with detail UI/nav appearance.
- `DEV-home-carousel-drag-smoothness`: no source/state overlap with detail UI/nav appearance.
- `DEV-poster-grid-smoothness`: **shared native-navigation principle and adjacent route lifecycle exist.** Poster Build283 owns its `EmbyServerBrowseV3` detail-activation repair and still has an explicit interactive-pop recheck pending. This task must remain isolated to the detail/still-viewer/appearance owner unless evidence proves a route dependency. If the final repair would require `EmbyServerBrowseV3` or Poster-owned route state, stop and record the dependency/stacking explicitly instead of silently editing both tasks.
- No Build/version candidate has been allocated, so there is no Build identity collision yet.

## Completed

- Session routed explicitly as a new development task by user request.
- Repository-wide rules, development router, module status, project state and technical navigation decision re-read.
- Other Active development checkpoints checked for branch/source/state overlap.
- Unique branch `fix/detail-immersive-still-viewer-nav` created from `main` head `91223978caf31c1de4c8e6cd38f9c2c07d0cee2f`.
- User screenshot and `OnePlayer-App-1791191453.log` inspected.
- Real detail, still-viewer and immersive navigation appearance definitions/call sites inspected.
- Initial structural hypothesis narrowed to modal-presentation ↔ destination-navigation-appearance lifecycle interaction; no patch claimed yet.

## Validation state

- User target-device regression report: ✅
- Screenshot symptom captured: ✅
- App log captured: ✅
- Relevant real source/state owners inspected: ✅
- Exact installed runtime Build / branch / commit identity: pending ❌
- Reproduction against matching source: pending ❌
- Code written: ❌
- CI passed: ❌
- IPA produced: ❌
- Repair real-device tested: ❌
- Stable / frozen: ❌

## Pending

1. Resolve the exact installed OnePlayer version / Build / branch / source commit corresponding to `OnePlayer-App-1791191453.log`.
2. Re-read the matching source blobs before editing and verify whether still-viewer dismissal/presentation causes the appearance bridge to restore or lose destination `UINavigationItem` appearance while the detail destination remains active.
3. Make only the smallest owner-level change supported by that evidence.
4. Preserve system-owned navigation and existing detail frozen contracts; add only narrow diagnostics/checker coverage required by the discovered invariant.
5. Allocate a unique Build/version candidate only after the patch direction is proven and collision-checked.

## Next exact action

Resolve the exact runtime package identity first. If the supplied package is confirmed to match a known branch/candidate, inspect that exact branch's `EmbyMediaDetailView.swift`, `EmbyDetailOverlayViews.swift` and `ImmersiveUIComponents.swift`, then reproduce the still-viewer dismissal lifecycle in source and patch the violated appearance invariant at its existing owner. Do not patch `main` speculatively while runtime identity is unresolved.

## Rejected / do-not-repeat

- Do not assume GitHub `main` is the failing runtime package.
- Do not fix this by hiding the native navigation bar or implementing custom back navigation.
- Do not add a timer/delayed reapply/watchdog/retry loop to keep the bar transparent.
- Do not globally mutate `UINavigationBar.appearance()`.
- Do not modify Poster Build283 route ownership just because the screenshot was reached from a poster grid.
- Do not reopen Build182 scroll/cache behavior without direct evidence.

## Open questions / risks

- The current runtime Build identity is absent from the supplied log. This is the only material blocker before a product code change.
- `.overFullScreen` presentation can affect UIKit appearance callbacks, but source structure alone does not prove which callback produces the visible opaque bar. The task must verify the actual lifecycle before changing behavior.
