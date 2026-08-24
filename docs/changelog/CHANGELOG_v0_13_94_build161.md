# OnePlayer 0.13.94 Build161

- PiP skip keeps the current SampleBuffer visual timeline running while MPV resolves the authoritative seek landing; the SampleBuffer pipeline pauses only for the short post-landing alignment window.
- Repeated PiP skips remain latest-wins and can resume the in-flight SampleBuffer generation while the next MPV landing is pending.
- PiP return now holds the player orientation mask through the AVKit restore animation and releases it only after `pictureInPictureControllerDidStopPictureInPicture`.
- Volume/brightness vertical adjustment callbacks are deduplicated at the existing 1% quantization boundary, preventing repeated identical MPVolumeView writes and SwiftUI HUD updates while preserving the current 1% haptic behavior.
- MPV native seek remains `absolute+keyframes`; UnifiedTransport, cache and STRM -> 302 -> 115 direct transport are unchanged.
- Deployment Target remains iOS 15.0; iOS 17.0 remains supported.
