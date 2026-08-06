# EmbyPlayerLab 0.7.9（Build 42）

## 本轮日志结论

- 63368 首次播放的完整 lane A 分段约 6.4–10.0 MB/s；后段 lane B 达到约 9.2–15.2 MB/s，但 v0.7.8 的 foreground priority 在快速 Seek 后同时关闭 lane A/B 三秒，且恢复时经常从旧顺序游标继续，双通道无法稳定保留。
- 63368 重播时大量 32 MB Range 已经缓存，只补充几十 KB到数 MB缺口；日志中的几百 KB/s主要是混合缓存补缺口速度，不代表115整条连接上限。
- 152901 已经成功从 AVPlayer `Cannot Open` 回退到 KTV＋KSPlayer/FFmpeg，播放位置推进并完成两次快速 Seek；主要问题是首次仍等待大 MP4 warmup和AVPlayer失败流程。

## 修复

- KTV 从 adaptive-1x2 改为 persistent-2：lane A立即启动，lane B在750 ms后直接启动。
- 去除正常会话的10秒单通道基线和15秒双通道试跑等待。
- 快速 Seek只迁移lane A到最终目标；lane B保持远端带宽填充。
- 低前向缓冲持续不足800 ms不再触发后台暂停；确认持续缓冲或Stall时只暂停lane B约1.25秒。
- 正式Stall时lane A立即对准当前播放字节，恢复时不再从旧顺序游标重新开始。
- lane B连续错误按失败次数退避后恢复，不再永久退出。
- 自动模式下，大于等于4 GiB且不少于1小时的MP4直接走KTV＋KSPlayer/FFmpeg。
- KSPlayer直接创建的KTV会话跳过AVPlayer专用首尾warmup。
- 混合缓存段日志增加`mixedCache=true`。
- Deployment Target保持iOS 15.0。
