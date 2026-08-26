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

## D012 — Home-carousel drag keeps one UIKit owner; foreground must slide and visual mapping is tuned separately

The carousel line remains Active and independent from Build199.

Retained input architecture from Build198:

- one UIKit interaction surface owns begin/move/end/cancel;
- vertical acquisition yields to Home `UIScrollView`;
- horizontal acquisition owns the gesture through end/cancel;
- actual touch drives rendering; predicted touch is release-only;
- 0.5pt axis acquisition, 0.28 commit threshold, 0.48×width predicted-distance release gate and existing settle timing remain one contract;
- high-frequency transition state remains localized to `V3HomeCarouselTransitionState`;
- no second SwiftUI drag/release owner;
- no timer/watchdog/reconciliation/interpolation/debounce/throttle to mask input/render problems.

Rejected/retained evidence:

- Build185/187 proved initial full-width page motion remained visibly coarse even with 120 Hz available.
- Build189/193 proved split native-move / SwiftUI-release ownership can freeze between pages; that architecture is rejected.
- Build198 proved the single UIKit lifecycle fixes the ownership failure mode, but minimum/subtle motion still felt too coarse.
- Build200 fixed the foreground spatially and used linear crossfade. It passed CI/IPA but target-device testing rejected the semantic regression because foreground no longer slid horizontally. **Fully fixed foreground is rejected.**
- Build201 restored horizontal movement at `0.15 × Hero width` with linear opacity. Target-device feedback on 2026-08-27 was partially positive — **“有点那种感觉了”** — and specifically requested travel `15% → 30%` plus opacity that changes little at drag start and increasingly faster later.

Current Build203 visual candidate:

- keep the Build198 UIKit owner and all gesture/release/settle semantics unchanged;
- keep one clamped `transitionProgress` as the only visual progress owner;
- foreground total travel = **`0.30 × Hero width`**;
- outgoing/incoming directional offset formulas remain unchanged;
- backdrop and foreground use the same **`blend = progress²`** mapping;
- outgoing opacity = `1 - blend`; incoming opacity = `blend`;
- this is mathematically an accelerating/ease-in curve, matching the user's requested perceptual behavior: very small opacity change at drag start, increasingly faster later;
- blend is independent of direction. Existing neighbor lookup `(index + direction + count) % count` remains first↔last wrapping authority, so left/right and edge wraps do not get a second boundary state machine.

Build203 / OnePlayer 0.14.36 evidence:

- branch `perf/home-carousel-accelerating-blend-build203`
- tested source `69beee45b93dc11c7c5be2ee4b81a5a0157f2653`
- durable cleanup head `edafd5d784cfacdcf8c451fad93535a55fb880fb`; cleanup removes only the temporary workflow
- run/job `32995898318` / `98264917294` — success
- artifact ID `9616576496`
- IPA SHA-256 `cee7241b73c4dc38efb6593c3d6ec9f54981f8e5a609be78a491b869df685226`
- MinOS 15.0 verified
- evidence: **Code written / CI passed / IPA produced+verified / real-device pending / not stable**.

Do not tune 30% or the `progress²` curve again before Build203 target-device evidence.

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