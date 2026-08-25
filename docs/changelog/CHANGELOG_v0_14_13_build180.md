# OnePlayer 0.14.13 Build180

- Warm-starts previously loaded detail-page presentation metadata (`episodes`, `seasons`, image metadata and similar items) from a session-level `NSCache` so re-entering the same series can immediately recover the known Logo and lower detail sections instead of rebuilding them from an empty ViewModel.
- Keeps every normal Emby detail load active after a warm hit, so current server data still replaces the presentation snapshot and Resume / watched / favorite state remains server-owned.
- Does not cache PlaybackInfo, MediaSource, PlaySession, ResolvedPlaybackSource or temporary 115/CDN URLs; playback resolution and the STRM → 302 → 115/CDN client-direct contract remain unchanged.
- Moves high-frequency detail Hero scroll offset out of root `EmbyMediaDetailView` render state into a dedicated ObservableObject observed only by the Hero scope, avoiding full detail-tree invalidation on every native `UIScrollView.contentOffset` update.
- Keeps the existing native ScrollView, Hero stretch/crop/pin mathematics, canonical Emby episode order, detail navigation, player episode-session replacement and trusted-natural-end auto-next behavior unchanged.
- Adds a detail-page performance contract check covering Hero state isolation, warm-cache field boundaries, live refresh paths and iOS 15.0 compatibility.
- Deployment Target remains iOS 15.0; target real-device validation remains iPhone 15 Pro Max / iOS 17.0.
