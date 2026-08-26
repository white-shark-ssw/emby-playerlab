# OnePlayer Project State

_Last updated after OnePlayer 0.14.32 / Build199 passed target-device acceptance for the Add/Edit Emby server-management line, after Home-carousel Build200 completed CI/IPA but was rejected on the target device for fixed foreground semantics, after Build201 restored horizontal foreground motion with short travel and produced a verified IPA, and after poster-scroll Build202 completed CI/IPA with target-device A/B still pending. Build199 remains the accepted overall functional baseline. The Home-carousel Build201 task and `DEV-poster-grid-smoothness` Build202 task remain Active and independent._

## Current functional baseline

The latest **real-device accepted** functional baseline is:

- Product: **OnePlayer**
- Version / Build: **0.14.32 / Build199**
- Canonical branch: `main`
- Final merge PR: **#256**
- Final merge commit: `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`
- Development branch: `feat/add-emby-page-optimization`
- Real-device-tested product source / dedicated CI source: `2b5f3bef073754371443c6c7a345657dbfa2a09a`
- Final PR head after removing the two temporary Build199 CI helpers: `9357f0cd9395b3e8ef75920d630578d739d5518b`
- Tested-source → final-PR-head delta: **temporary workflow deletions only; accepted product source unchanged**
- Dedicated standard MPV CI run: **32942618979 — success**
- Artifact: `OnePlayer-0.14.32-build199-add-emby-password-sync`
- Artifact ID: `9597143667`
- Artifact digest: `sha256:94d19775fc82d42232d1d5f3efe40b0f04719e599cb5cfb7317746490ca51972`
- IPA: `OnePlayer-0.14.32-build199-add-emby-password-sync-unsigned.ipa`
- IPA SHA-256: `8f0f43f62705e5e13ae666cc54d32fd047c596df1d0e9335668b01a25b6eb003`
- Deployment Target / built MinOS: **iOS 15.0**
- Required target device: **iPhone 15 Pro Max / iOS 17.0**
- Evidence: **Code written / CI passed / IPA produced / real-device accepted / stable for accepted Add/Edit Emby requirements / merged to main**

Build199 inherits the previously accepted Build195 player SeasonId/large-list behavior, Build191 detail episode-selection/navigation contract, Build184/182 detail presentation contracts, Build178 canonical Emby TV episode ordering, Build176 source-owned episode-session replacement, Build173 PiP freeze point, and the frozen MPV/Transport/Cache/STRM→302→115/CDN client-direct contracts.

## Accepted Add/Edit Emby server-management contract

Build192 established the modern Add/Edit server UI and same-server multi-route direction. Target-device feedback accepted that direction but exposed the missing Edit password row and refined auto-start to cached-first. Build196 established cached-first startup and optional password reauthentication. Build199 supersedes the earlier password-exclusion wording and completes the user-approved behavior.

Current accepted contract:

- `SessionStore` remains the single owner of saved Emby sessions and their server configuration; UI/runtime routing metadata does not get pushed into playback ownership.
- Add/Edit uses the modern server editor, one-tap clipboard parsing, route add/remove/probe, auto-start and iCloud controls.
- Alternate routes must resolve through the existing Emby public-info path to the **same Emby Server ID** before they are accepted as one server configuration.
- Route latency is editor/diagnostic information only. It is not a second runtime state owner and is not sprayed across Home/search/favorites/settings.
- Auto-start is **cached-first**: after local session/token restore, OnePlayer constructs the authenticated Emby root immediately so existing Home snapshots and image disk cache can render before route selection/live refresh completes.
- Best-route selection still runs concurrently. If a valid winner differs, normal Home state is rebuilt/refreshed with that client. If route selection fails while the cached-first client exists, stale cached Home remains instead of closing back to the first-level server list.
- A successful runtime route winner becomes the current session `serverURL`, improving the next launch's host-sensitive image disk-cache hits without creating a second route cache owner.
- The Emby password is retained in a **dedicated local Keychain item** and is preloaded into Edit Server.
- Saving an unchanged Edit password does not force unnecessary reauthentication.
- A changed password authenticates the stored username on a validated same-server route and must preserve the same Server ID (when returned) and exact User ID before the AccessToken is replaced.
- When `iCloud 同步` is enabled for that server, the password is additionally stored in a **separate `kSecAttrSynchronizable` Keychain item** for cross-device propagation. Turning sync off removes that synchronizable password item while the local password remains.
- Password is not embedded in UserDefaults, plain `EmbyServerConfiguration`, diagnostics, or the synchronized JSON server registry. AccessToken and password remain separate Keychain records.
- Same-server route selection changes only the Emby API/server entry. Media still follows `Emby / STRM → 302 → 115/CDN → iPhone`; the NAS must never relay media bytes.
- Player, MPV Seek, PiP, UnifiedTransport, Range/206, Cache, Emby Resume/progress and episode-ordering ownership remain outside this feature.

Build199 was accepted by the user on the target device and merged through PR #256. Treat this Add/Edit Emby contract as stable unless new real-device regression evidence requires reopening it.

## Accepted episode-selection and ordering contracts

### Build176 — source-owned episode-session replacement

- The in-player episode overlay keeps the accepted compact horizontal picker interaction.
- Selecting another episode replaces the complete source-owned playback session while the fullscreen host stays presented.
- Each selected episode gets a fresh `PlayerController`, orchestrator, transport context and Emby playback session.
- Temporary 115/CDN media URLs are resolved only on explicit episode selection or trusted natural auto-next; they are not pre-resolved as long-lived metadata.
- Auto-next may advance only through the existing trusted natural-end / `PrematureEOFGuard` gate. Raw engine EOF, starvation, premature EOF or abnormal short-media recovery is not enough.

### Build178 — canonical Emby TV episode order

- Canonical series episodes come from `GET /Shows/{SeriesId}/Episodes`.
- OnePlayer preserves Emby's returned order; it does not invent title/file/date/item-ID/artificial-number fallback sorting.
- `SeasonId` is season-membership authority, not a second in-season sort owner.
- Detail, full picker, player picker and trusted auto-next consume the same canonical episode array.

### Build191 — detail episode browsing

- Detail horizontal episode cards select only; they do not autoplay.
- Visible selection has one owner: `selectedEpisodeID`.
- Default selection is explicit initial episode → resumable episode → canonical first episode.
- Quick range buttons select that range's first canonical episode rather than clearing selection.
- Main Play/Resume targets the selected episode through the existing source-owned playback path.
- Full-picker playback leaves the picker mounted so closing player returns to the same picker/ScrollView state.
- Compact selected summary reuses the exact horizontal-card title formatter.

### Build194/195 — nonstandard SeasonId grouping and very large seasons

- Player episode metadata uses the same canonical `seriesEpisodes(seriesId:) + seriesSeasons(seriesId:)` semantics as detail.
- Episode `SeasonId` is resolved against the real Season item/index first; `ParentIndexNumber` is only a fallback.
- The supplied 980-episode single-SeasonId library remains complete in the player picker.
- The horizontal player episode row uses `LazyHStack`; large seasons are not solved by truncation, artificial pagination or a second sort.
- Trusted auto-next still indexes the full canonical episode array, not the UI-filtered season list.

Build195 remains the accepted player grouping/large-list foundation inherited by Build199.

## Detail-page accepted foundations

- **Build182** is frozen for high-rate detail scrolling and force-quit/relaunch presentation restoration. High-frequency native scroll offset is scoped to the Hero owner rather than root detail state.
- Build182's persistent detail cache is **presentation-only**: safe display metadata may be cached, but PlaybackInfo, MediaSource, PlaySession, ResolvedPlaybackSource and temporary 115/CDN URLs remain live/session-owned.
- **Build184** is the accepted detail visual hierarchy foundation.
- **Build191** is the accepted detail episode-selection/navigation foundation.

## Player / transport / PiP frozen contracts

- MPV remains the normal/main playback engine; MDK remains manual/experimental backup.
- Left double-tap immediately rewinds and right double-tap immediately fast-forwards; repeated rapid double-taps must not wait for debounce accumulation.
- MPV fast Seek uses one native `absolute+keyframes` Seek. Do not silently restore an `absolute+exact` correction loop.
- Real player byte demand / HTTP Range demand is authoritative. Never restore `targetTime / duration × fileSize` as a Seek/Transport anchor.
- UnifiedTransport/Cache remains shared infrastructure below the engine; Range/206 and session-level cache semantics remain required.
- Emby Resume/progress synchronization and abnormal short-media/premature-EOF diagnostics remain required.
- Media bytes never transit the NAS. STRM/HTTP 302 must end in client-direct 115/CDN playback.
- SwiftUI View lifecycle must not own Player/Transport/Cache/Emby Session core lifetimes.
- Native iOS navigation / interactive pop remains system-owned.
- PiP remains frozen at the accepted Build173 architecture: SampleBuffer visual bridge, MPV playback/audio/time authority, `vid=no` background suspension, PiP X = `pauseAndSuspend`, and no periodic bridge catch-up loop.

## Current parallel development

### Home carousel interaction — Active independent task

`DEV-home-carousel-drag-smoothness` is now testing **OnePlayer 0.14.34 / Build201**. Build199 remains the accepted overall runtime baseline; Build201 is not yet target-device accepted, merged or stable.

Build198 retained evidence:

- Build198 identity: `0.14.31 / 198`.
- One UIKit interaction surface owns begin/move/end/cancel; SwiftUI renders `V3HomeCarouselTransitionState`.
- Successful CI/IPA source: `a569155d443433a5f4769dfe506fec6ab9bdd0e6`; run/job `32987054824` / `98235720724`.
- Durable base after CI cleanup: `c769f2c4c05fffdb36e90d78d8baddec5e0e7c21`.
- Target-device result: release/settle/reversal and other tested behavior okay, but minimum/subtle drag still too coarse vs EX.
- Conclusion: **single UIKit input ownership retained; full-width visual mapping not accepted as final smoothness.**

Build200 evidence:

- identity/source: `0.14.33 / 200`, `4d3afe36768b7749d9d0bd0081725f3d947b2099`.
- visual delta: foreground offset fixed at zero; linear `1-progress / progress` blend; Build198 input owner/thresholds/settle unchanged.
- CI run/job `32991758526` / `98250719262` succeeded through Release/app validation/MinOS/packaging/upload.
- artifact ID `9614995121`; IPA SHA-256 `509395ca7fb847548110c22ec0a3f6b005e6b3f4521f911eb9b3f765ca6d1b1a`.
- target-device result on 2026-08-27: **rejected regression** because foreground content became fixed and no longer slid horizontally.
- Evidence: **Code written / CI passed / IPA produced+verified / real-device tested / rejected / not stable.**
- Fully fixed foreground must not be restored as the default carousel behavior.

Current Build201 evidence:

- identity: **0.14.34 / 201**.
- branch: `perf/home-carousel-short-travel-build201`.
- tested source: `e61070146d91bac45400e3f95e28eead756faa81`.
- runtime delta from Build198 remains scoped to `Sources/Core/AppIdentity.swift` and `Sources/UI/EmbyHomeCarouselStateV3.swift`; no Frozen/P0 runtime path touched.
- foreground horizontal slide is restored, but total travel is `0.15 × Hero width`; foreground opacity is the same linear progress blend.
- Build198 UIKit lifecycle owner, 0.5pt acquisition, 0.28 commit, 0.48×width release gate, settle, Hero/Core ownership, vertical ScrollView arbitration, tap and auto-advance remain unchanged.
- first one-shot run `32992912212` stopped before compilation because the inherited contract script hard-coded Build198 version `0.14.31`; product code did not fail. The check was minimally corrected for Build201's actual version/travel/blend contract.
- successful fixed-source run/job: **`32993286519` / `98255950676`** — source/Frozen guard, Xcode 16.4, icons, dependencies, Release build, app validation, MinOS, packaging and upload all succeeded.
- artifact: `OnePlayer-0.14.34-build201-home-carousel-short-travel`, ID **`9615585817`**, digest `sha256:95dcc70016c72c3dcab2a918331ebb5c5e3a9d1348a4ac3139fbc647c3dea231`.
- IPA SHA-256: `d889f2c36b3f617b429e4f39ba54d39d7f2826a058a2d4f874bc7a9bb574db58`; source ZIP SHA-256: `5f0392a2e472ed1e863c265a05a695ba1788b02c163f0c21e3117b0be002ea6e`.
- independent verification: bundle `com.embyplayerlab.app`, version/build `0.14.34 / 201`, MinOS `15.0`, primary/alternate icons and artifact hashes all correct.
- one-shot main helper was deleted after artifact capture; cleanup commit `a041d883dc153cc3b9be57dc4a8f4160ab779c02` changes only CI helper state.
- Evidence: **Code written / CI passed / IPA produced+verified / real-device pending / not stable.**

Target-device next action is Build201 A/B against Build198/Build200/EX: confirm foreground clearly slides again and judge whether 15% travel makes tiny motion materially finer without losing directionality. Do not change the 15% factor before that evidence.

### Poster 3-column / poster-heavy scroll smoothness — Active independent task

`DEV-poster-grid-smoothness` owns **OnePlayer 0.14.35 / Build202** on `perf/poster-grid-smoothness`, draft PR **#259**. Its current checkpoint is authoritative for the detailed source/profiling rationale.

Current Build202 evidence:

- accepted overall runtime remains Build199; Build202 is an independent performance candidate.
- target-device recording already proves the existing baseline hitch: at least one recorded ~33.3 ms stop-frame followed by catch-up around 6.80 s. This proves the problem, not the candidate fix.
- exact tested source: `a05dd3424bb499e46dc0834e69cf55654fb7733e`.
- durable feature head after deleting only the temporary feature workflow: `6e16865d1589a953f58bf65885d9fb01ff6374e0`; tested product/runtime source is unchanged by that cleanup.
- Build202 keeps the existing lazy containers and removes source-proven common-path poster overhead: duplicate grid Environment injection, unused callback-state publication, invisible loading-state publication, unchanged initial `image=nil` publication, oversized Home poster request width, and actor-result loading-state work.
- exact feature delta excludes Player/MPV/PiP/UnifiedTransport/playback Cache/Emby playback-session and active carousel gesture/state-owner files.
- successful exact-source run/job: **`32993726508` / `98257448257`**.
- artifact: `OnePlayer-0.14.35-build202-poster-scroll-smoothness`, ID **`9615751921`**, digest `sha256:1fa9236d08210440a80b2f9af2fcef24e5608aac6f8c52be602295b40ec68777`.
- IPA SHA-256: `f6e3a30206acf2cfd877df74f41aa13f1575e1614407eff79466884f9ec51279`; source ZIP SHA-256: `19ebc6a2bcefd61d53eb4a9eea7617d5e98be7f8ae7b4f2dbf027ff62d8fabfe`.
- IPA/source ZIP integrity, app identity `0.14.35 (202)`, bundle, icons and MinOS `15.0` were independently verified.
- temporary Build202 feature workflow and one-shot main helper were deleted after evidence capture.
- Evidence: **Code written / scoped diff + existing-problem real-device evidence / CI passed / IPA produced+verified / candidate real-device pending / not stable.**

Target-device next action for Build202 is A/B across Home, library 3×3, favorites/more, search, tag search and person/actor results. Do not claim the candidate fixed scrolling until that A/B is reported.

## Current development direction

Build199 / OnePlayer 0.14.32 remains the current real-device accepted overall `main` functional baseline. Current independent Active feature lines are Home-carousel Build201 and poster-scroll Build202; both now have verified CI/IPA evidence and both still require target-device validation before acceptance or integration. If either line is accepted, its durable product diff must be resynced against then-current `main` and affected validation rerun when the integration source materially changes. Protect all frozen playback/transport/cache/PiP/episode contracts throughout both lines.
