# DEV-poster-grid-smoothness

## Status

**Active — OnePlayer 0.14.35 / Build202 CI passed and IPA produced + independently verified; target-device A/B pending**

- **Work ID**：`DEV-poster-grid-smoothness`
- **Routing aliases / keywords**：3×3页面流畅度 / 3列海报流畅度 / 库页流畅度 / 海报网格优化 / poster grid smoothness
- **Task**：优化首页、媒体库、收藏/更多、搜索、标签搜索、演员搜索等海报密集页面的纵向滚动流畅度。用户最新真机结果优先于此前“只看 3 列 LazyVGrid”的初始假设。

## User intent / acceptance criteria

- Target device：iPhone 15 Pro Max / iOS 17.0。
- 用户明确反馈：首页、库页、收藏页、收藏中“更多”、搜索、标签搜索、演员搜索，只要是这种海报密集页面，连续上下滑动都会感到抖动/掉帧。
- 滚动需要连续、跟手；不能出现停一帧后下一帧追位的视觉顿挫。
- 保持现有海报数量、3 列布局、标题/年份/播放状态、原生导航语义和目标显示清晰度。
- 不通过截断列表、模糊图片、延迟输入、timer/debounce/throttle/watchdog 等方式掩盖卡顿。
- Deployment Target 保持 iOS 15.0。
- 不触碰 Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Resume/Session / STRM→302→115/CDN 客户端直连冻结合同。

## Baseline / identity

- Accepted overall runtime baseline：OnePlayer **0.14.32 / Build199**。
- Accepted product merge：PR #256 / `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`。
- Base product source：`main@d0c9f5fb5237041f09f46e9468240fc09986aca0`。
- Before Build202 allocation, compare from that source base to current `main` showed only project documentation and one-shot carousel CI helpers; no intervening product-source file changed.
- Working branch：`perf/poster-grid-smoothness`。
- Draft PR：**#259** — `Optimize shared poster scrolling smoothness`。
- **Build candidate：OnePlayer 0.14.35 / Build202**。
- Build200 / 0.14.33 and Build201 / 0.14.34 are owned by the independent Home-carousel line; this task deliberately skips both identities。
- Build202 successful CI / IPA source：`a05dd3424bb499e46dc0834e69cf55654fb7733e`。
- Durable feature head after deleting only the temporary feature workflow：`6e16865d1589a953f58bf65885d9fb01ff6374e0`。
- Tested-source → durable-head delta：**only `.github/workflows/temp-build202-poster-scroll-ci.yml` deletion; product/runtime source unchanged**。

## Real-device problem evidence — 2026-08-27

User supplied `RPReplay_Final1787760518.mp4` from the target-device usage path.

Measured recording facts:

- H.264 screen recording: **510×1108, constant 30 fps, 280 frames, 9.333 s**。
- The recording is only 30 fps, so it cannot quantify every 120 Hz frame miss on the iPhone 15 Pro Max; it can still prove stalls lasting at least one recorded 33.3 ms frame。
- Around **6.80 s**, while content is moving vertically, one frame is effectively repeated: robust feature tracking gives prior-frame vertical motion about **-2.74 px**, the 6.80 s frame **0 px**, then the next frame about **-10.36 px**。
- This is direct recording evidence of a **stop-one-frame → catch-up-next-frame** cadence, consistent with the user's visible “抖一下/掉帧” report。

Scope correction from that recording:

- The supplied recording shows Home vertical scrolling。
- Home poster sections do **not** use `EmbyPosterGrid`; Home poster rows are `ScrollView(.horizontal) + LazyHStack + V3PosterCard` inside the Home vertical scroll。
- Therefore the same visible hitch on Home cannot be explained by `EmbyPosterGrid` alone. Grid-local cleanup remains useful but is not treated as the cross-page root-cause theory。

## Source facts / Build202 product changes

1. `EmbyPosterGrid` is already the shared modern 3-column `LazyVGrid`; replacing it with another lazy container is not a valid optimization。
2. Build202 keeps that grid and only moves the two identical grid-owned Environment values (`embyPosterGridNavigationState`, `embyPosterGridCellWidth`) from every cell to the `LazyVGrid` ancestor。
3. `EmbyCachedRemoteImage` is a real common dependency across Home posters, 3-column media cards and person-result cards. The existing pipeline already owns decoded-memory cache, disk cache and detached ImageIO downsample/decode; no second cache/decoder is added。
4. Ordinary posters have no `onImageLoaded` consumer. Their image completion previously still wrote `reportedImageIdentifier` `@State`; Build202 exits that publisher path immediately when there is no callback. Hero/detail/carousel callback users preserve identifier deduplication and callback behavior。
5. `V3RemoteImage` renders `EmbyCachedRemoteImage(... showsLoadingIndicator: false)`, but the loader previously still published `isLoading=true/false`. Because the loader is a `@StateObject`, those invisible `@Published` changes still invalidated SwiftUI. Build202 threads `showsLoadingIndicator` into the loader and publishes loading state only when the view can actually render it。
6. Cache-miss first load previously assigned `image=nil` even when already nil. Build202 guards that assignment, so an unchanged empty image no longer emits object change。
7. Visible image assignment itself remains unchanged and remains the actual rendering update。
8. `V3PosterCard` explicit-width Home posters previously requested fixed `MaxWidth=440`. Build202 uses `min(440, ceil(resolvedWidth × UIScreen.main.scale))`; on the target 3× device a 118 pt Home poster requests about **354 px**, matching displayed device pixels instead of decoding roughly **54% more pixels by area** at 440 px. This is not a visible-quality reduction: request width remains at the actual rendered pixel width。
9. Grid cards continue to use their real resolved grid width × screen scale, capped at the existing 440 px。
10. `EmbyPersonResultPoster` uses `showsLoadingIndicator:false`, aligning actor/person 3×3 results with the ordinary poster path and avoiding invisible loading-state publications。
11. Home high-frequency scroll observation was inspected and is already isolated through `V3HomeHeroScrollState` / `V3HomeHeroScrollScope`; there is no evidence to reopen that owner for this task。
12. `EmbyPosterDetailLink` navigation construction was inspected but not changed because no current evidence proves it is the scrolling-time stall source。

## Exact Build202 tested-source delta

Compare `d0c9f5fb5237041f09f46e9468240fc09986aca0 → a05dd3424bb499e46dc0834e69cf55654fb7733e` was limited to:

- `.github/workflows/temp-build202-poster-scroll-ci.yml`
- `Sources/Core/AppIdentity.swift`
- `Sources/UI/EmbyPersonMediaView.swift`
- `Sources/UI/EmbyPosterGrid.swift`
- `Sources/UI/EmbyServerSharedV3.swift`
- `Sources/UI/EmbySharedImageAndNavigation.swift`
- `docs/changelog/CHANGELOG_v0_14_35_build202.md`
- `scripts/check_poster_grid_smoothness.py`

No Player / MPV / PiP / UnifiedTransport / playback Cache / Emby playback-session file and no active Home-carousel gesture/state-owner file is in the tested feature delta。

## Parallel dependency / carousel handling

- The independent carousel task owns Build200 and Build201; Build202 is unique to this task。
- Carousel runtime files `EmbyHomeCarouselInteractionV3.swift`, `EmbyHomeCarouselStateV3.swift`, `EmbyHomeHeroV3.swift`, `EmbyHomeCoreV3.swift` were explicitly rejected by the Build202 CI scope guard。
- `EmbySharedImageAndNavigation.swift` is a shared dependency because Home Hero consumes `EmbyCachedRemoteImage` with a real callback. Build202 preserves callback semantics, but after either feature merges the other must resync/revalidate against then-current `main` before final merge。
- `AppIdentity.swift` is also concurrently modified by test candidates, but each branch has a unique numeric identity. No Build number or IPA name is reused。

## Build202 CI / packaging evidence

- Feature/tested source：`a05dd3424bb499e46dc0834e69cf55654fb7733e`。
- One-shot exact-source workflow run：**32993726508 — success**。
- Job：**98257448257 — success**。
- Passed steps：exact SHA checkout; task source-contract checker; exact delta/Frozen/carousel-owner guard; Xcode 16.4/tool setup; icon generation; dependency resolution; Release build; built-app identity validation; MinOS validation; IPA/source packaging; artifact upload。
- Artifact：`OnePlayer-0.14.35-build202-poster-scroll-smoothness`。
- Artifact ID：**9615751921**。
- Artifact size：22,210,476 bytes。
- GitHub artifact digest：`sha256:1fa9236d08210440a80b2f9af2fcef24e5608aac6f8c52be602295b40ec68777`。
- Independently downloaded artifact ZIP SHA-256：`1fa9236d08210440a80b2f9af2fcef24e5608aac6f8c52be602295b40ec68777` — matches GitHub digest exactly。
- IPA：`OnePlayer-0.14.35-build202-poster-scroll-smoothness-unsigned.ipa`。
- IPA SHA-256：`f6e3a30206acf2cfd877df74f41aa13f1575e1614407eff79466884f9ec51279`。
- Source ZIP：`OnePlayer-0.14.35-build202-source.zip`。
- Source ZIP SHA-256：`19ebc6a2bcefd61d53eb4a9eea7617d5e98be7f8ae7b4f2dbf027ff62d8fabfe`。
- Independent `unzip -t`：IPA ✅ / source ZIP ✅。
- Independent IPA Info.plist check：bundle ID `com.embyplayerlab.app`; display/name `OnePlayer`; version/build `0.14.35 (202)`; `MinimumOSVersion=15.0`; icon metadata present。
- CI MinOS audit：runtime app Mach-O minimum OS compatibility **OK** at iOS 15.0; unreferenced Xcode 100.0 codeless/static-framework stubs were correctly excluded by the existing audit contract。
- Temporary Build202 feature workflow and one-shot main helper were deleted after evidence capture. Build201 helpers were not modified by this task。

## Validation state

- Existing-problem real-device recording：✅ — at least one recorded 33.3 ms stop/catch-up stall
- Build202 code written：✅
- Exact diff / Frozen / carousel-owner scope：✅
- Source-contract checker：✅ — executed successfully in run 32993726508
- CI passed：✅ — run 32993726508 / job 98257448257
- IPA produced：✅ — artifact 9615751921
- IPA/source independently verified：✅
- Candidate real-device tested：❌
- Stable / frozen：❌

## Next exact action

1. Install/test the verified Build202 IPA on iPhone 15 Pro Max / iOS 17.0。
2. A/B the user's reported paths: Home vertical scroll, library 3×3, favorites, favorites “更多”, search, tag search and actor/person search/results; include image-arrival and longer continuous scrolling。
3. Report whether the stop/catch-up feel is materially reduced, unchanged or worsened, and whether any image-quality/loading/navigation regression appears。
4. Do not modify more code before the Build202 target-device result unless a newly observed deterministic regression requires it; the current candidate already isolates the source-proven shared-path reductions。
5. If Build202 is positive, resync the durable product diff against then-current `main` before final merge and rerun affected validation if the integration source materially changes。
6. CI/IPA evidence alone cannot close or freeze this task。

## Rejected / do-not-repeat

- Treating `LazyVGrid` vs another lazy container as the root cause。
- Treating the grid Environment hoist as a complete fix after the Home recording。
- Adding a second poster cache/decoder。
- Reducing page size/list length or requesting below actual rendered device-pixel width。
- Generic debounce/throttle/timer/watchdog/retry/fallback。
- Reopening Home high-frequency scroll owner without new evidence。
- Refactoring navigation merely because `NavigationLink` looks expensive without a scrolling-time trace/source proof。
- Changing frozen playback/transport/cache/PiP/session contracts。
- Claiming Build202 fixed the real-device hitch before the new IPA is tested。

## Open questions / risks

- The 30 fps recording proves a visible recorded-frame stall but cannot identify every 120 Hz miss or attribute all hitching to one component。
- Build202 removes several source-proven common-path invalidations and an oversized Home poster request; the real-device effect size remains unknown until the target-device A/B。
- More than one bottleneck may exist. Any follow-up patch after Build202 should be driven by the new target-device result or concrete profiling evidence rather than speculative expansion。