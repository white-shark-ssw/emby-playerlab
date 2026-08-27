# OnePlayer 0.14.55 / Build222

- Diagnostic sibling A/B from the accepted Build216/main runtime baseline; it does not inherit Build217/219/221 carousel diagnostics.
- Reuse the existing Home Hero vertical scroll owner and record only a non-Published `isFullyOffscreen` lifecycle bit, so media rows and the root Home tree do not gain another high-frequency scroll state.
- When the Hero has moved beyond the existing `heroTrackingLimit`, the existing one-second carousel timer remains connected but no longer starts a new automatic carousel transition.
- Manual carousel drag behavior, transition geometry, persistent blurred backdrop, preload layer, refresh behavior and Dock remain unchanged.
- Purpose: isolate whether recurring carousel transition work while the Hero is offscreen contributes to Home vertical-scroll frame pacing. This build is diagnostic only until real-device comparison.
- Deployment Target remains iOS 15.0.
