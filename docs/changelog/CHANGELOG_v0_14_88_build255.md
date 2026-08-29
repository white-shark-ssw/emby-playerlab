# OnePlayer 0.14.88 / Build255

- Fix the only target-device issue reported for Build254 incremental Search recommendations: the recommendation container visibly twitched when a +6 batch appended.
- Replace only the Search landing outer `LazyVStack` with a normal `VStack`, matching the existing paginated poster-page layout ownership pattern while keeping the inner `EmbyPosterGrid` lazy.
- Preserve Build253/254 recommendation semantics exactly: first 9 normal Movie/Series items, then +6 batches from `/Users/{userId}/Items` with `SortBy=Random`, `Recursive=true`, `IncludeItemTypes=Movie,Series`, and `ExcludeItemIds` for already-visible recommendations.
- Preserve the existing last-card load trigger, image caches/pins and Build248 target-device-accepted Dock/keyboard behavior.
- No shared `EmbyPosterGrid`, Player, MPV, STRM/302/115 Transport, playback Session Cache, Resume/progress, credentials, PiP or Deployment Target changes.
- No timer, debounce, retry, fallback, watchdog, load-more spinner or second cache.

Dedicated Xcode 16.4 Release CI/IPA passed for exact product source `99af35f86229ca5fb0cf9699fb41ef1bf5c754d2` (run `33270048487`, artifact `9719867060`, IPA SHA-256 `2dbc76a146d4716eee0965c6861823e0df5592324812584fe261a30afb98019e`, MinOS 15.0). Target-device validation remains pending.
