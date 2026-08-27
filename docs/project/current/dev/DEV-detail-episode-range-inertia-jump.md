# DEV-detail-episode-range-inertia-jump

## Status

**Active — Build216 / OnePlayer 0.14.49 implementation complete; static contracts passed; Xcode Release CI/IPA pending.**

- **Work ID**: `DEV-detail-episode-range-inertia-jump`
- **Routing aliases / keywords**: 详情页选集惯性 / 跳集区间按钮 / 即将播放跳集 / episode range inertia / detail episode jump
- **Task**: 详情页横向剧集卡正在惯性滑动时，点击“即将播放”右侧区间按钮必须立即停止当前横向惯性，然后执行既有区间选择与滚动定位逻辑。

## User requirement / acceptance

1. 下方详情剧集横向 ScrollView 正在 decelerating 时，点击任一区间按钮不能被惯性吞掉。
2. 点击区间按钮后先在当前可见位置立即冻结横向惯性，再执行既有 `selectEpisodeRange` + 目标集滚动逻辑。
3. 非惯性状态下区间按钮行为保持 Build191 accepted contract：选中目标区间第一集、蓝框/摘要/主 Play target 同步。
4. 不改变 canonical episode order、SeasonId grouping、完整选集页、Player episode overlay、播放 session owner、Build182 detail Hero/cache owner。
5. 不增加 timer/watchdog/retry/debounce/throttle/fallback 或第二套选集状态。
6. Deployment Target 保持 iOS 15.0；目标真机 iPhone 15 Pro Max / iOS 17.0。

## Baseline / identity

- **Accepted overall baseline**: OnePlayer **0.14.46 / Build213**.
- **Current main at task creation**: `81ab52793d9fd64ffcef7302c6e0b2d71754ac75`.
- `main` later advanced to `bab40171b678019c5b672b33b1a1ae159afa65e0` only by registering this task checkpoint; no product source changed after the branch base.
- Accepted Build191 detail selection/navigation contract remains stable and is inherited.
- **Working branch**: `fix/detail-episode-range-inertia-build216`.
- **Branch base**: `main@81ab52793d9fd64ffcef7302c6e0b2d71754ac75`.
- **Current branch head**: `749fea5cf755fc48c2b2df5bd3a995c7fdc2678d`.
- Functional source commits: `0280e97c8fd65d57fa8e347fe7d8ac97407a4785` + lifetime cleanup `84ee048d1e8933ea8eedeaabb0b6c84324fb5768`.
- **PR**: none yet.
- **Build candidate**: **OnePlayer 0.14.49 / Build216**.
- **Target artifact**: `OnePlayer-0.14.49-build216-detail-range-inertia`.

## Source evidence / implemented fix

Original `Sources/UI/EmbyMediaDetailView.swift`:

- `upcomingEpisodesSection` owns a `ScrollViewReader` and a separate horizontal episode-card `ScrollView` / `LazyHStack`.
- range pills invoke `jumpToEpisodeRange(range, proxy:)` through the existing high-priority tap gesture.
- `jumpToEpisodeRange` previously called `model.selectEpisodeRange(...)`, resolved the range-first target, then asynchronously ran animated `proxy.scrollTo(...)`.
- there was no reference to the actual underlying horizontal `UIScrollView` and no deceleration cancellation before the programmatic range jump.
- therefore an in-flight native deceleration remained a competing `contentOffset` owner when the range jump started.

Build216 implementation:

- new `Sources/UI/EmbyDetailEpisodeScrollControl.swift` adds one detail-only `EmbyDetailEpisodeScrollController` and `EmbyDetailEpisodeNativeScrollProbe`.
- the probe is attached inside the existing episode-card `LazyHStack`, so its nearest ancestor is the existing horizontal native `UIScrollView`; the SwiftUI ScrollView itself is not replaced.
- controller stores only weak `UIView` / `UIScrollView` references and follows the existing project `UIViewRepresentable` + Coordinator attachment pattern.
- `stopDeceleration()` is synchronous on the main thread and is a no-op unless `scrollView.isDecelerating == true`; when active it executes `scrollView.setContentOffset(scrollView.contentOffset, animated: false)` to freeze at the currently visible native offset.
- `jumpToEpisodeRange` now calls `episodeScrollController.stopDeceleration()` before reading/updating range selection state. Existing `model.selectEpisodeRange`, target resolution, 0.32 s `ScrollViewReader.scrollTo` animation, selected-ID/title/Play semantics remain unchanged.
- existing `EpisodeRangeJump` diagnostic adds `stoppedDeceleration=true/false` for target-device attribution; no new periodic logging/state exists.
- `AppIdentity` is 0.14.49 and changelog `CHANGELOG_v0_14_49_build216.md` is present.

## Validation so far

Patch application/static run `33061880059` completed successfully on the exact Build216 source line before temporary patch-helper cleanup:

- `scripts/check_detail_episode_selection_navigation.py`: PASS, including new ordering contract that native deceleration stop occurs before `model.selectEpisodeRange(...)`.
- `scripts/check_detail_page_performance.py`: PASS.
- `git diff --check`: PASS.
- final durable branch diff after helper cleanup is only:
  - `Sources/Core/AppIdentity.swift`
  - `Sources/UI/EmbyDetailEpisodeScrollControl.swift`
  - `Sources/UI/EmbyMediaDetailView.swift`
  - `docs/changelog/CHANGELOG_v0_14_49_build216.md`
  - `scripts/check_detail_episode_selection_navigation.py`

## Parallel conflict guard

Current other Active tasks at creation:

- `DEV-home-carousel-drag-smoothness` — owns Home carousel UIKit/state/Hero/Core files; no detail source overlap.
- `DEV-poster-grid-smoothness` — owns shared poster-image diagnostics/grid paths; no detail source overlap.
- `DEV-aether-multi-engine-comparison` — playback-engine feasibility; no detail source overlap.

Build215 is occupied by Home carousel. Build216 / 0.14.49 had no repository/index/branch allocation when reserved here.

## Frozen / do-not-touch

- Build182 `EmbyDetailHeroScrollState` / persistent detail presentation cache semantics.
- Build191 selected-episode owner and default/range selection semantics except for the required pre-jump deceleration stop.
- Build195 player episode grouping/lazy row.
- Build178 canonical Emby episode order.
- Player/MPV/PiP/UnifiedTransport/Range/206/playback cache/Emby Resume/session/STRM→302→115/CDN client-direct.
- native navigation ownership.

## Evidence level

- User real-device bug report: **YES** — accepted/current behavior fails when episode-row inertia is active.
- Source cause identified: **YES** — no native deceleration cancellation existed before `scrollTo`.
- Code written: **YES**.
- Narrow static/source contracts: **PASS**.
- Xcode Release CI passed: **NO — pending**.
- IPA produced: **NO — pending**.
- Fix real-device tested: **NO**.
- Stable/frozen: **NO**.

## Next exact action

Run a dedicated Xcode 16.4 standard MPV Release Build216 workflow from the durable source, validating 0.14.49 (216), MinOS 15.0, detail inertia ordering + inherited Build191/Build182/Build178/Build195 contracts and frozen P0 file scope. Package `OnePlayer-0.14.49-build216-detail-range-inertia`, remove the temporary Release helper afterward, then provide the IPA for target-device testing. Real-device acceptance must specifically test repeated fast horizontal swipes followed by range-pill taps during active deceleration.