# OnePlayer 0.14.73 / Build240

- Diagnostic-only Home-carousel release-handoff measurement based exactly on the accepted Build239 product behavior.
- Keeps the 0.28 slow-drag commit threshold, direction-aware latest-delivered velocity >=600 pt/s fling gate, Build237 white-flash correction, Build236 real-sample start handling, Build231 foreground compositing, Build226 Hero residency and Build228 max-refresh-through-settle / 0.22s commit + 0.18s cancel tail unchanged.
- Reuses the existing carousel cadence CADisplayLink through settle; adds no timer, interpolator, spring, retry, watchdog or second visual/gesture owner.
- Makes the existing zero-size cadence render probe Animatable so it can report the release animation interpolation, then logs the first six animated-progress and display-link samples after a commit release for comparison with measured directional release velocity.
- No Player / MPV / PiP / Transport / Cache / Emby Session / STRM / 302 / Range changes.
