# OnePlayer 0.14.80 / Build247

Search follow-up from Build246 target-device evidence.

- Search Dock presentation is moved out of the keyboard-responsive Search `NavigationView` and back to the server-root owner while Search is selected.
- Recommendation visibility is a hard client-side whitelist: only actual Emby `Movie` and `Series` items are accepted, in addition to the server-side `IncludeItemTypes` request.
- Saved Emby sessions start one Search recommendation warm in the background immediately after app startup restore. The warm fetches a bounded 60-item recommendation set and preloads the exact Search poster URLs into the existing `EmbyImageDiskCache` / decoded image pool.
- Search landing consumes the already-started recommendation task instead of starting its first recommendation fetch only when the Search page appears.
- Recommendation scrolling no longer performs incremental Suggestions requests or mutates the grid item count near the scroll frontier. The fixed preloaded set removes the Build246 active-scroll load-more path that still twitched on device.
- Keyword Search remains separate because its query is not known at app launch.
- No Player/MPV/PiP, UnifiedTransport, playback Cache/Session, STRM/302/115, shared `EmbyPosterGrid` / shared image-loader implementation, credentials, or Deployment Target changes.
