# v0.9.6

- Hotfix UnifiedTransport startup scheduling regression introduced in v0.9.5.
- Metadata probes preempt background preload and may use Slot 1 immediately.
- Background Slot 1 no longer starts merely because Slot 0 became urgent.
- Any active urgent playback demand preempts background Slot 1 so current playback/seek keeps bandwidth priority.
- Dual-slot sequential preload is enabled only after startup-critical urgent/metadata work is cleared.
- Keep v0.9.5 MPV startup crash fix and thumb-less timeline.
- Deployment Target remains iOS 15.0.
