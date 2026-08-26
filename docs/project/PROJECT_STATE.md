# OnePlayer Project State

_Last updated after OnePlayer 0.14.32 / Build199 remained the accepted overall functional baseline, Home-carousel Build198 produced a verified IPA but still awaited target-device acceptance, and `DEV-poster-grid-smoothness` received new target-device recording evidence confirming a real shared poster-scrolling hitch. The poster task's original grid-only hypothesis is no longer considered sufficient because the same hitch is visible on Home, which does not use `EmbyPosterGrid`._

## Current functional baseline

The latest **real-device accepted** functional baseline is:

- Product: **OnePlayer**
- Version / Build: **0.14.32 / Build199**
- Canonical branch: `main`
- Final merge PR: **#256**
- Final merge commit: `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`
- Real-device-tested product source / dedicated CI source: `2b5f3bef073754371443c6c7a345657dbfa2a09a`
- Dedicated standard MPV CI run: **32942618979 — success**
- Artifact: `OnePlayer-0.14.32-build199-add-emby-password-sync`
- Artifact ID: `9597143667`
- IPA SHA-256: `8f0f43f62705e5e13ae666cc54d32fd047c596df1d0e9335668b01a25b6eb003`
- Deployment Target / built MinOS: **iOS 15.0**
- Required target device: **iPhone 15 Pro Max / iOS 17.0**
- Evidence: **Code written / CI passed / IPA produced / real-device accepted / stable for accepted Add/Edit Emby requirements / merged to main**

Build199 inherits the accepted player, PiP, transport/cache, Emby episode-ordering, detail-presentation and detail-selection contracts. None of the current scrolling work changes those frozen media contracts.

## Current frozen playback / transport contracts

- MPV remains the normal/main playback engine; MDK remains manual/experimental backup.
- Left/right double-tap Seek must respond immediately; repeated fast double-taps must not wait for debounce accumulation.
- MPV fast Seek uses one native `absolute+keyframes` Seek; do not restore exact-correction loops.
- Real byte demand / HTTP Range is authoritative; never restore `targetTime / duration × fileSize` as a Seek/Transport anchor.
- STRM / HTTP 302 must resolve to client-direct 115/CDN playback; the NAS must never relay media bytes.
- UnifiedTransport / Range 206 / session cache / Emby Resume/progress / abnormal-short-media diagnostics remain protected.
- PiP remains frozen at Build173.
- Native iOS navigation remains system-owned.
- Deployment Target stays 15.0 unless a proven dependency/API incompatibility requires otherwise.

## Accepted UI foundations still inherited

- Build182: detail high-frequency scroll isolation and persistent presentation-only cache — accepted/frozen.
- Build184: detail visual hierarchy — accepted/merged.
- Build191: detail episode selection/navigation — accepted/merged.
- Build195: large player episode list uses `LazyHStack`, full canonical data retained — accepted/merged.
- Build199: Add/Edit Emby + cached-first startup + retained password/iCloud sync — accepted/merged.

## Current parallel development

### Home carousel interaction — Active independent task

`DEV-home-carousel-drag-smoothness` owns **OnePlayer 0.14.31 / Build198** on its own branch/checkpoint.

Current Build198 evidence:

- Working branch: `perf/home-carousel-single-owner-build198`.
- Successful CI / IPA source: `a569155d443433a5f4769dfe506fec6ab9bdd0e6`.
- CI run / job: `32987054824` / `98235720724` — success.
- Artifact: `OnePlayer-0.14.31-build198-home-carousel-single-owner`.
- Artifact ID: `9613342337`.
- IPA SHA-256: `9432928b31898c0c3f05e7e0affb6949c23339a37edd8f14c1d47343ff31f3d8`.
- MinimumOSVersion: 15.0.
- Evidence: **Code written / CI passed / IPA produced + independently verified / real-device pending / not stable**.

Do not reuse Build198 and do not infer carousel acceptance from its CI/IPA.

### Poster / 3-column scrolling smoothness — Active independent task

`DEV-poster-grid-smoothness` is isolated on `perf/poster-grid-smoothness` with draft PR **#259**.

#### New target-device evidence

The user supplied a new recording and explicitly reported visible scrolling jitter/drop-frame feel across:

- Home;
- media-library pages;
- Favorites;
- Favorites → More;
- Search;
- tag search;
- actor/person search;
- and generally all poster-dense 3×3-style pages.

The supplied screen recording is 510×1108, constant 30 fps, 280 frames / 9.333 s. Because the recording itself is 30 fps it cannot measure every 120 Hz frame miss, but it does contain at least one direct stall: around 6.80 s, content motion goes from roughly -2.74 px to 0 px for one recorded frame, then catches up roughly -10.36 px on the next frame. This is consistent with the user's “停一下再追位”的 visible hitch.

#### Scope correction

Home source proves `posterRow` uses a horizontal `ScrollView + LazyHStack + V3PosterCard`; it does **not** use `EmbyPosterGrid`. Therefore the earlier Stage 1 theory that repeated `EmbyPosterGrid` cell wrappers were the shared root cause is falsified as a complete explanation. The small Environment-hoist cleanup may remain, but the task must investigate shared poster-rendering paths.

A source-proven common dependency is `EmbyCachedRemoteImage`. The existing loader already performs memory cache, disk cache, ImageIO downsampling and detached decode, so no duplicate cache/decoder is being added. Static inspection found a concrete redundant state write: ordinary poster images without an `onImageLoaded` consumer still wrote `reportedImageIdentifier`, creating an extra SwiftUI `@State` invalidation after image publication.

Current task branch head: **`069a6064db9ded6fc87954276ac2cde9259f38ca`**.

Current product diff from the task source base contains only:

- `Sources/UI/EmbyPosterGrid.swift` — hoists two stable Environment values from each cell to the grid ancestor;
- `Sources/UI/EmbySharedImageAndNavigation.swift` — ordinary images without callbacks now skip the redundant `reportedImageIdentifier` update; real callback paths preserve callback deduplication/behavior;
- `scripts/check_poster_grid_smoothness.py` — narrow source contract for both changes.

No Player/MPV/PiP/UnifiedTransport/playback Cache/Emby Session file is touched.

Evidence for the current branch is **Code written + exact scoped diff + existing-problem real-device recording**. The recording is not evidence that the new branch fixes the hitch. Current-head CI / IPA / candidate target-device A/B remain pending, and no Build/version candidate is allocated yet.

#### Build198 shared dependency note

Build198 Home Hero also consumes `EmbyCachedRemoteImage` with a real `onImageLoaded` callback. The poster task's new shared-image change preserves that callback path but is still a shared dependency change. Build198's already-built IPA/source evidence remains unchanged. If either task merges first, the other must resync against then-current `main` and rerun affected validation; old CI cannot prove a materially combined source tree.

## Current development direction

Build199 remains the accepted overall functional baseline. The new recording has changed the poster-smoothness task's technical direction: do not spend further effort treating `EmbyPosterGrid` alone as the root cause. Continue auditing shared poster/image/navigation render work, but only make minimal changes where redundant work is proven by real source. Next validation must keep evidence levels separate: compile/CI → IPA → target-device A/B → only then stable/frozen. Protect all frozen playback/transport/cache/PiP/session contracts throughout.