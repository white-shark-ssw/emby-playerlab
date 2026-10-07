# OnePlayer0.15.31 /Build298 — independent detail loading

DEV-poster-grid-smoothness /perf/poster-wall-library-build295 /Draft PR292; baseline exact297/source279f2c00fe86fa913962d22a0c7afbf17c82ca8d; iOS15 retained.

- Three bounded structured children publish Images, Similar and episode-dependent PlaybackInfo independently after the refreshed item. Series episodes→seasons→initial selection dependencies remain before PlaybackInfo. Actual playback/session flags and click-time60s reuse remain untouched.
- Cancellation propagates through every changed await and rejects late responses before publication. Cancelled loads remain retryable and do not store partial snapshots; ordinary partial presentation failures retain the previous complete cache. Playback user-data refresh may persist only a complete presentation baseline.
- The same warm-cache owner keeps its in-memory snapshot immediately; snapshot→JSON objects/serialization/atomic disk writes execute on one serial utility queue with an actor-isolated enqueue facade. Completed writes are awaited without blocking the main thread; schema/route keys/accepted restore semantics remain.
- Bounded data-transaction timing splits Library full apply into record preparation, native submission, replacement membership and first-screen demand; no new offset/physics/timer/cache owner or actual full-apply optimization claim. Ordinary append still maps only its suffix.
- Actual-source tests cover independent publication under delayed media/images, Series dependencies, cancelled late responses/retry/no empty warm hit, partial failure and cache preservation, media failure with complete presentation, cancelled basic request, immediate cache memory plus ordered off-main disk and route isolation, and playback-session reuse/user-data refresh.

Code candidate only until exact-source CI/Release/package verification. Target-device improvement and full P2 acceptance remain pending; accepted294/carousel293/Dock294/Search256/P0 and other host gates preserved.
