# OnePlayer 0.14.14 Build182

- Follows the Build180 real-device result: reverse-direction drag is now continuous, but the first visible foreground movement still jumps by a noticeable amount and the overall feel remains less fine-grained than EX.
- Keeps the Build180 zero-distance continuous drag state machine unchanged.
- Replaces full-width horizontal Hero foreground travel during carousel transitions with progress-driven crossfade, matching the spatially stable transition behavior visible in the EX reference recording.
- Keeps artwork/backdrop progress, commit/cancel thresholds, release animations, auto-advance timing, detail tap behavior and vertical homepage scrolling unchanged.
- Does not change PlayerController, MPV fast Seek, PiP, UnifiedTransport, Range/302/115 client-direct playback, session cache, episode selection/order, or native navigation.
- Deployment Target remains iOS 15.0; target validation remains iPhone 15 Pro Max / iOS 17.0.
