# Build Report

- Version: 0.8.1 (45)
- Deployment Target: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0
- Expected CI: Xcode 16.4, arm64 iPhoneOS Release
- Swift language mode: Swift 5
- KTVHTTPCache: 3.1.0 via CocoaPods; upstream public metadata reports minimum iOS 12; MIT
- KSPlayer: 2.3.4 via Swift Package Manager
- FFmpegKit: 6.1.4 through KSPlayer
- MPVKit: not linked; source adapter retained behind compile-time guard
- Automatic standard MP4 path: KTVHTTPCache localhost proxy + AVPlayer
- Large MP4 compatibility path: KTVHTTPCache localhost proxy + KSPlayer/FFmpeg
- Cache scheduler: 32 MiB contiguous-frontier allocator; one worker baseline, optional adjacent second worker; no fixed 96 MiB lead
- KTV observability in 0.8.1: public cache-item total bytes + public `zones.count`; exact zone offsets remain deferred until a verified fixed KTV observability adapter is added
- Seek preloader policy: no `time / duration × fileSize` byte guess; player Seek remains immediate; byte-level demand re-anchor pending KTV localhost Range observability
- Large MP4 metadata: tail metadata Range tracked separately from playable Range and does not advance playback frontier
- KSPlayer KTV startup fallback: state-driven only after repeated Range failures and >=12 s total no-progress; fixed 10 s timeout removed
- Buffered timeline: AVPlayer `loadedTimeRanges` / KSPlayer `playableTime`; disjoint gray ranges supported
- Runtime automatic engine switching after playback established: disabled
- NAS media proxy: prohibited and not used
- Deployment Target changed: no; remains iOS 15.0
- Local validation planned/completed: Swift parser, RangeMap standalone typecheck/smoke test, plist/YAML/Ruby/shell validation, manifest verification, clean patch application and ZIP/hotfix overlay comparison
- Full Objective-C importer validation, CocoaPods integration, iPhoneOS typecheck/link, embedded-framework MinimumOS validation and unsigned IPA packaging: requires GitHub Actions

## 0.8.x architecture boundary

0.8.1 intentionally does not pretend that the app can already enumerate every byte span inside KTVHTTPCache or observe every localhost player Range. `PlaybackRangeMap` is authoritative only for explicit app-managed preload ranges and metadata ranges. Player-facing buffer UI is authoritative in media time because it comes from the playback engine itself. A later phase will add a fixed KTV observability layer for true player-demand Range anchoring.
