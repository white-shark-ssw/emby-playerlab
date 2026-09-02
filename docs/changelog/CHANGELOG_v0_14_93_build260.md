# OnePlayer 0.14.93 / Build260

- Diagnostic-only continuation of Build259 shared 3×3 high-refresh A/B.
- Preserves the Build259 80→device-max `CADisplayLink.preferredFrameRateRange` request during real shared-grid drag/deceleration.
- Adds passive per-display-frame deceleration continuity metrics from the real ancestor `UIScrollView.contentOffset.y`: zero-move frames, zero→catch-up pairs, direction reversals, movement-step percentiles and consecutive movement-step ratio percentiles.
- No ScrollView physics/deceleration rate, grid layout, pagination, image/cache policy, Search Build256 semantics, Home carousel runtime, Player/MPV/PiP, UnifiedTransport, playback cache/session, STRM/302/115/CDN or Deployment Target behavior changes.
- Target remains iOS 15.0; target-device A/B is iPhone 15 Pro Max / iOS 17.0.
- No smoothness fix is claimed by this build; it exists to determine whether the residual EX-vs-OnePlayer hand-feel difference corresponds to per-display-frame position discontinuity during native deceleration.
