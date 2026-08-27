# OnePlayer 0.14.46 / Build213

## Favorites / Library persistent page cache — accepted

- Favorites and the seven Library top tabs restore the last accepted presentation data from `Library/Caches/OnePlayer/PagePresentation` before live refresh.
- Successful live refresh/pagination/user-data replacement atomically persists the accepted current snapshot; failed requests keep the existing visible/disk snapshot.
- Library paging frontier (`nextStartIndex` / `hasMore`) is restored with cached content so pagination can continue from the recovered state.
- Library `sortBy` is intentionally not persisted by page cache; sorting remains a separate Preference concern.
- `selectedTab`, scroll position, Favorites root session retention, Search/Genre/Person persistence are not part of this candidate.
- No Player/MPV/PiP, UnifiedTransport, playback Session Cache, Home carousel, shared poster image/scroll, STRM/302/115/CDN or Range/206 behavior changes.
- Deployment Target remains iOS 15.0; target-device validation is iPhone 15 Pro Max / iOS 17.0.

## Validation

- Dedicated standard MPV run/job `33052588518` / `98451457434` passed and produced artifact `9638292306` with built MinOS 15.0.
- IPA SHA-256: `a8c2d1753db33f41a5b07ce22c4706eb102cf5d905f1aaeee8f54d689b176fc8`.
- User reported target-device acceptance on iPhone 15 Pro Max / iOS 17.0 on 2026-08-27.
- Current route-scoped cache identity can benignly miss if Build199 selects a different URL for the same server on a later launch; acceptance does not broaden cache identity or weaken user/server isolation.
