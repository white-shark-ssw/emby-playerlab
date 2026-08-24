# OnePlayer 0.14.0 Build167

- PiP seek behavior is frozen from Build166 for this round; no further fast-seek tuning is included.
- PiP X now means the same as pressing Pause in the player and then leaving the app in the background: playback becomes paused, UnifiedTransport playback advancement stops, Emby receives Pause/Progress rather than Stopped, PlayerScreen remains alive, and iOS may naturally suspend the app.
- Returning to the app after PiP X restores the inline video renderer while remaining paused at the preserved playback position; the player is not dismissed to the detail page.
- MPV PiP background suspension no longer switches `vo` between `gpu-next` and `null`. Build167 disables only the selected video track with `vid=no`, preserving the MPV audio path while PiP video is supplied by the SampleBuffer pipeline.
- The selected MPV video track ID is captured before PiP suspension and restored on foreground return. Suspension state is reconciled from the real `vid` property on every suspend/resume completion, eliminating stale logical state such as “suspended=true while gpu-next is actually active”.
- PiP return uses the current MPV snapshot position as the authoritative restore target instead of the PiP replica clock.
- PlayerSurfacePresentationGate now separates “surface replay” from “cover release”. Final-orientation replay is triggered before MPV fresh-frame waiting, while the black presentation cover remains held; the cover is armed for release only after MPV reports a fresh restored video frame.
- If AVKit `didStop` arrives before renderer readiness, the PiP SampleBuffer source host remains in place as the visual bridge. It is removed only after MPV renderer readiness and presentation-gate release are both confirmed.
- Manual foreground restore after PiP X uses the same replay/fresh-frame handshake but keeps playback paused.
- Build166 shared Wi-Fi/cellular sparse Range cache semantics remain unchanged: one cache pool, network-specific preload limits only.
- MPV native seek remains `absolute+keyframes`; UnifiedTransport STRM -> 302 -> 115 client-direct byte flow remains unchanged.
- Deployment Target remains iOS 15.0; iOS 17.0 remains supported.
