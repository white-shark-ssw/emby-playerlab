# EmbyPlayerLab 0.8.1（Build 45）

## 目的

针对 0.8.0 真机日志确认的四个回归：63368 第二通道被错误关闭、Seek 后后台顺序缓存长期落后真实播放点、灰色缓冲条肉眼不可见、152901 KTV+FFmpeg 黑屏并在未 ready Seek 后进程重启。

## 主要修改

- `PlaybackRangeMap.nextClaim` 增加 bounded lookahead。最多2条active worker，但允许沿着“已缓存/正在下载”的无空洞链向前保留4个32MiB窗口，让较快的lane持续工作。
- KTV主通道仍先稳定10秒；随后第二通道进入 persistent 模式。取消基于15秒窗口总cacheLength的收益淘汰，因为该指标会被worker空闲、播放器自身KTV请求和cache hit污染。
- 只在播放器真实 `forwardPlayable` 持续接近0时进入 playback-demand priority。后台preloader暂停，真实播放器Range优先；恢复≥0.8秒可播数据后自动恢复连续预取。
- 大MP4启动不再并发执行“0–32MiB后台Range + 文件尾16MiB metadata Range”。改为启动前串行预热8MiB文件头、16MiB尾部metadata，然后再启动连续缓存和KSPlayer。
- metadata尾部Range失败自动重试一次；连续两次失败不再进入长期黑屏KTV+FFmpeg，而是直接使用AVIO兼容路径。
- KTV+FFmpeg创建后，如果8秒仍未ready但已有≥64MiB连续数据，则判定问题不是下载不足，自动进入AVIO兜底。
- KSPlayer未ready时的Seek改为排队最后一个目标，ready后再真正提交，避免native未初始化状态执行seek。
- 115 AVIO兼容路径后台bulk worker由固定1提高到最多2。
- 灰色缓冲条高度6pt、提高对比度，并增加“灰条缓冲至”诊断文字。

## 兼容性

- Deployment Target：iOS 15.0，未提高。
- iPhone 15 Pro Max / iOS 17.0仍为重点真机目标。
- KTVHTTPCache 3.1.0、KSPlayer 2.3.4版本不变。
- NAS不承载媒体字节流。
