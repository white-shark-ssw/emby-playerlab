# OnePlayer 0.14.99 / Build266

## Poster 3×3 loading-state publication A/B

- Directly extends target-device-tested Build263 / 0.14.96.
- For shared `V3PosterCard` 3-column cells (`width == nil`) only, keeps image loading/publication unchanged but stops publishing loader `isLoading` state that the card never renders.
- Horizontal poster rows and all other `EmbyCachedRemoteImage` callers retain the previous loading-state behavior.
- No image size/quality, cache/decode/network, LazyVGrid geometry, pagination, Search Build256 semantics, scroll physics, Home carousel owner, Player/MPV/PiP, UnifiedTransport, playback cache/session, STRM/302/115/CDN or Deployment Target changes.
- Candidate only: Code written does not imply target-device smoothness improvement.
