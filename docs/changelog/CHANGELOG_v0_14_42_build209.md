# OnePlayer 0.14.42 / Build209

## Motion-aware poster scroll diagnostics

- Build206 App-log capture proved immediate cell appearance, image commit and grid load-ahead are not a universal cross-page trigger, but its display-link gaps were not tied to actual vertical motion.
- A poster diagnostic package was briefly built as 0.14.41 / Build208, then retired before distribution because the independent Home-carousel task already owns Build208 / 0.14.41.
- Build209 keeps the same motion-aware diagnostic runtime code and gives the poster task a unique identity.
- `PosterScrollHitch` is emitted only when the display gap is at least 30 ms and the real vertical content offset changed across that gap.
- Each hitch adds `scroll_route`, `phase`, `offset_y`, `delta_y` and `velocity_y`, while retaining cell/image/load-ahead timing fields.
- Home and all shared 3-column poster grids register only a transparent, non-interactive scroll-owner probe; scroll physics, image policy, navigation, carousel gesture ownership and playback/transport paths are unchanged.
- Deployment target remains iOS 15.0.
