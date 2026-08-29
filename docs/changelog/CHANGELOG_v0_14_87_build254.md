# OnePlayer 0.14.87 / Build254

- Preserve the Build253 target-device-accepted Search recommendation source: normal `/Users/{userId}/Items` with `SortBy=Random`, `Recursive=true`, and `IncludeItemTypes=Movie,Series`.
- Keep the accepted first recommendation wall at 9 items.
- When the current last recommendation card enters the lazy-grid viewport, request 6 additional recommendations using the same endpoint plus `ExcludeItemIds` for all already-visible recommendation IDs, then append only new IDs.
- Reuse the existing persistent image cache, decoded image pool and Search-lifetime poster pins for newly appended recommendations.
- No `StartIndex + Random`, timer, debounce, retry, fallback, watchdog, second cache or load-more ProgressView.
- Preserve the Build248 target-device-accepted Search Dock/keyboard behavior.
- No Player, MPV, STRM/302/115 Transport, playback Session Cache, Resume/progress, credentials, PiP or Deployment Target changes.

Evidence pending dedicated Xcode 16.4 Release CI/IPA and target-device validation.
