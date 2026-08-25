# OnePlayer 0.14.18 Build185

- Reissues the carousel axis-acquisition fix under a unique Build after the parallel detail-page task occupied Build184 / 0.14.17.
- Follows the Build183 real-device result: crossfade felt somewhat finer, but it incorrectly changed the established carousel interaction by pinning Logo/rating/year/type/overview instead of moving them with the carousel page.
- Restores the Build180 foreground slide contract exactly: Logo, rating, year, type and overview travel horizontally with their carousel item.
- Keeps `DragGesture(minimumDistance: 0)` and continuous left↔right reversal behavior from Build180.
- Replaces the former `abs(horizontal) > abs(vertical) * 1.08` acquisition gate with a one-time axis lock at the first meaningful 0.5 pt movement; horizontal locks drive the carousel, vertical locks leave the homepage scroll gesture alone for the rest of that touch.
- Does not debounce, throttle, interpolate or accumulate finger movement before applying carousel progress.
- Keeps artwork/backdrop blend, commit/cancel thresholds, release animations, auto-advance timing, detail tap behavior, persistent blur design and vertical homepage scrolling otherwise unchanged.
- Does not change PlayerController, MPV fast Seek, PiP, UnifiedTransport, Range/302/115 client-direct playback, session cache, episode selection/order, detail-page cache work or native navigation.
- Deployment Target remains iOS 15.0; target validation remains iPhone 15 Pro Max / iOS 17.0.
