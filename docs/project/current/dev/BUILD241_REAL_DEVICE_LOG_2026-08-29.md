# Build241 real-device log evidence — 2026-08-29

Source log supplied by the user immediately after the Build241 / 0.14.74 IPA test. The app log itself does not embed AppIdentity/build/source SHA, so the exact binary cannot be proven from the log alone. Runtime behavior is nevertheless consistent with the Build241 500 pt/s gate and inconsistent with the Build239 600 pt/s gate because two releases at 559.82 and 522.47 pt/s report `velocity_commit=true`.

## Release decisions

- 29 release decisions total.
- 23 commit, 6 cancel.
- 22 commits are velocity-gated; one commit is progress-only (`actual_progress=0.312`, directional velocity 479.85 pt/s), preserving the 0.28 slow-drag rule.
- All six cancels are below both 0.28 progress and 500 pt/s directional velocity.
- No opposite-direction velocity commit appears in this sample.
- Exactly two releases would be newly committed by 500 pt/s but not by the old 600 pt/s gate:
  - `actual_progress=0.072`, directional velocity 522.47 pt/s, touch duration 70.81 ms — representative of the intended easier short flick.
  - `actual_progress=0.005`, directional velocity 559.82 pt/s, touch duration 429.26 ms. This is a borderline case: net release translation is only +2 pt while latest delivered velocity is -559.82 pt/s and latest coalesced velocity is only -399.97 pt/s. If the user reports an almost-stationary/after-pause accidental page change, this event is the primary suspect. Do not change the threshold from this log alone without subjective device feedback.

## Cadence / presentation

- 29 cadence summaries.
- Requested and maximum refresh are 120 Hz throughout.
- 11/29 gestures contain at least one display interval >=30 ms; 3 reach about 50.01 ms.
- Every >=30 ms worst display interval occurs 8.7–28.3 ms after the most recent `persistent` image event in that gesture.
- This is a strong temporal correlation with persistent-image publication/presentation, not proof of causation. It matches the already-known residual image/publication cadence family from earlier carousel diagnostics and is not attributable to Build241's threshold-only change.
- There is no sustained low-refresh collapse: many gestures retain display p95 near 8.34 ms, with the issue appearing as isolated spikes.

## Other log surfaces

- No crash, fatal, assertion, explicit error/failure, or timeout appears in this log.
- Detail warm-cache hit and episode diagnostics are internally consistent (34 episodes, one season, no unmatched/wrong-series entries).
- HTTP lines are request traces only; no failure response is recorded.
- Navigation appear/disappear/snapshot traces are orderly in this sample.
- This file contains no player/transport playback session, so it provides no new evidence about MPV, STRM/302, Range/206, cache, Resume, or EOF behavior.

## Evidence level

**Real-device diagnostic log reviewed; subjective Build241 acceptance remains pending.** Do not mark Build241 stable/frozen from this log alone.
