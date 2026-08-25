# OnePlayer 0.14.15 Build182

- Keeps Build181's real-device-improved detail scroll architecture: high-frequency native `UIScrollView.contentOffset` remains isolated to the Hero-only observable scope instead of invalidating the full detail tree.
- Extends the existing detail presentation warm cache across App process restarts by persisting the same safe display snapshot under `Library/Caches/OnePlayer/DetailPresentation`.
- Cold re-entry after a force quit can restore known episode/season/image/similar-item metadata before the normal Emby refresh completes, allowing an already cached Logo and lower detail sections to appear without rebuilding from an empty ViewModel.
- The disk snapshot is keyed by server base URL + Emby userId + itemId and is written atomically. Existing `NSCache` remains the in-process hot path.
- Normal detail loading still performs the current Emby item, canonical series episode, season, image-info and similar-item requests; the persisted snapshot is presentation-only and never becomes server authority.
- PlaybackInfo, MediaSource, PlaySession, ResolvedPlaybackSource and temporary 115/CDN URLs are not stored in the detail presentation cache. STRM → 302 → 115/CDN client-direct playback, Range/206, Resume syncing and the Build176/178 player/episode contracts are unchanged.
- Deployment Target remains iOS 15.0; target validation remains iPhone 15 Pro Max / iOS 17.0.
