# DEV-search-page-optimization

- Status: Active — Build244 target-device rejected as final; Build245 CI/IPA verified and ready for target-device test
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Draft PR: #264
- Build244 tested source: `0710fa4cf0a59dbf7e6748e951db2e3cddf2b82c`
- Build244 artifact: `OnePlayer-0.14.77-Build244-Search-final`, ID `9714601161`, IPA SHA-256 `a48d317f3caee89564789bca657da8700953f76a58fcff792562bbb67b146d05`
- Build245 exact tested product source: `4c5f286ee870589bd2eac05119a516631a31391a`
- Build245 cleanup branch head after temporary CI removal: `e45c82f41d3dcf3a7d72c7f4e510627fbeada20f`
- Current test candidate: **OnePlayer 0.14.78 / Build245**
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

Exact tested product source `4c5f286ee870589bd2eac05119a516631a31391a` contains only Search-scope follow-up changes plus the Build245 changelog:

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

## Build245 CI / IPA evidence — 2026-08-29

- Exact tested product source: **`4c5f286ee870589bd2eac05119a516631a31391a`**.
- Dedicated workflow run/job: **`33253244567 / 99102435848` — success**.
- Xcode 16.4 Release build, MPVKit resolution, bundle identity verification, IPA packaging and artifact upload all passed.
- Product artifact: **`OnePlayer-0.14.78-Build245-Search`**, ID **`9715042997`**, artifact digest **`sha256:7b4fc1baab92d4a05feb3c7a1d9989ab688c6bf01a00907d51ca863abe431ffd`**.
- IPA SHA-256: **`19f69ca62928a65fb23bfdb44c67a916a7ba9edea20c3c3755f0875bb65a6514`**.
- Source ZIP SHA-256: **`31b116e57265aee94bcfb577dc60f0fb86e61739728d50a94e536299db936349`**.
- Independent post-download verification reproduced both embedded SHA-256 values; IPA `unzip -t` reported no compressed-data errors.
- Independently extracted packaged identity: `CFBundleIdentifier=com.embyplayerlab.app`, `CFBundleShortVersionString=0.14.78`, `CFBundleVersion=245`, `MinimumOSVersion=15.0`, display/name `OnePlayer`.
- Temporary Build245 workflow and trigger were removed after artifact production; cleanup branch head is `e45c82f41d3dcf3a7d72c7f4e510627fbeada20f` and runtime product source remains the exact tested `4c5f286e...` snapshot.

Build245 evidence: **Code written ✅ / CI passed ✅ / IPA produced+independently verified ✅ / real-device tested ❌ / stable-frozen ❌**.

## Parallel / candidate guard

- Search branch remains `feat/search-page-optimization`, PR #264.
- Active poster work owns its independent Build243 / 0.14.76 line and shared poster files; Search does not edit those files.
- Aether owns its independent Player/engine candidate and does not overlap Search state ownership.
- Repository search found no prior `Build245`; Search owns **0.14.78 / Build245** for this follow-up.

## Frozen / do-not-touch

No Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115 client-direct media path, Emby Resume/progress, server credential storage, shared poster-grid owner, or Deployment Target change. Deployment Target remains iOS 15.0.

## Validation state

- Build244: **real-device tested and rejected as final** for the five concrete issues above.
- Build245 code written: **yes** — exact tested product source `4c5f286ee870589bd2eac05119a516631a31391a`.
- Build245 local syntax parse of both modified Swift files: **passed**.
- Build245 CI passed: **yes**, run/job `33253244567 / 99102435848`.
- Build245 IPA produced + independently verified: **yes**, artifact `9715042997`, IPA SHA `19f69ca62928a65fb23bfdb44c67a916a7ba9edea20c3c3755f0875bb65a6514`.
- Build245 real-device tested: **no**.
- Stable/frozen: **no**.

## Pending

- User target-device validation of the five requested Build245 corrections: gear size, keyboard/Dock behavior, single-target direct full-grid Search, 12+6 recommendations without media-type filtering, and competitor-aligned landing geometry.
- If the target-device result is accepted, resync against then-current `main`, rerun affected validation if the sync is material, merge PR #264 and close this task. If not, use only the new device evidence for the next narrow Search patch.

## Next exact action

Hand **OnePlayer 0.14.78 / Build245** to the user for iPhone 15 Pro Max / iOS 17.0 testing. Do not promote Build245 to stable/frozen until the user reports the real-device result.
