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

The center buffering/download-speed indicator represents real playback starvation, not every transient MDK demux/decoder refill.

For MDK user Seek:

- Raw MDK buffering may be hidden only during the first 500ms after the current Seek starts.
- If buffering still exists after 500ms, publish `snapshot.isBuffering = true` and show the normal buffering/download-speed indicator.
- Do not extend this grace to multi-second windows. Long grace periods hide real network stalls and produce a tail-end popup flash.
- A newer Seek replaces the old Seek grace generation; stale grace state must not suppress a newer real stall.

Startup buffering is not a Seek refill and is not subject to the Seek grace.

## Volume tick haptic

Current requested player-volume tick haptic:

- duration: 5ms
- user amplitude scale: 3.8/10
- CoreHaptics intensity: 0.38
- sharpness: 0.82

## Compatibility

These rules must remain compatible with Deployment Target iOS 15.0 and iOS 17.0 devices.
