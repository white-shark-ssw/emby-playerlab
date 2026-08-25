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
| Build173 / 0.14.6 | PiP Seek completion + return simplification | PiP freeze baseline. This was the previous overall accepted functional baseline; PiP remains frozen at this architecture unless a materially better renderer-lifecycle idea appears. |
| Build174 / 0.14.7 | First player episode selector + auto-next | Dedicated standard MPV CI passed and IPA produced. User installed it and confirmed the selector/data path on device, but rejected the large gray sheet/X/title presentation; partial real-device evidence only. |
| Build175 / 0.14.8 | Episode selector UI / season interaction refinement | Dedicated standard MPV Release CI passed and IPA produced. Real-device screenshot confirmed the fixed bottom-button layout direction, but exposed lower button visual bleed through transparent overview text and a left-aligned `正在播放` badge. Not accepted as stable UI. |
| **Build176 / 0.14.9** | Episode overlay visual-layer follow-up and task completion | **Current real-device accepted functional baseline and now merged to `main`.** Localized black fade prevents lower button bleed without restoring the rejected gray sheet; `正在播放` is centered; existing player-button coordinates stay fixed. Dedicated standard MPV Release CI passed, IPA produced, user accepted the result, and final merge PR #253 landed at `d10e0d63b429f72a664193a1a5bacf728cac50b6`. |

## Current accepted baseline

- OnePlayer **0.14.9 / Build176**
- canonical branch: `main`
- final merge PR: `#253`
- final merge commit: `d10e0d63b429f72a664193a1a5bacf728cac50b6`
- development branch: `feat/player-episode-picker-0.14.7`
- development PR: `#249` (historical / superseded by #253)
- product source before temporary Build176 helper: `f701f0446d65e84fc686f69ec14d60402c94839c`
- dedicated CI source: `221630297dc1080279bb8a3f05d69586461b328c`
- workflow-restored feature head: `4b26a7d3a9826c58bfdddd6aafaeb9eeb5c7c943`
- main-synchronization merge on feature branch: `1ff5598c18e8c46856efecbd1d2f15df422098c6`
- CI run `32782048086`
- artifact `OnePlayer-0.14.9-build176-episode-picker-ui`
- target device: iPhone 15 Pro Max / iOS 17.0
- evidence level: **Code written / CI passed / IPA produced / real-device accepted / stable for current requirements / merged to main**

## Episode-selection evidence trail

Build174 standard MPV Release source commit / run / artifact:

- `2d4c4cae7deac930e040ca7579b462d9952ce60d`
- run `32776020154`
- `OnePlayer-0.14.7-build174-episode-picker`

Build174 was installed on the target device and produced actionable selector-UI feedback. It is not a stable UI baseline.

Build175 standard MPV Release source commit / run / artifact:

- `cbd700dbb6ae884dbd6b9cca8cb110d590e3d39d`
- run `32780288067`
- `OnePlayer-0.14.8-build175-episode-picker-ui`

Build175 passed its dedicated contract checks, Xcode 16.4 Release compile, app identity validation, iOS 15.0 MinOS validation, IPA packaging and artifact upload. The user then tested it and reported the transparent overview/button overlap and badge alignment issue.

Build176 product source / dedicated CI source / run / artifact:

- product source before temporary helper: `f701f0446d65e84fc686f69ec14d60402c94839c`
- dedicated CI source: `221630297dc1080279bb8a3f05d69586461b328c`
- run `32782048086`
- `OnePlayer-0.14.9-build176-episode-picker-ui`
- workflow-restored branch head: `4b26a7d3a9826c58bfdddd6aafaeb9eeb5c7c943`

Build176 passed the dedicated selector/frozen-file contract checks, Xcode 16.4 Release compile, OnePlayer 0.14.9 (176) app identity validation, iOS 15.0 MinOS validation, IPA packaging and artifact upload. The user's subsequent real-device acceptance promoted Build176 to the stable functional baseline.

## Main integration evidence

Before the final merge, current `main` was synchronized into the Build176 feature branch. The main-only delta consisted of governance/history/CI files and did not contain `Sources/**` runtime changes. The synchronized feature tree reused the exact accepted Build176 product trees/blobs, so no Build177 was created solely for synchronization.

Final merge PR #253 triggered existing generic workflows. Two red checks were reviewed and are not Build176 MPV product regressions:

- `Validate Source` exits before compilation because it still hard-codes source version `0.13.3 / Build69`.
- `Build MDK Lab IPA` exits in its experimental local-file contract because it requires `Sources/UI/LocalMDKFileLabView.swift`, which is not part of the accepted Build176 product tree.

The authoritative Build176 release evidence remains dedicated standard MPV Release run `32782048086`, its produced IPA, and the user's real-device acceptance.

## Maintenance rule

Add a row only when a build materially changes architectural understanding, becomes a real-device reference point, or freezes/rejects a direction.
