# DEV-detail-immersive-still-viewer-nav

- **Status:** Active — Build287 target-device rejected; its dismissal-order behavior has been reverted. Build288 restores Build286 still-viewer behavior, adds narrow still-viewer lifecycle logging only, and is now CI/IPA-verified pending target-device diagnostics.
- **Work ID:** `DEV-detail-immersive-still-viewer-nav`
- **Routing aliases / keywords:** `详情页沉浸修复 / 详情页顶栏 / 剧照返回顶栏 / 沉浸式详情 / still viewer nav / immersive detail`
- **Task:** 修复详情页进入/退出剧照查看后继续滚动时，透明沉浸式系统导航栏可能恢复为不透明系统顶栏并重新显示返回标题的问题。

## Acceptance criteria

1. iPhone 15 Pro Max / iOS 17.0 上，详情页正常上下滚动以及剧照查看器关闭后继续滚动时，顶部必须保持原有透明沉浸外观，系统返回标题不得重新出现。
2. 不改变详情页 Hero、持续背景、滚动手感、剧照浏览视觉或关闭交互。
3. Native iOS push / pop / interactive-pop 继续由 UIKit 系统拥有；不新增第二导航状态所有者。
4. 保留 Build182 / 184 / 191 / 216 详情页既有合同。
5. 不触碰 Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Session / STRM→302→115/CDN P0 路径。
6. Deployment Target 保持 iOS 15.0。

## Baseline / identity

- **Original failing runtime:** OnePlayer `0.15.19 / Build286`，用户真机确认。
- **Build286 exact source:** `7e7b2ec944f5c0e74bc291e37683f1529e3d46b4`。
- **Build286 branch / PR:** `perf/home-carousel-progress-scope-build286` / draft PR `#289`。
- **Working branch:** `fix/detail-immersive-still-viewer-nav`。
- **PR:** draft PR `#290`, stacked on exact Build286 only for test attribution.
- **Rejected Build287 source:** `5b8806a0de63618e4f520b70f2e353952f327ecc` / OnePlayer `0.15.20 / Build287`.
- **Current Build288 diagnostic source:** `ce565996e37dcb750117c9de4607b23b673edce3` / OnePlayer `0.15.21 / Build288`.
- **Build288 CI control branch:** `ci/build288-detail-nav-diagnostics-20261005`.
- **Build288 workflow control head:** `110091a3dedc4a1b74d9752799d856d05854e649`.
- **Build288 Xcode 16.4 run / job:** `37296666668 / 111719392128` — success.
- **Build288 artifact:** `OnePlayer-0.15.21-build288-detail-nav-diagnostics`, ID `11340525765`, digest `sha256:9bbc4b5636f446f882025531bf33ac9a6b99512963f560fa9039ca0c0e111449`.
- **Build288 IPA SHA-256:** `f1100a6b2b344c6615ad20c2328cf096d52c84b46bf10a0402dad52ae5fa7eed`.
- **Build288 source ZIP SHA-256:** `ea963fe5f8d7d0a9303a8dcef48ddc1b2fe2947b376b527988eb06a6655d8609`.
- **Built identity:** `com.embyplayerlab.app / 0.15.21 (288) / MinimumOSVersion 15.0`; `CADisableMinimumFrameDurationOnPhone=true`.
- **Target device:** iPhone 15 Pro Max / iOS 17.0。

Build288 does not take ownership of Build286 Home work. Relative to exact Build286 product source, current Build288 changes only `Sources/Core/AppIdentity.swift` and `Sources/UI/EmbyDetailOverlayViews.swift`. `ImmersiveUIComponents.swift`, `EmbyMediaDetailView.swift`, `EmbyServerBrowseV3.swift`, all Home runtime files and all Player/Transport/Cache/Session paths remain unchanged.

## Build287 real-device result — rejected

On 2026-10-05 the user tested Build287 on the target device and reported a materially worse regression: after entering a detail page, only a small downward scroll is now enough for the opaque system top bar / native back title to appear; Build286 required additional conditions before the bug surfaced. The supplied screenshot captures this stronger failure.

This result **rejects Build287**. CI/IPA success did not solve the runtime issue.

The user also attached `OnePlayer-App-1791191453(1).log`, but its events are around `2026-10-05T09:10Z` (about 17:10 local +08:00), while the new screenshot shows 18:17. Therefore that uploaded log is not the current screenshot/reproduction session and cannot be used to attribute the new Build287 failure lifecycle.

## Hypothesis correction

The earlier Build287 root-cause claim — that clearing `selectedStillIndex` before UIKit dismissal was the defect — is no longer supported. Build287 changed that ordering, but the target-device result became worse.

More importantly, exact source comparison shows Build287 changed no normal detail-scroll owner and no navigation-appearance owner. The new report can occur on simple detail scrolling, so it would be unsafe to stack another behavior change on the rejected dismissal-order theory without fresh lifecycle evidence.

Therefore the Build287 behavioral patch is retired rather than preserved.

## Build288 diagnostic candidate

Build288 restores the exact Build286 still-viewer behavior:

- user close again clears `selectedStillIndex` before `coordinator.dismiss()`;
- `Coordinator.dismiss()` again calls plain `host.dismiss(animated: false)`;
- no dismissal completion ordering is used.

It adds only narrow `StillViewer` diagnostics around:

- present request / completion;
- close request;
- dismiss request;
- presentation skip because another controller is already presented.

The existing `NavigationVisual` diagnostics in `ImmersiveNavigationAppearanceViewController` remain untouched. A fresh Build288 log can therefore correlate still-viewer presentation/close events against the existing `destination-nav-appearance` / `destination-nav-restore` events without changing the navigation appearance owner itself.

No timer, watchdog, polling, delayed retry, notification refresh channel, global `UINavigationBar.appearance`, custom pop owner or duplicate navigation state is added.

## Build288 CI / package evidence

The dedicated Build288 workflow validated the exact Build286→Build288 two-file scope, confirmed the rejected Build287 completion-order code is absent, confirmed the original Build286 close ordering is restored, built Release with Xcode 16.4, validated OnePlayer identity / iOS 15.0 minimum OS, packaged the unsigned IPA, wrote the candidate manifest, and uploaded the artifact. All steps completed successfully.

The downloaded artifact was independently rechecked: outer artifact digest matches GitHub; IPA and source ZIP pass archive integrity; embedded checksum files match; built Info.plist is `com.embyplayerlab.app / 0.15.21 (288) / MinimumOSVersion=15.0`; source snapshot contains the new `StillViewer` diagnostics, does not contain the Build287 dismissal-completion behavior, and preserves `close request → selectedStillIndex=nil → coordinator.dismiss()` ordering.

This is **CI/package evidence only**, not a runtime repair result.

## Validation state

- Build286 target-device regression: ✅
- Build287 code written / CI passed / IPA produced: ✅
- Build287 target-device repair test: **rejected ❌**
- Build287 stable / frozen: ❌
- Build288 code written: ✅
- Build288 exact two-file product scope vs Build286: ✅
- Build288 CI passed: ✅
- Build288 IPA produced + independently verified: ✅
- Build288 target-device diagnostic run: pending ❌
- Stable / frozen: ❌

## Parallel conflicts / frozen boundaries

- `DEV-home-carousel-drag-smoothness`: Build288 remains stacked on exact Build286 only for test attribution; no Home source is modified.
- `DEV-poster-grid-smoothness`: shared system-navigation principle exists, but Poster-owned `EmbyServerBrowseV3` / grid route state is unchanged.
- `DEV-aether-multi-engine-comparison` and Search task: no source/state overlap.
- Build288 is reserved to this task.
- D007 system-owned navigation, Build182/184/191/216, Player/MPV/PiP/Transport/Cache/Session remain protected.

## Next exact action

Install Build288 on the target device. First enter a detail page and make the same small downward scroll **without opening any still**. If the opaque top bar appears, immediately export the App log and stop that run. Then start a fresh run: enter detail → open one still → close it once → make the same small scroll until the bug appears or clearly does not → immediately export that same-run App log. Correlate the new `StillViewer` timestamps with the existing `NavigationVisual` `destination-nav-appearance` / `destination-nav-restore` events to determine whether the appearance bridge loses ownership during modal presentation or whether a different detail/navigation lifecycle resets the bar.

Do not make a second behavioral navigation fix until that fresh Build288 lifecycle evidence identifies the violated owner invariant.

## Rejected / do-not-repeat

- Do not reuse Build287's dismiss-first / clear-binding-in-completion behavior without new contrary evidence.
- Do not hide the native navigation bar or replace native back navigation.
- Do not add timer/delayed reapply/watchdog/retry/polling.
- Do not globally mutate `UINavigationBar.appearance()`.
- Do not add a notification-based second appearance refresh channel.
- Do not modify Poster route ownership or reopen Build182 scroll/cache behavior without direct evidence.
