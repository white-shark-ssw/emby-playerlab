# OnePlayer 0.14.52 / Build219

## Home carousel 120 Hz request A/B

- Diagnostic-only successor to Build217.
- Preserves Build215 carousel behavior: one UIKit owner, acquisition-relative 1:1 foreground X, opaque foreground, full-width page slots, original 0.28 commit / 0.48×width predicted release gate, reversal/cancel/settle/wrap behavior and backdrop mapping.
- Keeps delivered touch as render authority. Coalesced touches remain measurement-only and predicted touches remain release-only.
- During an active horizontal drag, if `UIScreen.main.maximumFramesPerSecond > 60`, the existing diagnostic `CADisplayLink` requests an exact frame-rate range at that device maximum; on the target iPhone 15 Pro Max this is 120 Hz. 60 Hz devices do not receive a frame-rate-range request.
- Adds `requested_fps` to the aggregated `HomeCarouselCadence` App log so target-device evidence can distinguish the requested display cadence from the delivered-touch/progress/render cadence.
- No smoothing/interpolation/timer/debounce/throttle/watchdog/retry/fallback. No Player / MPV / PiP / Transport / Cache / Session change. Deployment target remains iOS 15.0.
