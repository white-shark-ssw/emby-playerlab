# EmbyPlayerLab v0.11.3 真机测试清单

- 确认日志 `source=0.11.3`，Build 57，Deployment Target 仍为 iOS 15.0。
- 63368 正常持续播放：观察 `UnifiedLaneHealth`。只有某 Lane 连续明显慢于健康 peer 时才应出现 `action=rotate-slow-lane`，整网都慢时不应反复 reset。
- 63368 下载速度：`networkBps` 不应再因 urgent/metadata 被 6 倍放大；与完整 Range `speedBps` 的量级应一致。
- 152901 冷启动：应出现 `critical-tail-metadata ... action=primary-lane` 与 `critical metadata queued on primary`。
- 152901 冷启动：文件尾约 10 MiB 索引应由 Slot 0 `role=metadata` 读取；Slot 1 的顺序预取应尽量继续。
- 152901 若尾索引首 MiB 仍 >1.5s 且 <1 MiB/s，应出现 `slow-start metadata ... refresh-115-source-and-resume`。
- 152901 首帧：重点比较 Player Start -> `file-loaded`、Player Start -> position > 0 的耗时，不应再出现缓存头部 100+ MB 仍等待慢尾索引约 11 秒的旧模式。
- 152901 播放后：应出现 MPV `[BufferHistory]`；灰色缓冲条应能看到 MPV 实际 demuxer cache 的历史范围。
- 首帧前若主动拖到片尾：不得误进 `critical-tail-metadata`，应按真实用户 Seek 处理。
- 连续双击快进/快退：仍保持即时响应，不因 Lane Health 重建正在使用的 foreground 连接。
