# OnePlayer 0.14.2 Build169

- PiP fast seek remains frozen in this round; the previously observed long-latency seek is intentionally deferred.
- Fixes the core PiP renderer replay bug: PlayerSurfacePresentationGate now has an explicit replay generation, and MPVSurface invalidates/reports geometry on every replay even before presentation release is armed.
- This makes the first PiP return/paused-foreground replay immediately reach RendererLayoutCoordinator and MPVRenderer instead of doing only UIView/CAMetalLayer layout and waiting for a 2.5 s resume timeout before retry.
- Return-to-player keeps the SampleBuffer bridge and black presentation cover until AVKit pictureInPictureControllerDidStopPictureInPicture has fired and MPV renderer is ready.
- Final AVKit -> MPV visual ownership changes on the next CADisplayLink tick after didStop, then sourceHost is hidden and presentation release is armed. This is a display-cycle barrier, not an arbitrary millisecond delay, and is intended to prevent the last AVKit transition frame from leaking into the first inline MPV frame.
- Logs now distinguish explicit gate replay, renderer-ready-before-system-stop, and next-vsync final handoff.
- App orientation remains locked to the final landscape target throughout restore. Build168 logs confirmed the app window was already 932x430 / landscape at restore start; the visible 430x181 -> 931x392 phase is AVKit transition-surface geometry, not a delayed landscape request.
- Build168 paused-frame signal, Build167 vid=no background suspension and PiP X=pauseAndSuspend, Build166 shared Wi-Fi/cellular cache, MPV native absolute+keyframes seek, and STRM -> 302 -> 115 client-direct transport remain unchanged.
- Deployment Target remains iOS 15.0; iOS 17.0 remains supported.
