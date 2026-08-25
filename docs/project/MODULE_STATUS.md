# OnePlayer Module Status

| Module | Status | Notes |
|---|---|---|
| Deployment compatibility | Frozen | Prefer iOS 15.0; must work on iPhone 15 Pro Max / iOS 17.0; never raise above iOS 17.0. |
| Emby / STRM / 302 | Frozen core | Client-direct final media path. NAS must not relay bytes. |
| Emby TV episode ordering | **Stable at Build178 / merged to main** | Canonical series order comes from Emby's `/Shows/{SeriesId}/Episodes`; no title/file/date/ID/artificial-number fallback sorting. |
| UnifiedTransport | Frozen core | Range/206 + real byte demand. Avoid unrelated edits. |
| Session cache | Frozen core | Shared playback-path cache contract. |
| MPV fast Seek | Frozen | One native `absolute+keyframes` Seek. No exact correction loop. |
| MDK | Experimental / manual | Manual backup/experimental engine, not normal automatic authority. |
| Player gesture UI | Stable baseline | Immediate left/right double-tap Seek, scrub, volume/brightness HUD, etc. |
| Native navigation | Frozen principle | System owns push/pop and interactive pop. |
| PiP | **Frozen at Build173** | Functional enough to leave for now; known renderer cold-return tail remains. |
| Player episode selection / auto-next | **Stable at Build176, inherited by later candidates** | Source-owned session replacement and trusted-natural-end auto-next remain unchanged by carousel/detail work. |
| Home carousel interaction | **Active Build190 release-owner candidate; Build189 real-device rejected** | Build187 proved SwiftUI initial horizontal samples arrive already at 4–16pt. Build189 native raw/coalesced movement exposed a release regression: lifting the finger could freeze the carousel at intermediate progress because native recognition competed with the SwiftUI-only settle owner. Build190 keeps native movement sampling passive and leaves only SwiftUI `onEnded` as commit/cancel owner; dedicated Release CI passed and IPA was produced. Real-device validation is pending. |
| Detail page scroll / cold-relaunch presentation | **Frozen at Build182** | Build181 isolated high-frequency Hero scroll state and clearly improved real-device scrolling. Build182 added persistent safe presentation metadata in `Library/Caches`; user accepted both scrolling and force-quit/relaunch detail restoration on iPhone 15 Pro Max / iOS 17.0. Do not reopen without new regression evidence. |
| Detail / episode page visual refinement | **Stable at Build184 / merged to main** | User accepted the final “视频信息” placement/title and 19 pt main section-header hierarchy on iPhone 15 Pro Max / iOS 17.0. Build182 performance/cache owner remains frozen; PR #255 merged at `5bf00bb0f48d0b640bcbea740d4c17c9f8e7be8f`. |
| Detail episode selection navigation | **Active Build190 candidate; real-device partial / follow-up required** | Build190 / 0.14.23 dedicated Release CI passed and IPA was produced. Target-device screenshots confirm quick range jumps now retain a selected episode/blue outline and the compact summary no longer disappears. A remaining presentation inconsistency is confirmed: Chinese-numeral generic Emby names such as `第十集` are not recognized by `isGenericEpisodeName`, so the summary can render `第 10 集 · 第十集` while another generic episode renders only `第 20 集`. Default-entry selection and full-picker return still require complete acceptance evidence. Build182 scroll/cache, Build176 player session replacement and Build178 canonical order remain unchanged. |
| Diagnostics | Required | Playback/App logs remain a first-class debugging surface. |
| App appearance/theme | Partial | Broader theme work can proceed separately without touching player core. |
| Other product modules | Active parallel work | Build184 / 0.14.17 is the accepted overall runtime baseline on `main`. Build190 / 0.14.23 carousel release-owner candidate and Build188 / 0.14.21 detail episode-selection are independent real-device-pending lines; neither replaces Build184 until accepted. |

## Change discipline

When touching a Frozen module:

1. state why the existing contract is insufficient;
2. identify the exact API/dependency/real-device evidence;
3. keep iOS 17.0 compatibility;
4. avoid bundling unrelated refactors;
5. update this matrix and `BUILD_TEST_INDEX.md` after the result is known.
