# OnePlayer 0.13.93 Build160

- PiP SampleBuffer source becomes a visible inline handoff surface before AVKit starts PiP.
- PiP seek waits for the MPV authoritative landing position before moving the SampleBuffer pipeline.
- PiP seek pauses the SampleBuffer pipeline while waiting for engine landing to prevent stale queued frames.
- MPV PiP restore waits for playback-restart, a valid gpu-next viewport, and a position close to the PiP authoritative timeline before completing the system restore handoff.
- MPV native seek behavior remains absolute+keyframes and unchanged.
- Deployment Target remains iOS 15.0; iOS 17.0 remains supported.
