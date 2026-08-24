# OnePlayer 0.14.5 Build172

- AVKit native black PiP transition / apparent double-orientation behavior remains intentionally frozen.
- Fixes the Build171 return handoff false-alignment bug. At return start, while the native AVKit transition is beginning, the SampleBuffer bridge is immediately aligned to the current MPV snapshot so a pre-existing PiP clock lead is not carried into the full-screen handoff.
- Final bridge authority no longer depends on coarse PlayerController snapshot refreshes. Once the inline MPV renderer reports ready, Build172 anchors authority to the returned MPV actual position plus host-time elapsed at 1x playback.
- If the bridge is behind MPV by more than 80 ms it is rebased forward. If the bridge is unexpectedly ahead by more than 120 ms, the bridge is held temporarily until the MPV renderer clock catches up instead of crossfading to a visibly older MPV frame.
- Final SampleBuffer -> MPV crossfade still requires bridge drift within 120 ms.
- PiP seek keeps MPV absolute+keyframes, the 180 ms visual long-tail guard, and MPV authoritative landing unchanged.
- Removes AVPictureInPictureController.invalidatePlaybackState() churn from the seek path. Build171 could invalidate AVKit up to four times per single skip (delegate completion, optimistic visual commit, settling start, settling end). Build172 performs no AVKit playback-state invalidation for seek-only timeline movement.
- AVKit playback-state invalidation remains for actual play/pause state changes.
- Adds PiP seek delegate-entry diagnostics so future logs can distinguish delay before AVKit delivers skipByInterval from delay after OnePlayer receives the callback.
- Build170 SampleBuffer visual bridge, Build167 vid=no background suspension and X=pauseAndSuspend, Build166 shared Wi-Fi/cellular cache, and STRM -> 302 -> 115/CDN direct transport remain unchanged.
- Deployment Target remains iOS 15.0; iOS 17.0 remains supported.
