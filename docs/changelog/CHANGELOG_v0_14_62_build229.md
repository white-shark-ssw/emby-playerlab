# OnePlayer 0.14.62 / Build229

## Poster grid pagination snapshot off-main candidate

- Target-device Build228 log captured a real 55.1 ms `grid / phase=dragging` long frame after `StartIndex=60`.
- The same sample measured image publish / Combine→UIKit adoption at 0.0 ms and pagination apply at 0.3 ms, while synchronous page snapshot persistence took 39.7 ms and completed about 8 ms before the hitch.
- Build229 keeps the accepted Build213 persistent-page cache semantics but changes only Library snapshot serialization + atomic disk write execution: the `@MainActor` library model still captures the immutable snapshot in state order, then awaits a serial utility queue for JSON conversion and disk write.
- The serial queue preserves write ordering; no timer, retry, fallback, debounce, throttle, watchdog, duplicate state or new cache is added.
- Favorites persistence is unchanged because the controlling hitch evidence is the Library pagination path.
- Poster image policy, Home carousel owner files, Player / MPV / PiP, UnifiedTransport, playback Cache / Session and STRM→302→115/CDN client-direct contracts are unchanged.
- Deployment Target remains iOS 15.0.
