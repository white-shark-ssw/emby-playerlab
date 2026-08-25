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
| Home carousel interaction | **Active Build185 candidate** | Build179 failed small-drag/reversal behavior. Build180 fixed reversal continuity but still felt coarse at initial motion. Build183 crossfade felt somewhat finer on device but was rejected because it changed the established interaction by pinning Logo/rating/year/type/overview. Build185 / 0.14.18 restores the original full-page foreground slide and removes the old 1.08 initial axis gate in favor of a one-time 0.5pt horizontal/vertical lock. Dedicated Release CI passed and IPA was produced; target-device validation is pending. |
| Detail page scroll / cold-relaunch presentation | **Frozen at Build182** | Build181 isolated high-frequency Hero scroll state and clearly improved real-device scrolling. Build182 added persistent safe presentation metadata in `Library/Caches`; user accepted both scrolling and force-quit/relaunch detail restoration on iPhone 15 Pro Max / iOS 17.0. Do not reopen without new regression evidence. |
| Detail / episode page visual refinement | **Active Build184 candidate** | UI-only scope: move media stream information below “更多类似” and above the bottom glass media-source card, rename it “视频信息”, and slightly reduce detail section-header typography. Build182 performance/cache owner stays frozen. Dedicated CI/IPA succeeded; real-device validation pending. |
| Diagnostics | Required | Playback/App logs remain a first-class debugging surface. |
| App appearance/theme | Partial | Broader theme work can proceed separately without touching player core. |
| Other product modules | Active parallel work | Build178 remains the accepted overall runtime baseline. Build185 carousel and Build184 detail visual refinement are separate candidates with unique Build identities and no current file/state-owner overlap. |

## Change discipline

When touching a Frozen module:

1. state why the existing contract is insufficient;
2. identify the exact API/dependency/real-device evidence;
3. keep iOS 17.0 compatibility;
4. avoid bundling unrelated refactors;
5. update this matrix and `BUILD_TEST_INDEX.md` after the result is known.
