# OnePlayer 0.14.50 / Build217

## Home carousel cadence diagnostics

- Diagnostic-only successor to Build215.
- Preserves the accepted acquisition-relative 1:1 foreground motion, opaque interactive foreground, full-width page slots, single UIKit owner, 0.28 commit threshold, 0.48×width predicted-distance gate, reversal/cancel/settle/wrap behavior and backdrop mapping.
- Adds horizontal-drag-only cadence observation for delivered/coalesced touch timing, progress publication timing, SwiftUI representable update timing and passive `CADisplayLink` frame gaps.
- Correlates the worst display gaps with the latest carousel 1400px image callback role (`hero`, `persistent`, `preload`) and item ID.
- Emits one aggregated `HomeCarouselCadence` App-log summary per drag; it does not log every touch/frame.
- The diagnostic display link does not request a preferred frame rate and never drives animation.
- No smoothing/interpolation/timer/debounce/throttle/watchdog/retry/fallback.
- No Player / MPV / PiP / Transport / Cache / Session path change. Deployment target remains iOS 15.0.
