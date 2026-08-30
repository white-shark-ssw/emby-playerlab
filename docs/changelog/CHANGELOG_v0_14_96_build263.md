# OnePlayer 0.14.96 / Build263

- Diagnostic-only continuation of Build261 on the exact poster-smoothness lineage.
- Keeps the already effective shared 3×3 80→device-max refresh request unchanged.
- Attributes severe `>=25 ms` and `>=33.3 ms` display gaps to cell lifecycle churn, grid poster image publication, load-ahead/item-count changes, or still-untracked work.
- Adds a main-run-loop `beforeWaiting` discriminator so severe gaps can show whether the main run loop reached a wait point between display ticks.
- Reuses the existing grid `CADisplayLink`; no timer, second display link, scroll-physics change, Grid geometry change, Search behavior change, image-cache policy change, or Player/Transport change.
- Deployment Target remains iOS 15.0.
