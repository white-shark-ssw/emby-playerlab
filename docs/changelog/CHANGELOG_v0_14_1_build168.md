# OnePlayer 0.14.1 Build168

- PiP fast-seek behavior is frozen from Build167/Build166 in this round. The single observed long-latency PiP seek is recorded for later dedicated investigation.
- Removes the custom PiP placeholder icon from PlayerPiPSourceHostView. The host is invisible until a real SampleBuffer is available, so a synthetic black PiP glyph is never needed during native return transitions.
- Return-to-player now hides the SampleBuffer bridge while PlayerSurfacePresentationGate is still holding the black cover, then arms MPV presentation release. This closes the Build167 ~17 ms window where the cover was already released but sourceHost was still above MPV, which could expose one stale PiP/fallback frame.
- Paused foreground restore after PiP X no longer waits for playback-restart/video-pts that may never arrive while MPV is paused. A stable enabled video track + gpu-next + valid viewport + matching time-pos is accepted as a valid paused frame signal.
- This removes the Build167 ~2.5 s first-attempt timeout before the retry that previously succeeded almost immediately.
- Build167 vid=no PiP suspension, X=pauseAndSuspend semantics, Build166 shared Wi-Fi/cellular cache pool, MPV native absolute+keyframes seek, and STRM -> 302 -> 115 client-direct transport remain unchanged.
- Deployment Target remains iOS 15.0; iOS 17.0 remains supported.
