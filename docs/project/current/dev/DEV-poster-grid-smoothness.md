# DEV-poster-grid-smoothness

## Status

**Active — Build202/204 real-device rejected; Build206 target-device App-log captured but could not distinguish idle display cadence from active scrolling; Build209 / 0.14.42 adds motion-gated diagnostics and is CI/IPA verified, target-device diagnostic run pending.**

- **Work ID**：`DEV-poster-grid-smoothness`
- **Routing aliases / keywords**：3×3页面流畅度 / 3列海报流畅度 / 库页流畅度 / 海报网格优化 / poster grid smoothness
- **Task**：优化首页、媒体库、收藏/更多、搜索、标签搜索、演员搜索等海报密集页面的纵向滚动流畅度。
- **Target device**：iPhone 15 Pro Max / iOS 17.0。
- **Working branch**：`perf/poster-grid-smoothness`
- **Draft PR**：#259

## Acceptance contract

- 连续上下滚动必须跟手，不能出现“停一帧 → 下一帧追位”的视觉顿挫。
- 保持海报数量、3 列布局、标题/年份/播放状态、原生导航语义和目标显示清晰度。
- 不用截断列表、模糊图片、timer/debounce/throttle/watchdog/retry/fallback 掩盖卡顿。
- Deployment Target 保持 iOS 15.0。
- Player / MPV / PiP / UnifiedTransport / playback Cache / Emby Resume/Session / STRM→302→115/CDN client-direct 均为 do-not-touch。

## Baseline / identities

- Accepted overall runtime baseline：OnePlayer **0.14.32 / Build199**。
- Accepted product merge：PR #256 / `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`。
- Build202：**0.14.35 / 202** — CI/IPA verified, target-device rejected for remaining hitch。
- Build204：**0.14.37 / 204** — CI/IPA verified, target-device rejected on Home and library 3×3。
- Build206：**0.14.39 / 206** — diagnostic-only, CI/IPA verified and target-device App-log captured; attribution incomplete because actual vertical motion was not recorded。
- Build208 / 0.14.41 is owned by the independent Home-carousel task. A poster diagnostic package was briefly built with that identity, then **retired before distribution** after the collision was detected; it must never be used for poster attribution。
- **Current poster diagnostic candidate：OnePlayer 0.14.42 / Build209**。

## Initial real-device evidence

User recording `RPReplay_Final1787760518.mp4` established the original cross-page stop/catch-up signature:

- 510×1108, constant 30 fps, 280 frames, 9.333 s；
- around 6.80 s：vertical motion about **-2.74 px → 0 px → -10.36 px**；
- Home uses `LazyHStack + V3PosterCard`, not `EmbyPosterGrid`, so grid-only optimization was falsified as the complete root-cause theory。

## Build202 — source-proven reductions, real-device rejected

Build202 kept the existing lazy containers and only reduced deterministic poster work:

- grid-owned Environment values moved from every cell to the grid ancestor；
- ordinary poster images stopped publishing invisible loading-state changes / unchanged initial nil；
- ordinary no-callback images stopped writing callback-dedup state；
- 118 pt Home posters request actual rendered device-pixel width rather than fixed 440 px；
- actor/person result posters use the no-loading-indicator path。

Identity/evidence：

- tested source `a05dd3424bb499e46dc0834e69cf55654fb7733e`；durable head `6e16865d1589a953f58bf65885d9fb01ff6374e0`；
- run/job `32993726508` / `98257448257` — success；artifact ID `9615751921`；
- IPA SHA-256 `f6e3a30206acf2cfd877df74f41aa13f1575e1614407eff79466884f9ec51279`；source ZIP `19ebc6a2bcefd61d53eb4a9eea7617d5e98be7f8ae7b4f2dbf027ff62d8fabfe`。

Latest Build202 recording still showed around 4.067 s approximately **-6.36 px → 0 px → -26.19 px**. Build202 therefore did not solve the visible hitch。

## Build204 — warm-cache cell-entry reduction, real-device rejected

Build204 removed two more deterministic ordinary-poster entry costs without adding another cache/decoder/navigation owner：

- existing decoded-memory-cache image can seed the ordinary no-callback loader before first body；
- ordinary no-callback images no longer install the `loader.$image` subscriber；
- callback paths keep their prior semantics。

Identity/evidence：

- exact CI source `e6a97b5083691ed10795a402edc0fd30f996cffc`；durable head `170778c3934a280d9b539fb45f0bfef673687825`；
- run/job `32996847597` / `98268250117` — success；artifact ID `9617026984`；
- IPA SHA-256 `b4ba266086674f95a09ef92500c78926b4bc9cfd022c637075985cd55c598130`；source ZIP `9f04a9f40f7f2617b0c9edee6cd2844cd4d3d7beed169eb5431ecbef5c01c506`。

Target device still showed stop/catch-up on Home and library 3×3, including approximately **-1.56 → 0 → -10.33 px** and **-1.99 → 0 → -20.27 px**. The warm-cache/no-op-subscriber work is therefore not the main cross-page cause。

## Build206 — first diagnostic baseline

Exact source：`351c62694ac25404c2bd4eb36a03314dd58ffed2`。

Build206 added one shared poster `CADisplayLink` and wrote `PosterScrollHitch` only for display intervals ≥30 ms, recording nearest cell appearance, image commit and grid load-ahead timing. It did not change scrolling/navigation/image policy or playback contracts。

CI / IPA：

- run/job `33000992493` / `98282482225` — success；artifact ID `9618646972`；
- IPA SHA-256 `ee981133777c316305c4890aaa1a99b8906792783cad1496d880bf786611e18c`；source ZIP `68fcde68a4fbf157bfe50a3ae5957e67e6664c461c067132d8d33f73553239ab`；
- app `0.14.39 (206)`；MinOS 15.0。

Target-device App log contained **17** records：Home/row 7，grid 10；grid max 118.7 ms。All 17 had `load_ahead=none`; 8/10 grid records were >1 s after both latest recorded cell appearance and image commit; grid had 0/10 within 20 ms of image commit. Two Home rows were ~10 ms after image commit, so image commit may be a local contributor but is not the universal Home+grid trigger。

Critical limitation：Build206 ran its display link whenever poster cells were visible but did **not** record real vertical offset, drag/deceleration state or velocity. Therefore every ≥30 ms callback interval could not be classified as a user-visible scrolling stall. This blocked another performance-source change。

## Build209 — motion-aware diagnostic candidate

Identity：**OnePlayer 0.14.42 / Build209**。

- Build206 base：`351c62694ac25404c2bd4eb36a03314dd58ffed2`
- current / exact CI source：**`e95d73b75938ad92f2c4d7f06a3ba2d441bb92f4`**
- main one-shot CI trigger commit：`2a95fc9f2e73a8637f43d3af8b212f64a44f9443`；temporary workflow later removed from main。

Build209 keeps Build206 diagnostic ownership and adds only real vertical-motion correlation：

- Home and shared 3-column grid each add a transparent, non-interactive `EmbyPosterScrollMotionProbe`；
- the probe resolves the real ancestor non-paging vertical `UIScrollView`；
- the existing single `CADisplayLink` samples `contentOffset.y` each tick；
- `PosterScrollHitch` is emitted only when **display gap ≥30 ms AND actual vertical `delta_y != 0`**；
- each record adds `scroll_route`, `phase=dragging/decelerating/moving`, `offset_y`, `delta_y`, `velocity_y` while retaining cell/image/load-ahead timing；
- no second display link, KVO polling, timer, debounce, throttle, retry or fallback；
- no scroll physics, image loading policy, navigation ownership or lazy-container change。

Exact Build206→Build209 product/checker delta is six files only：

- `Sources/Core/AppIdentity.swift`
- `Sources/UI/EmbyHomeCoreV3.swift`
- `Sources/UI/EmbyPosterGrid.swift`
- `Sources/UI/EmbySharedImageAndNavigation.swift`
- `docs/changelog/CHANGELOG_v0_14_42_build209.md`
- `scripts/check_poster_grid_smoothness.py`

No Player / MPV / PiP / Transport / Cache / Session / AVIO path is touched。

### Build209 CI / IPA evidence

- exact-source run/job：**`33006881819` / `98302809290` — success**；
- exact six-file scope, Frozen/P0 guard, carousel-owner guard, checker, Xcode 16.4, dependencies, Release build, app identity, MinOS, IPA/source packaging and artifact upload：all passed；
- artifact：`OnePlayer-0.14.42-build209-poster-motion-diagnostics`；artifact ID **`9621031556`**；
- GitHub artifact digest / independently downloaded artifact ZIP SHA-256：**`dc9d9aec4b266543fd894f8e6cdc6a5e811f88113c4a5fc7e1da83f1545dae7e`**；
- IPA：`OnePlayer-0.14.42-build209-poster-motion-diagnostics-unsigned.ipa`；
- independently verified IPA SHA-256：**`85f6649352718a8cac2b269ee090e19bfbb173881845462ed1493e1d90129572`**；
- source ZIP SHA-256：**`4437f8e1c7af4f28ac4682c6eea05cbfdd86f2f2a806a793ec81f91353cb716b`**；
- IPA unzip integrity：PASS；embedded checksum files match independent hashes；
- bundle `com.embyplayerlab.app`，display/name OnePlayer，version/build **`0.14.42 (209)`**，`MinimumOSVersion=15.0`，primary `OnePlayerIcon`，alternate `OnePlayerAltIcon`；
- independently extracted source confirms motion gate, Home/grid probes, exactly one `CADisplayLink`, and absence of the retired poster Build208 changelog。

**Build209 evidence level：Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device diagnostic pending / performance fix not claimed / not stable.**

## Parallel safety

- Home-carousel Build208 / 0.14.41 remains a separate Active candidate and owns its own carousel state/gesture changes。
- Poster Build209 touches `EmbyHomeCoreV3.swift` only to install the transparent Home vertical-scroll probe; it does not modify `EmbyHomeCarouselInteractionV3.swift`, `EmbyHomeCarouselStateV3.swift` or `EmbyHomeHeroV3.swift`。
- This is an explicit adjacent/shared dependency. If either Active task merges first, the other must resync to then-current `main` and rerun affected source/CI validation; old CI cannot prove combined source。
- `EmbySharedImageAndNavigation.swift` remains shared infrastructure, so final integration must revalidate it against then-current main。

## Validation state

- Build202 target-device smoothness：❌ rejected
- Build204 target-device smoothness：❌ rejected on Home + library 3×3
- Build206 target-device diagnostic capture：✅ 17 App-log records
- Build206 root-cause attribution：❌ incomplete because real motion state absent
- Build209 code / exact scope / Frozen guard：✅
- Build209 CI passed：✅
- Build209 IPA produced + independently verified：✅
- Build209 target-device diagnostic capture：⏳ pending
- Stable：❌

## Next exact action

1. Install **OnePlayer 0.14.42 / Build209** on iPhone 15 Pro Max / iOS 17.0。
2. Reproduce continuous vertical scrolling on at least Home poster-heavy area and library 3×3; also cover favorites/more/search/tag/person routes if convenient, because they share the reported signature。
3. Export the **App log** after reproducing. Only `PosterScrollHitch` entries that already passed `delta_y != 0` are treated as verified motion-overlapping gaps。
4. Compare `phase`, `delta_y`, `velocity_y` against cell/image/load-ahead ages. Do not modify another runtime path until this evidence identifies a repeatable correlation or rules out another owner。
5. A later performance fix requires a new unique Build/version, separate CI/IPA, and target-device acceptance before stable/frozen status。

## Rejected / do-not-repeat

- Treating `LazyVGrid` replacement as the fix。
- Treating Build202/204 as accepted merely because CI/IPA succeeded。
- Treating every Build206 ≥30 ms display-link interval as a proven scrolling hitch。
- Distributing or attributing the retired poster Build208 / 0.14.41 package。
- Adding another image cache/decoder。
- Lowering images below actual rendered device pixels。
- timer/debounce/throttle/watchdog/retry/fallback。
- Reopening carousel gesture/state owner for vertical poster hitching without direct evidence。
- Refactoring NavigationLink without a source/profile trace tying it to the stall。
- Touching Player / MPV / PiP / Transport / Cache / Session contracts。
