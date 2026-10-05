# OnePlayer 0.15.24 / Build291 — Home carousel geometry correction

Build290 is target-device rejected: reverse foreground movement, logo/text overlap and an upward Dock displacement. This candidate corrects the concrete geometry violations while retaining the resident native presentation and existing gesture/transition owner.

- Foreground layout uses untransformed bounds/center; ordinary progress updates no longer reset transformed frame geometry or relayout pages.
- Geometry/content boundaries prepare all resident page geometry. Vertical scroll updates visible pages without cancelling horizontal translation.
- Resource configuration preserves an in-flight animator rather than applying its final model state immediately.
- Native top overscan renders in an overlay of the accepted Build286 Home extent (viewport plus bottom safe area). Dock implementation and its inset remain unchanged.

Release/cancel timing, thresholds, auto interval, navigation, shared poster/image services, Player/MPV/PiP and transport remain unchanged. MinOS remains 15.0. Code written; simulator/CI/package/device evidence must be recorded separately.
