# Build Report

- Version: 0.7.3 (36)
- Deployment Target: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0
- Expected CI: Xcode 16.4, arm64 iPhoneOS Release
- Swift language mode: Swift 5
- KTVHTTPCache: 3.1.0 via CocoaPods; upstream minimum iOS 12.0; MIT
- CocoaAsyncSocket: transitive dependency of KTVHTTPCache
- MPVKit: not linked in 0.7.3; source adapter retained behind compile-time guard
- KSPlayer: 2.3.4
- FFmpegKit: 6.1.4 through KSPlayer
- Automatic standard MP4 path: KTVHTTPCache local iPhone proxy + AVPlayer
- Continuous cache: KTVHCDataLoader with adaptive 16/32/64 MB segmented Range scheduling, Seek reprioritization, and cache-cap/EOF completion
- Runtime automatic engine switching: disabled
- NAS media proxy: prohibited and not used
- Deployment Target changed: no; remains iOS 15.0
- Full iOS 17.0 compatibility claim: pending GitHub Actions build and real-device test
- Local validation: Swift parser for all Swift sources; plist/YAML/Ruby/shell validation; source manifest, patch application and ZIP extraction verification.
- Full Objective-C importer validation, CocoaPods integration, iPhoneOS typecheck/link, embedded-framework MinimumOS validation and unsigned IPA packaging: pending GitHub Actions.



## 0.7.3 传输与画面恢复策略

- KTV 上游速度以缓存文件真实新增字节计算，明确排除 localhost 向 AVPlayer 交付产生的虚高 `observedBitrate`。
- 预取器按 16/32/64 MB 分段试跑，记录当前 CDN 主机的平均速度并持久化优胜分段大小。
- 连续低速或无增长时只重建当前 Range；不会刷新 OneStrm 302，也不会自动更换播放器。
- Seek 后预取游标迁移到目标字节附近，目标播放数据优先，再继续补全文件。
- 视频帧看门狗通过 `AVPlayerItemVideoOutput` 识别“音频继续但画面停止”，恢复顺序固定为同 Item 轻量 Seek、同引擎 Item 重建。
- Runtime automatic engine switching remains disabled.

## 0.7.2 链接策略

KTVHTTPCache 通过 CocoaPods 静态链接时引入 `-ObjC`，会同时拉入 MPVKit 与 KSPlayer/FFmpegKit 内部重复的 FFmpeg、MoltenVK 符号。0.7.2 暂时不链接 MPVKit，只保留 KTV AVPlayer 与 KSPlayer/FFmpeg，避免 513 个重复符号并消除 MPVKit 部分对象最低 iOS 17.5 的警告。
