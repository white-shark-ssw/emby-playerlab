# OnePlayer 0.14.61 / Build228

- Home carousel release-tail max-refresh lifecycle A/B.
- Baseline is cleaned Build226 three-slot Hero residency; Build227 foreground pixel rounding is intentionally not carried forward after target-device text shimmer remained.
- Keeps the same device-max carousel refresh request alive through interactive commit/cancel settle instead of invalidating it at `touchesEnded` / `touchesCancelled`.
- Keeps Build226 Hero residency, normal Hero/persistent crossfades, acquisition-relative motion, 0.22s/0.18s release animations, 0.28 commit gate and 0.48×width predicted release gate unchanged.
- No new timer, interpolation, retry, watchdog, fallback, gesture owner or duplicate state.
- No Player / MPV / PiP / Transport / Cache / Emby Session / P0/Frozen changes.
