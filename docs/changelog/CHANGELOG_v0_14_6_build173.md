# OnePlayer 0.14.6 Build173

- AVKit native black PiP transition / apparent double-orientation behavior remains intentionally frozen.
- Removes Build171/172 periodic SampleBuffer bridge synchronization. Return-to-player now performs one initial bridge alignment when restore begins, then lets the bridge run naturally at 1x without periodic rebase or catch-up freezes.
- Final return handoff uses the MPV renderer-ready actual position plus host-time elapsed as a continuous authority measurement.
- If final bridge drift is within 120 ms, OnePlayer crossfades directly to MPV.
- If final drift unexpectedly exceeds 120 ms, Build173 permits only one final bridge correction, then waits for the next poll/display cycle before crossfade. No repeated freeze/rebase loop remains.
- PiP seek now follows AVKit completion ownership correctly: skipByInterval completion is stored per seek token and is not invoked when the callback first arrives.
- AVKit skip completion is delivered only after the SampleBuffer visual target has been enqueued and the control timebase has been updated to the new seek position.
- Optimistic, 180 ms long-tail, and authoritative/fallback visual commits all use the same completion ownership path.
- Superseded seek completions remain pending until a newer committed visual state covers them; lifecycle cancellation/reset guarantees any remaining completions are released exactly once.
- Adds callback-to-completion timing diagnostics so future logs can separate AVKit callback latency from OnePlayer visual/timebase commit latency.
- MPV native seek remains absolute+keyframes; Build171 long-tail candidate confidence rules remain unchanged.
- Build170 visual bridge, Build167 vid=no and X=pauseAndSuspend, Build166 shared Wi-Fi/cellular cache, UnifiedTransport, Range/206, and STRM -> 302 -> 115/CDN client-direct transport remain unchanged.
- Deployment Target remains iOS 15.0; iOS 17.0 remains supported.
