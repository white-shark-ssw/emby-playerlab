# OnePlayer 0.14.7 Build174

- Adds an in-player episode selection entry for Emby episode playback.
- The episode selector opens as a bottom-up horizontal strip with landscape thumbnails, season/episode labels, and an explicit current-playing state.
- Reuses Emby `libraryItem`, `seriesEpisodes`, `playbackInfo`, and `resolvePlaybackSource`; episode metadata may be loaded while playing, but the selected/next episode media source is resolved only when the user selects it or a trusted natural end occurs.
- Manual episode switching preserves the fullscreen player host while stopping the old playback session and creating a fresh source-owned PlayerController / PlaybackOrchestrator / PlaybackTransportContext for the selected episode.
- Adds the playback setting `自动加载下一集`, enabled by default for the Build174 test candidate.
- Automatic next episode is considered only after `PrematureEOFGuard` classifies the end as non-premature. Premature EOF, abnormal short-media recovery, buffering/starvation, and other recovery paths do not trigger episode advancement.
- Episode order follows the existing Emby `ParentIndexNumber,IndexNumber` ascending series list, including normal season boundaries.
- Does not pre-resolve or retain the next episode's 115/CDN temporary direct URL.
- MPV fast Seek, PiP Build173 behavior, UnifiedTransport, Range/206, STRM -> 302 -> 115/CDN client-direct transport, session cache semantics, and deployment target remain unchanged.
- Deployment Target remains iOS 15.0; iPhone 15 Pro Max / iOS 17.0 remains the target real-device validation environment.
