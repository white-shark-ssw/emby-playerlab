# EmbyPlayerLab 0.7.8（Build 41）

## 日志确认的回归

- 63368 在后台双通道仍有总下载时，AVPlayer 当前播放点的 `bufferedEnd` 只领先约 0.1 秒并连续 Stall。旧代码把“目标字节位于正在下载的 32 MB 段内”直接视为覆盖，即使该字节尚未实际下载。
- 一次重复播放使用了空 ItemId，生成 `/Videos//stream`，随后出现 404、`KTVHTTPCache error -192703` 和无限快速重试。
- 152901 完成头部 8 MB、尾部 16 MB预取后，`finishLargeMP4Warmup` 误清空播放器准备回调，因此没有出现 `KTVPlayer open warmup ready`，AVPlayer也没有真正开始打开，启动回退无法触发。

## 修复

- 大 MP4 预取完成后保留所有 `prepareForPlayback` 回调，再统一交付给 AVPlayer 或 KSPlayer。
- Seek覆盖判断改为 `segmentStart ..< segmentStart + loaded`，只认可实际已下载字节。
- 当前播放缓冲不足或 Stall 时暂停 lane A/B 约3秒，让播放器真实 localhost Range 请求优先；恢复后继续原缓存游标和已确认的双通道。
- 慢连接只有低于播放消耗并持续12秒才重建，重建冷却增加到20秒。
- lane A连续错误最多自动重试三次，避免空URL、404或临时错误导致无限连接风暴。
- 播放源使用已加载媒体的真实 `BaseItem.id`，不再使用可能被清空或修改的输入框字符串。
- Deployment Target保持iOS 15.0。
