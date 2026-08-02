# EmbyPlayerLab 0.5.2

- 根据 item 63368 的两次真机播放日志修复下载优先传输层。
- 115 CDN 不再启动第三条自适应测速连接，避免主下载与 Seek 下载并行时额外探测触发 403 或占用线路。
- AVPlayer 启动阶段的文件尾部小范围索引请求只走紧急读取，不再把主下载线程错误迁移到文件末尾。
- 连续双击或拖动时，主下载线程不再追逐每一个 AVPlayer 历史 Range；紧急通道立即服务当前 Seek，主通道只在最后一次 Seek 稳定 1.2 秒后迁移到后续区域。
- 实际 Range 驱动的主线程迁移增加 4 秒 Seek 保护期、10 秒位置相关性检查和 2 秒迁移冷却，减少 100 MB、350 MB、138 MB、756 MB 等位置之间的反复重连。
- 主下载到达范围末端后优先处理最新阻塞需求，不再选择最小的旧字节位置。
- 传输层 AVPlayer 关闭 `automaticallyWaitsToMinimizeStalling`，缓存有数据时优先立即播放。
- 停滞恢复增加两级处理：第一次直接 `playImmediately`，同一位置再次停滞时执行 0.05 秒软重 Seek，避免本地缓存充足但 AVPlayer 一直等待。
- 最近 Seek 目标之外的旧 localhost Range 不再占用紧急下载；等待 5 秒仍未命中的旧请求会主动取消。
- 新增 `[AVPlayerRecovery]`、`migrated-stable-seek` 与 `TransportHTTP server=` 日志，便于确认恢复、主线程迁移以及旧服务残留响应。
- Deployment Target 保持 iOS 15.0；KSPlayer 2.3.4、FFmpegKit 6.1.4、MPVKit 0.40.0-av 保持不变。
- 版本号更新为 0.5.2，Build 26。
