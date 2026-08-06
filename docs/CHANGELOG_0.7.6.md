# EmbyPlayerLab 0.7.6（Build 39）

## 修复目标

v0.7.5 中，63368 使用 KTVHTTPCache 双通道后可达到约 10–25 MB/s，部分阶段超过 30 MB/s；152901 在 AVPlayer `Cannot Open` 后回退 KSPlayer/FFmpeg，却离开 KTV 缓存链，改用旧 MediaTransportSession 单后台 worker，平均速度下降到约 6.5 MB/s。

## 变更

- KSPlayer/FFmpeg 在 KTV 传输策略下直接读取 KTV localhost 代理。
- KTVAVPlayerEngine 与 KSAVIOPlayerEngine 支持缓存会话双向移交。
- 启动阶段 `Cannot Open` 回退不再清空 KTV 缓存，也不重新建立115下载链。
- 自动模式中已标记 FFmpeg 优先的媒体从一开始使用 KTV 双通道缓存。
- KTV 大 MP4 首尾预取只执行一次，播放器引擎移交后不会重复等待。
- KSPlayer KTV 路径 10 秒仍未 ready 时，内部降级到旧 AVIO，确保兼容性兜底。
- KTV 第二通道首次瞬时错误先延迟重试一次，连续失败才关闭第二通道。
- Deployment Target 保持 iOS 15.0。

## 预期日志

```text
[KTVCache] handoff AVPlayer -> FFmpeg
[KSKTV] prepared ... transport=KTV-dual-lane
[KTVAdaptive] lane=A ...
[KTVAdaptive] lane=B ...
```

仅当 KTV 代理与 FFmpeg 组合仍无法启动时：

```text
[KSKTV] startup timeout ... fallback transport=AVIO
[KSAVIO] prepared ...
```
