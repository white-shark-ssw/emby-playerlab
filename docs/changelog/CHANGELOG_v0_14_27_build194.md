# OnePlayer 0.14.27 Build194

- Fixes the in-player episode selector for non-standard Emby series where most episodes have `ParentIndexNumber = nil` but a valid shared `SeasonId`.
- Player episode metadata now loads the same `seriesEpisodes` and `seriesSeasons` data used by the accepted detail-page path.
- Season selection and filtering use Episode `SeasonId` -> real Season `id/indexNumber` first, with `ParentIndexNumber` retained only as fallback.
- Preserves Build178 canonical `/Shows/{SeriesId}/Episodes` server order; no title/file/date/ID/artificial-number sorting is introduced.
- Auto-next continues to use the full canonical episode array and is not changed to use the season-filtered UI list.
- PlayerController, MPV Seek, PiP, UnifiedTransport, Cache, Range/206, STRM -> 302 -> 115/CDN client-direct playback and Emby Resume/progress are unchanged.
- Deployment Target remains iOS 15.0; target device remains iPhone 15 Pro Max / iOS 17.0.
