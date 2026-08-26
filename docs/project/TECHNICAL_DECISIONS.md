# OnePlayer Technical Decisions

This file records decisions that have already consumed significant implementation or real-device testing. Do not casually re-run rejected directions.

## D001 — Media bytes never transit the NAS

Normal playback is client-direct:

```text
Emby / STRM → HTTP 302 → 115/CDN → iPhone
```

The NAS/Emby side may resolve or redirect, but it must never become the actual media-byte relay.

## D002 — Real byte demand is authoritative

Do not map playback time to file byte offset using:

```text
targetTime / duration × fileSize
```

That time→byte proportional guess is rejected as a Seek/Transport anchor. Actual player byte demand / HTTP Range demand is authoritative.

## D003 — Unified transport/cache is shared infrastructure

Network, HTTP 302, Range/206, cache and playback-demand handling belong below the playback engine. Do not rebuild separate 115/CDN networking inside each engine and do not let ordinary UI work create a competing transport owner.

## D004 — Fast interaction beats exact Seek

For double-tap / rapid ±N-second Seek:

- latency is P0;
- MPV `absolute+keyframes` is the accepted runtime contract;
- `absolute+exact` was rejected as the normal path because it materially increased latency;
- there is no hidden second corrective native Seek.

Long-GOP accuracy error is an accepted physical limitation of keyframe-oriented fast Seek.

## D005 — MDK is not the automatic daily authority

MDK remains a manual backup/experimental engine. MPV is the normal/main engine because repeated real-device work did not show MDK beating MPV on the primary requirement: repeated fast ±10-second Seek consistency and long-tail stability.

Do not silently restore broad automatic engine fallback logic.

## D006 — Renderer ownership must respect MoltenVK/MPV

Previous attempts to manually seize `CAMetalLayer.delegate` / drawable lifecycle caused real-device instability or crashes. UIKit may own host geometry; do not casually take over MoltenVK/MPV drawable or swapchain ownership.

## D007 — System navigation is system-owned

Native iOS push/pop and interactive-pop behavior remain system-owned. Immersive appearance may adapt around navigation, but product code must not replace that ownership merely for visual convenience or by raising the minimum OS.

## D008 — PiP uses a visual bridge; MPV remains authority

PiP is frozen at the accepted Build173 architecture unless new real-device evidence or a materially better renderer-lifecycle idea appears.

Accepted semantics include:

- SampleBuffer provides the native PiP visual surface/bridge;
- MPV remains playback/audio/time authority;
- background MPV video suspension uses `vid=no`;
- the SampleBuffer bridge persists through return while the MPV renderer recovers;
- PiP X = `pauseAndSuspend`, not Stop;
- completion follows visual/timebase commit rather than callback entry;
- the periodic bridge catch-up/rebase loop tested before Build173 is not part of the frozen design.

Known MPV/MoltenVK cold-return tail is accepted for now rather than reopening renderer ownership.

## D009 — Evidence levels must remain explicit

Always distinguish:

1. Code written;
2. CI passed;
3. IPA produced;
4. Real-device tested;
5. Stable / frozen.

A successful GitHub Action or generated IPA does not by itself prove a runtime issue solved.

## D010 — Episode changes replace the source-owned playback session

A playback session is source-owned: `PlayerController`, `PlaybackOrchestrator`, `PlaybackTransportContext`, Emby PlaySession and resolved media path correspond to the current item.

Therefore selecting another episode must not mutate `PlayerController.source` in place. The accepted Build176 architecture keeps the fullscreen host presented while replacing the complete child playback session:

- stop the previous source/session through existing lifecycle;
- resolve the newly selected episode through the existing Emby direct-play path;
- create a fresh controller/orchestrator/transport context/session;
- do not intentionally bounce the main interface through portrait between child sessions.

Episode metadata may be prefetched, but the next episode's temporary 115/CDN URL is resolved only after explicit user selection or trusted natural auto-next.

Auto-next may advance only after the existing pure `PrematureEOFGuard` classifies the end as non-premature. Raw engine EOF, buffering/starvation, abnormal short-media recovery or premature EOF is insufficient. No new timer/retry/watchdog is part of this contract.

Build176 / OnePlayer 0.14.9 was real-device accepted and merged through PR #253 at `d10e0d63b429f72a664193a1a5bacf728cac50b6`. Treat this session-replacement and trusted-end gate as stable unless new real-device regression evidence requires reopening it.

## D011 — Emby TV API owns canonical episode order

For a TV series, OnePlayer must not invent a second client-side ordering rule when Emby already exposes TV episode order.

Accepted Build178 contract:

- load series episodes from `GET /Shows/{SeriesId}/Episodes`;
- preserve Emby's returned order;
- keep Episode `SeasonId` as season-membership authority but not as another in-season ordering owner;
- retain pagination and ID-preserving deduplication;
- do not add title, filename, DateCreated, item-ID or artificial episode-number fallback sorting;
- detail, full picker, player picker and trusted auto-next consume the same canonical array.

Build178 / OnePlayer 0.14.11 was real-device accepted and merged through PR #254 at `9e0d0cecb2df0a263a9a4a4c1f92c2d0e473d78f`. This ordering authority remains stable.

## D012 — Home-carousel manual drag keeps one complete UIKit interaction owner; current visual candidate is fixed-spatial progress blend

The carousel line remains Active and is not made stable by Build199. The current task checkpoint is authoritative for exact Build200 branch/head/CI state.

Long-term evidence:

- high-frequency carousel transition state stays localized to `V3HomeCarouselTransitionState`; root Home must not regain per-finger transition progress/from/to/drag state;
- Build185 real-device comparison showed full page-slide but coarse first visible movement (about 10/12/16 px versus EX about 1/1/2 px);
- Build187 proved the first useful SwiftUI horizontal samples on the target device could already be roughly 4.33/8.00/15.67/11.00pt with maxFPS=120 and Low Power Mode off; further arbitrary threshold tuning is not evidence-supported;
- Build189 native movement plus separate SwiftUI release ownership could freeze at intermediate progress;
- Build193 retained separate SwiftUI release ownership and reproduced the same freeze;
- therefore hybrid native-move / separate-SwiftUI-end ownership is rejected. Do not patch it with timer/watchdog/reconciliation.

Build198 established the retained input architecture:

- one UIKit interaction surface owns begin/move/end/cancel;
- vertical acquisition yields to the Home `UIScrollView`, while horizontal acquisition owns the carousel gesture to completion/cancel;
- actual touch position is the render input; predicted touch is release-only;
- 0.5pt axis acquisition, 0.28 progress commit threshold, 0.48×width predicted-distance gate and existing settle timing remain one contract;
- no second SwiftUI drag/release owner is allowed.

Build198 target-device result on 2026-08-27 then separated **input correctness** from **visual smoothness**: release/settle/reversal and other tested behavior were okay, but the user reported that minimum/subtle movement was still “比较大” and less delicate than EX. Therefore the single-owner UIKit lifecycle is retained, while the old assumption that full-width foreground page translation must remain the default visual mapping is no longer supported for this task.

EX forensic evidence had already shown the Hero content remaining effectively spatially fixed while blend weight changes. Build183's fixed-foreground crossfade felt somewhat finer but was premature then because page-slide had not yet been proven under a correct single owner. Build198 now satisfies that prerequisite and still fails the subtle-motion target, so the previously conditional fallback is activated for Build200.

Current Build200 decision:

- keep the Build198 UIKit interaction owner and all release/axis/settle semantics unchanged;
- use the existing single `transitionProgress` as the only visual transition progress;
- keep foreground Logo/rating/year/type/overview spatially fixed (`carouselForegroundOffset = 0`);
- outgoing foreground opacity = `1 - progress`, incoming foreground opacity = `progress`;
- backdrop already follows the same progress-driven blend and does not gain a second state owner;
- do not add interpolation, timer, watchdog, retry, debounce or throttle simply to make opacity motion look smoother;
- if Build200 remains perceptually coarse, first attribute whether the remaining difference is publication cadence, compositing cost or blend curve before changing code again.

This visual decision is **not stable yet**: Build200 still requires CI/IPA and target-device A/B. The retained single-owner UIKit input architecture is the stronger architectural conclusion; the exact fixed-spatial blend curve remains under test.

## D013 — Detail high-rate scroll and warm presentation stay scoped and presentation-only

Build181/182/184 established two accepted ownership boundaries.

First, native detail `UIScrollView.contentOffset` is a high-frequency render input and must not be written into root detail-view state that invalidates the whole page. Build181 isolates the raw offset in the Hero-scoped owner while native ScrollView geometry remains authoritative.

Second, warm detail state is presentation-only. Build182 may persist safe display metadata such as episodes, seasons, image info and similar items under `Library/Caches/OnePlayer/DetailPresentation`, but normal Emby loading still refreshes current server data. PlaybackInfo, MediaSource, PlaySession, ResolvedPlaybackSource and temporary 115/CDN URLs do not enter this cache. Resume/played/favorite authority remains live server/session state.

Build182 was real-device accepted for detail scrolling and force-quit/relaunch restoration. Build184 added the accepted visual hierarchy and merged through PR #255 at `5bf00bb0f48d0b640bcbea740d4c17c9f8e7be8f`. Treat these boundaries as stable/frozen unless new regression evidence appears.

## D014 — Emby server entry selection is Session-owned and media transport remains separate

The Add/Edit Emby line is now stable at Build199.

Ownership and routing contract:

- `SessionStore` remains the single owner of saved Emby sessions and a separate `EmbyServerConfiguration` keyed by session ID for alternate entries, auto-start identity and sync preference. `EmbySession` is not broadened merely to carry UI/runtime routing state.
- Alternate entries are validated through the existing `EmbyAPIClient.publicInfo()` path and must resolve to the same Emby Server ID.
- At normal entry, valid same-server candidates race before the normal Home client is selected; the winner is then reused rather than racing every poster/image request.
- Route latency is editor/diagnostic state only and does not become presentation state across Home/favorites/search/settings.
- Same-server route selection changes only the Emby API/server entry. Media remains `Emby / STRM → 302 → 115/CDN → iPhone`; NAS never becomes a media-byte relay.
- Player, UnifiedTransport, Cache, Seek, Resume, episode ordering and PiP remain outside this feature.

Credential split accepted at Build199:

- local AccessToken storage keeps its existing local Keychain ownership/accessibility contract;
- password is stored in a **separate dedicated local Keychain item** for retained/editable credentials;
- the synchronized server registry may contain server configuration, AccessToken and auto-start state but **does not embed the password**;
- when `iCloud 同步` is enabled for that server, password is additionally stored in an independent `kSecAttrSynchronizable` Keychain password item;
- turning iCloud sync off removes that synchronizable password item while retaining the local password;
- password remains absent from UserDefaults, plain server configuration and diagnostics.

Build192 established the editor/server-routing ownership boundary. Build196 refined startup to cached-first. Build199 / OnePlayer 0.14.32 completed retained/editable password handling plus opt-in iCloud Keychain password synchronization, passed dedicated standard MPV CI, produced the validated iOS 15.0 IPA, was accepted by the user on the target device, and merged through PR #256 at `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`.

Treat this Add/Edit Emby ownership/credential split as stable unless new target-device regression evidence requires reopening it.

## D014A — Auto-start is cached-first; retained password is Keychain-owned

Build192 target-device feedback and accepted Build196/199 follow-ups establish the startup/editor runtime contract without reopening playback transport.

- Auto-start must not gate Home construction on network route selection. After local session/token restore, `RootView` creates the normal authenticated client synchronously and constructs the target Emby root immediately.
- Existing `V3EmbyHomeViewModel` UserDefaults snapshots and `EmbyImageDiskCache` are the cached-home authorities. Do not add a second offline-home model or duplicate state owner.
- Best-route selection runs concurrently. If the winner differs, normal Home is rebuilt/refreshed with that client. If route selection fails while an initial local client exists, stale cached Home remains rather than closing to the server list.
- `EmbyImageDiskCache.stableKey(for:)` removes token query items but retains scheme/host/path; persisting the runtime same-server winner as current `serverURL` improves future image-cache host matching without a second route-cache owner.
- Edit Server preloads the retained password from its dedicated local Keychain item.
- Saving an unchanged password does not force reauthentication.
- A changed password authenticates the stored username on the validated same-server best route and must preserve the same Server ID (when returned) and exact User ID before AccessToken replacement.
- With iCloud sync enabled, the password is also written to its separate synchronizable Keychain item. Disabling sync removes only that synchronizable password copy.
- Password stays out of UserDefaults, plain `EmbyServerConfiguration`, diagnostics and the synchronized JSON server registry.
- Manual entry from the first-level server list retains its pre-Home route-selection behavior; cached-first is specifically required for auto-start.

Build199 dedicated standard MPV run `32942618979` passed; artifact `OnePlayer-0.14.32-build199-add-emby-password-sync` ID `9597143667` produced an iOS 15.0 IPA whose SHA-256 is `8f0f43f62705e5e13ae666cc54d32fd047c596df1d0e9335668b01a25b6eb003`. The user accepted the target-device result and requested completion/merge; PR #256 merged at `730faecf30f7cdbfa7bf4670022dd2e1f3a8de9b`. This contract is stable for the accepted Add/Edit Emby requirements.

## D015 — Detail episode browsing separates selection from playback and keeps one selected-episode owner

Build191 establishes the accepted detail/episode browsing contract:

- tapping a horizontal detail episode card selects it and moves the blue outline; it does not autoplay;
- `selectedEpisodeID` is the single visible selection owner;
- normal Series entry chooses explicit `initialEpisodeID`, otherwise resumable episode, otherwise canonical `episodes.first`;
- quick range buttons select that range's first canonical episode rather than clearing selection;
- the existing main Play/Resume action targets the selected episode through the source-owned playback path;
- compact selected summary reuses the same `displayEpisodeTitle(episode)` formatter as the horizontal card;
- full-picker playback keeps the picker mounted so closing player returns to the same picker/ScrollView position without a second offset cache;
- no second playback-source owner, selection owner, timer, retry, watchdog or manual scroll-position reconciliation belongs here.

This inherits Build176 session replacement, Build178 canonical ordering and Build182 detail presentation ownership. Build191 / OnePlayer 0.14.24 was real-device accepted and merged through PR #257 at `f153a36e9da8a208150fe638e0b9df5835df1dc0`.

## D016 — Player episode grouping follows real SeasonId; very large rows are lazy

The Build194/195 target-device line closes the nonstandard-season gap between detail and the in-player picker.

Accepted contract:

- player picker consumes the same canonical `seriesEpisodes(seriesId:) + seriesSeasons(seriesId:)` semantics as detail;
- Episode `SeasonId` resolves against the real Season item/index first;
- `ParentIndexNumber` is only the compatibility fallback when real Season mapping cannot be established;
- Build178 `/Shows/{SeriesId}/Episodes` response order remains the only in-series ordering authority; grouping does not introduce a second sort;
- trusted auto-next continues indexing the full canonical episodes array rather than the filtered UI season;
- the horizontal in-player episode row uses `LazyHStack` so a 980-item season does not eagerly instantiate every complex card on open;
- do not solve large-season performance by truncation, manual pagination, artificial sorting, debounce, timer, retry or watchdog;
- this decision does not modify PlayerController, MPV Seek, PiP, UnifiedTransport, Cache, Range/302/115 client-direct or Emby Resume/progress ownership.

Build194 proved the SeasonId correction on the target device and exposed eager-row opening cost. Build195 / OnePlayer 0.14.28 added only the lazy row, was real-device accepted, and merged through PR #258 at `a3f79b5bed7ec835cd53f48aa9eb6cadcdf884e1`. Treat SeasonId-first grouping and lazy large-season rendering as stable unless new target-device regression evidence requires reopening them.