# OnePlayer 0.14.46 / Build213

## Favorites / Library persistent page cache candidate

- Favorites and the seven Library top tabs restore the last accepted presentation data from `Library/Caches/OnePlayer/PagePresentation` before live refresh.
- Successful live refresh/pagination/user-data replacement atomically persists the accepted current snapshot; failed requests keep the existing visible/disk snapshot.
- Library paging frontier (`nextStartIndex` / `hasMore`) is restored with cached content so pagination can continue from the recovered state.
- Library `sortBy` is intentionally not persisted by page cache; sorting remains a separate Preference concern.
- `selectedTab`, scroll position, Favorites root session retention, Search/Genre/Person persistence are not part of this candidate.
- No Player/MPV/PiP, UnifiedTransport, playback Session Cache, Home carousel, shared poster image/scroll, STRM/302/115/CDN or Range/206 behavior changes.
- Deployment Target remains iOS 15.0; target-device validation is iPhone 15 Pro Max / iOS 17.0.
