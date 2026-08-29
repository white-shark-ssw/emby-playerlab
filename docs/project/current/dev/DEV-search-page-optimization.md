# DEV-search-page-optimization

- Status: Active — Build247 target-device tested and rejected as final; Build248 code written / CI-IPA pending
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Draft PR: #264
- Build246 exact tested product source: `748d6f31bf724d4f1ec7dab4765d25c9b6a195ac`
- Build247 exact CI product source: `5f693d82041bbb59d3fe481aa708b22a5feda42d`
- Build247 identity: **OnePlayer 0.14.80 / Build247**
- Build247 run/job: `33258792907 / 99117036605` — success
- Build247 artifact: `OnePlayer-0.14.80-Build247-Search`, ID `9716657082`, digest `sha256:9628b0c608488edbfc5af477199e847e5a35b119d4ab96edbecd036cbde4bfd1`
- Build247 IPA SHA-256: `952b2daeef4bc01fe62476611c6620cf7ce79d3905d87bd82336e4650d0d69b0`
- Build248 source candidate: `dc601099ded1074fafc0c7a4e000b8c6fd4c7338`
- Reserved test candidate: **OnePlayer 0.14.81 / Build248**
- Built/target MinOS: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0

## Build247 target-device result — 2026-08-29

The user installed Build247 and supplied a target-device screenshot. This is controlling Search evidence and supersedes the former Build247 real-device-pending state.

1. The Search Dock no longer matches the other server pages vertically: after moving it to `EmbyServerRootViewV3`, it is rendered too low and visibly extends beyond the physical screen bottom. Source inspection shows the Search root uses `fullHeight = geometry.size.height + geometry.safeAreaInsets.bottom` and aligns the new root-owned overlay to that expanded bottom. The missing bottom-safe-area compensation explains the exact direction of the screenshot regression.
2. The Search recommendation area remains on the loading spinner and does not produce visible content. Source inspection shows Build247's startup preloader waits for a fixed 60-item result, while each library Suggestions request asks for up to 100 items before the client stops after collecting 60. Search then awaits that same whole task. This is much more work than the original 3×3 recommendation requirement and can keep the landing UI blocked even though only nine posters are needed.

Build247 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / rejected as final ✅ / not stable**.

## Build248 evidence-backed implementation

Exact source candidate `dc601099ded1074fafc0c7a4e000b8c6fd4c7338` makes only two runtime corrections plus the candidate changelog:

- Search Dock alignment: keep the real Dock root-owned so the nested keyboard-responsive Search `NavigationView` cannot move it, but add the existing `geometry.safeAreaInsets.bottom` as bottom padding to the root Search overlay. This compensates for the root's intentionally expanded `fullHeight` and brings the Dock back to the same physical vertical band as the other tabs while preserving the Build247 ownership fix.
- Recommendation startup bound: restore the product requirement of an **up-to-3×3** recommendation wall by changing the Search preload limit from 60 to 9. For each Emby library, request only the number of remaining visible slots instead of `Limit=100`. Returned-item hard whitelist remains exactly `Movie` / `Series`; the existing startup one-shot preloader and exact-poster cache warm remain, but Search no longer waits for irrelevant excess recommendation metadata.

No retry, timeout, debounce, timer, watchdog, second cache owner, shared poster-grid edit, or Player/Transport/Session/Resume/PiP change was added.

## Ownership / parallel guard

- Search branch remains `feat/search-page-optimization`, Draft PR #264.
- Current Build248 collision search returned no existing `Build248` repository result before reservation; other active tasks retain their own Build identities.
- Build248 does not edit `EmbyPosterGrid.swift` or `EmbySharedImageAndNavigation.swift`; the independent poster-smoothness task retains those shared owners.
- No Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115 client-direct path, Emby Resume/progress, credentials, or Deployment Target changes.

## Validation state

- Build247: **real-device tested and rejected as final**.
- Build248 code written: **yes** — exact source candidate `dc601099ded1074fafc0c7a4e000b8c6fd4c7338`.
- Build248 CI/IPA: pending.
- Build248 real-device tested: no.
- Stable/frozen: no.

## Next exact action

Run syntax/diff and dedicated Xcode 16.4 Release/MPV validation for exact Build248 source, package OnePlayer 0.14.81 / Build248 with MinOS 15.0, independently verify artifact identity and hashes, update project docs/PR evidence, then hand the IPA to the user. Target-device validation must confirm Dock alignment, keyboard behavior, recommendation first paint, Movie/Series-only output, and absence of recommendation load-more twitch.
