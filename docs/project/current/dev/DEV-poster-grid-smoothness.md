# DEV-poster-grid-smoothness

## Status

**Active — Build202 target-device tested and rejected; Build204 warm-cache cell-entry follow-up code written; CI / IPA pending**

- **Work ID**：`DEV-poster-grid-smoothness`
- **Routing aliases / keywords**：3×3页面流畅度 / 3列海报流畅度 / 库页流畅度 / 海报网格优化 / poster grid smoothness
- **Task**：优化首页、媒体库、收藏/更多、搜索、标签搜索、演员搜索等海报密集页面的纵向滚动流畅度。
- **Target device**：iPhone 15 Pro Max / iOS 17.0。

## Acceptance contract

- 连续上下滚动必须跟手，不能出现“停一帧 → 下一帧追位”的视觉顿挫。
- 保持海报数量、3 列布局、标题/年份/播放状态、原生导航语义和目标显示清晰度。
- 不用截断列表、模糊图片、timer/debounce/throttle/watchdog/retry/fallback 掩盖卡顿。
- Deployment Target 保持 iOS 15.0。
- Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Resume/Session / STRM→302→115/CDN client-direct 均为 do-not-touch。

## Baseline / identities

- Accepted overall runtime baseline：OnePlayer **0.14.32 / Build199**。
- Accepted product merge：PR #256 / `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`。
- Working branch：`perf/poster-grid-smoothness`。
- Draft PR：#259。
- Build202：**0.14.35 / 202** — CI/IPA verified, target-device rejected for remaining hitch。
- Build203：owned by independent Home-carousel task; do not reuse。
- Current candidate：**OnePlayer 0.14.37 / Build204**。

## Initial real-device evidence before Build202

User supplied `RPReplay_Final1787760518.mp4`:

- 510×1108, constant 30 fps, 280 frames, 9.333 s。
- around 6.80 s: prior vertical motion about **-2.74 px**, one recorded frame **0 px**, next frame about **-10.36 px**。
- This proved an existing stop-one-recorded-frame → catch-up-next-frame cadence。
- Home uses `LazyHStack + V3PosterCard`, not `EmbyPosterGrid`, so grid-only optimization was falsified as the complete root-cause theory。

## Build202 changes and evidence

Build202 kept the existing lazy containers and made only source-proven reductions:

- two grid-owned Environment values moved from every `EmbyPosterGrid` cell to the grid ancestor;
- ordinary poster images stopped publishing invisible loading-state changes;
- unchanged initial `image=nil` stopped being republished;
- ordinary images without `onImageLoaded` stopped writing callback-dedup `@State`;
- 118 pt Home posters request actual rendered device-pixel width (~354 px on 3×) instead of fixed 440 px;
- actor/person result posters use the no-loading-indicator path。

Build202 tested source：`a05dd3424bb499e46dc0834e69cf55654fb7733e`。
Durable branch head after feature-workflow cleanup：`6e16865d1589a953f58bf65885d9fb01ff6374e0`；tested-source → durable-head product source unchanged。

CI / packaging:

- run/job：`32993726508` / `98257448257` — success；
- artifact：`OnePlayer-0.14.35-build202-poster-scroll-smoothness`；ID `9615751921`；
- artifact digest：`sha256:1fa9236d08210440a80b2f9af2fcef24e5608aac6f8c52be602295b40ec68777`；
- IPA SHA-256：`f6e3a30206acf2cfd877df74f41aa13f1575e1614407eff79466884f9ec51279`；
- source ZIP SHA-256：`19ebc6a2bcefd61d53eb4a9eea7617d5e98be7f8ae7b4f2dbf027ff62d8fabfe`；
- bundle/version/build/MinOS verified：`com.embyplayerlab.app`, `0.14.35 (202)`, iOS 15.0。

## Build202 target-device result — rejected — 2026-08-27

User supplied the latest Build202 recording `RPReplay_Final1787766039.mp4` and explicitly reported that visible hitching remains。

Measured recording facts:

- 510×1108, constant **30 fps**, **205 frames**, **6.833 s**。
- Around **4.067 s**, content is already moving upward when one recorded frame effectively freezes：
  - previous frame vertical motion ≈ **-6.36 px**；
  - stalled frame ≈ **0 px**；
  - next frame catch-up ≈ **-26.19 px**。
- Mean visual change of the stalled frame pair is extremely small, followed by a large catch-up delta。
- The stalled frame occurs while the visible posters are already rendered; there is no obvious single poster network-arrival event at that instant。
- The recording starts with Hero already scrolled away and the stall occurs while poster rows continue entering the viewport. This does not support reopening the carousel gesture owner or treating Hero rendering as the only explanation。

Conclusion：**Build202 did not solve the user-visible stop/catch-up hitch.** Do not merge/freeze it as a performance success。

Evidence level：**Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / smoothness rejected ❌ / not stable.**

## Source evidence after Build202 rejection

The exact Build202 shared image implementation still had two deterministic ordinary-poster costs when a new cell enters the viewport:

1. Every `EmbyCachedRemoteImage` installed `.onReceive(loader.$image.compactMap { $0 })` even when `onImageLoaded == nil`. The closure returned immediately, but the Combine subscription/modifier still existed for every ordinary poster cell。
2. On a decoded-memory-cache hit, `onAppear → loader.load()` synchronously executed `image = rendered` on the UI path. For a newly-created ordinary cell this causes an immediate `ObservableObject` publication / second SwiftUI invalidation even though the cached image was already available before the first visible body pass。

These costs are common to Home poster rows, 3-column grids and person/search poster paths and match the new evidence better than speculative NavigationLink refactoring。

Navigation destination construction remains **not changed** because the recording still does not isolate it as the stall source。

## Build204 — current code-written candidate

Identity：**OnePlayer 0.14.37 / Build204**。Build203 is skipped because the carousel task owns it。

Current branch commits after Build202 durable head:

- `d80c1944007b88a4954e6bbd5811916f3300e1a6` — ordinary poster warm-cache entry fast path；
- `82f427123d2b219d2b8b3459d44671792b320b3f` — checker guards the new contract；
- `50767ea48a32a1c1377d870fd4a473d796f50823` — AppIdentity 0.14.37 / Build204 allocation；
- `7cc4c966cf912c9b7decf16dd1d08138d7667686` — Build204 changelog。

Runtime change remains in `EmbySharedImageAndNavigation.swift` only, plus AppIdentity for test attribution：

- `EmbyCachedImageLoader(initialURL:)` can seed its initial `image` from the existing `EmbyDecodedImageRenderPool`；
- this seed is used **only when `onImageLoaded == nil`**；
- ordinary warm-cache poster cells can render the cached UIImage on their first body pass, so `onAppear` returns without publishing a second `image = rendered` change；
- ordinary no-callback images no longer install the `loader.$image` Combine subscriber at all；
- callback paths (Home Hero/detail/carousel image metrics) intentionally keep the pre-Build204 publication/subscription semantics and are not warm-seeded through this shortcut；
- Build202's loading-state, nil-publication and image-size reductions remain intact。

No new cache, decoder, retry, timer, fallback or navigation owner is added。

## Parallel safety

- Active carousel task owns Build203 and its own carousel state/gesture files。
- Build204 does not modify `EmbyHomeCarouselInteractionV3.swift`, `EmbyHomeCarouselStateV3.swift`, `EmbyHomeHeroV3.swift` or `EmbyHomeCoreV3.swift`。
- `EmbySharedImageAndNavigation.swift` is shared infrastructure, so callback semantics are deliberately preserved and final integration must revalidate against then-current main。
- Current main changes relative to the poster task's product base remain project-doc / parallel-CI control-plane changes; no accepted main product-source delta has silently been imported into this branch。

## Validation state

- Build202 existing-problem / rejection recording：✅
- Build202 CI / IPA：✅
- Build202 target-device smoothness：❌ rejected
- Build204 code written：✅
- Build204 source-contract checker updated：✅ locally checked
- Build204 CI passed：❌ pending
- Build204 IPA：❌ pending
- Build204 real-device：❌ pending
- Stable：❌

## Next exact action

1. Run exact-source Build204 CI with a scope guard that allows only the existing Build202 poster files plus the new Build204 identity/changelog/workflow/checker delta。
2. Require Xcode 16.4 Release build, `0.14.37 (204)`, MinOS 15.0, IPA/source packaging and artifact upload。
3. If CI/IPA passes, test the same Home scroll path first, especially when lower poster rows enter view; then repeat library 3×3, favorites/more, search, tag search and actor/person results。
4. If Build204 still shows the same stop/catch-up event, do **not** immediately rewrite NavigationLink or lazy containers. Obtain new evidence for the next synchronous cell-entry/layout/compositing cost first。

## Rejected / do-not-repeat

- Treating `LazyVGrid` replacement as the fix。
- Treating Build202 as accepted merely because CI/IPA succeeded。
- Adding another image cache/decoder。
- Lowering image below actual rendered device pixels。
- timer/debounce/throttle/watchdog/retry/fallback。
- Reopening carousel gesture/state owner for vertical poster hitching。
- Refactoring NavigationLink without a source/profile trace tying it to the stall。
- Touching Player / MPV / PiP / Transport / Cache / Session contracts。
