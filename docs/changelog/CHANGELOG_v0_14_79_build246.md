# OnePlayer 0.14.79 / Build246

Search follow-up from Build245 target-device evidence.

- Search gear enlarged 15% from Build245.
- Direct and grouped poster search use a Search-specific lean Emby item query and 18-item pages so the first poster wall is not blocked on the prior 60-item heavyweight metadata request.
- Recommendations are whitelisted to Emby `Movie` and `Series` item types only.
- Recommendation expansion preserves existing item identities and appends only newly returned items instead of replacing the full prefix; the incremental bottom spinner/layout shift is removed.
- Recommendation posters keep a Search-lifetime decoded-image pin after first presentation while continuing to use the existing shared persistent Emby image disk cache. Returning to an earlier lazy-grid cell can therefore render the already-seen image immediately instead of showing a placeholder while disk is decoded again.
- No Player/MPV/PiP, Transport, playback Cache/Session, STRM/302/115, shared poster-grid owner, credential, or Deployment Target changes.
