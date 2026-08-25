# OnePlayer Module Status

| Module | Status | Notes |
|---|---|---|
| Deployment compatibility | Frozen | Prefer iOS 15.0; must work on iPhone 15 Pro Max / iOS 17.0; never raise above iOS 17.0. |
| Emby / STRM / 302 | Frozen core | Client-direct final media path. NAS must not relay bytes. |
| UnifiedTransport | Frozen core | Range/206 + real byte demand. Avoid unrelated edits. |
| Session cache | Frozen core | Shared by playback path; network-specific preload limits do not imply separate cache pools. |
| MPV fast Seek | Frozen | One native `absolute+keyframes` Seek. No exact correction loop. |
| MDK | Experimental / manual | Keep available for targeted testing; not the normal automatic authority. |
| Player gesture UI | Stable baseline | Immediate left/right double-tap Seek, scrub, volume/brightness HUD, etc. |
| Native navigation | Frozen principle | System owns push/pop and interactive pop. |
| PiP | **Frozen at Build173** | Functional enough to leave for now; known renderer cold-return tail remains. |
| Player episode selection / auto-next | **Stable at Build176** | User accepted OnePlayer 0.14.9 / Build176 on device and closed the task. Accepted design: fixed existing player-button coordinates; in-player safe-area episode overlay; compact season filtering; detail-style title + two-line overview cards; centered `正在播放`; localized fade prevents lower-button bleed; full source-owned session replacement; auto-next only after trusted non-premature natural end. Frozen playback/transport modules remain untouched. |
| Diagnostics | Required | Playback/App logs remain a first-class debugging surface. |
| App appearance/theme | Partial | App identity/appearance work exists; broader theme work can be developed separately without touching player core. |
| Other product modules | Ready for next task | Start new feature work from the Build176 real-device accepted functional baseline unless later evidence establishes a newer one. |

## Change discipline

When touching a Frozen module:

1. state why the existing contract is insufficient;
2. identify the exact API/dependency/real-device evidence;
3. keep iOS 17.0 compatibility;
4. avoid bundling unrelated refactors;
5. update this matrix and `BUILD_TEST_INDEX.md` after the result is known.
