# OnePlayer Module Status

| Module | Status | Notes |
|---|---|---|
| Deployment compatibility | Frozen | Prefer iOS 15.0; must work on iPhone 15 Pro Max / iOS 17.0; never raise above iOS 17.0. |
| Emby / STRM / 302 | Frozen core | Client-direct final media path. NAS must not relay bytes. |
| Emby server management / multi-route | **Active Build196 candidate; Build192 device feedback superseded** | Build192 target-device Edit UI exposed the missing password row. Build196 keeps SessionStore ownership, makes Edit password actionable without persisting it, and changes auto-start to cached-first Home: existing Home snapshots/image disk cache render before network, route selection/refresh runs concurrently, stale Home survives route failure, and runtime winner serverURL is remembered for future image-cache hits. Dedicated Release CI/IPA passed; Build196 real-device + cross-device iCloud validation pending. Frozen STRM/302/115 client-direct media path remains untouched. |
| Emby TV episode ordering | **Stable at Build178 / merged to main** | Canonical series order comes from Emby's `/Shows/{SeriesId}/Episodes`; no title/file/date/ID/artificial-number fallback sorting. |
| UnifiedTransport | Frozen core | Range/206 + real byte demand. Avoid unrelated edits. |
| Session cache | Frozen core | Shared playback-path cache contract. |
| MPV fast Seek | Frozen | One native `absolute+keyframes` Seek. No exact correction loop. |
| MDK | Experimental / manual | Manual backup/experimental engine, not normal automatic authority. |
| Player gesture UI | Stable baseline | Immediate left/right double-tap Seek, scrub, volume/brightness HUD, etc. |
| Native navigation | Frozen principle | System owns push/pop and interactive pop. |
| PiP | **Frozen at Build173** | Functional enough to leave for now; known renderer cold-return tail remains. |
| Player episode selection / auto-next | **Active Build195 large-list performance candidate; Build194 grouping correctness confirmed** | Build194 TrollStore-friendly rewrap installed successfully and the supplied 980-episode non-standard Series displays the full episode set, confirming SeasonId-first grouping. Build194 also exposed several-second picker-open blocking because the player used an eager `HStack` for all 980 complex cards. Build195 changes only that episode row to `LazyHStack`; dedicated Xcode 16.4 standard MPV Release CI passed, 0.14.28 (195) / MinOS 15.0 validated, and a TrollStore-friendly IPA was produced. Real-device performance validation is pending. Full canonical data, SeasonId grouping, picker UI, source-owned session replacement and trusted-natural-end auto-next remain unchanged. |
| Home carousel interaction | **Active investigation; Build193 real-device rejected** | Build187 proved SwiftUI initial horizontal samples arrive already at 4–16pt. Build189 native raw/coalesced movement exposed a release freeze. Build193 then made native capture passive and left SwiftUI `onEnded` as the only settle owner, but target-device recording still shows the carousel repeatedly freezing at intermediate progress after finger release. The hybrid native-overlay movement + underlying SwiftUI release-owner design is therefore not accepted; do not allocate another Build until the release event path is proven. |
| Detail page scroll / cold-relaunch presentation | **Frozen at Build182** | Build181 isolated high-frequency Hero scroll state and clearly improved real-device scrolling. Build182 added persistent safe presentation metadata in `Library/Caches`; user accepted both scrolling and force-quit/relaunch detail restoration on iPhone 15 Pro Max / iOS 17.0. Do not reopen without new regression evidence. |
| Detail / episode page visual refinement | **Stable at Build184 / merged to main** | User accepted the final “视频信息” placement/title and 19 pt main section-header hierarchy on iPhone 15 Pro Max / iOS 17.0. Build182 performance/cache owner remains frozen; PR #255 merged at `5bf00bb0f48d0b640bcbea740d4c17c9f8e7be8f`. |
| Detail episode selection navigation | **Stable at Build191 / merged to main** | Build191 / 0.14.24 was accepted on the target device and merged through PR #257 at `f153a36e9da8a208150fe638e0b9df5835df1dc0`. Detail horizontal cards select only; normal Series entry selects explicit initial episode → resumable episode → canonical first episode; quick range buttons select the target-range first episode; the compact summary reuses the exact card title formatter; full-picker playback closes back to the same picker/scroll position. Build182 scroll/cache, Build176 source-owned episode-session replacement and Build178 canonical order remain unchanged. |
| Diagnostics | Required | Playback/App logs remain a first-class debugging surface. |
| App appearance/theme | Partial | Broader theme work can proceed separately without touching player core. |
| Other product modules | Active parallel work | Build191 / 0.14.24 is the accepted overall runtime baseline on `main`. Build192 / 0.14.25 Add/Edit Emby has real-device feedback and is superseded by Build196 / 0.14.29, whose cached-first/password follow-up has CI/IPA complete but awaits target-device validation. Build193 remains the rejected/investigation carousel line; Build194 proved player SeasonId grouping correctness; Build195 is the CI/IPA-complete lazy-row performance candidate pending real-device validation. |

## Change discipline

When touching a Frozen module:

1. state why the existing contract is insufficient;
2. identify the exact API/dependency/real-device evidence;
3. keep iOS 17.0 compatibility;
4. avoid bundling unrelated refactors;
5. update this matrix and `BUILD_TEST_INDEX.md` after the result is known.
