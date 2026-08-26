# OnePlayer 0.14.41 / Build208

## Motion-aware poster scroll diagnostics

- Build206 App-log capture proved immediate cell appearance, image commit and grid load-ahead are not a universal cross-page trigger, but its display-link gaps were not tied to actual vertical motion.
- Build208 remains diagnostic-only. It samples the real ancestor vertical `UIScrollView` from the existing shared display-link path.
- `PosterScrollHitch` is emitted only when the display gap is at least 30 ms and the vertical content offset actually changed across that gap.
- Each hitch adds `scroll_route`, `phase`, `offset_y`, `delta_y` and `velocity_y`, while retaining cell/image/load-ahead timing fields.
- Home and all shared 3-column poster grids register only a transparent, non-interactive scroll-owner probe; scroll physics, image policy, navigation, carousel gesture ownership and playback/transport paths are unchanged.
- Deployment target remains iOS 15.0.
