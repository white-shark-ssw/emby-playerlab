# DEV-search-page-optimization

- Status: Active — Build244 target-device tested with partial success; Build245 follow-up is being built
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Draft PR: #264
- Build244 tested source: `0710fa4cf0a59dbf7e6748e951db2e3cddf2b82c`
- Build244 artifact: `OnePlayer-0.14.77-Build244-Search-final`, ID `9714601161`, IPA SHA-256 `a48d317f3caee89564789bca657da8700953f76a58fcff792562bbb67b146d05`
- Current Build245 exact product source: `4c5f286ee870589bd2eac05119a516631a31391a`
- Reserved follow-up candidate: **OnePlayer 0.14.78 / Build245**
- Target device: iPhone 15 Pro Max / iOS 17.0

## Build244 target-device result — 2026-08-29

User installed and tested Build244 and supplied OnePlayer-vs-competitor screenshots. This is authoritative runtime evidence and supersedes the Build244 pending-test state.

What worked / remained usable:

- Search landing page, persistent history chips, recommendation content and the new gear/menu direction are present on-device.
- Search remains isolated from Player/Transport/P0 paths; no playback regression was reported in this Search test.

What must change before acceptance:

1. Search gear icon is too large; user requests **40% smaller**.
2. Focusing the search field still pushes the bottom Dock upward. The Build244 modifier was placed outside the root `GeometryReader`, so the actual geometry that computes Dock placement still reacts to keyboard safe-area changes.
3. If the active Search target set contains exactly one Emby server — either because only one server exists or global search has only one checked server — submitting Search should skip the grouped horizontal-row presentation and enter that server's `更多` 3-column page directly.
4. Build244 recommendation UI was artificially capped at 9 and used collection-type filtering. User requests no such filter/cap: initial display **12** items, then load **6 more** each time the user scrolls toward the end.
5. Build244 landing geometry is visibly oversized/too low compared with the supplied competitor screenshot. Search-owned title, header spacing, input field, history-chip sizing and section positioning must be tightened toward the competitor layout without editing the shared poster-grid owner.

Build244 therefore has evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / rejected as final Search layout ❌ / not stable**.

## Build245 implemented scope

Exact product source `4c5f286ee870589bd2eac05119a516631a31391a` contains only Search-scope follow-up changes plus the Build245 changelog:

- `Sources/UI/EmbySearchExperienceV3.swift`
  - gear font 27 → 16.2 pt (40% reduction), frame 38 → 26;
  - landing title 38 → 32 pt, tighter header spacing and a smaller close control;
  - input field 48 → 36 pt, smaller icon/text sizing and tighter top spacing;
  - history chips 34 → 26 pt with smaller text/padding; Search/history/recommendation vertical spacing tightened;
  - recommendation grid uses the existing `EmbyPosterGrid(horizontalPadding:)` parameter with Search-only 6 pt padding; shared `EmbyPosterGrid.swift` remains untouched;
  - recommendations request 12 initially, no `includeItemTypes` filtering, and `onApproachingEnd` increases the target by 6 and re-requests Emby Suggestions;
  - one active target server returns a direct Search destination and programmatically enters `V3GlobalSearchServerGridView`; multi-server behavior remains grouped horizontal rows + `更多`.
- `Sources/UI/EmbyServerRootViewV3.swift`
  - Search keyboard safe-area ignoring moved from the outer `Group` onto the actual `GeometryReader` so the geometry used for Dock placement should remain full-height while Search owns keyboard focus.
- `docs/changelog/CHANGELOG_v0_14_78_build245.md`
  - replaces the Build244 changelog; changelog directory keeps only the latest Search candidate record on this branch.

No retry, timer, watchdog, fallback, duplicate server/session authority or unrelated refactor was added.

## Source / ownership evidence

- Added-server authority remains `SessionStore.sessions`.
- Per-server route/client authority remains `SessionStore.clientForBestRoute(for:)`.
- Search API remains the real `searchItemsPage` implementation.
- Recommendation API is the real `librarySuggestions(parentId:limit:includeItemTypes:)`; it has no `StartIndex`. Incremental loading therefore increases the requested Limit by 6 and replaces the visible deduplicated prefix, rather than inventing a fake pagination parameter.
- Shared poster/detail contracts remain `EmbyPosterGrid`, `EmbyPosterDetailLink`, and `V3PosterCard`.
- Search does not modify poster-task-owned `EmbyPosterGrid.swift`, `EmbyServerBrowseV3.swift`, `EmbyServerSharedV3.swift`, or `EmbySharedImageAndNavigation.swift`.

## Parallel / candidate guard

- Search branch remains `feat/search-page-optimization`, PR #264.
- Active poster work owns its independent Build243 / 0.14.76 line and shared poster files; Search does not edit those files.
- Aether owns its independent Player/engine candidate and does not overlap Search state ownership.
- Repository search found no existing `Build245`; Search reserves **0.14.78 / Build245** for this follow-up.

## Frozen / do-not-touch

No Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115 client-direct media path, Emby Resume/progress, server credential storage, shared poster-grid owner, or Deployment Target change. Deployment Target remains iOS 15.0.

## Validation state

- Build244: real-device tested and rejected as final for the five issues above.
- Build245 code written: **yes** — exact product source `4c5f286ee870589bd2eac05119a516631a31391a`.
- Local syntax parse of both modified Swift files: **passed**.
- Build245 CI/IPA: dedicated Xcode 16.4 workflow run `33253244567`, job `99102435848` currently in progress.
- Build245 real-device tested: **no**.
- Stable/frozen: **no**.

## Pending

- Complete Build245 Release/IPA CI and verify bundle/version/build/MinOS/checksums.
- Remove temporary Build245 workflow/trigger after successful artifact production.
- Update `BUILD_TEST_INDEX.md`, `MODULE_STATUS.md`, PR #264 and this checkpoint with final Build245 artifact evidence.
- Hand Build245 IPA to user for target-device validation of all five requested corrections.

## Next exact action

Wait for run `33253244567` to finish. If successful, independently download/verify **OnePlayer 0.14.78 / Build245**, clean temporary CI files, sync project docs/PR evidence, and hand the IPA to the user. If compilation fails, inspect the first real compiler error and make only the smallest Search-scope fix.
