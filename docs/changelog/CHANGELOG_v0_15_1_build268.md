# OnePlayer 0.15.1 / Build268

- Shared 3×3 cadence diagnostics are reduced to a lean reference-session path after Build267 target-device evidence showed severe long frames falling while visible motion still exhibited stop/catch-up stepping.
- Keeps the existing single grid CADisplayLink and 80→device-max refresh request.
- Keeps one display-interval sample array for end-of-session cadence percentiles, but removes per-offset interval arrays, deceleration delta/ratio arrays, RunLoop observer attribution, and per-KVO velocity work.
- Adds scalar `offset_hz`, `display_hz`, `decel_zero_ratio`, and `decel_catchup_ratio` so motion continuity can be compared with much lower measurement overhead.
- No LazyVGrid geometry, poster image loading/quality/cache/decode/network/publication, pagination, Search Build256 semantics, scroll physics, Home carousel runtime, Player/MPV/PiP, Transport/Cache/Session, STRM/302/115/CDN, or deployment-target behavior changes.
