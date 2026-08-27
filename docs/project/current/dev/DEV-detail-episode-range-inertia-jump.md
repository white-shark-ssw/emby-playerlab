# DEV-detail-episode-range-inertia-jump

## Status

**Active — Build216 / OnePlayer 0.14.49 CI passed and IPA produced+verified; target-device test pending.**

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

- **Accepted overall baseline**: OnePlayer **0.14.46 / Build213**; Build216 尚未经过真机接受，不替换 accepted baseline。
- **Branch base**: `main@81ab52793d9fd64ffcef7302c6e0b2d71754ac75`.
- **Working branch**: `fix/detail-episode-range-inertia-build216`.
- **Tested CI source**: `dc00cac9f35ee4a3b950e4bb030bb324baf90b18`.
- **Current cleanup head**: `f04f09c50b8952596f4f72c7a12e7910938c99e1` — subsequent commits only removed the temporary Build216 Release workflow and added/removed a one-shot docs-index helper; product/runtime source is unchanged from tested source.
- **PR**: none yet.
- **Build candidate**: **OnePlayer 0.14.49 / Build216**.
- **Artifact**: `OnePlayer-0.14.49-build216-detail-range-inertia`.

## Source evidence / implemented fix

Original `Sources/UI/EmbyMediaDetailView.swift`:

- `upcomingEpisodesSection` owns a `ScrollViewReader` and a separate horizontal episode-card `ScrollView` / `LazyHStack`.
- range pills invoke `jumpToEpisodeRange(range, proxy:)` through the existing high-priority tap gesture.
- `jumpToEpisodeRange` previously called `model.selectEpisodeRange(...)`, resolved the range-first target, then asynchronously ran animated `proxy.scrollTo(...)`.
- there was no reference to the actual underlying horizontal `UIScrollView` and no deceleration cancellation before the programmatic range jump, so in-flight native deceleration remained a competing `contentOffset` owner.

Build216 implementation:

- new `Sources/UI/EmbyDetailEpisodeScrollControl.swift` adds one detail-only `EmbyDetailEpisodeScrollController` and `EmbyDetailEpisodeNativeScrollProbe`.
- the probe attaches inside the existing episode-card `LazyHStack`; the SwiftUI ScrollView itself is not replaced.
- controller stores only weak `UIView` / `UIScrollView` references and follows the existing project `UIViewRepresentable` + Coordinator attachment pattern.
- `stopDeceleration()` is synchronous on the main thread and no-ops unless `scrollView.isDecelerating == true`; when active it calls `scrollView.setContentOffset(scrollView.contentOffset, animated: false)` to freeze the row at the currently visible offset.
- `jumpToEpisodeRange` calls `episodeScrollController.stopDeceleration()` before the existing `model.selectEpisodeRange(...)`; target resolution, 0.32 s `ScrollViewReader.scrollTo` animation, selected-ID/title/main-Play semantics remain unchanged.
- `EpisodeRangeJump` diagnostics include `stoppedDeceleration=true/false` for real-device attribution.
- no timer/watchdog/retry/debounce/throttle/fallback or second episode-selection owner was added.

## Compile correction evidence

- First formal Build216 run/job `33062479997 / 98484394549` passed all static/scope contracts but failed at Xcode Release compile; no IPA was produced from that run.
- Exact new-source review showed `EmbyDetailEpisodeScrollProbeUIView` was declared `private` while it is the return/argument type of `UIViewRepresentable` protocol witnesses.
- The same pattern was reproduced with the available Swift 6.2.1 compiler, which reports `method must be declared fileprivate because its result uses a private type`; project precedent `AdaptiveHeroScrollProbeUIView` is internal.
- Compile-only correction commit `dc00cac9f35ee4a3b950e4bb030bb324baf90b18` removes only the `private` access modifier from the probe UIView. Runtime behavior is unchanged.

## Successful Build216 CI / IPA

- **Run / job**: `33064051545 / 98489652724` — success.
- **Tested source**: `dc00cac9f35ee4a3b950e4bb030bb324baf90b18`.
- Passed Build216 exact-delta/Frozen scope, detail selection/range/performance/Hero, SeasonId/player grouping, canonical series ordering, Xcode 16.4 standard MPV Release, bundle identity **0.14.49 (216)**, built MinOS **iOS 15.0**, and IPA archive integrity.
- **Artifact ID**: `9643031850`.
- **Artifact digest**: `sha256:9cbccc582be719b2daa10077293da2951f0cbce8016625128de8ef9d85b27f48`.
- **IPA**: `OnePlayer-0.14.49-build216-detail-range-inertia-unsigned.ipa`.
- **IPA SHA-256**: `e3054a53398e1df48134fecd8c30671e10ecaa8a93df5483936adcf10e055075`.
- **Source ZIP SHA-256**: `98e1b5b52ebe5d8b2e3fbf754d3dfb18d0ea082fd77bcd9e6905b0bcb56e0f6f`.
- `BUILD_TEST_INDEX.md` now records Build216 as **CI/IPA verified / real-device pending**; accepted baseline remains Build213.

## Parallel conflict guard / frozen boundaries

Other Active tasks remain isolated from this detail task. Build215 is owned by Home carousel; Build216 / 0.14.49 is uniquely owned here. Build182 detail Hero/presentation cache, Build191 selected-episode semantics, Build195 player episode grouping/lazy row, Build178 canonical order, native navigation and all Player/MPV/PiP/UnifiedTransport/Range/206/playback-cache/Emby Resume/session/STRM→302→115/CDN client-direct paths remain untouched.

## Evidence level

- User real-device bug report: **YES** — accepted/current behavior fails when episode-row inertia is active.
- Source cause identified: **YES**.
- Code written: **YES**.
- CI passed: **YES** — run `33064051545`.
- IPA produced+verified: **YES** — artifact `9643031850`, IPA SHA above.
- Fix real-device tested: **NO — pending**.
- Stable/frozen: **NO**.

## Next exact action

Install Build216 on iPhone 15 Pro Max / iOS 17.0. Repeatedly fling the detail episode row horizontally and, while it is visibly decelerating, tap several different range pills. Acceptance requires the row to stop its current inertia immediately and then perform the requested range jump every time; also verify ordinary non-inertia range taps, selected blue frame/summary/main Play target and full episode picker remain unchanged. If accepted, record the real-device result, merge via an isolated PR, promote the durable decision/project docs, and delete this task checkpoint.