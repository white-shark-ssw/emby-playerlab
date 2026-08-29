# DEV-search-page-optimization

- Status: Active — Build251 target-device returned 9 but displayed 0; Build252 CI/IPA verified, target-device pending
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Draft PR: #264
- Build248 identity: **OnePlayer 0.14.81 / Build248** — Dock/keyboard behavior accepted on target device
- Build249 identity: **OnePlayer 0.14.82 / Build249** — recommendation rejected on target device
- Build250 exact successful CI source: `6e7ae960bd3cc353b8d6146aea363f3876e9e8e8`
- Build250 identity: **OnePlayer 0.14.83 / Build250**
- Build250 run/job: `33263279291 / 99128762968` — success
- Build250 artifact: `9717900754`; IPA SHA-256 `f213b3d6f30ac101d563e3894c3352fdcd9c9bcb46c7a266faa48c8577e73ada`
- Build251 exact runtime source: `cc1806d7f606581e138579b44d94e16dc9ff7135`
- Build251 identity: **OnePlayer 0.14.84 / Build251**
- Build251 run/job: `33264608646 / 99132347141` — success
- Build251 artifact: `OnePlayer-0.14.84-Build251-Search`, ID `9718288974`, digest `sha256:da474aaa24a3d8ff65e41ed990b861ba377f6a92938670bfe89a9625d8cc4470`
- Build251 IPA SHA-256: `4923368ddca5bca9e3d9db83234b19547b12673feb22af50fd3e3279b08cc750`
- Built/target MinOS: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0

## Accepted Search Dock baseline

Build248 target-device testing confirmed the Search Dock position matches the other server pages and focusing the Search input no longer moves it. Preserve this behavior unchanged.

## Build250 target-device result — 2026-08-30

The user installed Build250 and reports that `推荐观看` still remains on the spinner. No additional app log is required for the next correction because the user supplied stronger comparative evidence: the same Emby account/server opened in the official Emby web client enters Search and immediately displays the built-in `更多推荐` content, with normal movie/series titles.

This new real-device/web evidence changes the implementation direction. The current OnePlayer preloader is still using the correct Emby Suggestions endpoint at the wrong scope: it first loads `UserViews`, then sends `/Users/{userId}/Suggestions` once per library with `ParentId`, potentially serially traversing many libraries. The Emby API implementation already permits the same `/Users/{userId}/Suggestions` request without a `ParentId`, which is the natural user-global Suggestions scope and matches the web Search behavior much more directly.

Build250 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / Dock accepted ✅ / recommendation loading rejected ❌ / not stable**.

## Build251 global-Suggestions correction

Exact runtime source `cc1806d7f606581e138579b44d94e16dc9ff7135` makes the minimum evidence-backed change:

- `librarySuggestions` now accepts an optional `ParentId`; when absent it omits the query parameter entirely rather than sending an empty value.
- Search recommendation preload no longer calls `userViews()` and no longer traverses libraries.
- Search makes one user-global `/Users/{userId}/Suggestions` request with `IncludeItemTypes=Movie,Series`, `Limit=9`, and the existing image/user-data fields.
- The existing Movie/Series whitelist remains: if returned `Type` exists it must be Movie/Series; if Emby omits `Type`, the exact server-side `IncludeItemTypes=Movie,Series` request remains the authority.
- Existing startup warm, in-memory result reuse, persistent image cache and decoded-image cache are unchanged.
- New diagnostic shape is one line: `recommendation warm global requested=Movie,Series returned=... nilType=... accepted=...`.

No retry, timeout, timer, watchdog, fallback traversal, second cache, poster-grid edit, Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115, Resume/progress, credentials or Deployment Target change.

Build251 passed Xcode 16.4 Release build, identity verification and IPA packaging in run/job `33264608646 / 99132347141`. Artifact `9718288974`; bundle `com.embyplayerlab.app`; OnePlayer `0.14.84 (251)`; `MinimumOSVersion=15.0`; IPA integrity passed; SHA-256 `4923368ddca5bca9e3d9db83234b19547b12673feb22af50fd3e3279b08cc750`.

Build251 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ❌ / stable/frozen ❌**.

## Next exact action

Target-device test Build252. The expected behavior is that the same fast global request now renders its returned 9 recommendations instead of discarding them.


## Build251 target-device result — 2026-08-30

The user installed Build251. The spinner now ends quickly, but no recommendation content appears. Uploaded `OnePlayer-App-1788023908.log` proves the global request itself succeeds: `/Users/{userId}/Suggestions?...Limit=9&IncludeItemTypes=Movie,Series` returned 9 items, `nilType=0`, while the local post-filter accepted 0. Therefore Build251 fixed request scope/latency but still discarded the complete Emby Suggestions payload after receipt.

Build251 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / request latency improved ✅ / recommendation display rejected ❌ / not stable**.

## Build252 correction

Exact product source `dbfd323ec4a14e12dc57293c98b1fe6fbe239c5e` keeps the single user-global Suggestions request with `IncludeItemTypes=Movie,Series` and removes only the incompatible second client-side type rejection. Search now consumes the exact 9-item Suggestions payload returned by that already constrained Emby request. A returned-type histogram diagnostic is retained for evidence; no library traversal, retry, fallback, timer, watchdog, second cache or shared poster-grid change is added.

Build252 / OnePlayer 0.14.85 run/job `33265539007 / 99134824511` passed Xcode 16.4 Release build/package. Artifact `9718566319`, digest `sha256:15343da3075db72f32349250d0dc9a1a7b67ecb325bbcd507ea22276084abb9c`; IPA SHA-256 `b4dd85fb880692e0b24c481d58079d2bb33db1609669d7e93a3244c53fc8e236`; bundle `com.embyplayerlab.app`; MinOS 15.0; IPA integrity passed. Evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ❌ / not stable**.
