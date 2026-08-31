# OnePlayer 0.15.13 / Build280 — Poster off-main persistence A/B

- Base: target-device-tested Build278 exact source `6ff8113d9c45dfae6d745afa98b4a04a3956cf33`.
- Evidence: Build278 measured 10 accepted +60 Library page states with synchronous full-snapshot persistence 38.31→94.66 ms followed 1–8 ms later by 49.96→108.33 ms display gaps; fixed/no-append 540–660 item sessions stayed ~119–120 Hz with zero >=25 ms gaps.
- Change: move the existing full Library snapshot JSON-object construction, JSON serialization and atomic write onto one serial utility queue. The MainActor model awaits completion, so accepted snapshots keep ordered atomic write-through semantics without blocking display frames.
- Retains Build278 persistence timing logs and Build276 native display-gap diagnostics, now also logging whether persistence work ran on the main thread.
- No pagination-size/source, UICollectionView, image, scroll-physics, Search, Home, Player/MPV/PiP, UnifiedTransport, playback Cache/Session, STRM/302/115/CDN or Deployment Target change.
- Evidence level at source commit: code written only; CI/IPA/target-device/stable require separate proof.
