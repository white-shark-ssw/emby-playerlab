# DEV-detail-immersive-still-viewer-nav

- **Status:** Active — Build287 code/CI/IPA verified; target-device repair test pending.
- **Work ID:** `DEV-detail-immersive-still-viewer-nav`
- **Routing aliases / keywords:** `详情页沉浸修复 / 详情页顶栏 / 剧照返回顶栏 / 沉浸式详情 / still viewer nav / immersive detail`
- **Task:** 修复详情页进入/退出剧照查看后继续滚动时，透明沉浸式系统导航栏偶发恢复为不透明系统顶栏并重新显示返回标题的问题。

## Acceptance criteria

1. iPhone 15 Pro Max / iOS 17.0 上，剧照查看器关闭后继续上下滚动，顶部必须保持原有透明沉浸外观，系统返回标题不得重新出现。
2. 不改变详情页 Hero、持续背景、滚动手感、剧照浏览视觉或关闭交互。
3. Native iOS push / pop / interactive-pop 继续由 UIKit 系统拥有；不新增第二导航状态所有者。
4. 保留 Build182 / 184 / 191 / 216 详情页既有合同。
5. 不触碰 Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN P0 路径。
6. Deployment Target 保持 iOS 15.0。

## Baseline / identity

- **Failing runtime:** OnePlayer `0.15.19 / Build286`，用户真机确认。
- **Build286 exact source:** `7e7b2ec944f5c0e74bc291e37683f1529e3d46b4`。
- **Build286 branch / PR:** `perf/home-carousel-progress-scope-build286` / draft PR `#289`。
- **Working branch:** `fix/detail-immersive-still-viewer-nav`。
- **Build287 product head:** `5b8806a0de63618e4f520b70f2e353952f327ecc`。
- **PR:** draft PR `#290`, stacked on `perf/home-carousel-progress-scope-build286` only so the test package preserves the exact failing Build286 Home runtime.
- **Build candidate:** OnePlayer `0.15.20 / Build287`。
- **Target device:** iPhone 15 Pro Max / iOS 17.0。

Build287 does not take ownership of Build286 Home work. Relative to exact Build286 product source, Build287 changes exactly two product files: `Sources/Core/AppIdentity.swift` and `Sources/UI/EmbyDetailOverlayViews.swift`.

## Evidence / root cause

Build286 screenshot shows the detail page remains present while the top status/navigation region becomes an opaque system bar and native back title reappears after the still-viewer path. The supplied App log proves the existing immersive destination appearance bridge is active in the affected sessions.

Exact Build286 source establishes the relevant ownership and ordering:

- `EmbyMediaDetailView` owns `selectedStillIndex`, keeps the native navigation bar alive and attaches `immersiveSystemNavigationAppearance()`.
- `EmbyStillViewerPresenter` owns the `.overFullScreen` UIKit still-viewer host.
- Build286 closes the still viewer by writing `selectedStillIndex = nil` **before** calling `host.dismiss(animated: false)`.
- That binding write invalidates the parent SwiftUI detail body and can run the existing immersive appearance bridge refresh while UIKit modal teardown is still in progress.
- `ImmersiveNavigationAppearanceViewController` already owns the destination `UINavigationItem` transparent appearance; no second appearance owner is required.

The minimal repair therefore changes only teardown ordering: complete UIKit dismissal first, then clear the existing binding so the existing detail invalidation/appearance refresh runs after modal teardown.

## Implemented Build287 patch

`Sources/UI/EmbyDetailOverlayViews.swift`:

- `Coordinator.dismiss` accepts an optional completion.
- It dismisses the retained host with `host.dismiss(animated: false, completion: completion)`.
- The user-close path now calls `coordinator.dismiss { binding.wrappedValue = nil }` instead of clearing the binding before dismissal.
- No timer, watchdog, polling, delayed retry, notification refresh channel, global `UINavigationBar.appearance`, custom pop owner or duplicate navigation state was added.

`Sources/Core/AppIdentity.swift` changes only candidate source identity to `0.15.20`.

`ImmersiveUIComponents.swift`, `EmbyMediaDetailView.swift`, `EmbyServerBrowseV3.swift`, all Home runtime files and all Player/Transport/Cache/Session paths are unchanged from Build286.

## CI / IPA baseline

- **Workflow:** `Build287 Detail Immersive Dismiss Order`
- **Run / job:** `37291455901 / 111702579502` — success.
- **Artifact:** `OnePlayer-0.15.20-build287-detail-immersive-dismiss-order`
- **Artifact ID:** `11336752155`
- **Artifact digest:** `sha256:8559b7288edbeeeede4708eefb5f2317f0c87e4a99d389fa80af9cd2c03549c8`
- **IPA:** `OnePlayer-0.15.20-build287-detail-immersive-dismiss-order-unsigned.ipa`
- **IPA SHA-256:** `790a589644eaf5942264216d07c589d4e95cbb5aaca52ec3ead1829fb7e5e488`
- **Source ZIP SHA-256:** `36ffb62136a8137adfe426d38fc4e6e3c093bf27f4108d21e36add144d6d48f8`
- **Verified package identity:** `com.embyplayerlab.app`, `0.15.20 (287)`, `MinimumOSVersion=15.0`, `CADisableMinimumFrameDurationOnPhone=true`.
- Independent artifact re-download matched GitHub artifact digest; IPA/source ZIP hashes matched the manifest and checksum files; both archives passed `unzip -t`; re-read source ZIP contains the new dismissal-completion ordering and no old binding-before-dismiss sequence.

## Validation state

- Build286 target-device regression reproduced/reported: ✅
- Exact failing Build286 source resolved: ✅
- Code written: ✅
- Exact two-file product scope verified: ✅
- CI passed: ✅
- IPA produced: ✅
- Artifact / IPA / source ZIP independently verified: ✅
- Deployment Target / built MinOS 15.0 verified: ✅
- Build287 target-device repair test: ❌ pending
- Stable / frozen: ❌

Evidence level is **Code written / CI passed / IPA produced+independently verified / real-device repair pending / not stable**.

## Parallel conflicts / frozen boundaries

- `DEV-home-carousel-drag-smoothness`: Build287 is stacked on exact Build286 for test attribution only; no Home source is modified.
- `DEV-poster-grid-smoothness`: shared system-navigation principle exists, but Poster-owned `EmbyServerBrowseV3` / grid route state is unchanged.
- `DEV-aether-multi-engine-comparison` and Search task: no source/state overlap.
- D007 system-owned navigation, Build182/184/191/216, Player/MPV/PiP/Transport/Cache/Session remain protected.

## Next exact action

Install Build287 on the target device and test the exact regression path: enter a detail page → open a still → close it (test both X and downward dismiss if convenient) → continue scrolling down/up. Confirm the top system navigation area remains transparent and the native back title does not reappear. Also do one normal system edge-swipe back check to confirm interactive-pop remains unchanged.

If the visual regression remains, collect one fresh Build287 App log and screenshot/video before any further code change. Do not add retries or a second appearance owner without that evidence.

## Rejected / do-not-repeat

- Do not hide the native navigation bar or replace native back navigation.
- Do not add timer/delayed reapply/watchdog/retry/polling.
- Do not globally mutate `UINavigationBar.appearance()`.
- Do not add a notification-based second appearance refresh channel.
- Do not modify Poster route ownership or reopen Build182 scroll/cache behavior without direct evidence.
