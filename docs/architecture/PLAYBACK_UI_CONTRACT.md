# OnePlayer Playback UI Contract

This contract is frozen for the player architecture refactor. Seek, health, transport and engine work must not silently redefine these UI semantics.

## Timeline: one control, three visual layers

The normal player has exactly one timeline control. Its visual layers share the same 6pt track and are clipped by the same capsule:

1. Unbuffered base: dark translucent track.
2. Buffered cache: gray ranges from `UnifiedMediaTransportSession.cachedByteRanges()` / `PlayerController.transportCacheRanges` only.
3. Played progress: solid white from start to the current presentation position.

`PlaybackBufferState.livePlayableRanges` and `verifiedHistoryRanges` remain available for engine health, recovery and diagnostics. They must not be rendered as additional normal-player timeline layers.

Do not draw total cache percentage as a fake contiguous range. Sparse cached byte ranges stay sparse. Metadata ranges must not be included in playback cache ranges.

## Buffering download indicator

The center buffering/download-speed indicator represents real network starvation, not the playback engine's internal buffering state by itself.

The normal rule is:

- Engine `isBuffering` is necessary but not sufficient.
- `PlaybackTransportStarvationState` must also report an active concrete blocked byte read.
- Only `engine buffering && transport starvation` may show the buffering/download-speed popup.
- MDK demux, keyframe positioning, decoder flush and A/V resynchronization must not show a network-download popup when required bytes are already locally available.
- MDK user Seek may still hide raw internal buffering during the first 500ms as flicker suppression, but the 500ms window is not the truth classifier.
- A blocked UnifiedTransport read starts starvation when zero requested bytes are locally available and ends starvation as soon as that read is satisfied or exits.

Startup buffering follows the same truth rule: the popup means a concrete transport read is actually waiting for bytes.

## Volume tick haptic

Current requested player-volume tick haptic:

- duration: 5ms
- user amplitude scale: 3.8/10
- CoreHaptics intensity: 0.38
- sharpness: 0.82

## Compatibility

These rules must remain compatible with Deployment Target iOS 15.0 and iOS 17.0 devices.
