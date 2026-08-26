# DEV-poster-grid-smoothness

## Status

**Active — Build204 target-device tested and rejected; Build206 target-device App-log captured; first diagnostic attribution remains inconclusive because display-link gaps are not scroll-state gated**

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
- Build204：**0.14.37 / 204** — CI/IPA verified, target-device rejected on Home and library 3×3。
- Build205 / Build207：owned by independent Home-carousel task; do not reuse。
- Current diagnostic baseline：**OnePlayer 0.14.39 / Build206**。

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

## Build204 — implementation and CI evidence

Identity：**OnePlayer 0.14.37 / Build204**。

Build204 product commits after Build202 durable head:

- `d80c1944007b88a4954e6bbd5811916f3300e1a6` — ordinary poster warm-cache entry fast path；
- `82f427123d2b219d2b8b3459d44671792b320b3f` — checker guards the new contract；
- `50767ea48a32a1c1377d870fd4a473d796f50823` — AppIdentity 0.14.37 / Build204 allocation；
- `7cc4c966cf912c9b7decf16dd1d08138d7667686` — Build204 changelog。

Exact CI source：`e6a97b5083691ed10795a402edc0fd30f996cffc`。
Durable branch head after removing only the temporary Build204 feature workflow：`170778c3934a280d9b539fb45f0bfef673687825`。
CI-source → durable-head diff：**only `.github/workflows/temp-build204-poster-scroll-ci.yml` deletion; product/runtime source unchanged**。

Runtime change remains in `EmbySharedImageAndNavigation.swift` only, plus AppIdentity for test attribution：

- `EmbyCachedImageLoader(initialURL:)` can seed its initial `image` from the existing `EmbyDecodedImageRenderPool`；
- this seed is used **only when `onImageLoaded == nil`**；
- ordinary warm-cache poster cells can render the cached UIImage on their first body pass, so `onAppear` returns without publishing a second `image = rendered` change；
- ordinary no-callback images no longer install the `loader.$image` Combine subscriber at all；
- callback paths (Home Hero/detail/carousel image metrics) intentionally keep the pre-Build204 publication/subscription semantics and are not warm-seeded through this shortcut；
- Build202's loading-state, nil-publication and image-size reductions remain intact。

No new cache, decoder, retry, timer, fallback or navigation owner is added。

### Build204 CI / IPA evidence

- one-shot exact-source run/job：**`32996847597` / `98268250117` — success**；
- source-contract checker / exact Build202→Build204 delta guard / Frozen-path guard / carousel-owner guard：passed；
- Xcode 16.4 Release build：passed；
- app identity：`com.embyplayerlab.app`, OnePlayer, **`0.14.37 (204)`**；
- MinOS：**15.0**；runtime Mach-O minOS audit passed；
- artifact：`OnePlayer-0.14.37-build204-poster-warm-cache`；
- artifact ID：**`9617026984`**；
- artifact digest / independently downloaded artifact ZIP SHA-256：**`7115be086057ba9254012df365e2e3f9b0f2d30a2d587b9e6bfcb65756c0f794`**；
- IPA：`OnePlayer-0.14.37-build204-poster-warm-cache-unsigned.ipa`；
- IPA SHA-256：**`b4ba266086674f95a09ef92500c78926b4bc9cfd022c637075985cd55c598130`**；
- source ZIP SHA-256：**`9f04a9f40f7f2617b0c9edee6cd2844cd4d3d7beed169eb5431ecbef5c01c506`**；
- IPA/source ZIP integrity：passed；
- build log contains `** BUILD SUCCEEDED **`。

## Build204 target-device result — rejected — 2026-08-27

User reported that Build204 still visibly hitches and explicitly reproduced the same problem on the library 3×3 page as well as Home poster-heavy scrolling。

Latest recording lower-bound evidence (30 fps):

- around **5.900 s**: tracked vertical motion approximately **-1.56 px → 0 px → -10.33 px**；
- around **7.133 s**: approximately **-1.99 px → 0 px → -20.27 px**；
- both are the same stop-recorded-frame → catch-up-next-frame signature seen before。

Conclusion: Build204's ordinary-poster no-op subscriber removal and warm-cache first-body seeding are not the main cross-page root cause. Build204 is **real-device tested and rejected for smoothness**, not stable。

## Build206 — diagnostic-only baseline

Identity：**OnePlayer 0.14.39 / Build206**。

Exact diagnostic source：`351c62694ac25404c2bd4eb36a03314dd58ffed2`。

Build206 deliberately does not attempt another speculative rendering fix. It adds only a low-noise shared poster hitch diagnostic:

- one `CADisplayLink` exists only while poster cells are visible；
- normal frames produce no log；
- only a main display interval **≥30 ms** writes `PosterScrollHitch`；
- the hitch record includes the nearest poster-cell appearance, image commit and grid load-ahead timestamps/identifiers；
- existing diagnostics logger/export surfaces are reused; no new logging screen is added；
- scrolling, navigation, image policy, carousel ownership and all P0 playback/transport/cache/session paths are unchanged。

### Build206 CI / IPA evidence

- exact-source run/job：**`33000992493` / `98282482225` — success**；
- source contract / exact five-file scope / Frozen / carousel-owner guards：passed；
- Xcode 16.4 Release build：passed；
- artifact：`OnePlayer-0.14.39-build206-poster-hitch-diagnostics`；artifact ID **`9618646972`**；
- artifact digest：`sha256:eb780276e88fcd6ce41df5e962168dec5976913a0f9e9a829350efc89ea29dbe`；
- independently downloaded IPA SHA-256：**`ee981133777c316305c4890aaa1a99b8906792783cad1496d880bf786611e18c`**；
- source ZIP SHA-256：**`68fcde68a4fbf157bfe50a3ae5957e67e6664c461c067132d8d33f73553239ab`**；
- IPA ZIP integrity：passed；build log contains `** BUILD SUCCEEDED **`；
- bundle/version/build：`com.embyplayerlab.app`, OnePlayer **0.14.39 (206)**；
- `MinimumOSVersion=15.0` and MinOS audit：passed。

### Build206 target-device App-log result — 2026-08-27

The user exported an empty playback-log file but supplied `OnePlayer-App-1787770662.log`. That App log **does contain the Build206 poster diagnostics**, so the poster task is not blocked by the empty playback log。

Observed `PosterScrollHitch` records:

- total：**17**；Home/non-grid `row`：**7**；3-column `grid`：**10**；
- row gaps：36.2 / 33.3 / 87.0 / 33.3 / 63.1 / 47.1 / 88.3 ms；median **47.1 ms**，max **88.3 ms**；
- grid gaps：46.2 / 49.4 / 99.6 / 62.1 / 33.3 / 118.7 / 76.0 / 49.6 / 39.7 / 97.6 ms；median **55.85 ms**，max **118.7 ms**；
- **17/17** records report `load_ahead=none`；
- **8/10 grid** records happened more than **1 s** after both the most recent recorded poster-cell appearance and image commit；
- grid has **0/10** records within 20 ms of an image commit；
- Home `row` has **2/7** records about **10.5 ms / 9.4 ms** after an image commit, so image commit can still be a local contributor in some Home cases, but it does not explain the common Home+grid signature by itself。

This is useful negative evidence: **immediate new-cell entry, image commit, and grid load-ahead are not a universal trigger for the cross-page hitch.** It does not justify another image-cache, pagination, NavigationLink or lazy-container rewrite。

However, exact-source review exposes an important diagnostic limitation: Build206 starts its shared `CADisplayLink` whenever at least one poster is visible. It does **not** record whether the vertical container is actually dragging/decelerating/moving, nor vertical offset/delta/velocity. Therefore a recorded ≥30 ms display-link interval is not sufficient by itself to classify that sample as a user-visible scrolling stall; some entries can reflect display-callback cadence while content is not moving. `visible` is also the diagnostic's active poster appearance count, not a literal count of posters currently inside the screen bounds。

Conclusion：**Build206 target-device diagnostic capture succeeded, but root-cause attribution is not yet conclusive.** The source evidence is strong enough to stop treating cell/image/load-ahead as the universal explanation, but not strong enough to modify another runtime path yet。

Evidence level：**Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device diagnostic capture ✅ / root-cause attribution incomplete / not stable.**

## Parallel safety

- Active carousel task owns Build205 / Build207 and its own carousel state/gesture files；Build206 remains poster-owned。
- Build206 does not modify `EmbyHomeCarouselInteractionV3.swift`, `EmbyHomeCarouselStateV3.swift`, `EmbyHomeHeroV3.swift` or `EmbyHomeCoreV3.swift`。
- `EmbySharedImageAndNavigation.swift` is shared infrastructure, so final integration must revalidate against then-current main。
- Current main changes relative to the poster task's product base remain project-doc / parallel-CI control-plane changes; no accepted main product-source delta has silently been imported into this branch。

## Validation state

- Build202 target-device smoothness：❌ rejected
- Build204 code / scope / CI / IPA：✅
- Build204 target-device smoothness：❌ rejected on Home + library 3×3
- Build206 code / exact diagnostic scope：✅
- Build206 CI passed：✅
- Build206 IPA produced + independently verified：✅
- Build206 target-device diagnostic capture：✅ App log contains 17 records
- Build206 diagnostic attribution：❌ incomplete because active-scroll/motion state is absent
- Stable：❌

## Next exact action

1. Before changing performance behavior, inspect the exact Home vertical-scroll owner, shared grid scroll ownership and existing offset observers/call sites on the Build206 source line。
2. If no existing signal already provides the needed facts, add the smallest **diagnostic-only** motion correlation: record actual vertical offset delta plus drag/deceleration/moving phase around a display-gap event. Do not change scrolling behavior, image policy, navigation ownership, cache policy or lazy-container structure。
3. Only count/correlate ≥30 ms gaps that overlap verified vertical motion; then compare those real motion stalls against cell/image/load-ahead timing。
4. Allocate another unique Build/version only after the diagnostic delta and global identity ownership are checked. A later performance fix still requires separate CI/IPA and target-device acceptance。

## Rejected / do-not-repeat

- Treating `LazyVGrid` replacement as the fix。
- Treating Build202 or Build204 as accepted merely because CI/IPA succeeded。
- Treating every Build206 `CADisplayLink` ≥30 ms interval as a proven scroll hitch without motion state。
- Adding another image cache/decoder。
- Lowering image below actual rendered device pixels。
- timer/debounce/throttle/watchdog/retry/fallback。
- Reopening carousel gesture/state owner for vertical poster hitching。
- Refactoring NavigationLink without a source/profile trace tying it to the stall。
- Touching Player / MPV / PiP / Transport / Cache / Session contracts。
