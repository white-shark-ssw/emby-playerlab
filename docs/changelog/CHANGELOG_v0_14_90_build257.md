# OnePlayer 0.14.90 / Build257

## Home inertial-scroll / carousel auto-advance isolation

- Based on current `main`, retaining the user-accepted Build241 carousel interaction/presentation contract and Build256 Search baseline.
- Reuses the existing Home vertical `UIScrollView` observer and keeps only a weak reference to that real scroll view; no duplicate drag/deceleration state is introduced.
- When carousel auto-advance is due, it now returns if the Home vertical scroll view is currently dragging or decelerating. The existing 1-second carousel timer naturally retries after vertical motion ends.
- Manual horizontal carousel interaction, 0.62-second auto-transition animation, Hero residency, persistent backdrop, preload, release behavior and carousel refresh cadence are unchanged.
- No new timer, retry, debounce, throttle, watchdog, interpolation or fallback is added.
- This candidate targets only the user-reproduced large hitch when auto-advance overlaps Home inertial scrolling. It does not claim to solve the separate mild baseline jitter that remains with the carousel disabled.
- Player/MPV/PiP, UnifiedTransport, playback Cache/Session, Emby Resume/Progress and STRM → 302 → 115/CDN client-direct contracts are untouched.
- Deployment Target remains iOS 15.0.
