# EmbyPlayerLab 0.8.0（Build 44）

## 缓存架构

- 新增 `PlaybackRangeMap`，以真实字节 Range 表示后台预取已经交付的数据。
- playback data 与 MP4 metadata 分离；metadata 不推进播放连续前沿。
- 双worker只允许领取相邻的32 MiB Range。前方hole未完成时，不允许第二通道继续向远端制造新的稀疏区间。
- 第二通道仍先经过单通道基线与双通道试验；失败时退回单通道并由主通道修补最早hole。
- 删除KTV后台预取的时间→字节比例Seek定位。播放器Seek不受影响，仍然立即执行。
- `BufferMap` 日志新增 scheduler anchor、frontier、playback bytes、metadata bytes、holes、KTV公开cache zone数量以及两条lane的实际Range。

## 152901 / 大 MP4

- KSPlayer/FFmpeg通过KTV代理启动时不再使用固定10秒超时。
- 只有后台Range全部停止、累计至少3次失败，并且至少12秒完全无进展时，才允许最终AVIO兜底。
- 大MP4文件尾16 MiB预加载被明确分类为metadata，和正常playback Range分离。
- 保留KSPlayer尚未ready时忽略0秒`.finished`的提前EOF保护。

## 播放器UI

- 新增iOS 15兼容的 `BufferedTimelineSlider`。
- AVPlayer灰色缓冲段来自 `AVPlayerItem.loadedTimeRanges`；不连续range会分段显示。
- KSPlayer灰色缓冲段来自 `currentPlaybackTime...playableTime`。
- 诊断行显示当前位置真实前向可播时间和buffered range数量。

## 已知边界

- KTVHTTPCache 3.1.0公开API可以提供缓存项总长度/总缓存长度并公开cache item zones，但0.8.0尚未依赖未确认字段解析完整zones。
- KTV localhost实际播放器Range demand尚未接入，因此后台scheduler anchor在0.8.0保持0，并明确记录 `demandAnchor=unavailable`。
- 这意味着Seek到远处后，播放器本身会通过KTV请求目标Range，但主动后台顺序预取不会使用时间比例猜测并跳到目标；真实demand re-anchor留到下一阶段。
- 未宣称0.8.0已经解决全部带宽波动，真机重点验证的是“无后台永久hole、缓冲条语义真实、152901不再固定10秒重建传输链”。

## 兼容性

- Deployment Target保持iOS 15.0。
- iPhone 15 Pro Max / iOS 17.0继续作为重点真机目标。
- NAS仍不承载任何媒体字节。
- 已建立播放后的自动引擎热切换仍然关闭。
