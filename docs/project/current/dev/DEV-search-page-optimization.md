# DEV-search-page-optimization

- Status: Active — Build249 target-device recommendation rejected; Build250 CI/IPA verified, target-device pending
- Task: 搜索页面优化 / 1:1 对标竞品搜索体验
- Routing aliases / keywords: 搜索页面优化, 搜索页, 全局搜索, 搜索历史, 推荐观看, 多 Emby 搜索
- Working branch: `feat/search-page-optimization`
- Base branch: `main`
- Draft PR: #264
- Build248 exact CI product source: `dc601099ded1074fafc0c7a4e000b8c6fd4c7338`
- Build248 identity: **OnePlayer 0.14.81 / Build248**
- Build248 run/job: `33259763303 / 99119574495` — success
- Build248 artifact: `9716945819`; IPA SHA-256 `8eb734bb26b77f377314223acbf7306da72ac9254a20586bfc443d59fea940c5`
- Build249 exact CI product source: `f49ed220367de1ffbf9e9a5aba097d2ce160dac7`
- Build249 identity: **OnePlayer 0.14.82 / Build249**
- Build249 run/job: `33261820598 / 99124950794` — success
- Build249 artifact: `9717502081`; IPA SHA-256 `0c62d51d488197b55dbfb98ab104c48404dd0caac77d786523f753c75acbb7a0`
- Build250 exact successful CI product source: `6e7ae960bd3cc353b8d6146aea363f3876e9e8e8`
- Build250 identity: **OnePlayer 0.14.83 / Build250**
- Build250 successful run/job: `33263279291 / 99128762968`
- Build250 artifact: `OnePlayer-0.14.83-Build250-Search`, ID `9717900754`, digest `sha256:f5cad646e230ffe1666e30fd2b6ce472b5d16cace168a850c9f07cf0e43e35e0`
- Build250 IPA SHA-256: `f213b3d6f30ac101d563e3894c3352fdcd9c9bcb46c7a266faa48c8577e73ada`
- Built/target MinOS: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0

## Accepted Search Dock baseline

Build248 target-device testing confirmed the Search Dock vertical position now matches the other server pages and focusing the Search input no longer moves the Dock. Build249 preserves that behavior. Build250 must preserve it unchanged.

## Build249 target-device result — 2026-08-30

The user installed Build249 and supplied `OnePlayer-App-1788020447.log`. Recommendations still remain on the spinner. The new Build249 diagnostics expose the exact remaining failure:

- `16:20:40.431Z`: `recommendation warm libraries total=21 eligible=19`
- `16:20:43.224Z`: movie library returned 9 Suggestions items but `accepted=0`
- `16:20:45.760Z`: TV library returned 9 Suggestions items but `accepted=0`

This proves the server is returning the requested recommendation data in roughly 2.5–2.8 seconds per library. The UI stays blocked because Build249's second client-side whitelist rejects every returned item. The preloader then serially advances through as many as 19 eligible movie/TV/mixed libraries.

Source inspection explains the rejection: Build249's `allows(_:)` requires `LibraryItem.type` to be non-nil and equal to Movie/Series. On this server's Suggestions response, the returned items do not provide a usable decoded `Type`, even though the request itself is already constrained by Emby's `IncludeItemTypes=Movie` or `Series`. Therefore all server-filtered results are discarded.

Build249 evidence: **Code written ✅ / CI passed ✅ / IPA produced+verified ✅ / real-device tested ✅ / Dock accepted ✅ / recommendation loading rejected ❌ / not stable**.

## Build250 correction

Exact successful CI product source `6e7ae960bd3cc353b8d6146aea363f3876e9e8e8` changes the Search recommendation acceptance contract only:

- library eligibility remains based on real `CollectionType`: movies, tvshows, mixed;
- request whitelist remains server-side Movie / Series only;
- when a Suggestions item includes `Type`, the client still requires actual Movie or Series;
- when Suggestions omits `Type`, the client accepts the item only because the exact request that produced it was itself restricted exclusively to Movie/Series;
- the Search view consumes the already validated preloader output directly rather than applying the old incompatible `Type != nil` filter a second time;
- diagnostics now include requested types, returned count, nil-Type count and accepted count;
- with the observed first movie library returning 9 items, the 3×3 wall can stop after that first eligible request instead of serially scanning the remaining libraries.

This is not media-type guessing or a generic fallback. The authority is the explicit Emby `IncludeItemTypes` filter used for that response, and it is only trusted when every requested type is in the Movie/Series whitelist.

No retry, timeout, timer, watchdog, debounce, second cache, shared poster-grid change, Player/MPV/PiP, UnifiedTransport, playback Session Cache, STRM/302/115, Resume/progress, credential or Deployment Target change.

## Build250 validation

- First Build250 run `33263000305` failed compilation because an intermediate edit accidentally replaced the Search view with an older incompatible file. No IPA was produced from that run and it is superseded/non-product evidence.
- The Search view was restored exactly from the Build249 baseline and only the intended recommendation consumer line was changed.
- Final exact source `6e7ae960bd3cc353b8d6146aea363f3876e9e8e8` passed Xcode 16.4 Release/MPV build and packaging in run/job `33263279291 / 99128762968`.
- Artifact `9717900754`; digest `sha256:f5cad646e230ffe1666e30fd2b6ce472b5d16cace168a850c9f07cf0e43e35e0`.
- Independently verified package: `com.embyplayerlab.app`, OnePlayer `0.14.83 (250)`, `MinimumOSVersion=15.0`, IPA integrity passed, SHA-256 `f213b3d6f30ac101d563e3894c3352fdcd9c9bcb46c7a266faa48c8577e73ada`.
- Evidence: **Code written ✅ / CI passed ✅ / IPA produced + independently verified ✅ / real-device tested ❌ / stable/frozen ❌**.

## Next exact action

Target-device test Build250. Measure recommendation first-paint time. If it still spins or remains materially slower than the competitor, export the app log; Build250 logs `requested=... returned=... nilType=... accepted=...`, which will directly show whether the first eligible Suggestions request fills the 3×3 wall. Only after that evidence should we decide whether persistent recommendation-metadata snapshots are needed for sub-network-latency cold entry.
