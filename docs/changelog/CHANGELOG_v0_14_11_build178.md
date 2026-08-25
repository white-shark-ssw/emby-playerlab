# OnePlayer 0.14.11 Build178

- Fixes canonical ordering for non-standard Emby TV series whose Episode items do not provide usable `IndexNumber` values.
- `seriesEpisodes(seriesId:)` now uses Emby's TV-specific `/Shows/{SeriesId}/Episodes` endpoint and preserves the server-provided episode order instead of forcing the generic Items query to sort by `ParentIndexNumber,IndexNumber`.
- Keeps existing SeasonId-based season grouping, pagination, image/user-data fields, ID deduplication, detail-page display order, player episode selection, and trusted automatic next-episode consumption unchanged.
- Does not add title/file-name/date/ID fallback sorting or client-side episode renumbering.
- Build178 is based on the real-device accepted Build176 / OnePlayer 0.14.9 episode-selection baseline; Build177 remains reserved by the separate home-carousel smoothness task.
- PlayerController, MPV Seek, PiP, UnifiedTransport, cache, STRM -> 302 -> 115/CDN client-direct transport, Range/206, and Emby progress/resume contracts are unchanged.
- Deployment Target remains iOS 15.0; target validation device remains iPhone 15 Pro Max / iOS 17.0.
