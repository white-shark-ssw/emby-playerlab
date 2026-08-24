# OnePlayer 0.13.96 Build163

- Replace Build162 30 ms PiP pause classification with an explicit seek-transaction suppression state.
- PiP seek ignores AVKit pause callbacks during the authoritative seek and the short post-visible echo window, while genuine pause still commits on the next main run-loop turn when no seek transaction begins.
- Closing the floating PiP window is now a distinct non-AVKit-restore path: release the PiP orientation hold immediately, keep the SampleBuffer cover alive while foreground MPV restores, then fade the cover only after a fresh MPV frame is confirmed.
- Explicit AVKit “return to player” keeps the Build162 destination-geometry experiment unchanged for continued real-device validation.
- Build161 volume/brightness 1% dedupe remains unchanged.
- MPV native seek remains `absolute+keyframes`; UnifiedTransport/cache/STRM -> 302 -> 115 client-direct transport remain unchanged.
- Deployment Target remains iOS 15.0; iOS 17.0 remains supported.
