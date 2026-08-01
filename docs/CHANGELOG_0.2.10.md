# 0.2.10

- v0.2.9 已能从 18.5 秒恢复并继续到 30.3 秒，坏交错 MP4 模式确认部分有效。
- 修复兼容重载后停滞计数未清零，导致下一次双击被误判成再次停滞。
- 兼容模式 Seek 改为两阶段：立即发送普通 Seek；2.5 秒内未收到 PLAYBACK_RESTART 才执行同 handle 的 loadfile replace 兜底。
- 普通 Seek 成功时不会增加重载开销。
- MPV 不再根据提前出现的 time-pos 判定 Seek 完成；只有 PLAYBACK_RESTART 才释放目标。
- 非零 startPosition 的 loadfile replace 建立 PendingSeek，恢复时记录真实落点。
- 增加 MPVSeekFallback 日志。
- 设置 demuxer-termination-timeout=2，减少旧远程连接被强制截断。
- 当前版本 0.2.10（14），Deployment Target 继续保持 iOS 15.0。
