# DEV-poster-grid-smoothness

## Status

**Active — Build212 / 0.14.45 source-aware diagnostic candidate is CI/IPA verified and awaiting target-device App-log capture. Build210 remains the controlling real-device evidence: four Home dragging hitches landed 6.2–11.0 ms after shared image commit, while the one grid record was only programmatic/micro-motion. Build212 adds memory/disk/network image source, callback/display role, item/type/MaxWidth, synchronous `onImageLoaded` callback duration and Core Image contrast-render duration without changing scroll/image/navigation behavior or active carousel owner files. Performance root cause remains unresolved and no fix is claimed.**

- **Work ID**: `DEV-poster-grid-smoothness`
- **Routing aliases / keywords**: 3×3页面流畅度 / 3列海报流畅度 / 库页流畅度 / 海报网格优化 / poster grid smoothness
- **Working branch**: `perf/poster-grid-smoothness`
- **Draft PR**: #259
- **Target device**: iPhone 15 Pro Max / iOS 17.0
- **Accepted overall baseline**: OnePlayer **0.14.32 / Build199**, PR #256, merge `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`

## Acceptance / protected contracts

- Home, library 3×3, favorites/more, search, tag and person/actor poster-heavy vertical scrolling must not show the visible “停一帧 → 下一帧追位” hitch.
- Keep poster count, 3-column layout, metadata, native navigation semantics and rendered image quality.
- Do not hide the problem with list truncation, lower-than-rendered image quality, debounce/throttle/timer/watchdog/retry/fallback.
- Deployment Target remains iOS 15.0.
- Player / MPV / PiP / UnifiedTransport / Range/206 / playback Cache / Emby Resume/Session / STRM→302→115/CDN client-direct are do-not-touch. NAS must never relay media bytes.

## Real-device history controlling the direction

### Build202 / 0.14.35 — rejected

CI/IPA passed, but the target-device recording still showed the stop/catch-up signature. Around 4.067 s the recorded vertical movement was approximately **-6.36 px → 0 px → -26.19 px**. Image-loading-state/request-size reductions therefore did not solve the user-visible hitch.

### Build204 / 0.14.37 — rejected

CI/IPA passed. Target device still visibly hitched on both Home and library 3×3. Recorded examples included approximately **-1.56 → 0 → -10.33 px** and **-1.99 → 0 → -20.27 px**. Removing ordinary no-op image subscriptions and warm-cache second invalidation is not the main cross-page cause.

### Build206 / 0.14.39 — first diagnostic capture

Exact source `351c62694ac25404c2bd4eb36a03314dd58ffed2`; run/job `33000992493 / 98282482225`; artifact ID `9618646972`; IPA SHA-256 `ee981133777c316305c4890aaa1a99b8906792783cad1496d880bf786611e18c`.

Target-device App log contained **17** `PosterScrollHitch` records: Home/row 7, grid 10, grid max 118.7 ms. All 17 had `load_ahead=none`; 8/10 grid entries were >1 s after both latest recorded cell appearance and image commit. This ruled out immediate cell entry / image commit / load-ahead as a universal trigger, but Build206 did not record whether vertical content was actually moving, so attribution remained incomplete.

## Build209 / 0.14.42 — target-device result

Exact source: **`e95d73b75938ad92f2c4d7f06a3ba2d441bb92f4`**.

Build209 added transparent Home/grid motion probes and gated the existing single poster `CADisplayLink` by actual `contentOffset.y` change. It logged `scroll_route`, drag/deceleration phase, offset, delta and velocity without changing scroll behavior.

CI / IPA evidence:

- run/job: **`33006881819 / 98302809290` — success**
- artifact ID: **`9621031556`**
- artifact ZIP SHA-256: `dc9d9aec4b266543fd894f8e6cdc6a5e811f88113c4a5fc7e1da83f1545dae7e`
- IPA SHA-256: `85f6649352718a8cac2b269ee090e19bfbb173881845462ed1493e1d90129572`
- source ZIP SHA-256: `4437f8e1c7af4f28ac4682c6eea05cbfdd86f2f2a806a793ec81f91353cb716b`
- bundle/version/build/MinOS: `com.embyplayerlab.app`, **0.14.42 (209)**, iOS 15.0

Latest target-device App log: `OnePlayer-App-1787774511.log`.

Verified `PosterScrollHitch` entries that already passed `delta_y != 0`:

1. **78.8 ms**, `scroll_route=home`, `phase=dragging`, `offset_y=1129.67`, `delta_y=5.33`, `velocity_y=0.0`.
2. **38.1 ms**, `scroll_route=home`, `phase=dragging`, `offset_y=1240.33`, `delta_y=1.33`, `velocity_y=0.0`.
3. **67.2 ms**, `scroll_route=home`, `phase=dragging`, `offset_y=2602.00`, `delta_y=-61.33`, `velocity_y=1012.3`.

The 67.2 ms sample is direct evidence of a long frame while Home content was materially moving. Build209 therefore confirms real Home motion stalls rather than only idle/ProMotion cadence.

However, the same session clearly scrolled shared grid content far enough to trigger pagination: the diagnostic `load_ahead_age_ms=15376.1` at 20:01:45.018 back-calculates to about **20:01:29.642**, matching the grid `StartIndex=60` request at **20:01:29.650**. Despite that, the log contains **zero `scroll_route=grid` hitch records**.

Exact-source inspection explains why: Build209 stores only one global `observedScrollView / observedScrollOwnerID / observedScrollRoute / lastScrollOffsetY`. Home remains in the navigation hierarchy while pushed grid pages can exist, and either transparent probe can re-attach during layout, overwriting the other diagnostic owner. Therefore **Build209 grid attribution is not reliable**. Do not infer “grid has no stalls” from its zero grid records.

**Build209 evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device diagnostic tested ✅ / Home motion stalls verified ✅ / grid attribution incomplete ❌ / performance root cause unresolved / not stable.**

## Build210 / 0.14.43 — current multi-owner diagnostic candidate

Build210 keeps the same 30 ms threshold and exactly one shared poster `CADisplayLink`. It changes only diagnostic owner registration so Home and pushed grid pages cannot overwrite each other.

Exact source: **`9d8fd6a62e6e7d281d4fae5ab8442754a6362f47`**.

Exact Build209→Build210 delta is four files only:

- `Sources/Core/AppIdentity.swift`
- `Sources/UI/EmbySharedImageAndNavigation.swift`
- `docs/changelog/CHANGELOG_v0_14_43_build210.md`
- `scripts/check_poster_grid_smoothness.py`

Diagnostic implementation:

- each probe owner has an independent weak `UIScrollView`, route and previous `contentOffset.y` in `scrollObservations[UUID]`;
- each display tick samples all registered vertical scroll views;
- only owners whose real offset changed become moving samples;
- if more than one moves, dragging is preferred over decelerating over programmatic moving, then larger absolute `delta_y` wins;
- log adds `registered_scrolls` and `moving_scrolls` so arbitration is observable;
- the old single-owner fields are absent;
- no Home/grid probe placement changed from Build209;
- no scroll physics, image policy, navigation behavior, lazy-container behavior or carousel owner changed.

During implementation an initial contents-API whole-file write truncated the shared file. **It was detected by exact diff before Build210 CI and never became a tested package.** One-shot repair run/job `33009161632 / 98310624611` restored the exact Build209 full source then applied only the multi-owner patch; checker, `git diff --check`, single-file repair scope and source-length guard passed. The repaired exact CI source is the SHA above.

Build210 CI / IPA evidence:

- exact-source run/job: **`33009322419 / 98311176681` — success**
- source checker, exact four-file scope, Frozen/P0 guard and carousel-owner/adjacency guard: PASS
- Xcode 16.4 Release build: PASS
- artifact: `OnePlayer-0.14.43-build210-poster-multi-owner-diagnostics`
- artifact ID: **`9621956333`**
- GitHub artifact digest / independently downloaded artifact ZIP SHA-256: **`d6ba61a5a2f6f635e316db81e3d6d520ae4710b972d652f3df579818f7cc7c32`**
- IPA SHA-256: **`813811fe0301cd8c942511e3e7786c184a80966960bf029ed3366d6edaa23701`**
- source ZIP SHA-256: **`ba59a91128e1b2b1730942966f19fdb364f52552a552c1cf60b8b19ce128a775`**
- IPA/source ZIP integrity: PASS
- bundle/version/build: `com.embyplayerlab.app`, OnePlayer **0.14.43 (210)**
- `MinimumOSVersion=15.0`; MinOS audit PASS
- source snapshot independently confirms multi-owner observations, `registered_scrolls/moving_scrolls`, exactly one poster `CADisplayLink`, no legacy single-owner fields, and complete shared source.

**Build210 evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device diagnostic tested ✅ / multi-owner route attribution validated ✅ / Home image-commit correlation strong but not yet causal / user-drag grid root cause unresolved / performance fix not claimed / not stable.**

## Build210 target-device result — 2026-08-27

Latest App log: `OnePlayer-App-1787807430.log`.

Build210 emitted five motion-gated `PosterScrollHitch` records:

- Home: **68.9 ms**, `phase=dragging`, `delta_y=16.00`, `image_age_ms=11.0`, `cell_age_ms=6644.2`.
- Home: **34.9 ms**, `phase=dragging`, `delta_y=3.00`, `image_age_ms=6.2`, `cell_age_ms=7277.1`.
- Home: **74.5 ms**, `phase=dragging`, `delta_y=2.33`, `image_age_ms=8.8`, `cell_age_ms=13651.4`.
- Home: **39.8 ms**, `phase=dragging`, `delta_y=11.00`, `velocity_y=-503.8`, `image_age_ms=9.0`, `cell_age_ms=14291.9`.
- Grid: **70.4 ms**, `scroll_route=grid`, `phase=moving`, `delta_y=0.33`, `velocity_y=0.0`, `registered_scrolls=2`, `moving_scrolls=1`, `image_age_ms=855.4`, `cell_age_ms=1151.0`.

This validates the Build210 multi-owner diagnostic model: Home and grid owners coexist and only the actually moving owner is selected. Build209's zero-grid result was therefore a diagnostic ownership defect, not proof of a smooth grid.

The four Home dragging hitches all occurred only **6.2–11.0 ms** after the most recent shared image commit while the latest poster cell appearance was already **6.6–14.3 s** old. Exact Build210 source shows decode already occurs in detached utility work; `imageDidCommit()` is timestamped immediately after `@Published image` assignment on MainActor. Home carousel `onImageLoaded` callbacks then synchronously run `updateCarouselImageMetrics`, including `EmbyImageContrastAnalyzer.prefersLightForeground` → `CIAreaAverage` → `CIContext.render`, and may mutate root Home `@State` dictionaries. This is the strongest Home-specific source/device correlation so far.

However, `imageDidCommit` is global and does not identify item/route/cache source, so the 4/4 correlation is not yet enough to change image policy. The one grid record is also not a user-drag sample and has no near-image correlation. Do not claim a cross-page root cause yet.

## Build212 / 0.14.45 — source-aware diagnostic candidate

Build212 is a **diagnostic-only** successor to Build210. Build211 / 0.14.44 is owned by the independent Home-carousel task; the poster task retired its temporary 211 identity before distribution and uses the unique Build212 identity.

Exact source: **`4f0a89ab026cd2103f66e5854a1f352d34852e45`**.

Exact Build210→Build212 product delta is four files only:

- `Sources/Core/AppIdentity.swift`
- `Sources/UI/EmbySharedImageAndNavigation.swift`
- `docs/changelog/CHANGELOG_v0_14_45_build212.md`
- `scripts/check_poster_grid_smoothness.py`

Build212 retains Build210's one shared motion-gated poster `CADisplayLink` and multi-owner Home/grid attribution, then adds only source-aware correlation in shared image infrastructure:

- image publish context: Emby item ID, image type, requested `MaxWidth`, `source=memory/disk/network`, and `role=display/callback`;
- synchronous `onImageLoaded` callback duration measured around the existing callback invocation;
- synchronous `CIContext.render` duration in `EmbyImageContrastAnalyzer`;
- existing hitch log keeps route/phase/offset/delta/velocity/cell/image/load-ahead timing and adds the new image/callback/contrast fields;
- authentication query data is not logged;
- no timer, debounce, throttle, watchdog, retry, fallback, second display link, image-policy change, scroll-physics change, navigation change or carousel-owner change.

CI / IPA evidence:

- exact-source run/job: **`33045869471 / 98429601490` — success**
- source checker, exact four-file scope, Frozen/P0 and carousel-owner guard: PASS
- Xcode 16.4 dependency resolution + Release build: PASS
- artifact: `OnePlayer-0.14.45-build212-poster-source-aware-diagnostics`
- artifact ID: **`9635696107`**
- GitHub artifact digest / independently downloaded artifact ZIP SHA-256: **`eb53a4b88564165b399edfd9085fcc888718cfa62141725d1f24cc539d598615`**
- IPA SHA-256: **`dcdec181dd16e9b3b666882de8347a76671c743ab8392aa27791d40599eec7a1`**
- source ZIP SHA-256: **`9a618698a71ba45074ae915d859afdf9173f312e989e9a646717ed8c6ba60459`**
- IPA/source ZIP integrity and embedded checksum verification: PASS
- bundle/version/build: `com.embyplayerlab.app`, OnePlayer **0.14.45 (212)**
- `MinimumOSVersion=15.0`; MinOS audit PASS
- source snapshot independently confirms source-aware image fields, callback/contrast timing and the unchanged single poster `CADisplayLink`.

**Build212 evidence: Code written ✅ / exact scope+Frozen guard ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device diagnostic pending ❌ / performance fix not claimed / not stable.**

## Parallel safety

- Build211 / 0.14.44 identity is owned by the independent Home-carousel task; poster Build212 does not reuse that identity.
- Build210 does **not** modify `EmbyHomeCoreV3.swift`, `EmbyHomeCarouselInteractionV3.swift`, `EmbyHomeCarouselStateV3.swift` or `EmbyHomeHeroV3.swift`; it reuses Build209's already-present transparent Home/grid probes.
- `EmbySharedImageAndNavigation.swift` is shared infrastructure. Whichever Active task integrates second must resync to then-current `main` and rerun affected validation; old CI cannot prove combined source.

## Next exact action

1. Install Build212 / 0.14.45 on iPhone 15 Pro Max / iOS 17.0 and export the **App log** after reproducing Home vertical scrolling and library/favorites/search/tag/person 3×3 scrolling.
2. For Home hitches, correlate `image_source`, `image_role`, image item/type/MaxWidth, `callback_duration_ms` and `contrast_duration_ms` with the motion-gated frame gap before changing runtime behavior.
3. Obtain at least one real `phase=dragging` or `phase=decelerating` grid hitch before changing a shared grid path; the Build210 `phase=moving / delta_y=0.33` record remains insufficient.
4. Keep poster work out of carousel owner files while Build211 is active; if Build212 proves the synchronous carousel callback/contrast path causal, reconcile the two tasks explicitly before a runtime patch.
5. Preserve P0 playback/transport/cache/session contracts and iOS 15.0 deployment.

## Do not repeat

- Treating Build202/204 as performance successes because CI/IPA passed.
- Treating Build209 zero grid hitches as evidence the library grid is smooth.
- Replacing `LazyVGrid` without trace evidence.
- Adding another image cache/decoder or lowering images below rendered device pixels.
- timer/debounce/throttle/watchdog/retry/fallback.
- Refactoring NavigationLink or carousel gesture ownership without direct evidence.
- Touching Player / MPV / PiP / Transport / Cache / Session contracts.
