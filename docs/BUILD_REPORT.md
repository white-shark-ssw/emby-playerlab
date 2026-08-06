# Build Report

- Version: 0.7.6 (39)
- Deployment Target: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0
- Expected CI: Xcode 16.4, arm64 iPhoneOS Release
- Swift language mode: Swift 5
- KTVHTTPCache: 3.1.0 via CocoaPods; upstream minimum iOS 12.0; MIT
- CocoaAsyncSocket: transitive dependency of KTVHTTPCache
- MPVKit: not linked in 0.7.6; source adapter retained behind compile-time guard
- KSPlayer: 2.3.4
- FFmpegKit: 6.1.4 through KSPlayer
- Automatic standard MP4 path: KTVHTTPCache local iPhone proxy + AVPlayer; compatibility path: the same KTV proxy + KSPlayer/FFmpeg
- Continuous cache: fixed 32 MB segmented Range scheduling with 10-second single-lane baseline, 15-second dual-lane trial, 750 ms coalesced primary-lane Seek reprioritization, and cache-cap/EOF completion
- Runtime automatic engine switching: disabled
- NAS media proxy: prohibited and not used
- Deployment Target changed: no; remains iOS 15.0
- Full iOS 17.0 compatibility claim: pending GitHub Actions build and real-device test
- Local validation: Swift parser for all Swift sources; plist/YAML/Ruby/shell validation; source manifest, patch application and ZIP extraction verification.
- Full Objective-C importer validation, CocoaPods integration, iPhoneOS typecheck/link, embedded-framework MinimumOS validation and unsigned IPA packaging: pending GitHub Actions.



## 0.7.6 统一高速传输

- KTV AVPlayer 与 KSPlayer/FFmpeg 共享同一 KTVCachePlaybackSession。
- 启动阶段回退会移交现有缓存会话，避免旧 AVIO 单 worker 导致的速度下降。
- 已标记 FFmpeg 优先的媒体直接使用 KTV 双通道，不再创建旧 PlaybackTransportContext。
- KTV＋FFmpeg 10 秒仍未 ready 时才内部降级旧 AVIO。
- 第二通道首次瞬时错误会重试一次。

## 0.7.5 双通道与启动容错

- 通道 A 负责播放附近，通道 B 在后方下载；双通道净缓存增长至少提高 12% 且无新增失败才保留。
- 大于 4 GB 或超过 1 小时的 MP4 在 AVPlayer 打开前预取头部 8 MB 与尾部 16 MB。
- AVPlayer 在 0 秒 `Cannot Open` 且传输健康时，完整关闭 KTV AVPlayer 后从 0 秒启动 KSPlayer/FFmpeg。
- 已开始播放后的 Runtime automatic engine switching remains disabled.

## 0.7.4 稳定化策略

- 固定 32 MB 分段，慢连接同尺寸重建，避免 64 MB Range 在弱连接中继续拖慢。
- 缓存命中与真实新增缓存分离；当前外部速度仍是“缓存有效增长估算”，新增 CDN 探针用于比较不同时段的最终 Host 和解析延迟。
- 连续 Seek 合并为一次后台预取迁移。
- Seek 期间暂停视频冻结检测；累计两次确认冻结的 Item 在下次自动播放时预选 KSPlayer/FFmpeg。
- Runtime automatic engine switching remains disabled.

## 0.7.3 传输与画面恢复策略

- KTV 上游速度以缓存文件真实新增字节计算，明确排除 localhost 向 AVPlayer 交付产生的虚高 `observedBitrate`。
- 预取器按 16/32/64 MB 分段试跑，记录当前 CDN 主机的平均速度并持久化优胜分段大小。
- 连续低速或无增长时只重建当前 Range；不会刷新 OneStrm 302，也不会自动更换播放器。
- Seek 后预取游标迁移到目标字节附近，目标播放数据优先，再继续补全文件。
- 视频帧看门狗通过 `AVPlayerItemVideoOutput` 识别“音频继续但画面停止”，恢复顺序固定为同 Item 轻量 Seek、同引擎 Item 重建。
- Runtime automatic engine switching remains disabled.

## 0.7.2 链接策略

KTVHTTPCache 通过 CocoaPods 静态链接时引入 `-ObjC`，会同时拉入 MPVKit 与 KSPlayer/FFmpegKit 内部重复的 FFmpeg、MoltenVK 符号。0.7.2 暂时不链接 MPVKit，只保留 KTV AVPlayer 与 KSPlayer/FFmpeg，避免 513 个重复符号并消除 MPVKit 部分对象最低 iOS 17.5 的警告。
