# OnePlayer 0.15.0 / Build267

## Poster 3×3 diagnostic self-overhead A/B

- Directly extends target-device-tested Build266 / 0.14.99.
- Changes only `EmbyPosterGridCadenceDiagnostics.MotionSession` from value semantics to reference semantics while retaining every diagnostic field, threshold, KVO sample, CADisplayLink sample, 80→device-max refresh request and end-of-session log.
- This removes repeated copy-on-write risk from growing per-session arrays when high-frequency contentOffset/display callbacks mutate the diagnostic session.
- No poster image loading/quality/cache/decode/network/publication, LazyVGrid geometry, pagination, Search Build256 semantics, scroll physics, Home carousel runtime, Player/MPV/PiP, UnifiedTransport, playback cache/session, STRM/302/115/CDN or Deployment Target changes.
- Candidate only: Build266 real-device evidence shows 3×3 long frames remain; Build267 tests whether measurement overhead itself is contaminating those results.
