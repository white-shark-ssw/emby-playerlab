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
| Build173 / 0.14.6 | PiP Seek completion + return simplification | PiP freeze baseline. This was a previous overall accepted functional baseline; PiP remains frozen at this architecture unless a materially better renderer-lifecycle idea appears. |
| Build174 / 0.14.7 | First player episode selector + auto-next | Dedicated standard MPV CI passed and IPA produced. User installed it and confirmed the selector/data path on device, but rejected the large gray sheet/X/title presentation; partial real-device evidence only. |
| Build175 / 0.14.8 | Episode selector UI / season interaction refinement | Dedicated standard MPV Release CI passed and IPA produced. Real-device screenshot confirmed the fixed bottom-button layout direction, but exposed lower button visual bleed through transparent overview text and a left-aligned `正在播放` badge. Not accepted as stable UI. |
| **Build176 / 0.14.9** | Episode overlay visual-layer follow-up and task completion | Previous accepted functional baseline. Dedicated standard MPV Release CI passed, IPA produced, user accepted the result, and final merge PR #253 landed at `d10e0d63b429f72a664193a1a5bacf728cac50b6`. Its player episode-selection/session contract remains stable and is inherited by Build178 and later carousel candidates. |
| Build177 / 0.14.10 | Preliminary home carousel drag smoothness | Dedicated Release CI passed and IPA was produced on the older Build173 isolated baseline, but it was superseded before user distribution after `main` advanced through accepted Build178. It remains preliminary implementation/CI evidence only. |
| **Build178 / 0.14.11** | Canonical Emby episode ordering for non-standard series | **Current real-device accepted functional baseline and merged to `main`.** Uses `/Shows/{SeriesId}/Episodes` server order instead of forcing generic Items `ParentIndexNumber,IndexNumber`; dedicated standard MPV Release CI passed, IPA produced, user accepted the result on device, and PR #254 merged at `9e0d0cecb2df0a263a9a4a4c1f92c2d0e473d78f`. |
| **Build179 / 0.14.12** | First accepted-baseline home carousel smoothness candidate | Dedicated standard MPV Release CI passed and IPA produced. High-frequency carousel transition state was scoped away from the full home root and drag start reduced to 4 pt. **Real-device test failed:** small movements still had a dead zone and left↔right reversal could pause then jump a large distance. Rejected, not stable. |
| **Build180 / 0.14.13** | Continuous home carousel drag through zero/reversal | **Current code candidate.** Keeps Build179 local state ownership but removes the remaining 4 pt/8% progress dead zones: drag receives movement from 0 pt, axis dominance only acquires the initial horizontal drag, established drag continues through center reversal, and artwork blend uses raw progress. CI/IPA/real-device pending. |

## Current accepted baseline

- OnePlayer **0.14.11 / Build178**
- canonical branch: `main`
- final merge PR: `#254`
- final merge commit: `9e0d0cecb2df0a263a9a4a4c1f92c2d0e473d78f`
- development branch: `fix/nonstandard-episode-sorting`
- clean product head before merge: `8718f60a1b0a3d0034473f1cc1769c0b5bc3665f`
- dedicated CI source: `db9aa2498fba5c6b092bfec2427042859e32b26a`
- CI run: `32836693548`
- artifact: `OnePlayer-0.14.11-build178-episode-ordering`
- artifact ID: `9558981442`
- IPA: `OnePlayer-0.14.11-build178-episode-ordering-unsigned.ipa`
- IPA SHA-256: `2e4ed5be2c32535249ea2049a9686f6ac24a217e04535806ee6ee4721e78ba5b`
- target device: iPhone 15 Pro Max / iOS 17.0
- evidence level: **Code written / CI passed / IPA produced / real-device accepted / stable for current requirements / merged to main**

Build179 has been rejected by real-device carousel evidence. Build180 is the current carousel code candidate but does not replace Build178 as the accepted baseline unless a later target-device test is accepted.

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

Build176 passed the dedicated selector/frozen-file contract checks, Xcode 16.4 Release compile, OnePlayer 0.14.9 (176) app identity validation, iOS 15.0 MinOS validation, IPA packaging and artifact upload. User real-device acceptance made its player episode-selection/session contract stable; Build178 and later carousel candidates inherit that contract unchanged.

## Build178 episode-ordering evidence

- task: `DEV-nonstandard-episode-sorting` — completed and checkpoint retired after merge
- branch: `fix/nonstandard-episode-sorting`
- PR: `#254` — merged
- merge commit: `9e0d0cecb2df0a263a9a4a4c1f92c2d0e473d78f`
- clean product head after restoring the temporary helper: `8718f60a1b0a3d0034473f1cc1769c0b5bc3665f`
- dedicated standard MPV Release CI source: `db9aa2498fba5c6b092bfec2427042859e32b26a`
- CI run: `32836693548`
- artifact: `OnePlayer-0.14.11-build178-episode-ordering`
- artifact ID: `9558981442`
- artifact archive digest: `sha256:b4f75969157eb929f8bccec50cc9fcaf51025f1696370a7143c20e1d59b8d158`
- IPA: `OnePlayer-0.14.11-build178-episode-ordering-unsigned.ipa`
- IPA SHA-256: `2e4ed5be2c32535249ea2049a9686f6ac24a217e04535806ee6ee4721e78ba5b`
- source zip SHA-256: `eb2059c776a5bdc09d17462a1085a63a1c7fdc5e4a80ea3a4fa18c6b9aefd214`
- CI evidence: ordering contract passed; Build176 downstream/frozen files unchanged; Xcode 16.4 Release build passed; app identity validated as 0.14.11 (178); app/runtime Mach-O MinOS validated at 15.0; IPA packaged and uploaded.
- real-device evidence: user accepted Build178 on 2026-08-25 and explicitly approved task completion and code merge.
- stable contract: canonical series order comes from `GET /Shows/{SeriesId}/Episodes`; OnePlayer preserves server order and does not add client-side title/file/date/ID/artificial-number fallback sorting.

## Build179 home-carousel evidence

- task: `DEV-home-carousel-drag-smoothness` — Active, Build179 rejected and continued as Build180
- integration base: accepted Build178 runtime at `main@967b743c88d68b05205eb39f1de75cab41362e8b`
- branch: `perf/home-carousel-drag-smoothness-build179`
- workflow-restored branch head: `839cc0c3506c68e1c04887e438a77575a10fd8a0`
- dedicated standard MPV Release CI source: `22515402f4d17e1a9b4073c535265b65ba55f52d`
- CI run: `32841344067`
- artifact: `OnePlayer-0.14.12-build179-home-carousel-smoothness`
- artifact ID: `9560700233`
- artifact archive digest: `sha256:5d4b06c3fbcc0515a3ce8293c60701ec8ddd31b6632a7bd4d0fac5717d242a24`
- IPA: `OnePlayer-0.14.12-build179-home-carousel-smoothness-unsigned.ipa`
- IPA SHA-256: `80f2c70215fe3f1c9323894eedbd22c5f61b29bcfb61e3a6e14115a4b932ddd8`
- MinOS: app and main runtime Mach-O validated at iOS 15.0; compatibility audit OK
- CI evidence: carousel state-isolation/4 pt drag contract passed; home-carousel and scroll-performance checks passed; Build178 series-ordering check passed; Build176/178 accepted player/order files and P0 frozen modules were zero-diff from the Build178 integration base; Xcode 16.4 Release build passed; app identity validated as 0.14.12 (179); IPA packaged and uploaded.
- real-device evidence: user installed Build179 on iPhone 15 Pro Max / iOS 17.0 and reported a persistent start dead zone plus a visible freeze/large catch-up jump when reversing direction through the center. New `轮播图卡顿.mp4` supports that rejection.
- evidence level: **Code written / CI passed / IPA produced / real-device tested and rejected / not stable**

## Build180 home-carousel candidate

- task: `DEV-home-carousel-drag-smoothness` — Active
- branch: `perf/home-carousel-drag-smoothness-build180`
- base: Build179 clean product head `839cc0c3506c68e1c04887e438a77575a10fd8a0`
- current product head: `cdc86d7fd75b30194b5363bf9abb497da2cc5a7b`
- version/build: OnePlayer 0.14.13 / Build180
- product delta vs Build179: `EmbyHomeCarouselStateV3.swift` removes 4 pt gesture/progress gates and applies initial-only axis acquisition; AppIdentity/changelog/static carousel check updated. `EmbyHomeCoreV3.swift` is unchanged from Build179's local-owner implementation.
- CI/IPA/real-device: pending
- evidence level: **Code written / CI pending / IPA pending / real-device pending / not stable**

## Main integration evidence

Build176 was merged through PR #253 and established the accepted player episode-selection/session contract.

Build178 was developed from the accepted Build176 `main` runtime baseline. Before its dedicated CI, target-branch advancement was checked and only governance/project-control files had moved; no relevant runtime source overlap invalidated the Build178 product test. Dedicated run `32836693548` passed, the temporary CI helper was restored, and the final PR diff contained only:

- `Sources/Core/AppIdentity.swift`
- `Sources/Networking/EmbyAPIClient.swift`
- `docs/changelog/CHANGELOG_v0_14_11_build178.md`
- `scripts/check_series_episode_ordering.py`

After user real-device acceptance, PR #254 was merged to `main` at `9e0d0cecb2df0a263a9a4a4c1f92c2d0e473d78f`. Build178 is therefore the current accepted functional baseline. Build179 is explicitly rejected for carousel interaction, and Build180 remains an unvalidated feature candidate.

## Maintenance rule

Add a row only when a build materially changes architectural understanding, becomes a real-device reference point, or freezes/rejects a direction.
