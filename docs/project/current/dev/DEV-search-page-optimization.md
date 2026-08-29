# DEV-search-page-optimization

- Status: Active
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Base/head at task creation: `c6d0f4b9c8eb75906e48cec111f7228bbdae78d3`
- Current product head: `cf8be3562687ed65a8cf63c62ad3dda3150d3cde`
- Draft PR: #264
- Build / version candidate: not allocated yet

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

At `cf8be356...`:

- new isolated `Sources/UI/EmbySearchExperienceV3.swift` owns Search-only UI state and persistence;
- `Sources/UI/EmbyServerRootViewV3.swift` now mounts `V3EmbyGlobalSearchView` and ignores keyboard safe-area only while Search is selected so the shared Dock remains at the physical bottom/behind the keyboard;
- native gear `Menu` exposes global-search, recommendation, and per-server check states;
- global-search defaults enabled and initial server selection defaults to all restored servers, then persists via `UserDefaults`;
- search history is deduplicated, ordered newest-first, persisted via `UserDefaults`, shown as quick chips, and cleared only after a native destructive alert;
- empty history omits the whole history section;
- landing recommendations use Emby `userViews` + per-library `librarySuggestions`, deduplicate items, and render at most 9 items in the shared 3-column grid;
- search results use the selected server set, preserve `SessionStore` route ownership, show one horizontal poster row per server, and provide `更多` to a paginated shared 3-column grid;
- no retry/debounce/timer/watchdog/fallback or duplicate server/session state was added.

## Parallel-work conflict guard

- Active poster PR #259 currently modifies `EmbyServerBrowseV3.swift`, `EmbyPosterGrid.swift`, `EmbyServerSharedV3.swift` and related poster/image files.
- Search implementation intentionally does **not modify** those files. PR #264 changed paths are currently only `Sources/UI/EmbySearchExperienceV3.swift` and `Sources/UI/EmbyServerRootViewV3.swift`.
- Reusing `EmbyPosterGrid`, `V3PosterCard`, and `EmbyPosterDetailLink` is a shared dependency; re-check poster PR #259 / `main` before final candidate build or merge if that task advances materially.
- Aether work is Player/engine scoped and does not currently overlap Search UI state ownership.

## Frozen / do-not-touch

No Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115 client-direct media path, Emby Resume/progress, server credential storage, or Deployment Target changes. Deployment Target remains iOS 15.0.

## Validation state

- Code written: yes — `cf8be3562687ed65a8cf63c62ad3dda3150d3cde`
- Draft PR: #264
- CI passed: pending PR validation
- IPA produced: no
- Real-device tested: user requirement/current-vs-competitor evidence only; new implementation not tested
- Stable/frozen: no

## Pending

- Wait for PR #264 `Validate Source` Xcode 16.4 compile result; inspect compiler logs if it fails.
- Re-check active candidate allocations and reserve a unique Build/version.
- Materialize candidate identity/changelog, run dedicated Release/IPA validation, verify Artifact/IPA identity and MinOS 15.0.
- Hand IPA to user for iPhone 15 Pro Max / iOS 17.0 testing.

## Next exact action

Inspect PR #264 validation run for exact head `cf8be356...`; fix only compiler/source issues proven by that run before allocating the test-build identity.
