# OnePlayer 0.14.3 Build170

- PiP fast-seek remains frozen in this round. The previously observed long-latency PiP seek is recorded for later dedicated work.
- Replaces the “wait for MPV, then finish AVKit return” handoff with a persistent SampleBuffer visual bridge.
- Return-to-player now accepts AVKit restore as soon as the app is active, final landscape geometry is ready, and the inline SampleBuffer host is laid out. MPV renderer readiness is no longer a prerequisite for system restore completion.
- After AVKit returns to the full-screen player, the same SampleBuffer pipeline remains visible and continues normal video playback while MPV restores its selected video track and gpu-next viewport underneath.
- MPV still owns audio, playback state, and the authoritative timeline. SampleBuffer remains a visual replica only.
- When MPV renderer is genuinely ready and PlayerSurfacePresentationGate has released its black cover, the SampleBuffer bridge crossfades to MPV over 100 ms, then the PiP pipelines and host are destroyed.
- AVKit didStop no longer removes the PiP host or completes visual ownership transfer. It only marks the native PiP transition as finished; the bridge stays live until MPV handoff succeeds.
- PiP X retains the last displayed SampleBuffer frame after pausing. FFmpeg/SampleBuffer pipelines are stopped, audio is paused, and no background decoding/download work is kept alive, but the display layer and host remain attached as a static visual bridge.
- When the user later reopens the app after PiP X, the preserved paused frame is shown immediately while MPV video-track/viewport restoration runs behind it. After MPV is ready, the same 100 ms crossfade returns ownership to MPV.
- PiP X semantics remain pause-and-suspend: no PlayerController.stop(), no Emby Stopped, no PlayerScreen dismissal.
- Build169 replayGeneration, Build168 paused-frame signal, Build167 vid=no background suspension, Build166 shared Wi-Fi/cellular cache, MPV native absolute+keyframes seek, and STRM -> 302 -> 115 client-direct transport remain unchanged.
- Deployment Target remains iOS 15.0; iOS 17.0 remains supported.
