# Build Report

- Version: 0.5.2 (26)
- Deployment Target: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0
- Expected CI: Xcode 16.4, arm64 iPhoneOS Release
- MPVKit: 0.40.0-av
- KSPlayer: 2.3.4
- FFmpegKit: 6.1.4 (through KSPlayer)
- KSPlayer declared minimum iOS: 13.0
- Local validation: all Swift sources parsed successfully; plist/YAML/JSON and shell syntax checked.
- v0.5.2 source changes are based on the 2026-08-02 item 63368 transport log: 115 lane probe disabled, stable-Seek main migration, metadata-probe isolation and AVPlayer soft stall recovery.
- Full iPhoneOS typecheck, link, embedded-framework MinimumOS validation and unsigned IPA packaging: pending GitHub Actions.
