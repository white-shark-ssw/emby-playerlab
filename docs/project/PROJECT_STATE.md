# OnePlayer Project State

_Last updated after OnePlayer 0.14.32 / Build199 passed target-device acceptance for the Add/Edit Emby server-management line. The user explicitly accepted the result and requested task closure/code merge on 2026-08-26. PR #256 merged the accepted product code to `main` at `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`. Build199 is now the accepted overall functional baseline. The home-carousel Build198 task remains an independent Active line and is not implied accepted by this merge._

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

`DEV-home-carousel-drag-smoothness` remains Active and owns **OnePlayer 0.14.31 / Build198** on its own branch/checkpoint. It is an independent interaction task and was not accepted, merged or stabilized by Build199.

Known carousel evidence remains:

- Build187 proved the first useful SwiftUI horizontal samples can already arrive several points into the gesture on the target device.
- Build189/193 proved split ownership between native movement and a separate SwiftUI release owner can freeze at intermediate progress after release; that hybrid architecture is rejected.
- The accepted page-slide visual requirement remains unless the user explicitly selects the previously allowed fixed-spatial/crossfade fallback.
- The carousel task's own current checkpoint is authoritative for its exact Build198 head/CI state and next action.

Do not reuse Build198 for another task and do not infer carousel acceptance from the Build199 merge.

## Current development direction

Build199 / OnePlayer 0.14.32 is the current real-device accepted overall `main` functional baseline. Add/Edit Emby is complete and its active checkpoint should be retired. New work must resync against current `main` and protect all frozen playback/transport/cache/PiP/episode contracts above. The only currently known independent feature line is the home-carousel Build198 task, which keeps its own branch, identity and evidence state.