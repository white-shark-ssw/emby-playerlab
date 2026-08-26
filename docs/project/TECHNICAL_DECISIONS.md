# OnePlayer Technical Decisions

This file records decisions that have already consumed significant implementation or real-device testing. Do not casually re-run rejected directions.

## D001 — Media bytes never transit the NAS

Normal playback is client-direct:

`Emby / STRM → HTTP 302 → 115/CDN → iPhone`

The NAS/Emby side may resolve or redirect, but must never become the media-byte relay.

## D002 — Real byte demand is authoritative

Never use `targetTime / duration × fileSize` as a Seek/Transport anchor. Actual player byte demand / HTTP Range demand is authoritative.

## D003 — Unified transport/cache is shared infrastructure

HTTP 302, Range/206, cache and playback-demand handling live below playback engines. Do not create per-engine 115/CDN networking or UI-owned transport state.

## D004 — Fast interaction beats exact Seek

For double-tap/rapid ±N-second Seek, latency is P0. MPV `absolute+keyframes` is the accepted runtime contract; `absolute+exact` is rejected as the normal path and there is no hidden second corrective Seek.

## D005 — MDK is not automatic daily authority

MDK remains manual/experimental backup. MPV is the normal engine because repeated real-device work did not show MDK beating MPV on repeated fast Seek consistency and long-tail stability. Do not silently restore broad automatic fallback.

## D006 — Renderer ownership must respect MoltenVK/MPV

UIKit may own host geometry; product code must not casually seize `CAMetalLayer.delegate`, drawable or swapchain ownership from MoltenVK/MPV.

## D007 — System navigation is system-owned

Native iOS push/pop and interactive-pop remain system-owned. Immersive appearance may adapt around navigation but must not replace that ownership.

## D008 — PiP uses a visual bridge; MPV remains authority

PiP is frozen at Build173 unless new real-device evidence or a materially better renderer-lifecycle approach appears. SampleBuffer is the native visual bridge; MPV remains playback/audio/time authority; background video suspension uses `vid=no`; PiP X = `pauseAndSuspend`; no periodic bridge catch-up loop is part of the frozen design.

## D009 — Evidence levels remain explicit

Always distinguish:

1. Code written
2. CI passed
3. IPA produced
4. Real-device tested
5. Stable / frozen

CI/IPA alone never proves a runtime problem solved.

## D010 — Episode changes replace the source-owned playback session

Selecting another episode replaces the complete source-owned playback session while fullscreen presentation remains. Each selected episode gets a fresh controller/orchestrator/transport context/Emby session. Temporary 115/CDN URLs are resolved only after explicit selection or trusted natural auto-next. Auto-next requires the existing `PrematureEOFGuard` trusted natural-end classification; raw EOF/starvation/premature EOF is insufficient. Build176 was real-device accepted and merged through PR #253.

## D011 — Emby TV API owns canonical episode order

Canonical series order comes from `GET /Shows/{SeriesId}/Episodes`; OnePlayer preserves Emby's returned order. `SeasonId` is season-membership authority, not a second in-season sort owner. Do not add title/file/date/item-ID/artificial-number fallback sorting. Build178 was accepted and merged through PR #254.

## D012 — Home-carousel drag keeps one UIKit owner; foreground uses full-width page slots

The carousel line remains Active and independent from Build199.

Retained input architecture from Build198:

- one UIKit interaction surface owns begin/move/end/cancel;
- vertical acquisition yields to Home `UIScrollView`;
- horizontal acquisition owns the gesture through end/cancel;
- actual touch drives raw `transitionProgress`; predicted touch is release-only;
- 0.5pt axis acquisition, 0.28 commit threshold, 0.48×width predicted-distance release gate and existing settle timing remain one contract;
- high-frequency transition state remains localized to `V3HomeCarouselTransitionState`;
- no second SwiftUI drag/release owner;
- no timer/watchdog/reconciliation/interpolation/debounce/throttle to mask input/render problems.

Rejected/retained evidence:

- Build185/187 proved initial full-width page motion remained visibly coarse even with 120 Hz available.
- Build189/193 proved split native-move / SwiftUI-release ownership can freeze between pages; that architecture is rejected.
- Build198 proved the single UIKit lifecycle fixes the ownership failure mode, but minimum/subtle motion still felt too coarse.
- Build200 fixed the foreground spatially and was rejected because foreground horizontal-slide semantics disappeared.
- Build201 restored horizontal movement at `0.15 × Hero width`; target-device feedback was partially positive but total travel was too short.
- Build203 used 30% spatial travel; target-device testing showed 30% was still too short and raw-linear spatial mapping exposed the coarse first displacement again.
- Build205 used 80% total travel and whole-range `progress²`; target-device testing rejected that curve because the start was over-restrained and the nonlinear tail felt unnatural.
- Build207 kept 80% travel and changed to an early-only soft-start / linear-tail mapping. Target-device screenshots then exposed a deeper layout defect: the first visible displacement was still too large, and adjacent foreground Logo/title/rating/overview content visibly overlapped while EX preserved a clear separation.

Source-backed layout conclusion from Build207:

- every `carouselHeroForeground` is itself a full Hero-width page;
- Build207 placed outgoing/incoming full-width page centers only `0.80 × width` apart, so the page frames structurally overlap by 20% throughout the transition;
- existing foreground content width is `width - 56`;
- therefore the correct minimal page model is **full-width page slots**: outgoing/incoming page centers stay exactly one `width` apart;
- with the existing `width - 56` content width, adjacent foreground content edges keep a constant ~56pt separation instead of overlapping;
- this is implemented mathematically with the existing two visible foreground pages and one transition owner; do not add a second ScrollView/HStack gesture owner merely to express page slots.

Current Build208 visual contract:

- foreground `pageStep = width`;
- outgoing offset = `-direction × visualProgress × pageStep`;
- incoming offset = `direction × (1 - visualProgress) × pageStep`;
- distance between page centers is exactly one Hero width at every transition progress;
- raw `transitionProgress` remains linear and authoritative for release/commit logic;
- earliest visual attenuation remains a pure stateless mapping: `progress * (1 - 0.85 * (1-progress)^6)` after clamping;
- the `0.85` coefficient reduces only the earliest first-sample displacement relative to Build207, while exponent 6 still makes mid/late drag converge rapidly to raw linear progress and tail derivative reach 1.0;
- foreground/backdrop opacity uses the same visual progress;
- mapping remains direction-independent; existing `(index + direction + count) % count` remains first↔last wrapping authority.

Identity/evidence discipline:

- A carousel `0.14.37 / Build204` package was retired because Build204 already belongs to the poster-scroll task; do not use it for attribution.
- Build205 / 0.14.38 and Build207 / 0.14.40 are real-device-tested rejected visual references, not stable builds.
- Build206 belongs to the independent poster-scroll diagnostics line.
- Current carousel candidate is **Build208 / OnePlayer 0.14.41** on `perf/home-carousel-page-slots-build208`.
- Build208 tested source `2ad089f0ea8b4b6827257bb3a91a67c2d3748e5f`; durable cleanup head `51c366b6840d77c818eae20e1f3f43c0dbd75c72`; cleanup removes only the temporary Build208 workflow.
- Build208 run/job `33004390654` / `98294100402` — success; artifact ID `9620046266`.
- artifact ZIP digest `sha256:4ace3db785c131b987bfd9e18dc931e1bdeaf9f7528d85b8807214b45774afbb`.
- IPA SHA-256 `24f47ac5cd5685f6eea85b1c3a4fad2841d81f6169a90cd0629bea85a2072308`; source ZIP SHA-256 `807d03947c0d087ddc54f295e63fdabc37ac0ddfbe0e0f03da4477eb750e95ee`.
- bundle identity `0.14.41 (208)` and MinOS 15.0 independently verified.
- Build208 evidence: **Code written / CI passed / IPA produced+verified / real-device pending / not stable**.

Do not retune UIKit ownership or release thresholds based on the Build207 foreground-layout failure. First test the full-width page-slot model on device.

## D013 — Detail high-rate scroll and warm presentation stay scoped and presentation-only

High-frequency native detail scroll offset stays in the Hero-scoped owner, not root detail state. Persistent warm detail cache is presentation-only: safe display metadata may be cached, but PlaybackInfo, MediaSource, PlaySession, ResolvedPlaybackSource and temporary 115/CDN URLs remain live/session-owned. Build182 was real-device accepted/frozen; Build184 visual hierarchy was accepted and merged through PR #255.

## D014 — Emby server entry selection is Session-owned and media transport remains separate

`SessionStore` owns saved sessions/server configuration. Alternate routes must resolve to the same Emby Server ID. Route latency is editor/diagnostic state only. Same-server route selection changes only the Emby API/server entry; media remains `Emby / STRM → 302 → 115/CDN → iPhone`. Player/Transport/Cache/Seek/Resume/PiP remain outside this feature.

Credential split accepted at Build199: AccessToken and retained password are separate Keychain records; password is absent from UserDefaults/plain server config/diagnostics/synchronized JSON. When iCloud sync is enabled, password is additionally stored in a separate synchronizable Keychain item. Build199 was real-device accepted and merged through PR #256.

## D014A — Auto-start is cached-first; retained password is Keychain-owned

After local session/token restore, auto-start constructs the authenticated Emby root immediately so existing Home snapshots/image cache can render while route selection/live refresh proceeds. If route selection fails and an initial client exists, stale cached Home remains. Edit Server preloads the retained local Keychain password; unchanged password does not force reauthentication; changed password must preserve same Server ID/User ID before AccessToken replacement. Manual first-level server entry retains its pre-Home route-selection behavior.

## D015 — Detail episode browsing separates selection from playback

Detail horizontal episode cards select only. `selectedEpisodeID` is the visible selection owner. Default selection is explicit initial episode → resumable episode → canonical first episode. Quick range buttons select the range's first canonical episode. Main Play/Resume targets selected episode through the source-owned playback path. Full picker stays mounted through playback. Build191 was accepted and merged through PR #257.

## D016 — Player episode grouping follows real SeasonId; very large rows are lazy

Player picker consumes the same canonical episode/season semantics as detail. Episode `SeasonId` resolves against real Season item/index first; `ParentIndexNumber` is fallback only. Build178 server order remains authoritative. The horizontal player episode row uses `LazyHStack`; do not solve large seasons through truncation/artificial pagination/second sorting. Build195 was accepted and merged through PR #258.
