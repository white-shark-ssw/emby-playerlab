# Build Report

- Version: 0.5.3 (27)
- Deployment Target: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0
- Expected CI: Xcode 16.4, arm64 iPhoneOS Release
- MPVKit: 0.40.0-av
- KSPlayer: 2.3.4
- FFmpegKit: 6.1.4 (through KSPlayer)
- KSPlayer declared minimum iOS: 13.0
- Local validation: all Swift sources parsed successfully; plist/YAML/JSON and shell syntax checked.
- v0.5.3 source changes are based on the second 2026-08-02 item 63368 transport log: persistent playback intent across AVPlayer Seek, faster transport-stall recovery and single-connection 115 slow-lane reconnect without adding a third probe connection.
- Full iPhoneOS typecheck, link, embedded-framework MinimumOS validation and unsigned IPA packaging: pending GitHub Actions.
