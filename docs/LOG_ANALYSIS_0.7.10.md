# 0.7.9 真机日志分析 → 0.7.10 调度修正

测试日志：`EmbyPlayerLab-1786090566.log`

## 结论

0.7.9 的 persistent lane B 启动过早。63368 和 152901 都在播放建立初期同时启动 KTV lane A、lane B 与播放器自身的 localhost 请求，随后出现 KTV `-192703`、lane B 长时间低速，以及 lane A 被连带拖慢。

与此前 0.7.5 真机日志比较：

- 0.7.5 / 63368：lane A 中位约 13.9 MB/s、lane B 中位约 17.2 MB/s，峰值约 24 / 25.6 MB/s。
- 0.7.9 / 63368：lane A 中位约 5.6 MB/s、lane B 中位约 2.0 MB/s，并出现多次 `-192703`。
- 0.7.9 / 152901：lane B 首个 32 MiB 段约 0.85 MB/s；lane A 连续发生多次 `-192703`。

因此 0.7.10 恢复 0.7.5 已验证的 staged adaptive 策略：先单 lane A 建立稳定连接，再试 lane B；lane B 只有在总吞吐实际提升且没有错误时才保留。

## 152901

0.7.9 已经能够直接选择 KTV + KSPlayer/FFmpeg，但 KSPlayer 尚未 ready 时 `playbackState == .finished` 会被当成真正 EOF，上报 0 秒提前结束并触发重复 prepare。0.7.10 仅在 `isReadyToPlay` 后才接受 `.finished` 为 EOF。
