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

## D012 — Home-carousel drag keeps one UIKit owner; raw input progress and visual progress are separate concerns

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
- Build200 fixed the foreground spatially and used linear crossfade. It passed CI/IPA but target-device testing rejected the semantic regression because foreground no longer slid horizontally. **Fully fixed foreground is rejected.**
- Build201 restored horizontal movement at `0.15 × Hero width` with linear opacity. Target-device feedback on 2026-08-27 was partially positive — **“有点那种感觉了”** — but the total travel was too short.
- Build203 increased foreground travel to `0.30 × Hero width` and changed opacity to clamped `progress²`, while spatial offset still used raw linear progress. Target-device feedback then showed the important distinction: 30% still felt too short overall, yet the larger raw-linear spatial mapping made the coarse first visible displacement/jitter perceptible again.

Therefore the current architectural conclusion is:

- do **not** change the UIKit gesture owner or raw `transitionProgress` ownership based on Build203;
- keep raw `transitionProgress` linear and authoritative for release/commit logic;
- visual opacity and visual spatial mapping may transform that raw progress independently, as long as they reuse the same single state owner and do not feed back into gesture thresholds;
- current visual mapping uses clamped **`visualProgress = progress²`** for both opacity and spatial interpolation;
- foreground total travel is **`0.80 × Hero width`**;
- outgoing offset = `-direction × visualProgress × travel`;
- incoming offset = `direction × (1 - visualProgress) × travel`;
- outgoing opacity = `1 - visualProgress`; incoming opacity = `visualProgress`;
- at raw progress 0.10 this maps spatial movement to `0.80 × 0.10² = 0.008 width`, materially smaller than Build203's `0.30 × 0.10 = 0.03 width`, while still allowing 80% total travel at completion;
- mapping is direction-independent. Existing neighbor lookup `(index + direction + count) % count` remains first↔last wrapping authority; left/right and edge wraps do not get a second state machine.

Identity/evidence discipline:

- Build203 / OnePlayer 0.14.36 is the real-device reference that rejected raw-linear 30% spatial mapping as final.
- A carousel `0.14.37 / Build204` package was briefly produced with the intended 80% eased mapping but was retired before distribution after mandatory global state resync showed that Build204 already belongs to the independent poster-scroll task. Do not use that carousel package for attribution.
- Current carousel candidate is **Build205 / OnePlayer 0.14.38** on `perf/home-carousel-eased-travel-build205`.
- Build205 tested source `e5f2e7b4135eca333d5dda24545f19ee8d0be439`; durable cleanup head `70d6cca676911e656591aae6b342c771cc92b9fe`; cleanup removes only the temporary workflow.
- Build205 run/job `32998533448` / `98273968966` — success; artifact ID `9617634710`; IPA SHA-256 `fe4a81ebee9d330526c108edf2ab4652632ae5b204719864e0b5dee486086479`; MinOS 15.0 independently verified.
- Build205 evidence: **Code written / CI passed / IPA produced+verified / real-device pending / not stable**.

Do not tune the 80% factor or `progress²` visual mapping again before Build205 target-device evidence.

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
