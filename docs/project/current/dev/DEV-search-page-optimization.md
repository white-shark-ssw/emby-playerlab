# DEV-search-page-optimization

- Status: Active — Build244 is CI/IPA verified; target-device validation pending
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Base/head at task creation: `c6d0f4b9c8eb75906e48cec111f7228bbdae78d3`
- Exact Build244 tested product source: `0710fa4cf0a59dbf7e6748e951db2e3cddf2b82c`
- Current cleanup branch / PR head: `b8debcaa31c02939057e0c9612dbfe195c050798`
- Draft PR: #264
- Reserved / produced test candidate: **OnePlayer 0.14.77 / Build244**
- Target device: iPhone 15 Pro Max / iOS 17.0

## User requirement / target-device evidence

2026-08-29 user supplied current OnePlayer + competitor real-device screenshots and explicitly requested a 1:1 competitor-aligned Search page. Required behavior:

1. Focusing the Search text field must not push the server Dock above the keyboard; the Dock stays at the physical bottom/behind the keyboard rather than joining keyboard avoidance.
2. Search page has a leading gear menu with `全局搜索`, `显示推荐观看`, and an `Emby 服务器` section listing every added Emby server with independent check state.
3. Global search searches the enabled server set; results are grouped by server, each server shown as its own horizontal poster row with `更多` into a 3-column grid page.
4. Search history is persistent, rendered as quick chips below the search field, and has a trailing trash action with native confirmation alert before clearing all history.
5. If history is empty, the whole history section disappears and recommendations move upward automatically.
6. `推荐观看` uses Emby-provided recommendation/suggestion data and is presented as a 3-column, up-to-3-row (3×3) poster surface.
7. Search landing/result visual hierarchy should follow the supplied competitor screenshots as closely as practical while keeping OnePlayer's existing poster/detail navigation contracts.
8. After a search is submitted, the result page uses the competitor-style compact search field with a trailing blue `取消` action instead of retaining the large landing-page title/gear/X header.

## Preflight / real source ownership

- Previous search implementation is `V3EmbySearchView` + `V3SearchViewModel` inside `Sources/UI/EmbyServerBrowseV3.swift`; it remains untouched because poster PR #259 owns that file.
- Root tab owner is `Sources/UI/EmbyServerRootViewV3.swift`; Search is mounted there and this is the correct place to control keyboard safe-area behavior for the server-root geometry.
- Added-server authority remains `SessionStore.sessions`; per-server client authority remains `SessionStore.clientForBestRoute(for:)`. No duplicate server/token/route state was introduced.
- Existing APIs used by the implementation are the real `searchItemsPage`, `userViews`, and `librarySuggestions` definitions.
- Existing 3-column/detail contracts are reused through `EmbyPosterGrid`, `EmbyPosterDetailLink`, and `V3PosterCard`.

## Implemented scope

Exact Build244 product source `0710fa4...`:

- new isolated `Sources/UI/EmbySearchExperienceV3.swift` owns Search-only UI state and persistence;
- `Sources/UI/EmbyServerRootViewV3.swift` mounts `V3EmbyGlobalSearchView` and ignores keyboard safe-area only while Search is selected so the shared Dock remains at the physical bottom/behind the keyboard;
- native gear `Menu` exposes global-search, recommendation, and per-server check states;
- global-search defaults enabled and initial server selection defaults to all restored servers, then persists via `UserDefaults`;
- search history is deduplicated, newest-first, persisted via `UserDefaults`, shown as quick chips, and cleared only after a native destructive alert;
- empty history omits the whole history section;
- landing recommendations use Emby `userViews` + per-library `librarySuggestions`, deduplicate items, and render at most 9 items in the shared 3-column grid;
- search results use the selected server set, preserve `SessionStore` route ownership, show one horizontal poster row per server, and provide `更多` to a paginated shared 3-column grid;
- submitted-search presentation switches to the compact search bar + blue `取消` result header shown by the competitor;
- no retry/debounce/timer/watchdog/fallback or duplicate server/session state was added.

## CI / IPA evidence — Build244

### Compile baseline

- Dedicated workflow `Temp Search PR264 MPV Compile`, run **33251213958**, explicitly checked out earlier Search runtime source `cf8be3562687ed65a8cf63c62ad3dda3150d3cde`.
- Xcode 16.4 + MPVKit generic-iPhoneOS Debug compile: **PASS**.
- `IPHONEOS_DEPLOYMENT_TARGET=15.0` verification: **PASS**.
- The temporary compile workflow/trigger was removed afterward.

### Final competitor-layout candidate

- Exact final tested source: **`0710fa4cf0a59dbf7e6748e951db2e3cddf2b82c`**.
- Dedicated Xcode 16.4 Release / MPVKit IPA workflow run/job: **`33251653411 / 99098250151` — success**.
- Artifact: **`OnePlayer-0.14.77-Build244-Search-final`**; artifact ID **`9714601161`**; artifact digest **`sha256:3cf6eb658fcf3a164160a01318fb27333dba5dac78f600ed2d29fe5e6fc2bc85`**.
- IPA: `OnePlayer-0.14.77-Build244-Search-final.ipa`; SHA-256 **`a48d317f3caee89564789bca657da8700953f76a58fcff792562bbb67b146d05`**.
- Exact source ZIP SHA-256: **`9f8631fd2a7fc4c1941ccd6fc7e4f71d90dd536e2107b44c4c5ed775b0973a21`**.
- Independently downloaded artifact was rechecked after CI: embedded SHA files match, IPA `unzip -t` reports no errors, and packaged Info.plist is `com.embyplayerlab.app`, OnePlayer **0.14.77 (244)**, `MinimumOSVersion=15.0`, display/name `OnePlayer`.
- Exact source ZIP contains no temporary Build244 workflow or trigger file.
- Temporary final-IPA workflow and trigger were deleted after the successful run. PR #264 now has exactly three changed paths: `Sources/UI/EmbySearchExperienceV3.swift`, `Sources/UI/EmbyServerRootViewV3.swift`, and `docs/changelog/CHANGELOG_v0_14_77_build244.md`.
- Cleanup PR/branch head after removing temporary CI files: **`b8debcaa31c02939057e0c9612dbfe195c050798`**. Product runtime/changelog content is unchanged from the tested source; only temporary workflow/trigger history follows it.

## Parallel-work conflict guard

- Active poster PR #259 owns `EmbyServerBrowseV3.swift`, `EmbyPosterGrid.swift`, `EmbyServerSharedV3.swift`, `EmbySharedImageAndNavigation.swift` and related poster/image files; its current candidate is Build243 / 0.14.76.
- Search does **not modify** those poster-owned runtime files. It consumes the existing poster/grid/detail APIs only.
- Aether owns its independent Player/engine scope and Build235 identity; it does not overlap Search UI state ownership.
- Fresh identity check before Build244 found no other Active task owning Build244 / 0.14.77. Search retains Build244 as its unique candidate.

## Frozen / do-not-touch

No Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115 client-direct media path, Emby Resume/progress, server credential storage, or Deployment Target changes. Deployment Target remains iOS 15.0.

## Validation state

- Code written: **yes** — exact candidate source `0710fa4cf0a59dbf7e6748e951db2e3cddf2b82c`
- Draft PR: **#264**, cleanup head `b8debcaa31c02939057e0c9612dbfe195c050798`
- CI passed: **yes** — final Release/IPA run `33251653411 / 99098250151`
- IPA produced: **yes, independently verified** — artifact `9714601161`, IPA SHA-256 `a48d317f3caee89564789bca657da8700953f76a58fcff792562bbb67b146d05`
- Real-device tested: **no** — new Search implementation still requires target-device testing
- Stable/frozen: **no**

## Pending

Target-device validation of Build244 on iPhone 15 Pro Max / iOS 17.0, specifically:

- keyboard must not push Dock upward;
- landing header/gear/X and compact submitted-search header must match the intended competitor hierarchy;
- global-search toggle + per-server check states must persist and search the selected Emby set;
- history chips must persist across relaunch; clear button must show the native confirmation and empty history must remove the entire history block;
- recommendation content must load from Emby Suggestions and show up to 3×3;
- multi-server results must appear as one horizontal row per server; `更多` must enter the paginated 3-column page;
- poster/detail navigation must remain correct.

## Next exact action

Hand **OnePlayer 0.14.77 / Build244** to the user for target-device Search-page validation. Do not merge/freeze until real-device evidence is received. If a runtime mismatch is reported, inspect the exact Build244 behavior/source and make only the smallest evidence-supported Search-scope correction.