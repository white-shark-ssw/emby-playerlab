# 0.2.0

## 播放器

- 固定接入 MPVKit 1.0.0 的 LGPL 产品，Deployment Target 保持 iOS 15.0。
- 新增 MPV 播放引擎，使用 `vo=avfoundation` 和 `AVSampleBufferDisplayLayer` 输出画面。
- 自动路由：MKV/WebM/AVI/FLV/TS/M2TS/WMV 默认使用 MPV，普通 MP4 默认使用 AVPlayer。
- 播放页可即时手动切换 AVPlayer / MPV，并从当前位置继续。
- MPV 启用 VideoToolbox 硬件解码与软件回退。
- MPV 缓存启用 `cache`、`cache-secs`、`demuxer-max-bytes`、`demuxer-max-back-bytes` 和 `demuxer-seekable-cache`。
- MPV Seek 使用快速关键帧模式，并以 `MPV_EVENT_PLAYBACK_RESTART` 测量真实恢复播放耗时。
- AVPlayer 使用 `AVPlayerItemVideoOutput` 观察 Seek 后的新画面，避免把 Seek completion 错当成首帧完成。

## 交互

- 新增全屏横向滑动调整播放进度。
- 只有明显的横向手势才会触发，避免以后与竖向音量/亮度手势冲突。
- 滑动过程中仅更新目标预览，松手后只提交一次 Seek，避免产生连续 Range 请求。
- 双击 Seek 仍然即时执行。
- 连续双击期间合并 Emby 进度上报，播放器操作不等待网络上报。

## 容错与诊断

- 新增播放停滞检测：播放位置和缓冲范围连续约 8 秒不增长时触发恢复。
- AVPlayer 连续停滞会自动切换 MPV。
- AVPlayer 疑似提前结束会自动切换 MPV。
- 日志增加真实媒体标题、引擎、视频/音频编码、停滞恢复和 Seek 测量类型。
- 获取 Emby BaseItem，媒体列表不再把 `MediaSource.Name`（如 2160p）误当成影片标题。

## 构建

- GitHub Actions 固定解析 MPVKit 1.0.0。
- SwiftPM 缓存目录为 `.spm-cache`。
- 构建超时提高到 120 分钟，首次下载 MPVKit 二进制依赖可能较慢。
- 最低系统检查递归扫描 App 内所有 Framework 和 dylib。
