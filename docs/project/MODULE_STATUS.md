# OnePlayer Module Status

| Module | Status | Notes |
|---|---|---|
| Deployment compatibility | Frozen | Prefer iOS 15.0; must work on iPhone 15 Pro Max / iOS 17.0; never raise above iOS 17.0. |
| Emby / STRM / 302 | Frozen core | Client-direct final media path. NAS must not relay bytes. |
| Emby TV episode ordering | **Stable at Build178 / merged to main** | User accepted OnePlayer 0.14.11 / Build178 on device. Canonical series order now comes from Emby's `/Shows/{SeriesId}/Episodes` response; OnePlayer does not add title/file/date/ID/artificial-number fallback sorting. PR #254 merged at `9e0d0cecb2df0a263a9a4a4c1f92c2d0e473d78f`. This does not change STRM/302 media transport. |
| UnifiedTransport | Frozen core | Range/206 + real byte demand. Avoid unrelated edits. |
| Session cache | Frozen core | Shared by playback path; network-specific preload limits do not imply separate cache pools. |
| MPV fast Seek | Frozen | One native `absolute+keyframes` Seek. No exact correction loop. |
| MDK | Experimental / manual | Keep available for targeted testing; not the normal automatic authority. |
| Player gesture UI | Stable baseline | Immediate left/right double-tap Seek, scrub, volume/brightness HUD, etc. |
| Native navigation | Frozen principle | System owns push/pop and interactive pop. |
| PiP | **Frozen at Build173** | Functional enough to leave for now; known renderer cold-return tail remains. |
| Player episode selection / auto-next | **Stable at Build176, inherited by Build178 baseline** | Build176 established the accepted in-player episode overlay, source-owned session replacement and trusted-natural-end auto-next gate. Build178 leaves those owners unchanged and only replaces the shared upstream episode ordering with the now-accepted Emby TV canonical order. |
| Diagnostics | Required | Playback/App logs remain a first-class debugging surface. |
| App appearance/theme | Partial | App identity/appearance work exists; broader theme work can be developed separately without touching player core. |
| Other product modules | Active parallel work | Build178 is the current accepted `main` baseline. Build177 remains reserved by the independent home-carousel smoothness task; because `main` advanced through Build178, that task must re-check/synchronize before final merge. |

## Change discipline

When touching a Frozen module:

1. state why the existing contract is insufficient;
2. identify the exact API/dependency/real-device evidence;
3. keep iOS 17.0 compatibility;
4. avoid bundling unrelated refactors;
5. update this matrix and `BUILD_TEST_INDEX.md` after the result is known.
