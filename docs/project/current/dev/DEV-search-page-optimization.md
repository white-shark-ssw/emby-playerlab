# DEV-search-page-optimization

- Status: Active — Build247 target-device tested and rejected as final; Build248 CI/IPA verified, target-device pending
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
- Build248 exact CI product source: `dc601099ded1074fafc0c7a4e000b8c6fd4c7338`
- Build248 identity: **OnePlayer 0.14.81 / Build248**
- Build248 run/job: `33259763303 / 99119574495` — success
- Build248 artifact: `OnePlayer-0.14.81-Build248-Search`, ID `9716945819`, digest `sha256:b15d327e7f628188e9df6a500ff0e26227a149a60a03b6bd1595c9aa82fffd2a`
- Build248 IPA SHA-256: `8eb734bb26b77f377314223acbf7306da72ac9254a20586bfc443d59fea940c5`
- Build248 source ZIP SHA-256: `94ce1911d3981d8f5ad53bc59a8a7413a1ddf54a54c1a97e49642b1b909f1bec`
- Built/target MinOS: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0

## Build247 target-device result — 2026-08-29

The user installed Build247 and supplied a target-device screenshot. This is controlling Search evidence and supersedes the former Build247 real-device-pending state.

1. The Search Dock no longer matches the other server pages vertically: after moving it to `EmbyServerRootViewV3`, it is rendered too low and visibly extends beyond the physical screen bottom. Source inspection shows the Search root uses `fullHeight = geometry.size.height + geometry.safeAreaInsets.bottom` and aligns the new root-owned overlay to that expanded bottom. The missing bottom-safe-area compensation explains the exact direction of the screenshot regression.
2. The Search recommendation area remains on the loading spinner and does not produce visible content. Source inspection shows Build247's startup preloader waits for a fixed 60-item result, while each library Suggestions request asks for up to 100 items before the client stops after collecting 60. Search then awaits that same whole task. This is much more work than the original 3×3 recommendation requirement and can keep the landing UI blocked even though only nine posters are needed.

Build247 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / rejected as final ✅ / not stable**.

## Build248 evidence-backed implementation

Exact CI product source `dc601099ded1074fafc0c7a4e000b8c6fd4c7338` makes only two runtime corrections plus the candidate changelog:

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
- Build248 source validation: syntax parse / `git diff --check` / exact source guards passed in run `33259763303`.
- Build248 dedicated Xcode 16.4 Release/MPV build and package: **passed** — run/job `33259763303 / 99119574495`.
- Artifact: `OnePlayer-0.14.81-Build248-Search`, ID `9716945819`, digest `sha256:b15d327e7f628188e9df6a500ff0e26227a149a60a03b6bd1595c9aa82fffd2a`.
- Independent artifact verification reproduced embedded hashes; IPA `unzip -t` passed; packaged identity is `com.embyplayerlab.app`, OnePlayer `0.14.81 (248)`, `MinimumOSVersion=15.0`.
- Evidence: **Code written ✅ / CI passed ✅ / IPA produced + independently verified ✅ / real-device tested ❌ / stable/frozen ❌**.

## Next exact action

Target-device test Build248. Confirm: Search Dock vertical band matches Home/Favorites/Settings and still does not lift with keyboard; recommendation wall appears instead of remaining on the spinner; only Movie/Series are visible; recommendation area remains fixed at up to 3×3 with no load-more twitch. Do not claim resolution until the target-device result is reported.
