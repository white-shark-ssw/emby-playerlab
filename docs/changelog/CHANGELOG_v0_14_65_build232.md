# OnePlayer 0.14.65 / Build232

- Diagnostic-only Home carousel start-step measurement build.
- Base: cleaned Build231 foreground-compositing candidate; Build231 `compositingGroup()` is retained unchanged.
- Adds no carousel motion, threshold, easing, timing, residency, refresh-rate, release or rendering behavior changes.
- Records touch-down → horizontal acquisition time, acquisition translation, acquisition → first rendered move time, first rendered X, and first total delivered X in the existing `HomeCarouselCadence` log.
- Purpose: distinguish the reported “press-and-wait then drag” small first step from the “touch and immediately drag” larger first step before changing acquisition behavior.
- Player / MPV / PiP / Transport / Cache / Emby Session / STRM→302→115/CDN and all Frozen/P0 paths remain unchanged.
