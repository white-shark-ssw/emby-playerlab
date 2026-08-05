# Build Report

- Version: 0.7.2 (35)
- Deployment Target: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0
- Expected CI: Xcode 16.4, arm64 iPhoneOS Release
- Swift language mode: Swift 5
- KTVHTTPCache: 3.1.0 via CocoaPods; upstream minimum iOS 12.0; MIT
- CocoaAsyncSocket: transitive dependency of KTVHTTPCache
- MPVKit: not linked in 0.7.2; source adapter retained behind compile-time guard
- KSPlayer: 2.3.4
- FFmpegKit: 6.1.4 through KSPlayer
- Automatic standard MP4 path: KTVHTTPCache local iPhone proxy + AVPlayer
- Continuous cache: KTVHCDataLoader, from byte zero to cache cap or EOF
- Runtime automatic engine switching: disabled
- NAS media proxy: prohibited and not used
- Deployment Target changed: no; remains iOS 15.0
- Full iOS 17.0 compatibility claim: pending GitHub Actions build and real-device test
- Local validation: Swift parser for all Swift sources; plist/YAML/Ruby/shell validation; source manifest, patch application and ZIP extraction verification.
- Full Objective-C importer validation, CocoaPods integration, iPhoneOS typecheck/link, embedded-framework MinimumOS validation and unsigned IPA packaging: pending GitHub Actions.


## 0.7.2 链接策略

KTVHTTPCache 通过 CocoaPods 静态链接时引入 `-ObjC`，会同时拉入 MPVKit 与 KSPlayer/FFmpegKit 内部重复的 FFmpeg、MoltenVK 符号。0.7.2 暂时不链接 MPVKit，只保留 KTV AVPlayer 与 KSPlayer/FFmpeg，避免 513 个重复符号并消除 MPVKit 部分对象最低 iOS 17.5 的警告。
