# 0.9.0 真机日志分析与 0.9.1 修复依据

分析日志：`EmbyPlayerLab-1786114033.log`。

## 63368：不是带宽不足，而是 AVPlayer 消费层失速

- 自动路径为 `AVPlayer + UnifiedTransport`，但实际仍经过本机 `TransportHTTPServer`。
- 前段 Seek 可在约 79–716 ms 出新画面；后段多次变成约 1.83–3.15 秒，并出现 `AV 首帧等待超时`。
- 慢 Seek / Stall 时统一下载器多次被判断为 `transportHealthy=true`，当前连续缓存达到约 128–352 MiB，实时下载仍可处于约 7–12 MiB/s。
- 与此同时 AVPlayer 的 `forwardPlayable` 多次只剩约 0.09–0.10 秒，并持续 `AVPlayerWaitingToMinimizeStallsReason`。
- 因此本轮的主瓶颈不是 115 总吞吐，而是 localhost Range / AVFoundation demux 消费状态没有及时把已经存在的 ByteStore 数据转化成可播放帧。

历史 0.6.0 ResourceLoader 真机基线曾完整播放 609.934 秒、AccessLog 0 Stall / 0 dropped，并记录 45 次 Seek、中位新画面约 83 ms。0.9.1 因此重新让自动原生媒体直接通过 `AVAssetResourceLoader` 消费同一个统一 ByteStore，去掉 localhost HTTP 中间层。

另外，0.9.0 的 `noteDemand` 在真实 Range 已完全缓存时会提前返回，导致 Seek 虽然命中缓存，`pendingUserSeek` 却没有机会消费，后台 `playbackAnchor` 可能继续停留在旧位置。0.9.1 改为先接受真实需求并重锚，再决定是否需要新网络读取。

## 152901：黑屏根因明确

日志显示：

- `MPVStream` 已成功打开 5.88 GB 资源并完成大量头尾/播放字节读取；
- AudioUnit 成功建立，`current-ao=audiounit`，48 kHz 立体声音频参数正常；
- 播放位置持续推进，普通 +10 秒 MPV Seek 多数约 46–67 ms；
- 但出现 `Video output avfoundation not found` 与 `Error opening/initializing the selected video_out`。

因此“有声音、黑屏”不是 302、Range、缓存或解封装失败，而是 0.9.0 指定了当前 MPVKit 构建不存在的 `vo=avfoundation`。0.9.1 改为 MPVKit iOS Metal 路径：`CAMetalLayer + gpu-next + Vulkan/MoltenVK + VideoToolbox`。

## 灰色缓冲条

0.9.0 历史层实现本身使用时间范围并集，没有主动删除逻辑，但视觉层只有白色 28% 透明度、7pt 高；底轨为 13%，实时层又覆盖其上，因此在黑色渐变背景中非常不明显，实时层缩短时也容易被误认为历史缓存回退。

0.9.1：

- 底轨 9pt；
- 历史层提高到 68% 对比度；
- 当前实时层提高到 92%；
- 新增 `[BufferHistory] verifiedRanges=...` 日志。

历史层仍坚持使用播放器实际验证的时间缓冲，不按 `cachedBytes / fileSize` 伪造时间进度。
