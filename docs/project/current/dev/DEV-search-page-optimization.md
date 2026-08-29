# DEV-search-page-optimization

- Status: Active
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Base/head at task creation: `c6d0f4b9c8eb75906e48cec111f7228bbdae78d3`
- PR: not created yet
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

- Current search implementation is `V3EmbySearchView` + `V3SearchViewModel` inside `Sources/UI/EmbyServerBrowseV3.swift`; it is current-server-only and overlays the shared Dock inside a keyboard-avoiding hierarchy.
- Root tab owner is `Sources/UI/EmbyServerRootViewV3.swift`; Search is mounted there and this is the correct place to control keyboard safe-area behavior for the server-root geometry.
- Added-server authority remains `SessionStore.sessions`; per-server client authority remains `SessionStore.clientForBestRoute(for:)`. Do not duplicate server configuration/token/route state.
- Existing Emby APIs already provide `searchItemsPage`, `userViews`, `librarySuggestions`, and `movieRecommendations`; no guessed API is required for the first implementation.
- Existing 3-column surface is `EmbyPosterGrid`; existing detail navigation/card contracts are `EmbyPosterDetailLink` + `V3PosterCard`.

## Parallel-work conflict guard

- Active poster PR #259 currently modifies `EmbyServerBrowseV3.swift`, `EmbyPosterGrid.swift`, `EmbyServerSharedV3.swift` and related poster/image files.
- Therefore this task must **not modify** `EmbyServerBrowseV3.swift`, `EmbyPosterGrid.swift`, or `EmbyServerSharedV3.swift` while that task is Active. Implement the new Search experience in a new source file and switch only the Search mounting point in `EmbyServerRootViewV3.swift`.
- Reusing the existing public/internal `EmbyPosterGrid`, `V3PosterCard`, and `EmbyPosterDetailLink` APIs is allowed, but they are a shared dependency; re-check PR #259 / `main` before final CI/merge and rerun validation if their source changes materially.
- Aether work is Player/engine scoped and does not currently overlap Search UI state ownership.

## Frozen / do-not-touch

Do not modify Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115 client-direct media path, Emby Resume/progress, server credential storage, or Deployment Target. Search UI must remain iOS 15.0 compatible.

## Completed

- New task explicitly authorized by user.
- New isolated branch created from current `main`.
- Current search/root/session/API/poster definitions and call sites inspected.
- Parallel poster PR changed-file overlap inspected; implementation boundary chosen to avoid shared-file writes.

## Validation state

- Code written: no
- CI passed: no
- IPA produced: no
- Real-device tested: user requirement/current-vs-competitor evidence only; new implementation not tested
- Stable/frozen: no

## Pending

- Implement isolated replacement Search experience + root keyboard-safe-area correction.
- Add focused source checks for required Search contracts.
- Allocate unique Build/version candidate only after collision check.
- Create PR, run standard MPV CI/IPA workflow, verify Artifact/IPA identity and MinOS 15.0.
- Hand IPA to user for iPhone 15 Pro Max / iOS 17.0 testing.

## Next exact action

Write `Sources/UI/EmbySearchExperienceV3.swift` on `feat/search-page-optimization` and minimally switch `EmbyServerRootViewV3.swift` to it, without touching poster PR #259 files.
