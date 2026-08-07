# Changelog 0.9.0 (Build 46)

## Unified transport
- Added `UnifiedMediaTransportSession` as the single byte source for automatic AVPlayer and MPV profiles.
- Exactly two upstream 115/CDN slots are used for background traffic. Slot 0 may service a real playback hole; Slot 1 is kept alive whenever possible.
- Sequential prefetch uses `PlaybackRangeMap`; user Seek never estimates byte offsets from media time.
- The first real post-Seek byte demand reanchors the sequential frontier. Demux metadata/tail probes are urgent but do not move the playback anchor.
- On Wi-Fi, continuous preload may use the configured session disk budget; cellular background preload remains explicit opt-in.
- A real demand inside Slot 1 may be duplicated by an urgent <=2 MiB Slot 0 request to reduce player latency without cancelling Slot 1.

## AVPlayer
- Automatic native-friendly media uses `AVPlayer + UnifiedTransport` through the local Range server.
- The local server can stop independently without destroying the shared transport session during engine handoff.
- Startup Cannot Open can switch to MPV only in automatic mode, before playback establishes, and only after transport health is confirmed.

## MPV
- Added MPVKit `0.41.0-n8.1.2` as the formal compatibility engine dependency.
- Added `MPVUnifiedStreamBridge` using libmpv `stream_cb` read/seek/size/close/cancel callbacks.
- MPV loads `embyunified://media` and consumes the same ByteStore as AVPlayer; it does not fetch the 115 URL itself.
- Removed the old MPV direct-HTTP compatibility reload path from active Seek/stall recovery.
- KSPlayer was removed from the formal target; legacy source is compile-guarded only.

## Buffer timeline
- Added persistent verified buffered-time history separate from the current engine live buffer.
- Timeline uses a dim gray verified-history layer plus brighter current-buffer layer.

## Compatibility
- Deployment Target remains iOS 15.0.
- Target test device remains iPhone 15 Pro Max / iOS 17.0.
