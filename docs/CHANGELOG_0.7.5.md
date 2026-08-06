# EmbyPlayerLab 0.7.5（Build 38）

## 双通道持续缓存

- 32 MB Range 保持不变，通道 A 负责播放位置附近，通道 B 在后方独立填充缓存。
- 先采集 10 秒单通道净缓存增长，再试运行 15 秒双通道。
- 双通道总速度至少提高 12% 且无新增失败时保留；收益不足或第二通道失败时自动关闭。
- 第二通道不跟随每次连续 Seek，避免所有高速连接同时被取消。
- 日志新增 `lane=A/B`、`dual trial start`、`dual lane kept/rejected`。

## 大 MP4 打开容错

- MP4 大于 4 GB 或时长超过 1 小时时，在创建 AVPlayerItem 前预取文件头 8 MB 与文件尾 16 MB。
- 预取最多等待 6 秒；完成或超时后再启动 AVPlayer。
- AVPlayer 在 0 秒报 `Cannot Open` 且 KTV 下载链路健康时，标记媒体为 FFmpeg 优先，并从 0 秒受控重启为 KSPlayer/FFmpeg。
- 启动阶段回退与播放中热切换分离；已开始播放后的 Stall 仍不会自动换引擎。

## 兼容性

- Deployment Target 保持 iOS 15.0。
- KTVHTTPCache 3.1.0、KSPlayer 2.3.4 与 FFmpegKit 版本不变。
- MPVKit 仍不链接。
