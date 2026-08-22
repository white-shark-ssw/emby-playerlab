# OnePlayer Playback Engine Strategy

This is a frozen product and architecture decision.

## Default engine

- MPV is the default engine for every new playback session.
- MPV is the primary engine for normal playback, rapid Seek, STRM/HTTP 302 playback, H.264/HEVC and future UnifiedTransport preloading.
- MDK is retained as a manually selectable experimental/diagnostic engine, not as an automatic fallback target.
- OnePlayer does not require MDK Seek performance or behavior to match MPV before shipping the main playback path.

## Engine switching

- OnePlayer must never automatically switch MPV and MDK because of prepare timeout, first-frame timeout, Seek latency, buffering, decoder errors, renderer-health warnings, EOF suspicion, or other health heuristics.
- A playback error may offer explicit actions such as Retry, Switch to MDK, or Close, but the switch only happens after a user action.
- The playback UI must expose the current engine and allow manual MPV ↔ MDK switching.
- Manual switching should preserve the current rendered/playback position and reuse the active UnifiedTransport session/cache when safe.
- Engine choice is session-scoped. A new media playback session defaults to MPV rather than silently inheriting MDK from a previous test.

## Health Coordinator

- Health Coordinator diagnoses playback health; it does not own engine selection.
- Timers and watchdogs may submit evidence and trigger diagnostics/error presentation, but they must not quarantine an engine for the purpose of automatically switching to another engine.
- A fixed timeout alone must not be treated as authority to change engines.

## UnifiedTransport and preloading

Future preload/prefetch is engine-agnostic infrastructure owned above the playback engines:

`SeekPrefetchCoordinator → UnifiedTransport → shared session cache → MPV / MDK`

MPV and MDK consume the same cached byte ranges through normal transport reads and do not need engine-specific preload implementations.

Priority is frozen as:

1. concrete blocked playback read;
2. current user Seek urgent demand;
3. predictive Seek prefetch;
4. ordinary background cache fill.

Predictive preload must never delay a real Seek or active playback read. Preloading does not include predecoding or a hidden second player.

## MDK role

MDK remains valuable for manual comparison, diagnostics, compatibility experiments and testing media behavior. It is not a mandatory rescue path for MPV. If MPV cannot play a file, OnePlayer may offer MDK as a manual experiment, but must not assume MDK will succeed or switch automatically.

## Compatibility

This strategy does not change the deployment policy: iOS 15.0 remains the preferred minimum while iOS 17.0 device compatibility is mandatory and the Deployment Target must never exceed iOS 17.0.
