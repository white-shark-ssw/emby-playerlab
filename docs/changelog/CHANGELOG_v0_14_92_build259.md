# OnePlayer 0.14.92 / Build259

- Diagnostic A/B for the shared 3×3 poster-grid smoothness task.
- Based exactly on Build258 / 0.14.91 cadence diagnostics.
- Reuses the existing shared poster-grid diagnostic `CADisplayLink`; no second display link, timer, watchdog, debounce, retry or smoothing owner is added.
- While at least one observed real 3×3 `UIScrollView` is dragging or decelerating on a >60 Hz device, the existing display link requests `CAFrameRateRange(minimum: 80, maximum: deviceMaximum, preferred: deviceMaximum)`.
- The request returns to `CAFrameRateRange.default` when all observed grid motion ends.
- Adds request state/range to `PosterGridCadence` for direct Build258↔Build259 comparison.
- Does not change `EmbyPosterGrid` layout, Search Build256 recommendation source/+6 append/lifetime contract, Library pagination/persistence, poster image loading/cache/decode, navigation, Home carousel behavior, Player/MPV/PiP, Transport, playback Cache/Session or STRM/302/115/CDN behavior.
- Deployment Target remains iOS 15.0.
- This is an A/B candidate, not a claimed final smoothness fix.
