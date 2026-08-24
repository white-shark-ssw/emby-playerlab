# OnePlayer 0.13.97 Build164

- PiP close now has an explicit system-stop transaction so AVKit stop-generated `setPlaying(false)` callbacks cannot pause an actively playing MPV session.
- Directly closing the floating PiP window restores against the MPV authoritative engine position instead of a potentially drifted SampleBuffer clock.
- The PiP source host captures one frozen frame from the last real SampleBuffer before system stop/restore and uses that frame as the handoff cover, eliminating the permanent black placeholder state seen in Build163.
- Closed-PiP restore can no longer keep the PiP cover forever after repeated renderer timeouts; the cover is forcibly released after the bounded retry budget.
- PiP skip completion is acknowledged to AVKit immediately after the seek command is accepted while MPV authoritative landing and SampleBuffer alignment continue internally.
- MPV native seek remains `absolute+keyframes`; Build161 volume/brightness dedupe, UnifiedTransport/cache, and STRM -> 302 -> 115 client-direct transport remain unchanged.
- Deployment Target remains iOS 15.0; iOS 17.0 remains supported.
