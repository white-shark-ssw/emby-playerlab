# OnePlayer 0.14.94 / Build261

- Build260 target-device evidence reframes the remaining EX gap around long-frame elimination rather than scroll-curve tuning.
- Home vertical scrolling requests 80→device-max refresh only during real drag/deceleration through the existing native UIScrollView observer.
- Home adds passive `HomeScrollCadence` display-interval summaries for direct 120 Hz verification.
- Shared 3×3 cadence diagnostics classify every >=12.5 ms display gap against same-frame cell churn, load-ahead and item-count changes, while recording offset-update count without per-frame logging.
- No `decelerationRate`, Grid structure, Search semantics, image/cache policy, Home carousel interaction, Player/MPV/PiP, Transport, STRM/302/115/CDN or Deployment Target change.
- Diagnostic/A-B candidate only; no final smoothness claim.
