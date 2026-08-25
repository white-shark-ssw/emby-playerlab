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
| **Build176 / 0.14.9** | Episode overlay visual-layer follow-up and task completion | Previous accepted functional baseline. Dedicated standard MPV Release CI passed, IPA produced, user accepted the result, and final merge PR #253 landed at `d10e0d63b429f72a664193a1a5bacf728cac50b6`. Its player episode-selection/session contract remains stable and is inherited by Build178 and later candidates. |
| Build177 / 0.14.10 | Preliminary home carousel drag smoothness | Dedicated Release CI passed and IPA was produced on the older Build173 isolated baseline, but it was superseded before user distribution after `main` advanced through accepted Build178. It remains preliminary implementation/CI evidence only. |
| **Build178 / 0.14.11** | Canonical Emby episode ordering for non-standard series | **Previous accepted baseline, merged to `main` and inherited by Build184.** Uses `/Shows/{SeriesId}/Episodes` server order instead of forcing generic Items `ParentIndexNumber,IndexNumber`; dedicated standard MPV Release CI passed, IPA produced, user accepted the result on device, and PR #254 merged at `9e0d0cecb2df0a263a9a4a4c1f92c2d0e473d78f`. |
| **Build179 / 0.14.12** | First accepted-baseline home carousel smoothness candidate | Dedicated standard MPV Release CI passed and IPA produced. **Real-device rejected:** small movements still had a dead zone and left↔right reversal could pause then jump a large distance. |
| **Build180 / 0.14.13** | Continuous home carousel drag through zero/reversal | Dedicated Release CI/IPA succeeded. Real-device test confirmed reversal continuity was fixed, but initial motion still felt coarse and overall smoothness remained below EX. **Partial improvement / rejected for acceptance.** |
| **Build181 / 0.14.14** | Detail-page warm presentation + Hero scroll isolation | Dedicated Release CI/IPA succeeded. Target-device recording showed detail scroll clearly improved, but force-quit/relaunch lost the session-only warm metadata. **Partial success, cold-start requirement failed.** |
| **Build182 / 0.14.15** | Persistent detail presentation cache | Extends Build181's safe presentation snapshot to `Library/Caches` while retaining live Emby refresh and playback/session boundaries. Dedicated Release CI/IPA succeeded; user accepted detail scrolling plus force-quit/relaunch restoration on target device. **Frozen for these two requirements.** |
| **Build183 / 0.14.16** | Carousel fixed-foreground crossfade experiment | Dedicated Release CI/IPA succeeded. User said the feel seemed somewhat finer, but Logo/rating/year/type/overview were pinned instead of moving with their carousel page. **Interaction regression; rejected as default direction.** |
| **Build184 / 0.14.17** | Detail performance/cache + visual hierarchy completion | Inherits accepted Build181/182 detail scroll and persistent presentation cache, moves “视频信息” below “更多类似” and above the bottom glass media-source card, and uses 19 pt bold main detail section headers. Dedicated Release CI/IPA succeeded; user accepted the final result on target device and PR #255 merged to `main`. **Previous accepted overall baseline; inherited unchanged by Build191.** |
| **Build185 / 0.14.18** | Restore carousel page-slide semantics + refine initial axis acquisition | Dedicated Release CI passed and IPA produced. **Real-device rejected:** page-slide interaction/reversal were correct, but first visible movement remained about 10/12/16 px versus EX about 1/1/2 px and ongoing drag remained visibly coarser. |
| **Build186 / 0.14.19** | Carousel drag-cadence instrumentation | Dedicated Release CI/IPA succeeded from accepted Build184 integration; passive timing was implemented, but its generic category routed to App logs and the package was not distributed for diagnosis. |
| **Build187 / 0.14.20** | Exportable carousel drag-cadence diagnostic | Dedicated Release CI/IPA succeeded. **Real-device diagnostic confirmed:** first useful SwiftUI horizontal samples were already about 4.33/8.00/15.67/11.00pt with maxFPS=120 and Low Power Mode off, proving threshold tuning cannot recover fine initial sampling in this ScrollView/DragGesture path. |
| **Build188 / 0.14.21** | Detail episode selection semantics + full picker return | Dedicated Release CI/IPA succeeded. **Real-device follow-up required:** normal Series entry lacked a visible default selection and quick range buttons cleared selection/title; these state issues were addressed on the later detail line. Not accepted/stable. |
| **Build189 / 0.14.22** | Carousel native raw/coalesced-touch input | Native movement sampling worked, but **real-device rejected:** releasing a drag could leave the carousel frozen at the intermediate progress instead of completing/cancelling. Source inspection showed native recognition was competing with the SwiftUI-only release owner. |
| **Build190 / 0.14.23** | Carousel release-owner implementation under collided identity | The passive-native / SwiftUI-release implementation passed dedicated Release CI and produced an IPA, but the same Build190 identity was already used by the parallel detail-selection line. **Carousel Build190 identity retired; do not distribute or use for attribution.** |
| **Build191 / 0.14.24** | Detail episode-selection/navigation completion | Inherits the Build188/190 detail-selection follow-ups and unifies the compact summary with the exact horizontal-card `displayEpisodeTitle(episode)` formatter. User accepted the complete detail/episode-page behavior on the target device and PR #257 merged to `main` at `f153a36e9da8a208150fe638e0b9df5835df1dc0`. **Current accepted overall baseline / stable for this detail-selection task.** |
| **Build192 / 0.14.25** | Add/Edit Emby modernization + same-server multi-route startup | Modern card editor, one-tap clipboard import, editor-only route latency, root-level auto-start, synchronizable Keychain opt-in server registry, and first-valid same-Server-ID route selection before Home client creation. Dedicated Xcode 16.4 standard MPV Release CI passed, app identity/MinOS 15.0 validated and unsigned IPA produced. **Real-device pending; does not replace Build191.** |
| **Build193 / 0.14.26** | Carousel passive native movement + single SwiftUI release owner | Dedicated Release CI passed and IPA/checksums verified, but **real-device rejected:** the new recording again shows drag progress moving while finger release leaves the carousel frozen between pages. Making the native recognizer passive did not restore the underlying SwiftUI settle path; this hybrid ownership is not a valid baseline. |
| **Build194 / 0.14.27** | Player non-standard SeasonId grouping | Dedicated standard MPV Release CI passed and IPA produced. The original CI ZIP hit TrollStore parse error 302, while a packaging-only rewrap with the same app content installed successfully. **Real-device grouping result positive:** the supplied 980-episode Series now displays the complete episode set in the player picker. Follow-up required because opening that 980-card eager `HStack` blocks for several seconds. |
| **Build195 / 0.14.28** | Lazy player episode row for very large seasons | Replaces only the player picker's eager episode `HStack` with `LazyHStack`; full canonical data, SeasonId grouping, UI and auto-next remain unchanged. Dedicated Xcode 16.4 Release CI passed, MinOS 15.0 validated and TrollStore-friendly IPA produced. **Real-device performance validation pending; does not replace Build191.** |

## Current accepted baseline

- OnePlayer **0.14.24 / Build191**
- canonical branch: `main`
- final merge PR: `#257`
- final merge commit: `f153a36e9da8a208150fe638e0b9df5835df1dc0`
- development branch: `feat/detail-episode-selection-navigation`
- final feature head before merge: `8279df9f8ceb7605bad1fade9bcba2582cddbbd6`
- functional Build191 commit: `6dc3f69d90049cd9228bdf006e50fc3402c1c6b9`
- dedicated CI source: `63fb252936360b284d75c4477d41587193e4fbd8`
- CI run: `32875670990`
- artifact: `OnePlayer-0.14.24-build191-detail-summary-title`
- artifact ID: `9573898096`
- IPA: `OnePlayer-0.14.24-build191-detail-summary-title-unsigned.ipa`
- IPA SHA-256: `03c7dd61c2f151d537e78ec6727f888381d86839ea1ff75f0bbb388c3c56a354`
- source ZIP SHA-256: `25c28eb7529cb371aa4b2d991691811c041bdecc4e9904538c663fb976267a98`
- target device: iPhone 15 Pro Max / iOS 17.0
- Deployment Target / MinOS: **iOS 15.0**
- evidence level: **Code written / CI passed / IPA produced / real-device accepted / stable for completed detail-selection requirements / merged to main**

Build182 remains accepted/frozen for detail scrolling and force-quit/relaunch presentation restoration; Build184 remains the accepted detail visual-hierarchy foundation. Build191 is now the accepted overall runtime baseline and adds the accepted detail episode-selection/navigation contract. Build192 / 0.14.25 Add/Edit Emby remains an independent candidate; Build193 carousel is rejected/investigation. Build194 proved the player SeasonId-grouping correction on real device but exposed large-list open latency; Build195 is the active performance candidate. None of these candidates replace Build191 until separately accepted.

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

Build176 passed the dedicated selector/frozen-file contract checks, Xcode 16.4 Release compile, OnePlayer 0.14.9 (176) app identity validation, iOS 15.0 MinOS validation, IPA packaging and artifact upload. User real-device acceptance made its player episode-selection/session contract stable; Build178 and later candidates inherit that contract unchanged.

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
- IPA SHA-256: `80f2c70215fe3f1c9323894eedbd22c5f61b29bcfb61e3a6e14115a4b932ddd8`
- real-device evidence: persistent start dead zone plus freeze/large catch-up jump when reversing direction through center.
- evidence level: **Code written / CI passed / IPA produced / real-device tested and rejected / not stable**

## Build180 home-carousel evidence

- branch: `perf/home-carousel-drag-smoothness-build180`
- CI run: `32845376285` — success
- artifact: `OnePlayer-0.14.13-build180-home-carousel-continuous-drag`
- artifact ID: `9562183159`
- IPA SHA-256: `9da61f301e610fd2dd8a20aafba22dd55fb415e609ac8b2fe8923407d73d40cc`
- real-device evidence: reversal continuity fixed; initial visible motion still coarse and overall feel below EX.
- evidence level: **Code written / CI passed / IPA produced / real-device tested / partial improvement / rejected for acceptance**

## Build183 home-carousel crossfade evidence

- branch: `perf/home-carousel-drag-smoothness-build183`
- CI run: `32849750890` — success
- artifact: `OnePlayer-0.14.16-build183-home-carousel-crossfade`
- artifact ID: `9563857302`
- IPA SHA-256: `ad96332ea3ce0bab9eabd03cfe16e39fe5a3c10513eacb4c072f9f8cd0133e57`
- result: **diagnostically useful but interaction regression / rejected as default direction**.

## Build185 home-carousel evidence

- task: `DEV-home-carousel-drag-smoothness` — Active
- branch: `perf/home-carousel-drag-smoothness-build185`
- CI run: **`32853247583` — success**
- artifact: `OnePlayer-0.14.18-build185-home-carousel-axis-acquisition`
- artifact ID: **`9565234614`**
- IPA SHA-256: **`1f7ec2f6d09540b344ad10c36c438c4626bf40be3985d01b0d1b3404818e9b24`**
- real-device result: **rejected** after OP vs EX recordings quantified first visible movement around 10/12/16 px vs 1/1/2 px and coarser ongoing increments.

## Build186 / Build187 home-carousel cadence evidence

- Build186 run `32858062142` success; artifact `9567101523`; IPA SHA-256 `08cdf0398e024f8cc64dd75b2e6dfecab2b26833807feb810e280034b345f780`.
- Build187 run **`32860057516` success**; artifact ID **`9567940931`**; IPA SHA-256 **`5fa04513919b5e2928ee2ca09cf45dddc79c91d64858971f571b423dbb2d50f8`**.

## Build189 home-carousel native-touch evidence

- branch: `perf/home-carousel-native-touch-build189-from187`
- CI run: **`32868634314` — success**
- artifact ID: **`9571260479`**
- IPA SHA-256: **`50c74bd43935a31ca3dda781c04a1113c2ce616c7da9e24e438cba78988c3a6d`**
- implementation: UIKit raw/coalesced touch samples drive manual transition progress; original SwiftUI predicted release commit, foreground page-slide, auto-advance and P0/Frozen contracts remain unchanged.

## Build181 detail-page evidence

- task: `DEV-detail-episode-page-optimization`
- CI run: `32845717063` — success
- artifact ID: `9562323675`
- IPA SHA-256: `698d80d59767134c9479d517cedf24bf6494e73099d2f9125fa3d7a431d5a2f8`
- real-device evidence: scroll clearly improved; force-quit/relaunch still showed cold presentation before Build182.

## Build182 persistent detail-cache evidence

- CI run: `32848214004` — success
- artifact ID: `9563302306`
- IPA SHA-256: `b9638df6f70f11be5f030ec7136a42125f2bc3a16af220c1d8b6de1b0cb3ce4c`
- real-device evidence: user accepted both detail scroll smoothness and force-quit/relaunch presentation restoration; these two requirements are frozen.

## Build184 detail visual evidence

- CI run: `32851745960` — success
- artifact ID: `9564647845`
- IPA SHA-256: `d89953c76b678fe1bc0b9f3fcc8b5b5b3ea430ec74bdd420834b427c91d47eb4`
- user accepted final visual result and PR #255 merged.

## Build192 Add/Edit Emby evidence

- task: `DEV-add-emby-page-optimization` — Active
- branch: `feat/add-emby-page-optimization`
- Draft PR: `#256`
- CI run: **`32875941745` — success**
- artifact ID: **`9574058602`**
- IPA SHA-256: **`b13b76d322c0b301b751ad3723ff0368cb9bc9d0182ec701cf5fcc7a16e4c81d`**
- source ZIP SHA-256: **`87bf231fb49a167a749174fe0e78d79c42ed05172b08df67f31cfb1b8a24ac33`**
- evidence level: **Code written / CI passed / IPA produced / real-device pending / not stable**

## Build191 detail episode-selection acceptance

- task: `DEV-detail-episode-selection-navigation` — completed and checkpoint retired after merge
- branch: `feat/detail-episode-selection-navigation`
- PR: `#257` — merged
- merge commit: `f153a36e9da8a208150fe638e0b9df5835df1dc0`
- CI run: `32875670990` — success
- artifact ID: `9573898096`
- IPA SHA-256: `03c7dd61c2f151d537e78ec6727f888381d86839ea1ff75f0bbb388c3c56a354`
- evidence: **Code written / CI passed / IPA produced / real-device accepted / stable / merged to main**.

## Build194 / Build195 player SeasonId + large-list evidence

- task: `DEV-player-nonstandard-episode-season-grouping` — Active
- branch: `fix/player-nonstandard-episode-season-grouping`
- Draft PR: `#258`
- Build194 SeasonId fix commit: `bf095264ed61640d6b6840a7fc1d57624fc390f0`
- Build194 dedicated run: **`32879897997` — success**
- Build194 artifact: `OnePlayer-0.14.27-build194-player-seasonid-grouping`; ID **`9575488345`**
- Build194 CI IPA SHA-256: `21ebddfff348efd8a48e82381183f711135dfb054ff6d83d80c54364d5813ad1`
- Build194 TrollStore-friendly rewrap SHA-256: `e8d969cbdcab42c05e847f1ef16492ea870f62273d65c4bcb5eafbb77f2d55ae`
- Build194 real-device evidence: rewrap installs successfully; the supplied 980-episode Series now displays complete player-picker data; opening the eager 980-card row blocks for several seconds, so Build194 is not stable.
- Build195 lazy-row product commit: `091ad4ca394256951ad7a142b4187cb25f96972c`
- Build195 dedicated CI source: `edd7d42bdee2b20bc327ed7d4341c7433c58bb15`
- Build195 workflow-restored branch head: `8c2f767652ce449deaa28f8cc9d8c21b95058af1`
- Build195 dedicated run: **`32884343196` — success**
- Build195 artifact: `OnePlayer-0.14.28-build195-player-episode-lazy-row`; ID **`9577124023`**; digest `sha256:262007d104d62252a837e075baf69fcdf36e8761b6fac9424b99f1aadc8de421`
- Build195 IPA SHA-256: **`fab4e7f6552933096f49b86c4b9d3604025e1dd916b186015a00097802543af2`**
- Build195 source ZIP SHA-256: `0c5f9e3b2a9621cc712b8ab94d7976199579489f1fc94e887ab7c4984311e394`
- Build195 packaging: CI directly places main `Info.plist` before the executable/remaining bundle content, following the Build194 rewrap structure that installed successfully through TrollStore.
- Build195 validation: SeasonId 980-item contract, lazy-row contract, Build178 canonical order, full-array auto-next, Frozen/P0 zero-diff, Xcode 16.4 Release, 0.14.28 (195), MinOS 15.0, IPA packaging/upload all passed.
- evidence: Build194 = **real-device grouping positive / performance follow-up required**; Build195 = **Code written / CI passed / IPA produced / real-device pending / not stable**.

## Maintenance rule

Add a row only when a build materially changes architectural understanding, becomes a real-device reference point, or freezes/rejects a direction.
