# DEV-search-page-optimization

- Status: Active — Build246 target-device rejected; Build247 CI/IPA verified, target-device pending
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Draft PR: #264
- Build246 exact tested product source: `748d6f31bf724d4f1ec7dab4765d25c9b6a195ac`
- Build246 run/job: `33255278229 / 99107775908`; artifact `9715650501`; IPA SHA-256 `184082a21d850e7203c1be717e27d7fb95301caa5a36de6b814e4930b30750b9`
- Build247 exact CI product source: `5f693d82041bbb59d3fe481aa708b22a5feda42d`
- Build247 identity: **OnePlayer 0.14.80 / Build247**
- Build247 run/job: `33258792907 / 99117036605` — success
- Build247 artifact: `OnePlayer-0.14.80-Build247-Search`, ID `9716657082`, digest `sha256:9628b0c608488edbfc5af477199e847e5a35b119d4ab96edbecd036cbde4bfd1`
- Build247 IPA SHA-256: `952b2daeef4bc01fe62476611c6620cf7ce79d3905d87bd82336e4650d0d69b0`
- Build247 source ZIP SHA-256: `44494de6213883b8bee16b6e99336b33073ed38b17a53062f9be7a2cff22b73d`
- Built MinOS: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0

## Build246 target-device result — 2026-08-29

The user installed Build246 and reported five controlling failures/follow-ups:

1. Focusing Search still lifts the bottom Dock; the prior outer `.ignoresSafeArea(.keyboard)` strategy is rejected as sufficient.
2. Recommendations require a real client-visible whitelist: only actual Emby `Movie` and `Series` items may be displayed.
3. Entering the Search landing page still waits too long for its recommendation poster wall; new requirement is one background recommendation warm at app startup.
4. Recommendation load-more still causes visible container twitch while scrolling.
5. Later recommendation posters load slowly; unexpected item types are a possible contributor, but cold poster bytes also remain a direct cost.

Build246 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / rejected as final ✅ / not stable**.

## Build247 implementation

- Search Dock ownership: `EmbyServerRootViewV3` now mounts the real `serverTabBar` at the server root while Search is selected. `V3EmbyGlobalSearchView` receives an empty nested Dock, so its keyboard-responsive `NavigationView` no longer owns the visible Dock.
- Hard recommendation whitelist: `V3SearchRecommendationPolicy.allows(_:)` accepts only returned `LibraryItem.type == Movie/Series` case-insensitively. The server-side `IncludeItemTypes=Movie,Series` remains an optimization, not the sole enforcement authority.
- Startup preloader: after `SessionStore.restore()` in `RootView`, `V3SearchRecommendationPreloader.shared.start(...)` starts one process-lifetime warm for restored sessions. Search consumes the same in-flight/completed task instead of starting its first recommendation request only on Search entry.
- Fixed recommendation set: the preloader deduplicates a bounded 60-item set. Search no longer attaches recommendation `onApproachingEnd`, no longer increases the Suggestions limit during active scrolling, and no longer mutates recommendation item count at the scroll frontier.
- Poster warm: the preloader warms the exact Search poster URL sizing into the existing persistent `EmbyImageDiskCache` and existing `EmbyDecodedImageRenderPool`. The Search-lifetime decoded-image pin remains. No second disk cache was introduced.
- Keyword Search remains separate because the keyword is not known at app launch.

## Ownership / parallel guard

- Build247 does not edit `EmbyPosterGrid.swift` or `EmbySharedImageAndNavigation.swift`; the independent poster-smoothness task retains those shared owners.
- No Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115 client-direct path, Emby Resume/progress, credentials, or Deployment Target changes.
- Active poster task owns Build243; Active Aether task owns Build235. Build247 is unique to Search.

## Validation state

- Patch workflow `33258670151 / 99116714646`: modified Swift syntax parse + `git diff --check` passed.
- Dedicated Xcode 16.4 Release/MPV run `33258792907 / 99117036605`: passed.
- Artifact identity independently verified: `com.embyplayerlab.app`, `0.14.80 (247)`, `MinimumOSVersion=15.0`; IPA `unzip -t` passed and independent SHA-256 matches the embedded checksum.
- Evidence: **Code written ✅ / CI passed ✅ / IPA produced + independently verified ✅ / real-device tested ❌ / stable/frozen ❌**.

## Next exact action

Target-device test Build247 against the five Build246 failures: Search Dock must remain fixed while keyboard appears; recommendation types must be only Movie/Series; Search landing poster wall should benefit from startup warm; scrolling through the fixed recommendation set should not twitch from recommendation load-more; later posters should already be warm or persistently cached. Do not claim resolution until that test is reported.
