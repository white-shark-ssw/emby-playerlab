# DEV-poster-grid-smoothness

## Status

**Active — Build229 / 0.14.62 is now target-device tested and overall Library 3×3 hitching still exists. The latest captured 77.2 ms moving hitch occurred about 7.3 s after page apply/snapshot completion and about 0.77 s after the latest image publish, so Build228’s synchronous snapshot write is not the direct trigger for this sample and moving Library persistence off MainActor is not sufficient to solve the whole hitch family. Poster branch head `deba1534e55bfc73f4d3cf43f2682c854a04cb39` materialized a diagnostic-only 0.14.66 / Build233 commit, but Build233 is already owned by the independent Home carousel task; resume identity guard therefore fails and poster development is paused until this candidate identity is explicitly released/reallocated. Not stable.**

- **Work ID**: `DEV-poster-grid-smoothness`
- **Routing aliases / keywords**: 3×3页面流畅度 / 3列海报流畅度 / 库页流畅度 / 海报网格优化 / poster grid smoothness
- **Working branch**: `perf/poster-grid-smoothness`
- **Draft PR**: #259
- **Target device**: iPhone 15 Pro Max / iOS 17.0
- **Accepted overall baseline**: OnePlayer **0.14.49 / Build216**, PR #261, merge `f5ad126b7b47e9713b1949780a6507fb3f0ca50f`

## Build229 latest target-device result / candidate identity guard — 2026-08-29

Build229 / OnePlayer 0.14.62 was exercised again on the target device and the user still reports visible jitter. The latest App-log evidence contains a **77.2 ms** `PosterScrollHitch` on the Library grid. At that hitch, the latest Library page apply and awaited snapshot completion were already about **7.3 s** old, while the latest image publish was about **0.77 s** old. The captured sample is `phase=moving`, `velocity_y=0`, `delta_y=1.33`, so it is a real long-frame/catch-up sample but not pagination-adjacent.

Controlling interpretation: Build228’s 39.7 ms synchronous Library snapshot write remains a valid contributor to the earlier severe pagination-adjacent sample, but Build229 proves that removing that main-thread write is **not sufficient** to remove the broader 3×3 hitch family. This 77.2 ms sample does not support direct attribution to page apply, snapshot persistence, or the latest image publication because all three are far outside the hitch window. Pagination-specific improvement from Build229 is still not established by this sample.

Resume identity guard on 2026-08-29 also found a hard candidate collision:

- checkpoint branch remains `perf/poster-grid-smoothness`, Draft PR #259;
- real branch / PR head is `deba1534e55bfc73f4d3cf43f2682c854a04cb39`, commit `Add Build233 poster background-work diagnostics`, directly parented by Build229 exact source `f5e3e3eb144578c863b172e3bd3a1aa13e5c2177`;
- that head changes poster diagnostics/version/changelog to **0.14.66 / Build233** but has no valid poster CI/IPA attribution;
- independent Active task `DEV-home-carousel-drag-smoothness` already owns OnePlayer **0.14.66 (233)** and has CI/IPA evidence for that identity;
- Home also allocated Build234 and Aether currently reserves Build235, so poster must not silently rename itself to another number without a fresh collision check.

**Identity guard result: FAILED.** Do not run/distribute poster Build233, do not call it a poster candidate, and do not modify product source until the user explicitly resolves the candidate collision.

**Evidence:** Build229 Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅ / overall hitch still present ❌ / pagination-specific improvement unproven / stable ❌. Poster `deba1534...` code exists, but candidate identity is invalid and no poster CI/IPA should be claimed.

**Pending:** explicit user decision to release the invalid poster Build233 identity and allocate a new unique poster candidate after rechecking all Active checkpoints / `BUILD_TEST_INDEX.md`.

**Next exact action:** after explicit resolution, restore a unique poster candidate identity from the current branch evidence, rerun exact-scope/source guards, then build the existing background-work diagnostic instrumentation to a verified IPA. Until then, no product-source edits.

## Build228 real-device result / Build229 candidate — 2026-08-28

Build228 / OnePlayer 0.14.61 exact source `20f0edaf30c3c9161a79f64fd29dbc79c199473e` was tested on iPhone 15 Pro Max / iOS 17.0. User verdict: **“还是会有抖动感，有的时候还很强烈”**. Build228 is diagnostic-only and is rejected as a smoothness fix.

Uploaded App log `OnePlayer-App-1787905589.log` contains a real **55.1 ms** `scroll_route=grid`, `phase=dragging`, `delta_y=6.0` long frame during the `StartIndex=60` pagination window. Build228's new timing separates the nearby synchronous work:

- image publish / synchronous Combine→UIKit adoption: **0.0 ms** for the latest correlated publish;
- pagination result apply: **0.3 ms**;
- Library persistent snapshot serialization + atomic write: **39.7 ms**, completing about **8 ms** before the hitch.

The supplied 30 fps screen recording confirms the user's visible/tactile jitter report but its file timestamp does not align with that exact logged 55.1 ms event, so the log — not frame matching — controls attribution.

This is direct evidence that Build213's synchronous Library presentation-snapshot persistence can materially block the current pagination-adjacent scroll path. It is **not** evidence that persistence is the universal historical root cause: Build212 captured the same grid-hitch family before Build213 existed.

Build229 / OnePlayer **0.14.62 (229)** is the minimum evidence-supported candidate. Exact source: **`f5e3e3eb144578c863b172e3bd3a1aa13e5c2177`**. Exact Build228→Build229 delta is five paths only: `AppIdentity`, `EmbyPagePersistentCache`, `EmbyServerBrowseV3`, Build229 changelog and poster checker. The `@MainActor` Library model still captures one immutable snapshot in current state order; only Library snapshot object→JSON conversion, JSON serialization and `.atomic` disk write run on one serial `.utility` queue, and the async caller awaits completion. Favorites persistence, cache schema/identity/content, image policy, Home carousel owner files, Player/MPV/PiP, Transport, playback Cache/Session and all P0 contracts are unchanged.

Build229 CI / IPA evidence:

- exact-source run/job: **`33156266871 / 98799654927` — success**;
- Xcode 16.4 Release + exact five-path scope/checker: PASS;
- artifact: `OnePlayer-0.14.62-build229-poster-snapshot-off-main`; ID **`9679803873`**;
- artifact ZIP SHA-256: `8b301f7644f0dfb7e1fb80dba78069f870123c663ba5b323edc93a1e88f067b2`;
- IPA SHA-256: `49efcb8766cc9414a3f35e3d8fe75a04eaf6adf2ba86a40f526a5e53c40acd4c`;
- source ZIP SHA-256: `1de13e01617a575bf5b204e9dd546af443b8a7fdf79003e3eba1399edfb06e5a`;
- bundle/version/build: `com.embyplayerlab.app`, OnePlayer **0.14.62 (229)**; `MinimumOSVersion=15.0`;
- artifact/IPA/source integrity independently verified; source snapshot contains no temporary Build229 workflow.

**Build229 evidence: Code written ✅ / exact scope+checker ✅ / CI passed ✅ / IPA produced+independently verified ✅ / target-device tested ✅ / overall hitch still present ❌ / pagination-specific improvement unproven / stable or frozen ❌.**

Next target-device A/B should repeat Library 3×3 scrolling through a real pagination boundary. The key question is whether the severe pagination-adjacent hitch disappears or materially shrinks. Do not claim the remaining non-pagination hitch family solved without new device evidence.

## Build229 Home-only supporting capture — 2026-08-28

The user immediately supplied a second target-device recording/log after Build229, but this capture is **Home vertical scrolling**, not the intended Library 3×3 pagination A/B. It therefore does **not** promote Build229 to target-device-tested for its Library persistence change. At this historical point the intended Build229 Library test was still pending; the later 2026-08-29 Library result above supersedes that status.

Uploaded files: `OnePlayer-App-1787907572.log` and `RPReplay_Final1787907569.mp4`. The App log contains only five `HomeCarousel settled` records and no `PosterScrollHitch`, pagination, Library snapshot read/write, or page-apply records. The 15.47 s / 30 fps recording spans approximately 08:59:13.53Z–08:59:29.00Z by filename time. Two carousel settles fall inside that span at approximately +5.214 s (`item=143014`) and +12.211 s (`item=143013`). Frame-motion inspection shows near-zero/duplicate-frame → catch-up patterns shortly after both settle points, with the cleaner second sequence around +12.30–12.37 s. Because the recording itself is only 30 fps and the App log emitted no `PosterScrollHitch`, this is **supporting correlation, not proof of a 60–70 ms app-main-thread stall**.

Exact Build229 source keeps the normal Home carousel timer on `.main`; `autoAdvanceCarouselIfNeeded()` starts a 0.62 s transition and schedules `settleCarousel` after 0.63 s. `settleCarousel` synchronously mutates `currentCarouselItemID`, transition IDs/progress/direction, drag state and `carouselLastSettledAt`, then logs `HomeCarousel settled`. Those state changes can invalidate Home presentation, so the approximately 7 s recurring settle cadence is a plausible contributor to a periodic “sudden twitch” subtype. However Build222 already blocked new automatic carousel transitions after Home left the top and the user still perceived Home vertical hitching, so offscreen auto-advance/settle is already rejected as the **sole or sufficient** explanation for Home vertical jitter. Do not repeat Build222 as a blind fix.

Current interpretation: Build228's 39.7 ms synchronous Library write remains a valid contributor to the severe **Library pagination-adjacent** sample, while this new Home-only capture points to a separate periodic Home presentation/state-update correlation. The two paths must remain separate until route-specific device evidence proves otherwise.

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

## Build212 target-device result — 2026-08-27

Latest App log: `OnePlayer-App-1787813666.log`.

Build212 emitted **18** motion-gated `PosterScrollHitch` records: 6 Home and 12 grid. The useful user-drag samples split cleanly by route.

### Home

- **5 real `phase=dragging` hitches**, frame gaps **43.6–73.8 ms**.
- All 5 latest image publishes were `image_source=memory`, `image_role=callback`, `image_type=Primary`, `image_max_width=1400`.
- Image publish age at the hitch was only **8.3–12.2 ms**.
- The measured synchronous callback duration was only **1.0–3.2 ms**; measured Core Image contrast render was only **1.0–3.0 ms**.
- Latest ordinary poster-cell appearance was already **7.3–21.9 s** old.
- The log also shows `HomeCarousel settled` events around the same repeating transition cadence. Some image items produce a hitch before settle and another shortly after settle, consistent with more than one carousel image consumer publishing the same memory-resident 1400px artwork during a transition.

Conclusion: the previous suspicion that `CIContext.render` / `onImageLoaded` synchronous work itself explains the 40–70 ms Home stall is **rejected**. Their measured duration is too small. The stronger Home lead is the carousel's 1400px memory-hit image publication / SwiftUI presentation work while the user is vertically scrolling, including when the Hero is far above the visible scroll position. This is Home-specific and overlaps the independent carousel owner.

### Grid

- **11 real `phase=dragging` hitches**, frame gaps **31.0–37.3 ms**.
- All 11 latest image publishes were `image_source=network`, `image_role=display`, `image_type=Primary`, `image_max_width=378`.
- Image publish age at the hitch was **0.0–20.1 ms**.
- Latest grid-cell appearance was only **118.8–177.8 ms** old.
- Carousel callback/contrast events were stale by **13.6–39.9 s** and therefore unrelated to these grid stalls.
- Pagination/load-ahead timing is not the common trigger; the repeated pattern is newly visible grid cells plus display-image publication during active dragging.

Conclusion: Build212 finally proves the user's library/grid hitch during actual dragging and ties it to the display-only poster image publish/render path, not to the Home carousel callback path.

### Architectural consequence

The earlier assumption that Home and all 3×3 routes require one universal root cause is no longer supported. Treat them as two independent runtime fixes:

1. **Home**: reconcile with `DEV-home-carousel-drag-smoothness` before touching carousel owner files; investigate suppressing unnecessary offscreen carousel image presentation work rather than contrast-analysis optimization.
2. **Grid**: inspect the shared display-only poster publish/render path for the smallest change that avoids 31–37 ms main-thread presentation stalls while preserving exact rendered pixel width, image count, navigation and no throttle/debounce/timer behavior.

**Build212 evidence: Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device diagnostic tested ✅ / Home callback/contrast as primary cost rejected ✅ / real grid dragging stalls captured ✅ / two-route cause split established ✅ / runtime fix not yet tested / not stable.**

## Build218 / 0.14.51 — target-device result

Exact tested source: **`ccc3a69f3b77c56a730593f072a2c7dfde599073`**. CI run/job **`33066739271 / 98498551491`** succeeded; artifact ID **`9644109849`**; artifact ZIP SHA-256 `16096a2c3a1b4dcb4ed3bcfa8524e3839f9114eb040e7ee419279555c1e71c4e`; IPA SHA-256 `104eb5266c304102c912eaa2b9e95a4f0ae6183b0bf071fd377b3a52ea8d57bc`; source ZIP SHA-256 `41dfb97a0bfd38cb65ed000b3f9fc2679dc7bf471abe7635020895a5f4f12b90`; OnePlayer 0.14.51 (218), MinOS 15.0 independently verified.

Target-device evidence supplied 2026-08-27:

- User report: **Home still has obvious vertical jitter**. This is the highest-priority evidence and Build218 must not be described as a Home fix.
- Recording `RPReplay_Final1787833032.mp4`: 510×1108, 30fps, 691 frames, ~23.03s. Frame-to-frame crop translation retains clear stop/catch-up examples: around 6.50s movement is ~2.85 recorded px, 6.53s ~0, 6.57s ~11.98px; around 20.13s ~1.14px, 20.17–20.20s ~0, then 20.23s ~9.07px. 30fps remains only a lower-bound observation of the 120Hz device.
- This test only establishes the Home result. The user did not provide a 3×3 grid A/B result in this turn, so Build218 grid effectiveness remains pending.
- Screenshot shows a rectangular background behind the carousel movie Logo. Exact source proves `Sources/UI/EmbyHomeHeroV3.swift` is byte-identical between accepted Build216 main and Build218 (`8a2d5ec00cdd2daa3ef116930e388f18791b580b`). The Logo call uses `EmbyCachedRemoteImage(... contentMode: .fit, showsLoadingIndicator: false)` with no callback, so Build218 routed it through the new poster-task UIKit display surface. That surface kept `backgroundColor = .secondarySystemBackground` even after a transparent Logo loaded, unlike the prior SwiftUI path where that background existed only while no image was present. Therefore the white rectangle **is a Build218 shared-image regression**, not a carousel-owner change.
- Minimal correction now written on poster branch head **`ac8a8cd0b87c4ee544c8817fec13edeea226826b`**: when the UIKit surface has an image, its background becomes `.clear`; when image is nil it keeps `.secondarySystemBackground`. No Home carousel owner source is touched.

**Evidence now: Build218 code/CI/IPA ✅ / Build218 Home target-device tested and still hitches ❌ / Build218 grid A/B pending / Build218 distributed package has a confirmed transparent-Logo regression ❌ / transparency correction code written ✅ / corrected source CI/IPA pending / not stable.**

## Build220 / 0.14.53 — corrected grid UIKit A/B candidate

Build220 is the Build218 grid/display-only UIKit experiment resynchronized onto the accepted Build216 overall runtime baseline, plus the one-line transparent-image presentation correction. Poster Build219 was retired before distribution when the independent carousel task claimed that identity.

- exact tested source: **`6198466a749a54603a67c6c32bc0efcf9d7e2082`**
- accepted-main comparison base used for exact scope: `6a3f52bd8b91995a01f0c908887ffb375d8ec737`
- exact product/check delta: seven poster paths only (`AppIdentity`, person poster policy, `EmbyPosterGrid`, shared poster sizing, shared image/diagnostics, Build220 changelog, poster checker)
- no `EmbyHomeCoreV3.swift`, `EmbyHomeHeroV3.swift`, `EmbyHomeCarouselStateV3.swift`, `EmbyHomeCarouselInteractionV3.swift`, Player or Transport changes
- shared UIKit display surface preserves `secondarySystemBackground` only while image is nil and switches to `.clear` once an image is present, restoring transparent Logo semantics without modifying carousel owner code
- run/job: **`33083504023 / 98556783889` — success**
- artifact: `OnePlayer-0.14.53-build220-poster-grid-uikit-transparent`; ID **`9651230376`**
- GitHub artifact digest / independently downloaded ZIP SHA-256: **`fc1cd17fe974b6e35b2eda03eb32718ca3fca6fa4034406016385a9aa5c1f729`**
- IPA SHA-256: **`a73a33866745418663d1dcc35634f5b21b0a73436a91f40ed8a4f6dc6bbcf574`**
- source ZIP SHA-256: **`7c222973433e8e94608946fc5ffda4e5ec4442a9c6200be4b98e84d680695fad`**
- artifact ZIP, IPA and source ZIP integrity: PASS; embedded SHA files match independent calculation
- built identity: `com.embyplayerlab.app`, OnePlayer **0.14.53 (220)**, `MinimumOSVersion=15.0`; primary/alternate icon metadata present
- exact source snapshot contains the clear-background regression fix and no Build220 temporary workflow
- one-shot Build220 build helper self-cleaned successfully

**Evidence: Code written ✅ / synchronized exact 7-path scope + checker ✅ / CI passed ✅ / IPA produced + independently verified ✅ / target-device tested ✅ / user reports 3×3 basically unchanged ❌ / stable or frozen ❌.**

Target-device test must explicitly cover Library 3×3, Favorites, Favorites → More, Search, Tag and Person/Actor grids. Home may be checked only for regression; Build218 already proved this poster candidate does not solve the separate Home hitch path.

### Build220 target-device result — 2026-08-27

User verdict on the intended 3×3 scrolling A/B: **“体感来说：基本一样”**. This is the controlling real-device result; Build220 must not be described as a grid smoothness improvement.

Uploaded App log: `OnePlayer-App-1787845216.log`. It is short but contains two `PosterScrollHitch` records on the grid route:

1. **33.3 ms**, `phase=dragging`, `offset_y=3506.00`, `delta_y=5.33`, `visible=12`. The latest poster event was item `29670` only **171.7 ms** earlier and is also the load-ahead trigger. The latest image commit was item `29668`, `Primary`, `MaxWidth=378`, `source=network`, `role=display`, **35.8 ms** before the hitch. The `StartIndex=60` page request began about **164 ms** before the hitch.
2. **74.1 ms**, `phase=moving`, `offset_y=3639.33`, `delta_y=1.00`, `velocity_y=0.0`. The latest image commit was already **1010.1 ms** old and the latest cell/load-ahead event **1146.1 ms** old, so this second sample is not evidence of an immediate image-publish trigger and is weaker than the dragging sample for user-touch attribution.

Exact Build220 source matters for interpretation. The display-only path no longer makes the surrounding SwiftUI poster cell observe loader image changes, but `EmbyCachedImageLoader` still performs `self.image = loaded` on the MainActor. That `@Published` assignment synchronously delivers to the UIKit surface's Combine sink, which then calls `UIImageView.image = image`. Current diagnostics timestamp `imageDidCommit` only **after** the assignment; they do not measure the assignment/publisher/sink/UI image-adoption duration or bursts of several commits. Therefore Build220 falsifies “SwiftUI poster-cell observation is the primary sufficient cause”, but does **not** yet isolate whether the remaining cost is the MainActor publish/Combine→UIImageView adoption/compositor path.

The first hitch also occurs immediately after grid load-ahead starts `StartIndex=60`. On the accepted Build216 baseline, library pagination applies new items on a `@MainActor` model and then synchronously serializes/writes the persistent page snapshot. That path is worth measuring for this pagination-adjacent sample. However it cannot be the universal historical cause: Build212 captured the same 3×3 hitch family before the Build213 persistent-page-cache milestone existed. Do not replace the image-path evidence with a cache-only theory.

**Build220 evidence now: Code written ✅ / synchronized exact scope+checker ✅ / CI passed ✅ / IPA produced+verified ✅ / target-device tested ✅ / user reports 3×3 basically unchanged ❌ / grid UIKit observation-bypass hypothesis rejected as sufficient ✅ / root cause still unresolved / not stable.**

Next diagnostic should be measurement-only: time the MainActor `@Published image` assignment including synchronous Combine delivery to the UIKit surface, record image-publish bursts around long frames, and separately time pagination result application plus persistent snapshot serialization/write. Do not add another smoothing patch until those costs are separated.

## Parallel safety

- Build211 / 0.14.44 identity is owned by the independent Home-carousel task; poster Build212 does not reuse that identity.
- Build210 does **not** modify `EmbyHomeCoreV3.swift`, `EmbyHomeCarouselInteractionV3.swift`, `EmbyHomeCarouselStateV3.swift` or `EmbyHomeHeroV3.swift`; it reuses Build209's already-present transparent Home/grid probes.
- `EmbySharedImageAndNavigation.swift` is shared infrastructure. Whichever Active task integrates second must resync to then-current `main` and rerun affected validation; old CI cannot prove combined source.

## Next exact action

1. Treat Build220 as a real-device ineffective grid candidate; do not merge or tune the UIKit surface blindly.
2. Add measurement-only diagnostics for MainActor `image` publication / synchronous Combine→`UIImageView` adoption duration and nearby publish bursts.
3. Add separate timing for pagination result application and Build213 page-persistent snapshot serialization/write, because the first Build220 dragging hitch is pagination-adjacent.
4. Preserve Build212 as the historical guardrail: persistent page cache cannot be the universal cause because the grid hitch family predates Build213.
5. Keep Home-carousel ownership separate and do not touch Player / Transport / Cache / Session P0 contracts.

## Do not repeat

- Treating Build202/204 as performance successes because CI/IPA passed.
- Treating Build209 zero grid hitches as evidence the library grid is smooth.
- Replacing `LazyVGrid` without trace evidence.
- Adding another image cache/decoder or lowering images below rendered device pixels.
- timer/debounce/throttle/watchdog/retry/fallback.
- Refactoring NavigationLink or carousel gesture ownership without direct evidence.
- Touching Player / MPV / PiP / Transport / Cache / Session contracts.
