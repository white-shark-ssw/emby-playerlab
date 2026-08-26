# OnePlayer 0.14.37 / Build204

- Home carousel foreground total travel increases from 30% to 80% of Hero width.
- Foreground spatial interpolation now uses the same clamped `progress²` curve as opacity, keeping initial movement restrained while accelerating later in the drag.
- Raw `transitionProgress` remains the gesture/release authority; commit/release thresholds are unchanged.
- Existing left/right direction and first↔last modulo neighbor handling remain unchanged; no edge-specific state owner is added.
- No Player / MPV / PiP / Transport / Cache / Emby Session runtime path changes.
