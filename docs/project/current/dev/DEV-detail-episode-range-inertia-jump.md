# DEV-detail-episode-range-inertia-jump

## Status

**Active — Build216 / OnePlayer 0.14.49 reserved.**

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
- Accepted Build191 detail selection/navigation contract remains stable and is inherited.
- **Working branch**: `fix/detail-episode-range-inertia-build216`.
- **Branch base**: `main@81ab52793d9fd64ffcef7302c6e0b2d71754ac75`.
- **PR**: none yet.
- **Build candidate**: **OnePlayer 0.14.49 / Build216**.
- **Target artifact**: `OnePlayer-0.14.49-build216-detail-range-inertia`.

## Source evidence

Current `Sources/UI/EmbyMediaDetailView.swift`:

- `upcomingEpisodesSection` owns a `ScrollViewReader` and a separate horizontal episode-card `ScrollView` / `LazyHStack`.
- range pills invoke `jumpToEpisodeRange(range, proxy:)` through the existing high-priority tap gesture.
- `jumpToEpisodeRange` currently calls `model.selectEpisodeRange(...)`, resolves the range-first target, then asynchronously runs animated `proxy.scrollTo(...)`.
- there is no reference to the actual underlying horizontal `UIScrollView` and no deceleration cancellation before the programmatic range jump.
- therefore an in-flight native deceleration remains a competing `contentOffset` owner when the range jump starts.

Existing `AdaptiveHeroNativeScrollObserver` proves the project already uses a small iOS-15-compatible `UIViewRepresentable` probe to attach to the nearest native `UIScrollView`; this task should use the same narrow UIKit-bridge principle for the episode row rather than replacing the SwiftUI ScrollView.

## Parallel conflict guard

Current other Active tasks at creation:

- `DEV-home-carousel-drag-smoothness` — owns Home carousel UIKit/state/Hero/Core files; no detail source overlap.
- `DEV-poster-grid-smoothness` — owns shared poster-image diagnostics/grid paths; no detail source overlap.
- `DEV-aether-multi-engine-comparison` — playback-engine feasibility; no detail source overlap.

Build215 is occupied by Home carousel. Build216 / 0.14.49 had no repository/index/branch allocation when reserved here.

## Intended minimal scope

Expected product/source scope:

- `Sources/UI/EmbyMediaDetailView.swift` — call the episode-row scroll controller before range selection and attach a probe to the existing horizontal episode ScrollView.
- a small detail-only UIKit bridge/controller file if needed, to hold only a weak reference to that UIScrollView and synchronously stop native deceleration.
- `Sources/Core/AppIdentity.swift` only when producing Build216.
- `scripts/check_detail_episode_selection_navigation.py` or one narrow new checker for the inertia-stop ordering contract.
- Build216 changelog/CI helper only when the candidate is ready.

## Frozen / do-not-touch

- Build182 `EmbyDetailHeroScrollState` / persistent detail presentation cache semantics.
- Build191 selected-episode owner and default/range selection semantics except for adding the required pre-jump deceleration stop.
- Build195 player episode grouping/lazy row.
- Build178 canonical Emby episode order.
- Player/MPV/PiP/UnifiedTransport/Range/206/playback cache/Emby Resume/session/STRM→302→115/CDN client-direct.
- native navigation ownership.

## Evidence level

- User real-device bug report: **YES** — current behavior fails when episode-row inertia is active.
- Source cause identified: **YES** — no native deceleration cancellation exists before `scrollTo`.
- Code written: **NO**.
- CI passed: **NO**.
- IPA produced: **NO**.
- Fix real-device tested: **NO**.
- Stable/frozen: **NO**.

## Next exact action

Inspect the smallest iOS-15-safe native episode-scroll control, implement synchronous deceleration cancellation immediately before the existing range-selection/jump path, add a narrow source contract, review exact diff/Frozen boundaries, then build Build216 only after the product patch is complete.