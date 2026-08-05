# EmbyPlayerLab 0.7.3（Build 36）

## KTV 自适应分段预取

- 不再创建覆盖整部媒体的一条巨大 Range 请求。
- 持续预取改为 16 MB、32 MB、64 MB 分段请求。
- 首轮按段记录真实新增缓存字节和完成耗时，并为当前 CDN 主机保存表现最好的分段大小。
- 每秒继续采样上游缓存增长；连续低于播放需求或长期无新增数据时，等待确认后从当前字节游标重建连接并轮换 Range 大小。
- 普通低速不会刷新 OneStrm 302，也不会更换播放引擎。
- 用户 Seek 时立即取消旧预取，把下载窗口迁移到目标时间对应字节位置；目标附近优先，随后继续向文件末尾预取。
- 缓存预算大于文件体积时仍会自然缓存完整文件；预算不足时以设置的磁盘缓存上限为目标。
- 下载速度只使用 KTV 缓存新增字节计算，不再把 localhost → AVPlayer 的 `observedBitrate` 当作 115 下载速度。

## 视频轨冻结检测

- `AVPlayerItemVideoOutput` 现在持续检测实际新视频帧，而不是只在 Seek 后测量首帧。
- 当播放时钟和音频继续推进、播放器状态为 playing，但 2.5 秒以上没有新 PixelBuffer 时，记录 `[VideoFreeze]`。
- 第一次检测到冻结：在同一 AVPlayerItem 内对当前位置执行轻量 Seek 并立即恢复。
- 冻结仍未恢复：重建同一个 AVPlayerItem，继续复用 KTV 已缓存数据。
- 整个过程不自动切换到 KSPlayer、MPV 或其他引擎。

## 兼容性

- Deployment Target 保持 iOS 15.0。
- KTVHTTPCache 3.1.0、KSPlayer 2.3.4 和 FFmpegKit 版本不变。
- MPVKit 仍不链接，避免与 KSPlayer/FFmpegKit 重复符号。
