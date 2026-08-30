# OnePlayer 0.14.91 / Build258

- Measurement-only 3-column poster-grid cadence diagnostic based on current `main`.
- Adds passive per-scroll-session `PosterGridCadence` summaries for Library, Search, Person, Genre, Favorites and Detail-filter 3x3 routes.
- Records content-offset and passive display-link p50/p95/p99/max gaps plus >=10/12.5/16.7/25/33.3 ms counts, drag/deceleration samples, cell lifecycle, load-ahead triggers and item-count changes.
- Does not force 120 Hz or change `UIScrollView` physics, grid layout, image request/decode/cache policy, navigation, carousel behavior, Player, Transport, playback Cache/Session or PiP.
- Build257 Home auto-advance inertia gate is intentionally not included; that behavior remains a fallback-only experiment pending root-cause work.
- Deployment target remains iOS 15.0.
