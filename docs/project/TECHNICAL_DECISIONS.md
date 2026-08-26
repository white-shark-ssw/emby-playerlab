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
- Build203 increased foreground travel to `0.30 × Hero width` and changed opacity to clamped `progress²`, while spatial offset still used raw linear progress. Target-device feedback showed 30% still felt too short overall while the larger raw-linear spatial mapping exposed the coarse first visible displacement/jitter again.
- Build205 raised total foreground travel to `0.80 × Hero width` and applied clamped `progress²` to both opacity and spatial interpolation. Target-device testing then rejected that whole-range curve as final: drag start felt too restrained, and the continued nonlinear tail felt like an unnatural easing effect.

Therefore the current architectural conclusion is:

- do **not** change the UIKit gesture owner or raw `transitionProgress` ownership based on these visual findings;
- keep raw `transitionProgress` linear and authoritative for release/commit logic;
- visual opacity and visual spatial mapping may transform that raw progress independently, as long as they reuse the same single state owner and do not feed back into gesture thresholds;
- keep total foreground travel at **`0.80 × Hero width`** unless new device evidence specifically rejects that distance;
- do **not** apply `progress²` over the entire transition;
- current Build207 visual mapping is `progress * (1 - 0.60 * (1-progress)^6)` after clamping;
- this gives an initial slope of about **0.40**, so start motion is restrained but substantially less than Build205's zero-slope `progress²` start;
- the attenuation decays rapidly and mid/late drag converges closely to raw linear progress;
- endpoint remains exactly 1.0 and tail derivative tends to **1.0**, avoiding artificial tail acceleration/deceleration;
- foreground/backdrop opacity and foreground spatial interpolation use the same visual progress;
- outgoing offset = `-direction × visualProgress × travel`;
- incoming offset = `direction × (1 - visualProgress) × travel`;
- outgoing opacity = `1 - visualProgress`; incoming opacity = `visualProgress`;
- mapping is direction-independent. Existing neighbor lookup `(index + direction + count) % count` remains first↔last wrapping authority; left/right and edge wraps do not get a second state machine.

Identity/evidence discipline:

- Build203 / OnePlayer 0.14.36 is the real-device reference that rejected raw-linear 30% spatial mapping as final.
- A carousel `0.14.37 / Build204` package was briefly produced with the intended 80% eased mapping but was retired before distribution because Build204 already belongs to the independent poster-scroll task. Do not use that carousel package for attribution.
- Build205 / OnePlayer 0.14.38 was CI/IPA verified and then target-device tested; its whole-range `progress²` mapping is rejected as final.
- Build206 is owned by the independent poster diagnostics task.
- Current carousel candidate is **Build207 / OnePlayer 0.14.40** on `perf/home-carousel-soft-start-linear-tail-build207`.
- Build207 tested source `06936503a6c382d1d39d3cdd52f23bfe2058901e`; durable cleanup head `7044ca68c7082cd055a7e4ce42dda6f00fe29674`; cleanup removes only the temporary workflow.
- Build207 run/job `33000526138` / `98280846494` — success; artifact ID `9618484884`; IPA SHA-256 `bbd7c9c22c2a79a89f41e0d94db16023cf7cd2a720ffeb3c4f31cb9066a15a21`; source ZIP SHA-256 `ecb6f4dbfb0609194406dbb5e0efc3ecde8907ed22992ee7aa4dcf6a886bc275`; MinOS 15.0 independently verified.
- Build207 evidence: **Code written / CI passed / IPA produced+verified / real-device pending / not stable**.

Do not retune the 80% distance, start attenuation coefficient or exponent until Build207 target-device feedback establishes which part is still wrong, if any.

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
