# OnePlayer Module Status

| Module | Status | Notes |
|---|---|---|
| Deployment compatibility | Frozen | Prefer iOS 15.0; must work on iPhone 15 Pro Max / iOS 17.0; never raise above iOS 17.0. |
| Emby / STRM / 302 | Frozen core | Client-direct final media path. NAS must not relay bytes. |
| Emby server management / multi-route | **Active Build199 candidate; IPA produced / device pending** | Build199 supersedes the earlier password-exclusion policy after the user explicitly required retained/editable passwords and iCloud cross-device password sync. SessionStore remains the owner: password is kept in a dedicated local Keychain item and, only when iCloud sync is enabled, a separate synchronizable Keychain item; Edit preloads it and unchanged saves avoid extra reauth. Cached-first auto-start and same-server route selection remain intact. Dedicated standard MPV Build199 run `32942618979` passed and IPA was produced; real-device/cross-device validation is pending. Frozen STRM/302/115 client-direct media path remains untouched. |
| Emby TV episode ordering | **Stable at Build178 / merged to main** | Canonical series order comes from Emby's `/Shows/{SeriesId}/Episodes`; no title/file/date/ID/artificial-number fallback sorting. |
| UnifiedTransport | Frozen core | Range/206 + real byte demand. Avoid unrelated edits. |
| Session cache | Frozen core | Shared playback-path cache contract. |
| MPV fast Seek | Frozen | One native `absolute+keyframes` Seek. No exact correction loop. |
| MDK | Experimental / manual | Manual backup/experimental engine, not normal automatic authority. |
| Player gesture UI | Stable baseline | Immediate left/right double-tap Seek, scrub, volume/brightness HUD, etc. |
| Native navigation | Frozen principle | System owns push/pop and interactive pop. |
| PiP | **Frozen at Build173** | Functional enough to leave for now; known renderer cold-return tail remains. |
| Player episode selection / auto-next | **Stable at Build195 / merged to main** | Build194 target-device testing confirmed SeasonId-first grouping restores the complete 980-episode non-standard Series. Build195 replaces only the eager player episode-row `HStack` with `LazyHStack`; the user confirmed target-device acceptance and task completion. The earlier TrollStore helper `168` incident was a truncated download copy, not a product/runtime rejection. Full canonical data, Build178 server order, SeasonId grouping, picker UI, source-owned session replacement and trusted-natural-end auto-next remain unchanged. PR #258 merged at `a3f79b5bed7ec835cd53f48aa9eb6cadcdf884e1`. |
| Home carousel interaction | **Active Build198 candidate** | Build193 real-device rejected the hybrid native-move/SwiftUI-release ownership. The separate carousel task now owns Build198 / 0.14.31 and a single UIKit gesture-lifecycle direction; keep its checkpoint authoritative for that independent task and do not reuse Build198 here. |
| Detail page scroll / cold-relaunch presentation | **Frozen at Build182** | Build181 isolated high-frequency Hero scroll state and clearly improved real-device scrolling. Build182 added persistent safe presentation metadata in `Library/Caches`; user accepted both scrolling and force-quit/relaunch detail restoration on iPhone 15 Pro Max / iOS 17.0. Do not reopen without new regression evidence. |
| Detail / episode page visual refinement | **Stable at Build184 / merged to main** | User accepted the final “视频信息” placement/title and 19 pt main section-header hierarchy on iPhone 15 Pro Max / iOS 17.0. Build182 performance/cache owner remains frozen; PR #255 merged at `5bf00bb0f48d0b640bcbea740d4c17c9f8e7be8f`. |
| Detail episode selection navigation | **Stable at Build191 / merged to main** | Build191 / 0.14.24 was accepted on the target device and merged through PR #257 at `f153a36e9da8a208150fe638e0b9df5835df1dc0`. Detail horizontal cards select only; normal Series entry selects explicit initial episode → resumable episode → canonical first episode; quick range buttons select the target-range first episode; the compact summary reuses the exact card title formatter; full-picker playback closes back to the same picker/scroll position. Build182 scroll/cache, Build176 source-owned episode-session replacement and Build178 canonical order remain unchanged. |
| Diagnostics | Required | Playback/App logs remain a first-class debugging surface. |
| App appearance/theme | Partial | Broader theme work can proceed separately without touching player core. |
| Other product modules | Active parallel work | Build195 / 0.14.28 is the accepted overall runtime baseline on `main`. Build199 / 0.14.32 is the independent Add/Edit Emby password-sync candidate with dedicated CI/IPA complete and target-device validation pending. Home-carousel Build198 / 0.14.31 remains a separate Active task/identity. |

## Change discipline

When touching a Frozen module:

1. state why the existing contract is insufficient;
2. identify the exact API/dependency/real-device evidence;
3. keep iOS 17.0 compatibility;
4. avoid bundling unrelated refactors;
5. update this matrix and `BUILD_TEST_INDEX.md` after the result is known.
