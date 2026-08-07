# Build Report

- Version: 0.7.10 (43)
- Deployment Target: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0
- Expected CI: Xcode 16.4, arm64 iPhoneOS Release
- Swift language mode: Swift 5
- KTVHTTPCache: 3.1.0 via CocoaPods; upstream minimum iOS 12.0; MIT
- CocoaAsyncSocket: transitive dependency of KTVHTTPCache
- MPVKit: not linked in 0.7.10; source adapter retained behind compile-time guard
- KSPlayer: 2.3.4
- FFmpegKit: 6.1.4 through KSPlayer
- Automatic standard MP4 path: KTVHTTPCache local iPhone proxy + AVPlayer; MP4 files at least 4 GiB and 1 hour use the same KTV proxy + KSPlayer/FFmpeg from startup; stored compatibility items use the same FFmpeg path
- Continuous cache: two persistent 32 MB Range lanes on Wi-Fi/KTV, lane B starts after 750 ms, primary-lane Seek reprioritization remains coalesced at 750 ms, confirmed foreground starvation pauses only lane B for about 1.25 seconds, and cache-cap/EOF completion remains enabled
- Runtime automatic engine switching: disabled
- NAS media proxy: prohibited and not used
- Deployment Target changed: no; remains iOS 15.0
- Full iOS 17.0 compatibility claim: pending GitHub Actions build and real-device test
- Local validation: Swift parser for all Swift sources; plist/YAML/Ruby/shell validation; source manifest, patch application and ZIP extraction verification.
- Full Objective-C importer validation, CocoaPods integration, iPhoneOS typecheck/link, embedded-framework MinimumOS validation and unsigned IPA packaging: pending GitHub Actions.



## 0.7.10 持续双通道与大 MP4 直启兼容引擎

- 真机日志确认 v0.7.8 的 lane A 单通道可达约 11–16 MB/s，lane B 可达约 8–15 MB/s；但快速 Seek 触发的 foreground priority 会同时关闭两条通道并重置双通道试跑，因此多数会话无法持续维持总带宽。
- KTV 会话现在直接进入 persistent-2 模式：lane A 立即启动，lane B 在 750 ms 后启动，不再等待 10 秒单通道基线和 15 秒试跑。
- transient buffering 不立即让路；只有低前向缓存持续至少 800 ms 或正式 Stall 才触发 foreground priority。
- foreground priority 只暂停 lane B 约 1.25 秒，lane A 保持工作；正式 Stall 时 lane A 立即对准当前播放字节。
- lane B 连续错误不再永久禁用，按 8–30 秒退避恢复。
- 自动模式下，KTV 环境中大于等于 4 GiB且时长不少于 1 小时的 MP4 直接选择 KSPlayer/FFmpeg；KSPlayer 创建 KTV 会话时跳过 AVPlayer 专用首尾 warmup。
- Runtime automatic engine switching during established playback remains disabled.


## 0.7.8 播放优先与大 MP4 回归修复

- 修复 `finishLargeMP4Warmup` 在执行准备完成回调前清空 `playbackPreparationCallbacks` 的错误；大 MP4 现在能够真正创建 AVPlayerItem，并在 `Cannot Open` 时进入受控 FFmpeg 回退。
- `laneContainsOffsetLocked` 只计算当前 loader 已经实际交付的字节，不再用完整 `segmentEnd` 误判 Seek 目标已覆盖。
- AVPlayer 当前读取发生 Stall/低前向缓冲时，KTV 后台 lane A/B 暂停约 3 秒，优先让 localhost 代理服务播放器真实 Range，然后恢复后台预取。
- 慢连接重建阈值改为低于实际播放消耗才触发，确认时间与冷却时间延长；主通道连续失败最多自动重试三次。
- `PlaybackLabViewModel` 使用已加载 `BaseItem.id` 生成播放 URL，避免输入框为空时生成 `/Videos//stream`。



## 0.7.7 Swift throwing 表达式编译修复

- 修复 `KTVAVPlayerEngine.swift:28` 与 `KSAVIOPlayerEngine.swift:140` 的 `operator can throw but expression is not marked with try`。
- 原因是 throwing 初始化器位于 nil-coalescing `??` 的右侧自动闭包中，Swift 要求整条 `??` 表达式显式 `try`。
- 改为明确的 `if let` 会话复用分支，保留同一 KTVCachePlaybackSession 的交接语义。
- KTVHTTPCache、KSPlayer、FFmpegKit 已进入主目标 Swift 编译阶段；本次日志未显示第三方依赖或链接错误。


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
