# OnePlayer 0.13.98 Build165

- Replaces the Build160-Build164 PiP callback patchwork with a single PiP behavior state machine: PlaybackState, PresentationState, ExitIntent, and SeekState.
- PiP close (system X without restore intent) now means close playback: PlayerController.stop() runs during PiP stop, audio stops immediately, Emby Stopped is reported once, and PlayerScreen dismisses when the app returns foreground.
- System return-to-player and direct PiP close are separate paths. Closing PiP never runs renderer restore.
- PiP return arms PlayerSurfacePresentationGate release before AVKit expands and only allows system restore after MPV renderer readiness, final orientation geometry, and the black presentation gate are all ready.
- Orientation remains locked through AVKit didStop, while the black presentation cover is allowed to release earlier after renderer acknowledgement.
- PiP source host becomes transparent after the first real video sample and no longer attempts to derive an image from compressed CMSampleBuffer data.
- PiP fast seek uses speculative parallel SampleBuffer preroll from MPV native dispatch telemetry. MPV remains the only authoritative landing timeline.
- If speculative preroll does not match the MPV landing, fallback seek keeps the old queued PiP video visible until the first authoritative replacement sample is ready; no pre-landing display-layer flush.
- AVKit seek completion remains immediate after the seek command is accepted; post-seek system pause callbacks are absorbed by SeekState rather than ad-hoc pause flags.
- MPV PiP renderer resume compares against a moving expected playback position instead of a frozen restore target, avoiding false timeouts while playback continues.
- MPV native seek remains absolute+keyframes; UnifiedTransport/cache/STRM -> 302 -> 115 client-direct transport and Build161 volume/brightness dedupe remain unchanged.
- Deployment Target remains iOS 15.0; iOS 17.0 remains supported.
