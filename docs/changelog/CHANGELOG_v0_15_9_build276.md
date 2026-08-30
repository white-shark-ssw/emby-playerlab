# OnePlayer 0.15.9 / Build276 — Native poster frame-tail attribution

- Diagnostic-only continuation from target-device Build273 exact source.
- Keeps Library `.items` native UICollectionView behavior unchanged.
- Records per-display callback interval p50/p95/p99/max and >=12.5/25/33.3 ms gap counts.
- Correlates those gaps with existing append `insertItems` batches and same-ID visible hosting-root reconfiguration.
- Logs only >=25 ms individual display gaps to limit diagnostic I/O; >=12.5 ms is aggregate-only.
- Keeps native reverse/bounds diagnostics and the existing motion-local 80→device-max refresh request.
- No scroll-physics, Grid/container, image-quality/loading, pagination-source, Search, Home, Player/MPV/PiP, Transport/Cache/Session, STRM/302/115/CDN, or Deployment Target behavior change.
