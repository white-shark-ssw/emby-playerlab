# OnePlayer 0.14.67 / Build234

- Diagnostic-only Home carousel acquisition coalesced-sample instrumentation.
- Keeps Build233 acquisition-first-frame behavior unchanged.
- Adds acquisition-event coalesced sample count, predecessor status, predecessor delta X, and predecessor age to `HomeCarouselCadence`.
- Purpose: explain the remaining Build233 coarse-start cases before changing sample selection or guards.
- Retains Build231 foreground compositing, Build226 Hero residency, Build228 max-refresh-through-settle, 0.28/0.48 release rules, and all Frozen/P0 playback/transport contracts.
- Deployment target remains iOS 15.0.
