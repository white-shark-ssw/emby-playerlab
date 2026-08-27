# OnePlayer 0.14.45 / Build212

## Poster scroll source-aware diagnostics

- Diagnostic-only successor to Build210; no scrolling, image-loading policy, navigation, carousel interaction, playback, transport, cache, or session behavior change.
- Keeps the single shared motion-gated poster `CADisplayLink` and multi-owner Home/grid attribution.
- Adds safe image publish context to hitch records: callback vs display-only role, memory/disk/network source, Emby image type, item ID, and requested MaxWidth. Authentication query data is never logged.
- Measures synchronous `onImageLoaded` callback duration in the shared image wrapper, allowing Home carousel image-metric work to be timed without editing active carousel owner files.
- Measures Core Image contrast render duration in the shared contrast analyzer for correlation with verified Home hitches.
- Deployment Target remains iOS 15.0.
