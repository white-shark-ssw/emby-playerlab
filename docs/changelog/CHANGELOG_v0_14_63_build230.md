# OnePlayer 0.14.63 (Build230)

## Home carousel persistent residency A/B

- Starts from the accepted-for-now carousel Build228 release-tail foundation.
- Reuses the existing settled current + previous + next carousel residency window for the full-screen persistent backdrop.
- Keeps normal current→target persistent opacity crossfade; unlike Build221, the outgoing backdrop is not frozen during drag.
- Moves adjacent persistent 1400px + blur presentation creation out of active finger tracking so the target persistent is already mounted before horizontal acquisition.
- Build226 Hero residency, Build228 max-refresh-through-settle, acquisition-relative foreground motion, 0.28/0.48 release rules and all P0/Frozen playback/transport contracts are unchanged.
- Diagnostic candidate only until target-device slow-drag/title-shimmer and overall hand-feel A/B.
