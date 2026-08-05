# Build Report

- Version: 0.6.0 (30)
- Deployment Target: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0
- Expected CI: Xcode 16.4, arm64 iPhoneOS Release
- Swift language mode: Swift 5
- MPVKit: 0.40.0-av
- KSPlayer: 2.3.4
- FFmpegKit: 6.1.4 through KSPlayer
- KSPlayer declared minimum iOS: 13.0
- Automatic primary path: AVPlayer + AVAssetResourceLoaderDelegate
- Automatic fallback path: KSPlayer FFmpeg custom AVIO, then MPV
- Shared transport: MediaTransportSession retained by PlaybackTransportContext
- Automatic path localhost HTTP: disabled
- Deployment Target changed: no; remains iOS 15.0
- Full iOS 17.0 compatibility claim: pending GitHub Actions build and real-device test
- Local validation: Swift parser for all sources; targeted Swift typechecks for orchestrator, MediaTransportSession and AVIO coordinator; plist/YAML/JSON/shell validation; manifest and archive verification.
- Full iPhoneOS typecheck, link, embedded-framework MinimumOS validation and unsigned IPA packaging: pending GitHub Actions.
