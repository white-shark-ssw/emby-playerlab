# OnePlayer 0.14.36 / Build203

Home carousel target-device follow-up to Build201.

- Retain Build198/201 single UIKit begin/move/end/cancel gesture ownership and existing settle/commit semantics.
- Increase foreground interactive horizontal travel from `0.15 × Hero width` to `0.30 × Hero width`.
- Keep one normalized `transitionProgress`; map backdrop and foreground crossfade through `progress²`, so opacity changes are subtle at drag start and accelerate later in the transition.
- Preserve the existing modulo neighbor lookup, so the same progress/blend mapping applies to left/right swipes and first↔last wrap boundaries without a second edge state machine.
- No Player / MPV / PiP / UnifiedTransport / Cache / Emby playback/session changes.
- Deployment Target remains iOS 15.0.
