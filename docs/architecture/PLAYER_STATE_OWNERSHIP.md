# OnePlayer Player State Ownership

This document is the architecture contract for the post-Build118 player refactor. It is intentionally stricter than the historical implementation so Seek, startup, buffering, recovery, UI presentation, and engine fallback cannot silently own the same state.

## Baseline

The refactor starts from the exact source materialized by the Build101→Build118 CI chain at Build118 head `06f8a73a7a66cdb3122f44a2ca2682e178071ea7`.

Rejected Build119 / PR #161 is forensic input only and is not a runtime baseline.

The repository source itself must be buildable. Production/validation builds on this branch must not require historical `instrument_mdk_*` scripts to discover the actual Swift code being compiled.

## Ownership rules

### PlayerController

Owns user intent and product presentation state only:

- play / pause intent;
- latest requested Seek target and direction;
- scrub interaction state;
- displayed timeline position;
- Emby session/progress reporting;
- engine selection and engine transition orchestration.

`PlayerController` must not infer that an MDK frame landed merely because `PlayerSnapshot.position` changed.

### PlayerEngine / MDK engine

Owns native playback facts only:

- native lifecycle (`prepare`, `play`, `pause`, `stop`);
- native Seek ownership;
- native callback results;
- decoded/buffer state;
- rendered-frame timestamps;
- engine-confirmed playable media-time ranges.

A native Seek stays owned until its actual native callback returns or the whole engine generation is torn down. A watchdog must never clear native Seek ownership in order to dispatch another Seek.

### Health coordinator

Exactly one coordinator owns automatic failure/fallback decisions for an engine generation.

It tracks the current phase (startup prepare, first-frame wait, normal playback, native Seek, post-callback frame wait) and progress evidence. Individual timers may record diagnostics, but they must not independently quarantine/switch the engine.

A fixed wall-clock deadline alone is insufficient evidence of failure when transport, native state, or rendering is still progressing.

### Timeline UI

There is exactly one interactive timeline control.

That single track may layer:

1. played progress;
2. UnifiedTransport byte-cache projection;
3. engine-confirmed live playable media-time window.

No second/third slider or separate progress-like band may be introduced for buffering visualization.

### Seek presentation

For MDK, `player.position` / polling `PlayerSnapshot.position` is a playback clock, not proof that the requested frame is visible.

Relative Seek UI may optimistically show the user's latest target while the request is pending, but the presentation may only transition to an engine landing position from a rendered-frame-backed Seek completion/event. MDK polling snapshots must not complete a pending Seek presentation anchor.

### Audio

Decoded audio readiness and MDK log messages are not treated as proof of audible device output. Audio continuity experiments must be isolated from Seek scheduling and health/fallback changes.

## Invariants enforced by CI

- Deployment Target remains iOS 15.0 and never exceeds iOS 17.0.
- Build119 `SeekDisplayAnchor` is absent.
- No separate `liveTrackHeight` timeline band exists.
- The existing MDK-specific rule that polling snapshots cannot complete an MDK Seek anchor remains present until replaced by a rendered-position API.
- Historical materializer scripts are not executed by the flat-source build.
- Runtime refactors must preserve fixed 2 MiB bounded AVIO unless a later isolated experiment explicitly changes it.

## Refactor order

1. Flatten exact Build118 source.
2. Prove the flattened repository builds directly.
3. Replace multiple fallback-capable MDK watchdogs with one phase-aware health owner.
4. Replace overlapping native Seek preemption with explicit latest-intent / single-native-owner semantics.
5. Replace temporary timeline heuristics with a rendered-position-backed presentation contract.
6. Keep the buffering visualization inside one timeline control.
7. Only after state ownership is stable, resume isolated Seek/audio performance experiments such as `InCache` or AVIO variants.
