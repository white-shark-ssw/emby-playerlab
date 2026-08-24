# OnePlayer 0.14.4 Build171

- The AVKit native double-orientation / black PiP transition frame is explicitly frozen and not modified in this build.
- Return-to-player no longer requires MPV playback-restart as the only playing fresh-frame signal. Build171 captures the pre-restore video-pts baseline and accepts a genuinely advanced post-restore video-pts when vid is enabled, gpu-next has a valid viewport, and the restored position matches the MPV authority.
- The full-screen SampleBuffer visual bridge now follows MPV authority while return-to-player is in progress. If the bridge falls behind MPV by more than 80 ms, its control timebase is rebased forward to the current MPV snapshot.
- Final SampleBuffer -> MPV crossfade waits until the remaining bridge/MPV drift is within 120 ms, reducing the visible catch-up/jump at the ownership handoff.
- PiP seek still uses the native MPV absolute+keyframes command unchanged.
- Optimistic PiP seek no longer treats the mere presence of a previous keyframe as sufficient confidence. Immediate visual commit now requires a real first SampleBuffer frame close to the requested/dispatch/predicted target.
- A 180 ms PiP seek visual long-tail deadline is added. If MPV landing is still pending but the standby pipeline already has a first frame within 650 ms of the requested or dispatch target, PiP may display that candidate early and later validate/correct it against the authoritative MPV landing.
- The long-tail escape is visual-only. It does not change MPV native seek, MPV target selection, UnifiedTransport scheduling, Range/206 behavior, or the authoritative landing result.
- Build170 persistent SampleBuffer return bridge, Build167 vid=no background suspension and PiP X=pauseAndSuspend semantics, and Build166 shared Wi-Fi/cellular sparse Range cache remain intact.
- STRM -> 302 -> 115/CDN remains client-direct; NAS does not relay media bytes.
- Deployment Target remains iOS 15.0; iOS 17.0 remains supported.
