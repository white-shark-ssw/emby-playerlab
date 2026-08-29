# DEV-search-page-optimization

- Status: Active — Build248 target-device tested: Dock fixed, recommendations still blocked; Build249 CI/IPA verified, target-device pending
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Draft PR: #264
- Build248 exact CI product source: `dc601099ded1074fafc0c7a4e000b8c6fd4c7338`
- Build248 identity: **OnePlayer 0.14.81 / Build248**
- Build248 run/job: `33259763303 / 99119574495` — success
- Build248 artifact: `OnePlayer-0.14.81-Build248-Search`, ID `9716945819`
- Build248 IPA SHA-256: `8eb734bb26b77f377314223acbf7306da72ac9254a20586bfc443d59fea940c5`
- Build249 exact CI product source: `f49ed220367de1ffbf9e9a5aba097d2ce160dac7`
- Build249 identity: **OnePlayer 0.14.82 / Build249**
- Build249 run/job: `33261820598 / 99124950794` — success
- Build249 artifact: `OnePlayer-0.14.82-Build249-Search`, ID `9717502081`, digest `sha256:3cc924d6733cb4590361fa255d85ef2c31f879f07538e11523a6e246da487510`
- Build249 IPA SHA-256: `0c62d51d488197b55dbfb98ab104c48404dd0caac77d786523f753c75acbb7a0`
- Built/target MinOS: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0

## Build248 target-device result — 2026-08-29

The user reports the Search bottom Dock is now correct: its vertical position matches the other pages and focusing the Search field no longer moves it. That portion of Build248 is accepted as current device evidence and must be preserved.

The recommendation wall still remains on the spinner. The uploaded app log `OnePlayer-App-1788018797.log` gives direct evidence for the remaining problem:

- recommendation requests are not stuck on one HTTP call; they are completing and then the preloader starts another library request sequentially;
- observed Suggestions calls advance about every 2.4–2.7 s (`15:53:02.153`, `04.609`, `07.188`, `09.961`, `12.498`, `14.952`, `17.412`), each with `Limit=9`;
- the preloader does not publish any partial result. `fetchRecommendations` only returns after it either accumulates 9 accepted items or finishes scanning all `userViews` libraries;
- Build248 asks every library for `Movie,Series` without first checking that library's real `CollectionType`. Returned items are then hard-filtered again, so incompatible/non-video views can produce zero accepted items while still costing one full Suggestions request each.

Therefore the spinner is a preloader traversal problem, not a Dock problem, not image decoding, and not a single hung network request.

Build248 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / Dock fix accepted ✅ / recommendation loading rejected ❌ / not stable**.

## Build249 evidence-backed correction

Exact CI product source `f49ed220367de1ffbf9e9a5aba097d2ce160dac7` changes only the Search recommendation preloader runtime plus the Build249 changelog:

- use the real `LibraryItem.collectionType` already decoded from Emby `UserViews`;
- query only recommendation-capable libraries: `movies`, `tvshows`, and `mixed`;
- map request type to the library: movies→`Movie`, tvshows→`Series`, mixed→`Movie,Series`;
- preserve the final client-visible whitelist, so only actual returned `Movie` / `Series` items can display;
- keep the existing 9-item cap, startup one-shot warm, persistent image cache, decoded-image cache, and no recommendation load-more;
- add Search diagnostics for total/eligible library count, per-library returned/accepted counts, and final accepted count so the next device log can prove exactly where time is spent.

No fallback, retry, timer, watchdog, debounce, second cache, shared poster-grid edit, or Player/Transport/PiP change was added.

## Validation state

- Build248: real-device tested; Dock fix accepted; recommendation loading rejected.
- Build249 source validation + Xcode 16.4 Release/MPV build/package: passed in run/job `33261820598 / 99124950794`.
- Artifact `9717502081`; artifact digest `sha256:3cc924d6733cb4590361fa255d85ef2c31f879f07538e11523a6e246da487510`.
- Independent package verification: bundle `com.embyplayerlab.app`; OnePlayer `0.14.82 (249)`; `MinimumOSVersion=15.0`; IPA `unzip -t` passed; IPA SHA-256 `0c62d51d488197b55dbfb98ab104c48404dd0caac77d786523f753c75acbb7a0`.
- Evidence: **Code written ✅ / CI passed ✅ / IPA produced + independently verified ✅ / real-device tested ❌ / stable/frozen ❌**.

## Next exact action

Target-device test Build249. The next app log should show `recommendation warm libraries total=... eligible=...`, only eligible collection types being queried, per-library accepted counts, and `recommendation warm completed items=...`. Preserve the Build248-accepted Dock behavior while validating whether recommendation first paint is now resolved.
