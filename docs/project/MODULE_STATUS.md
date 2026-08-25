# OnePlayer Module Status

| Module | Status | Notes |
|---|---|---|
| Deployment compatibility | Frozen | Prefer iOS 15.0; must work on iPhone 15 Pro Max / iOS 17.0; never raise above iOS 17.0. |
| Emby / STRM / 302 | Frozen core | Client-direct final media path. NAS must not relay bytes. |
| Emby TV episode ordering | **Build178 candidate** | Non-standard-series ordering now uses Emby's `/Shows/{SeriesId}/Episodes` server order rather than forcing generic Items `ParentIndexNumber,IndexNumber`. Dedicated standard MPV CI passed and IPA produced; abnormal + standard series real-device validation pending. This does not change STRM/302 media transport. |
| UnifiedTransport | Frozen core | Range/206 + real byte demand. Avoid unrelated edits. |
| Session cache | Frozen core | Shared by playback path; network-specific preload limits do not imply separate cache pools. |
| MPV fast Seek | Frozen | One native `absolute+keyframes` Seek. No exact correction loop. |
| MDK | Experimental / manual | Keep available for targeted testing; not the normal automatic authority. |
| Player gesture UI | Stable baseline | Immediate left/right double-tap Seek, scrub, volume/brightness HUD, etc. |
| Native navigation | Frozen principle | System owns push/pop and interactive pop. |
| PiP | **Frozen at Build173** | Functional enough to leave for now; known renderer cold-return tail remains. |
| Player episode selection / auto-next | **Stable at Build176 / merged to main** | User accepted OnePlayer 0.14.9 / Build176 on device. Final merge PR #253 landed on `main` at `d10e0d63b429f72a664193a1a5bacf728cac50b6`. Accepted design: fixed existing player-button coordinates; in-player safe-area episode overlay; compact season filtering; detail-style title + two-line overview cards; centered `正在播放`; localized fade prevents lower-button bleed; full source-owned session replacement; auto-next only after trusted non-premature natural end. Build178 only changes the shared upstream episode order consumed by this stable UI/session contract. |
| Diagnostics | Required | Playback/App logs remain a first-class debugging surface. |
| App appearance/theme | Partial | App identity/appearance work exists; broader theme work can be developed separately without touching player core. |
| Other product modules | Active parallel work | Build176 remains the accepted baseline. Build177 is reserved by home-carousel smoothness; Build178 is the episode-ordering CI/IPA candidate. Neither becomes the stable baseline until its own real-device acceptance. |

## Change discipline

When touching a Frozen module:

1. state why the existing contract is insufficient;
2. identify the exact API/dependency/real-device evidence;
3. keep iOS 17.0 compatibility;
4. avoid bundling unrelated refactors;
5. update this matrix and `BUILD_TEST_INDEX.md` after the result is known.
