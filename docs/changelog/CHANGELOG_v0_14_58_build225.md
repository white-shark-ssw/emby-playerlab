# OnePlayer 0.14.58 / Build225

- Home carousel horizontal diagnostic only.
- Starts from the Build219 carousel cadence/high-refresh line, not Build221's frozen-persistent experiment.
- During active horizontal drag, keep the already-mounted current Hero clear artwork opaque and do not mount the target Hero clear artwork.
- Restore normal persistent current/target presentation; keep preload, foreground page travel, acquisition-relative motion, release gates and device-max refresh request unchanged.
- Target Hero presentation resumes after release so release/settle can be evaluated separately.
- No Player / MPV / PiP / Transport / Cache / Emby Session or other P0/Frozen path changes.
