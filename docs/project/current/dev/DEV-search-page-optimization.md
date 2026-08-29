# DEV-search-page-optimization

- Status: Active
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Base/head at task creation: `c6d0f4b9c8eb75906e48cec111f7228bbdae78d3`
- Runtime product head: `cf8be3562687ed65a8cf63c62ad3dda3150d3cde`
- Draft PR: #264
- Reserved test candidate: **OnePlayer 0.14.77 / Build244**

## User requirement / target-device evidence

2026-08-29 user supplied current OnePlayer + competitor real-device screenshots and explicitly requested a 1:1 competitor-aligned Search page. Required behavior:

1. Focusing the Search text field must not push the server Dock above the keyboard; the Dock stays at the physical bottom/behind the keyboard rather than joining keyboard avoidance.
2. Search page has a leading gear menu with `全局搜索`, `显示推荐观看`, and an `Emby 服务器` section listing every added Emby server with independent check state.
3. Global search searches the enabled server set; results are grouped by server, each server shown as its own horizontal poster row with `更多` into a 3-column grid page.
4. Search history is persistent, rendered as quick chips below the search field, and has a trailing trash action with native confirmation alert before clearing all history.
5. If history is empty, the whole history section disappears and recommendations move upward automatically.
6. `推荐观看` uses Emby-provided recommendation/suggestion data and is presented as a 3-column, up-to-3-row (3×3) poster surface.
7. Search landing/result visual hierarchy should follow the supplied competitor screenshots as closely as practical while keeping OnePlayer's existing poster/detail navigation contracts.

## Preflight / real source ownership

- Previous search implementation is `V3EmbySearchView` + `V3SearchViewModel` inside `Sources/UI/EmbyServerBrowseV3.swift`; it is current-server-only and remains untouched because poster PR #259 owns that file.
- Root tab owner is `Sources/UI/EmbyServerRootViewV3.swift`; Search is mounted there and this is the correct place to control keyboard safe-area behavior for the server-root geometry.
- Added-server authority remains `SessionStore.sessions`; per-server client authority remains `SessionStore.clientForBestRoute(for:)`. No duplicate server/token/route state was introduced.
- Existing APIs used by the implementation are the real `searchItemsPage`, `userViews`, and `librarySuggestions` definitions.
- Existing 3-column/detail contracts are reused through `EmbyPosterGrid`, `EmbyPosterDetailLink`, and `V3PosterCard`.

## Implemented scope

At runtime source `cf8be356...`:

- new isolated `Sources/UI/EmbySearchExperienceV3.swift` owns Search-only UI state and persistence;
- `Sources/UI/EmbyServerRootViewV3.swift` now mounts `V3EmbyGlobalSearchView` and ignores keyboard safe-area only while Search is selected so the shared Dock remains at the physical bottom/behind the keyboard;
- native gear `Menu` exposes global-search, recommendation, and per-server check states;
- global-search defaults enabled and initial server selection defaults to all restored servers, then persists via `UserDefaults`;
- search history is deduplicated, ordered newest-first, persisted via `UserDefaults`, shown as quick chips, and cleared only after a native destructive alert;
- empty history omits the whole history section;
- landing recommendations use Emby `userViews` + per-library `librarySuggestions`, deduplicate items, and render at most 9 items in the shared 3-column grid;
- search results use the selected server set, preserve `SessionStore` route ownership, show one horizontal poster row per server, and provide `更多` to a paginated shared 3-column grid;
- no retry/debounce/timer/watchdog/fallback or duplicate server/session state was added.

## CI evidence / candidate allocation — 2026-08-29

- Dedicated workflow `Temp Search PR264 MPV Compile`, run **33251213958**, explicitly checked out runtime source `cf8be3562687ed65a8cf63c62ad3dda3150d3cde`.
- Xcode 16.4 + MPVKit generic-iPhoneOS Debug compile: **PASS**.
- `IPHONEOS_DEPLOYMENT_TARGET=15.0` build-setting verification step: **PASS**.
- Temporary compile workflow/trigger files were deleted after the run; PR #264 net changed paths returned to the two intended runtime files only.
- Normal `Validate Source` on the PR remains an infrastructure false-negative because that repository workflow still hardcodes the stale `0.13.3` source identity; this is not a Search compiler failure.
- Fresh collision checks found no `Build244`, `0.14.77`, or branch named with `244`; active poster task owns Build243 / 0.14.76. Search therefore reserves **OnePlayer 0.14.77 / Build244** for the first Search device candidate.

## Parallel-work conflict guard

- Active poster PR #259 still modifies `EmbyServerBrowseV3.swift`, `EmbyPosterGrid.swift`, `EmbyServerSharedV3.swift`, `EmbySharedImageAndNavigation.swift` and related poster/image files; its current docs reserve Build243 / 0.14.76.
- Search implementation intentionally does **not modify** poster-owned runtime files. PR #264 net runtime paths are only `Sources/UI/EmbySearchExperienceV3.swift` and `Sources/UI/EmbyServerRootViewV3.swift`.
- Reusing `EmbyPosterGrid`, `V3PosterCard`, and `EmbyPosterDetailLink` is a shared dependency; re-check poster PR #259 / `main` before merge if that task advances materially.
- Aether work is Player/engine scoped and does not currently overlap Search UI state ownership.

## Frozen / do-not-touch

No Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115 client-direct media path, Emby Resume/progress, server credential storage, or Deployment Target changes. Deployment Target remains iOS 15.0.

## Validation state

- Code written: **yes** — runtime source `cf8be3562687ed65a8cf63c62ad3dda3150d3cde`
- Draft PR: **#264**
- CI passed: **yes for exact runtime source** — dedicated MPV compile run `33251213958`
- IPA produced: **no, pending Build244 packaging**
- Real-device tested: **no** — screenshots are requirement/current-vs-competitor evidence, not validation of new code
- Stable/frozen: **no**

## Pending

- Materialize Build244 changelog/candidate packaging without changing runtime behavior.
- Run dedicated Xcode 16.4 Release/MPV IPA build for exact Search candidate; verify bundle/version/build, Artifact/IPA integrity and MinOS 15.0.
- Hand IPA to user for iPhone 15 Pro Max / iOS 17.0 testing of keyboard/Dock, gear/server selection, persistent history + clear alert, multi-server horizontal rows/More grid, and recommendation layout/data.

## Next exact action

Build and verify OnePlayer **0.14.77 / Build244** from the already-compiled Search runtime source, then update the project docs with the IPA evidence without promoting the task to real-device-tested or stable.
