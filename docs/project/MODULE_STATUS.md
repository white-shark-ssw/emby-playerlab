# OnePlayer Module Status

| Module | Status | Notes |
|---|---|---|
| Deployment compatibility | Frozen | Prefer iOS 15.0; must work on iPhone 15 Pro Max / iOS 17.0; never raise above iOS 17.0. |
| Emby / STRM / 302 | Frozen core | Client-direct final media path. NAS must not relay bytes. |
| Emby server management / multi-route | **Active Build192 candidate** | SessionStore-owned same-Server-ID route configuration/selection, root-level auto-start and opt-in synchronizable Keychain server registry. Dedicated Release CI/IPA passed; real-device route/iCloud/startup validation pending. This does not reopen the Frozen STRM/302/115 client-direct media path. |
| Emby TV episode ordering | **Stable at Build178 / merged to main** | Canonical series order comes from Emby's `/Shows/{SeriesId}/Episodes`; no title/file/date/ID/artificial-number fallback sorting. |
| UnifiedTransport | Frozen core | Range/206 + real byte demand. Avoid unrelated edits. |
| Session cache | Frozen core | Shared playback-path cache contract. |
| MPV fast Seek | Frozen | One native `absolute+keyframes` Seek. No exact correction loop. |
| MDK | Experimental / manual | Manual backup/experimental engine, not normal automatic authority. |
| Player gesture UI | Stable baseline | Immediate left/right double-tap Seek, scrub, volume/brightness HUD, etc. |
| Native navigation | Frozen principle | System owns push/pop and interactive pop. |
| PiP | **Frozen at Build173** | Functional enough to leave for now; known renderer cold-return tail remains. |
| Player episode selection / auto-next | **Stable Build176 session/UI contract; nonstandard season-grouping regression confirmed** | 2026-08-26 real-device logs for series `151175` show canonical `/Shows/{SeriesId}/Episodes` loads all 980 episodes; all 980 share `SeasonId=152156`, while 979 have `ParentIndexNumber=nil` and only one has `ParentIndexNumber=1`. The current player overlay still derives and filters seasons only from `parentIndexNumber`, so it displays only that single indexed episode. Detail-page SeasonId grouping remains correct. Source-owned session replacement and trusted-natural-end auto-next are not implicated. |
| Home carousel interaction | **Active Build193 release-owner candidate; Build189 real-device rejected** | Build187 proved SwiftUI initial horizontal samples arrive already at 4–16pt. Build189 native raw/coalesced movement exposed a release regression: lifting the finger could freeze the carousel at intermediate progress because native recognition competed with the SwiftUI-only settle owner. Build193 keeps native movement sampling passive and leaves only SwiftUI `onEnded` as commit/cancel owner; dedicated Release CI passed and IPA was produced. Carousel Build190/191 identities were retired because parallel detail work owns those builds, and Build192 belongs to Add/Edit Emby. Real-device validation is pending. |
| Detail page scroll / cold-relaunch presentation | **Frozen at Build182** | Build181 isolated high-frequency Hero scroll state and clearly improved real-device scrolling. Build182 added persistent safe presentation metadata in `Library/Caches`; user accepted both scrolling and force-quit/relaunch detail restoration on iPhone 15 Pro Max / iOS 17.0. Do not reopen without new regression evidence. |
| Detail / episode page visual refinement | **Stable at Build184 / merged to main** | User accepted the final “视频信息” placement/title and 19 pt main section-header hierarchy on iPhone 15 Pro Max / iOS 17.0. Build182 performance/cache owner remains frozen; PR #255 merged at `5bf00bb0f48d0b640bcbea740d4c17c9f8e7be8f`. |
| Detail episode selection navigation | **Stable at Build191 / merged to main** | Build191 / 0.14.24 was accepted on the target device and merged through PR #257 at `f153a36e9da8a208150fe638e0b9df5835df1dc0`. Detail horizontal cards select only; normal Series entry selects explicit initial episode → resumable episode → canonical first episode; quick range buttons select the target-range first episode; the compact summary reuses the exact card title formatter; full-picker playback closes back to the same picker/scroll position. Build182 scroll/cache, Build176 source-owned episode-session replacement and Build178 canonical order remain unchanged. This does not resolve the separately confirmed in-player nonstandard season-grouping regression. |
| Diagnostics | Required | Playback/App logs remain a first-class debugging surface. |
| App appearance/theme | Partial | Broader theme work can proceed separately without touching player core. |
| Other product modules | Active parallel work | Build191 / 0.14.24 is the accepted overall runtime baseline on `main`. Build192 / 0.14.25 remains the independent Add/Edit Emby candidate and Build193 / 0.14.26 remains the independent home-carousel candidate; both must resync with Build191 and rerun affected validation before final integration. |

## Change discipline

When touching a Frozen module:

1. state why the existing contract is insufficient;
2. identify the exact API/dependency/real-device evidence;
3. keep iOS 17.0 compatibility;
4. avoid bundling unrelated refactors;
5. update this matrix and `BUILD_TEST_INDEX.md` after the result is known.
