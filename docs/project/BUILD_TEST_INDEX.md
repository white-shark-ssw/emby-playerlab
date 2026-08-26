# OnePlayer Build / Test Index

This is a milestone index, not a list of every experimental build. Evidence levels are kept distinct: Code written → CI passed → IPA produced → real-device tested → stable/frozen.

| Milestone | Main purpose | Result / current meaning |
|---|---|---|
| Build84 / 0.13.17 | MDK RecoveryIsolation | Protected app/exit lifecycle better; did not prove abnormal media was solved. |
| Build96 | MDK single-generation safety | Avoided unsafe same-process MDK generation rebuild after failure. |
| Build98 / 0.13.31 | Recovery/refresh continuation | Continued protection/detail-state work; protection ≠ MDK compatibility solved. |
| Build111 / 0.13.44 | MDK Seek / transport-tail experiments | Real-device feedback still showed worse long-tail Seek than MPV. |
| Build131 / 0.13.64 | MPV intent Seek | Fast double-tap recovered low latency; exact scrub path demonstrated precision/latency trade-off. |
| Build145 / 0.13.78 | MPV fast keyframe Seek convergence | Current fast-Seek architecture established; no-cache tests were roughly P50 86.6 ms, P90 106 ms, P95 111.8 ms. |
| Build146 / 0.13.79 | MPV Seek code cleanup | Removed historical experiment scaffolding while keeping Build145 runtime contract. |
| Build160 / 0.13.93 | PiP native handoff work | Expanded SampleBuffer handoff and fresh-frame return gating. |
| Build167 / 0.14.0 | PiP lifecycle semantics | `vid=no` background video suspension; PiP X = `pauseAndSuspend`. |
| Build170 / 0.14.3 | Persistent PiP visual bridge | SampleBuffer host remains the visual bridge while MPV renderer recovers. |
| Build171 / 0.14.4 | PiP authority/seek-tail guard | Added return authority alignment and rare long-tail visual escape. |
| Build172 / 0.14.5 | PiP handoff authority controls | Real-device analysis showed periodic bridge catch-up introduced visible churn. |
| **Build173 / 0.14.6** | PiP Seek completion + return simplification | PiP freeze point. Functional enough to keep frozen unless a materially better renderer-lifecycle approach appears. |
| Build174 / 0.14.7 | First player episode selector + auto-next | CI/IPA succeeded; target device confirmed data path but rejected the large gray sheet/X/title presentation. |
| Build175 / 0.14.8 | Episode selector UI refinement | CI/IPA succeeded; real-device screenshot exposed lower-button visual bleed and badge alignment. |
| **Build176 / 0.14.9** | Episode overlay completion | Real-device accepted; PR #253 merged at `d10e0d63b429f72a664193a1a5bacf728cac50b6`. Source-owned episode-session replacement and trusted-natural-end auto-next remain stable. |
| Build177 / 0.14.10 | Preliminary carousel smoothness | CI/IPA only; superseded before distribution. |
| **Build178 / 0.14.11** | Canonical Emby episode ordering | Real-device accepted; `/Shows/{SeriesId}/Episodes` order became canonical; PR #254 merged at `9e0d0cecb2df0a263a9a4a4c1f92c2d0e473d78f`. |
| **Build179 / 0.14.12** | First accepted-baseline carousel candidate | Real-device rejected: small-drag dead zone and reversal pause/catch-up remained. |
| **Build180 / 0.14.13** | Carousel reversal continuity | Real-device partial improvement: reversal fixed, initial motion still coarse; rejected for acceptance. |
| **Build181 / 0.14.14** | Detail Hero scroll isolation | Real-device scroll clearly improved; force-quit/relaunch warm presentation still failed. |
| **Build182 / 0.14.15** | Persistent detail presentation cache | Real-device accepted/frozen for detail scrolling and force-quit/relaunch presentation restoration. |
| **Build183 / 0.14.16** | Carousel fixed-foreground crossfade experiment | Felt somewhat finer but changed required page-slide semantics; rejected as default direction at that stage. |
| **Build184 / 0.14.17** | Detail visual hierarchy completion | Real-device accepted; PR #255 merged at `5bf00bb0f48d0b640bcbea740d4c17c9f8e7be8f`. |
| **Build185 / 0.14.18** | Carousel axis-acquisition/page-slide refinement | Real-device rejected: first visible movement remained about 10/12/16 px vs EX about 1/1/2 px. |
| Build186 / 0.14.19 | Carousel drag-cadence instrumentation | CI/IPA only; first log channel was not exportable through existing playback logs. |
| **Build187 / 0.14.20** | Exportable carousel cadence diagnostic | Real-device diagnostic confirmed first useful SwiftUI horizontal samples about 4.33/8.00/15.67/11.00pt, maxFPS=120, Low Power Mode off. |
| **Build188 / 0.14.21** | Detail episode-selection first candidate | CI/IPA succeeded; real-device follow-up exposed missing default selection and range-button selection clearing. |
| **Build189 / 0.14.22** | Carousel native raw/coalesced movement | Real-device rejected: release could freeze between pages because native movement and SwiftUI release ownership diverged. |
| Build190 / 0.14.23 | Collided carousel identity | Carousel package retired because the same identity belonged to the parallel detail line; do not use for attribution. |
| **Build191 / 0.14.24** | Detail episode-selection/navigation completion | Real-device accepted; PR #257 merged at `f153a36e9da8a208150fe638e0b9df5835df1dc0`. |
| **Build192 / 0.14.25** | Add/Edit Emby modernization + multi-route startup | CI/IPA passed; real-device accepted editor direction but exposed missing Edit password row and refined startup to cached-first. Superseded. |
| **Build193 / 0.14.26** | Carousel passive native movement + SwiftUI release | Real-device rejected: split ownership still froze at intermediate progress. Hybrid native-move/separate-SwiftUI-release architecture rejected. |
| **Build194 / 0.14.27** | Player nonstandard SeasonId grouping | Real-device grouping positive: complete supplied 980-episode Series appeared; eager 980-card row exposed opening latency. |
| **Build195 / 0.14.28** | Lazy player episode row | Real-device accepted; `LazyHStack` solved the large-row construction issue while preserving complete canonical data. PR #258 merged at `a3f79b5bed7ec835cd53f48aa9eb6cadcdf884e1`. |
| **Build196 / 0.14.29** | Cached-first auto-start + optional password reauth | Dedicated CI/IPA passed. Historical predecessor to Build199; its password-exclusion policy was superseded by the user's retained-password/iCloud-sync requirement. |
| **Build198 / 0.14.31** | Home-carousel single UIKit lifecycle owner | CI/IPA passed and verified. Real-device: release/settle/reversal and other tested behavior were okay, but minimum/subtle drag remained visibly coarse vs EX; rejected for final carousel smoothness while its single-owner input architecture is retained. |
| **Build199 / 0.14.32** | Add/Edit Emby completion + password retention/iCloud sync | Dedicated standard MPV CI passed, IPA produced, target-device acceptance passed, and PR #256 merged at `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`. **Current accepted overall baseline.** |
| **Build200 / 0.14.33** | Carousel fixed-spatial foreground + linear EX blend | Independent carousel candidate; not owned by the poster-scroll task. Refer to `DEV-home-carousel-drag-smoothness` for its latest evidence. |
| **Build201 / 0.14.34** | Carousel short-travel follow-up | Independent carousel candidate; exact Build201 CI helpers/source exist, so this identity is reserved to the carousel line and must not be reused. |
| **Build202 / 0.14.35** | Poster-heavy scrolling smoothness | `DEV-poster-grid-smoothness` candidate. Target-device recording proves an existing stop-frame/catch-up hitch. Exact feature source `a05dd3424bb499e46dc0834e69cf55654fb7733e` removes source-proven poster invalidation/decode overhead while preserving layouts/navigation/P0 paths. One-shot run `32993726508` is in progress at this index update; CI pass, IPA and candidate real-device improvement are not yet claimed. |

## Current accepted baseline

- Product: **OnePlayer 0.14.32 / Build199**
- canonical branch: `main`
- final merge PR: `#256`
- final merge commit: `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`
- development branch: `feat/add-emby-page-optimization`
- real-device-tested product source / dedicated CI source: `2b5f3bef073754371443c6c7a345657dbfa2a09a`
- final PR head after temporary workflow cleanup: `9357f0cd9395b3e8ef75920d630578d739d5518b`
- tested-source → final-PR-head diff: the two temporary Build199 workflows were deleted; accepted product files were unchanged
- CI run: **`32942618979` — success**
- artifact: `OnePlayer-0.14.32-build199-add-emby-password-sync`
- artifact ID: **`9597143667`**
- artifact digest: `sha256:94d19775fc82d42232d1d5f3efe40b0f04719e599cb5cfb7317746490ca51972`
- IPA: `OnePlayer-0.14.32-build199-add-emby-password-sync-unsigned.ipa`
- IPA SHA-256: **`8f0f43f62705e5e13ae666cc54d32fd047c596df1d0e9335668b01a25b6eb003`**
- Deployment Target / built MinOS: **iOS 15.0**
- target device: **iPhone 15 Pro Max / iOS 17.0**
- evidence: **Code written / CI passed / IPA produced / real-device accepted / stable for accepted Add/Edit Emby requirements / merged to main**

Build199 inherits all previously accepted/frozen player, PiP, transport, cache, episode-ordering, detail-presentation and episode-selection contracts. The independent home-carousel and poster-scroll lines remain Active and are not made stable by this merge.

## Build202 poster-scroll evidence

- task: `DEV-poster-grid-smoothness`
- branch / draft PR: `perf/poster-grid-smoothness` / #259
- identity: **0.14.35 / 202**
- exact feature source: `a05dd3424bb499e46dc0834e69cf55654fb7733e`
- existing-problem real-device evidence: supplied 30 fps recording contains at least one stop-one-recorded-frame → catch-up-next-frame event around 6.80 s; this proves the baseline hitch, not the candidate fix
- source scope: `EmbyPosterGrid`, shared image loader/view, `V3PosterCard`, person-result poster, AppIdentity, changelog, checker and task CI helper only
- key reductions: no per-cell duplicate grid Environment wrappers; no unused callback-tracking state write; no invisible loading-state publication for ordinary posters; no unchanged initial `image=nil` publication; Home 118 pt posters request actual screen-scale pixel width (~354 px on 3×) instead of fixed 440 px
- no Player/MPV/PiP/UnifiedTransport/playback Cache/Emby playback-session or carousel gesture/state-owner file in the feature delta
- one-shot exact-source CI run: **32993726508 — in progress at this update**
- artifact / IPA: pending
- target-device result: pending
- evidence: **Code written ✅ / exact scoped diff ✅ / existing-problem real-device evidence ✅ / CI running / IPA pending / candidate real-device pending / not stable**

## Build199 Add/Edit Emby evidence

- task: `DEV-add-emby-page-optimization` — **completed; checkpoint retired after final documentation sync**
- Build192 real-device feedback: editor direction accepted; tested route displayed latency/fastest state; auto-start+iCloud controls rendered; missing Edit password row rejected
- Build196: established cached-first Home startup and optional changed-password reauthentication; later superseded on credential retention/sync policy
- Build199 accepted credential contract:
  - dedicated local Keychain password item for retained/editable password
  - Edit Server preloads that password
  - unchanged password does not force reauthentication
  - changed password authenticates stored username and requires same Server ID/User ID before token replacement
  - opt-in iCloud sync uses a separate `kSecAttrSynchronizable` Keychain password item
  - disabling iCloud sync removes the synchronizable password item while retaining the local password
  - password is not embedded in UserDefaults, plain server configuration, diagnostics, or synchronized JSON registry
- cached-first startup remains: local session/token can construct Home before route selection/live refresh; stale cached Home survives route failure when the initial client exists
- same-server route selection remains: alternate entries must resolve to the same Emby Server ID; runtime winner can become current `serverURL` for future host-sensitive cache hits
- frozen media path remains `Emby / STRM → 302 → 115/CDN → iPhone`; no NAS byte relay
- tested source / CI source: `2b5f3bef073754371443c6c7a345657dbfa2a09a`
- final PR head after deleting temporary CI helpers only: `9357f0cd9395b3e8ef75920d630578d739d5518b`
- dedicated standard MPV run: **`32942618979` — success**
- artifact / ID: `OnePlayer-0.14.32-build199-add-emby-password-sync` / `9597143667`
- artifact digest: `sha256:94d19775fc82d42232d1d5f3efe40b0f04719e599cb5cfb7317746490ca51972`
- IPA SHA-256: `8f0f43f62705e5e13ae666cc54d32fd047c596df1d0e9335668b01a25b6eb003`
- MinOS: 15.0
- real-device result: **accepted** — user explicitly reported acceptance and requested task closure/code merge on 2026-08-26
- merge: PR `#256` → `main` at `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`

## Accepted foundation evidence

### Build176 episode-session replacement

- merge PR #253: `d10e0d63b429f72a664193a1a5bacf728cac50b6`
- accepted contract: selecting another episode replaces the complete source-owned playback session; auto-next uses trusted natural-end/PrematureEOFGuard rather than raw EOF.

### Build178 canonical episode order

- merge PR #254: `9e0d0cecb2df0a263a9a4a4c1f92c2d0e473d78f`
- accepted contract: canonical series order comes from `GET /Shows/{SeriesId}/Episodes`; no title/file/date/ID/artificial-number fallback sorting.

### Build182/184 detail presentation

- Build182: real-device accepted/frozen for detail scroll isolation and persistent presentation-only cache.
- Build184 merge PR #255: `5bf00bb0f48d0b640bcbea740d4c17c9f8e7be8f`
- accepted boundary: presentation cache excludes PlaybackInfo/MediaSource/PlaySession/ResolvedPlaybackSource/temporary 115-CDN URL and live server refresh remains final authority.

### Build191 detail episode selection

- merge PR #257: `f153a36e9da8a208150fe638e0b9df5835df1dc0`
- accepted behavior: select-only horizontal cards; explicit initial → resumable → canonical-first default; range-first quick jumps; main Play/Resume targets selection; full picker remains mounted through playback; compact summary matches card title formatter.

### Build194/195 player SeasonId + large-list behavior

- Build195 merge PR #258: `a3f79b5bed7ec835cd53f48aa9eb6cadcdf884e1`
- accepted behavior: Episode `SeasonId` resolves against real Season item/index first, `ParentIndexNumber` only fallback; full 980-episode canonical array remains; horizontal player row uses `LazyHStack`; no truncation/artificial pagination/second sort.

## Home-carousel independent evidence

The carousel line is independent from Build199 and remains Active under its own checkpoint/identities. Build200 and Build201 are reserved to that line; this file does not override the carousel checkpoint's more recent detailed state.

- Build187: target-device diagnostic showed first useful SwiftUI horizontal samples about 4.33/8.00/15.67/11.00pt with maxFPS=120 and Low Power Mode off.
- Build189/193: split movement/release ownership could freeze and is rejected.
- Build198: single UIKit lifecycle owner retained; CI/IPA passed, real-device lifecycle/settle good, minimum visual drag still too coarse vs EX.
- Build200 / 0.14.33: fixed-spatial/progress-blend carousel candidate.
- Build201 / 0.14.34: later carousel short-travel candidate; exact-source CI helper proves the identity is occupied by that task.
- Refer to `docs/project/current/dev/DEV-home-carousel-drag-smoothness.md` and its current source/CI evidence before any carousel change.
