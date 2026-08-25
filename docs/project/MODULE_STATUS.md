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
| Player episode selection / auto-next | **Active Build194 SeasonId grouping candidate; Build176 session/UI contract remains stable** | Build194 changes only player picker metadata grouping to consume `seriesEpisodes + seriesSeasons` and use SeasonId-first membership with ParentIndex fallback. Dedicated Xcode 16.4 standard MPV Release CI passed and IPA was produced. First distributed IPA failed TrollStore install with parse error 302 before runtime testing; local CI artifact inspection shows a valid `Payload/OnePlayer.app/Info.plist` and intact ZIP. A packaging-only TrollStore-friendly rewrap is pending installation. Source-owned session replacement and trusted-natural-end auto-next remain unchanged. |
| Home carousel interaction | **Active investigation; Build193 real-device rejected** | Build187 proved SwiftUI initial horizontal samples arrive already at 4–16pt. Build189 native raw/coalesced movement exposed a release freeze. Build193 then made native capture passive and left SwiftUI `onEnded` as the only settle owner, but target-device recording still shows the carousel repeatedly freezing at intermediate progress after finger release. The hybrid native-overlay movement + underlying SwiftUI release-owner design is therefore not accepted; do not allocate another Build until the release event path is proven. |
| Detail page scroll / cold-relaunch presentation | **Frozen at Build182** | Build181 isolated high-frequency Hero scroll state and clearly improved real-device scrolling. Build182 added persistent safe presentation metadata in `Library/Caches`; user accepted both scrolling and force-quit/relaunch detail restoration on iPhone 15 Pro Max / iOS 17.0. Do not reopen without new regression evidence. |
| Detail / episode page visual refinement | **Stable at Build184 / merged to main** | User accepted the final “视频信息” placement/title and 19 pt main section-header hierarchy on iPhone 15 Pro Max / iOS 17.0. Build182 performance/cache owner remains frozen; PR #255 merged at `5bf00bb0f48d0b640bcbea740d4c17c9f8e7be8f`. |
| Detail episode selection navigation | **Stable at Build191 / merged to main** | Build191 / 0.14.24 was accepted on the target device and merged through PR #257 at `f153a36e9da8a208150fe638e0b9df5835df1dc0`. Detail horizontal cards select only; normal Series entry selects explicit initial episode → resumable episode → canonical first episode; quick range buttons select the target-range first episode; the compact summary reuses the exact card title formatter; full-picker playback closes back to the same picker/scroll position. Build182 scroll/cache, Build176 source-owned episode-session replacement and Build178 canonical order remain unchanged. |
| Diagnostics | Required | Playback/App logs remain a first-class debugging surface. |
| App appearance/theme | Partial | Broader theme work can proceed separately without touching player core. |
| Other product modules | Active parallel work | Build191 / 0.14.24 is the accepted overall runtime baseline on `main`. Build192 / 0.14.25 remains the independent Add/Edit Emby candidate, Build193 / 0.14.26 remains the rejected/investigation home-carousel line, and Build194 / 0.14.27 is the player SeasonId-grouping candidate pending install/runtime validation. |

## Change discipline

When touching a Frozen module:

1. state why the existing contract is insufficient;
2. identify the exact API/dependency/real-device evidence;
3. keep iOS 17.0 compatibility;
4. avoid bundling unrelated refactors;
5. update this matrix and `BUILD_TEST_INDEX.md` after the result is known.
