# OnePlayer Build / Test Index

This is a milestone index, not a list of every experimental build.

| Milestone | Main purpose | Result / current meaning |
|---|---|---|
| Build84 / 0.13.17 | MDK RecoveryIsolation | Protected app/exit lifecycle better; did not prove abnormal media was solved. |
| Build96 | MDK single-generation safety | Avoided unsafe same-process MDK generation rebuild after failure. |
| Build98 / 0.13.31 | Recovery/refresh continuation | Continued protection and detail-state work; protection ≠ MDK compatibility solved. |
| Build111 / 0.13.44 | MDK Seek / transport-tail experiments | Real-device feedback still showed worse long-tail Seek than MPV. |
| Build131 / 0.13.64 | MPV intent Seek | Fast double-tap recovered low latency; exact scrub path demonstrated precision/latency trade-off. |
| Build145 / 0.13.78 | MPV fast keyframe Seek convergence | Current fast-Seek architecture established; no-cache tests reported roughly P50 86.6 ms, P90 106 ms, P95 111.8 ms. |
| Build146 / 0.13.79 | MPV Seek code cleanup | Removed historical experiment scaffolding while keeping Build145 runtime contract. |
| Build160 / 0.13.93 | PiP native handoff work | Introduced/expanded SampleBuffer handoff and fresh-frame return gating. |
| Build167 / 0.14.0 | PiP lifecycle semantics | `vid=no` background video suspension; PiP X changed to `pauseAndSuspend`. |
| Build170 / 0.14.3 | Persistent PiP visual bridge | SampleBuffer host remains visual bridge while MPV renderer recovers. |
| Build171 / 0.14.4 | PiP authority/seek-tail guard | Added return authority alignment and a rare long-tail visual escape. |
| Build172 / 0.14.5 | PiP handoff authority controls | Real-device analysis showed periodic bridge catch-up introduced visible churn. |
| **Build173 / 0.14.6** | PiP Seek completion + return simplification | **Current real-device accepted functional baseline. PiP frozen pending a materially better renderer-lifecycle idea.** |
| Build174 / 0.14.7 | First player episode selector + auto-next | Dedicated standard MPV CI passed and IPA produced. User installed it and confirmed the selector/data path on device, but rejected the large gray sheet/X/title presentation; therefore it is partial real-device evidence, not a stable UI baseline. |
| Build175 / 0.14.8 | Episode selector UI / season interaction refinement | Dedicated standard MPV Release CI run 32780288067 passed and IPA was produced. Real-device screenshot confirmed the fixed bottom-button layout direction, but exposed lower button visual bleed through transparent overview text and a left-aligned `正在播放` badge. Not accepted as stable UI. |
| **Build176 / 0.14.9** | Episode overlay visual-layer follow-up | Code written from Build175 real-device evidence: localized black fade masks lower button bleed without restoring the rejected gray sheet, and `正在播放` is centered in the thumbnail. CI/IPA and real-device validation pending. |

## Build173 repository evidence

Known development branch:

`fix/pip-seek-completion-return-simplify-0.14.6`

Known PR:

`#238`

Known head during handoff:

`4f7acf8da06ded00db735b07210983a0d2dd5be6`

A dedicated release workflow subsequently produced the Build173 test artifact. This confirms build/IPA availability only; runtime acceptance is based on the later real-device logs and user decision to freeze PiP for now.

## Build174 / Build175 / Build176 episode-selection evidence

Development branch:

`feat/player-episode-picker-0.14.7`

Draft PR:

`#249`

Build174 standard MPV Release source commit / run / artifact:

- `2d4c4cae7deac930e040ca7579b462d9952ce60d`
- run `32776020154`
- `OnePlayer-0.14.7-build174-episode-picker`

Build174 was installed on the target device and produced actionable selector-UI feedback. It must not be described as stable or fully accepted.

Build175 standard MPV Release source commit / run / artifact:

- `cbd700dbb6ae884dbd6b9cca8cb110d590e3d39d`
- run `32780288067`
- `OnePlayer-0.14.8-build175-episode-picker-ui`

Build175 passed its dedicated contract checks, Xcode 16.4 Release compile, app identity validation, iOS 15.0 MinOS validation, IPA packaging and artifact upload. The user then tested it on the target device and reported the transparent overview/button overlap and badge alignment issue. This is real-device evidence, but Build175 is not accepted/stable.

Build176 current product source head before dedicated CI helper:

- `f701f0446d65e84fc686f69ec14d60402c94839c`

Build176 changes only the episode selector visual masking/alignment plus version/changelog; frozen player/transport modules are intentionally unchanged. CI/IPA evidence is pending.

## Maintenance rule

Add a row only when a build materially changes architectural understanding, becomes a real-device reference point, or freezes/rejects a direction.
