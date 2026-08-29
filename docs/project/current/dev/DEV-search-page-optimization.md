# DEV-search-page-optimization

- Status: Active — Build250 target-device recommendation rejected; Build251 global-Suggestions correction code written, CI/IPA pending
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
- Build251 runtime source after direct correction: `cc1806d7f606581e138579b44d94e16dc9ff7135`
- Built/target MinOS: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0

## Accepted Search Dock baseline

Build248 target-device testing confirmed the Search Dock position matches the other server pages and focusing the Search input no longer moves it. Preserve this behavior unchanged.

## Build250 target-device result — 2026-08-30

The user installed Build250 and reports that `推荐观看` still remains on the spinner. No additional app log is required for the next correction because the user supplied stronger comparative evidence: the same Emby account/server opened in the official Emby web client enters Search and immediately displays the built-in `更多推荐` content, with normal movie/series titles.

This new real-device/web evidence changes the implementation direction. The current OnePlayer preloader is still using the correct Emby Suggestions endpoint at the wrong scope: it first loads `UserViews`, then sends `/Users/{userId}/Suggestions` once per library with `ParentId`, potentially serially traversing many libraries. The Emby API implementation already permits the same `/Users/{userId}/Suggestions` request without a `ParentId`, which is the natural user-global Suggestions scope and matches the web Search behavior much more directly.

Build250 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / Dock accepted ✅ / recommendation loading rejected ❌ / not stable**.

## Build251 direct correction — code written

Runtime source `cc1806d7f606581e138579b44d94e16dc9ff7135` makes the minimum evidence-backed change:

- `librarySuggestions` now accepts an optional `ParentId`; when absent it omits the query parameter entirely rather than sending an empty value.
- Search recommendation preload no longer calls `userViews()` and no longer traverses libraries.
- Search makes one user-global `/Users/{userId}/Suggestions` request with `IncludeItemTypes=Movie,Series`, `Limit=9`, and the existing image/user-data fields.
- The existing Movie/Series whitelist remains: if returned `Type` exists it must be Movie/Series; if Emby omits `Type`, the exact server-side `IncludeItemTypes=Movie,Series` request remains the authority.
- Existing startup warm, in-memory result reuse, persistent image cache and decoded-image cache are unchanged.
- New diagnostic shape is one line: `recommendation warm global requested=Movie,Series returned=... nilType=... accepted=...`.

No retry, timeout, timer, watchdog, fallback traversal, second cache, poster-grid edit, Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115, Resume/progress, credentials or Deployment Target change.

Current Build251 evidence: **Code written ✅ / CI passed ❌ pending / IPA produced ❌ pending / real-device tested ❌ / stable/frozen ❌**.

## Next exact action

Compile/package Build251 from exact runtime source, then target-device test first-paint time against the official Emby web Search behavior. The intended request contract is now one global Suggestions call rather than per-library traversal.