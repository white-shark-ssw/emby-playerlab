# 0.5.3 真机日志分析与 0.5.4 修复

## 下载速度

- 初始连接约 5 MB/s，旧逻辑在连接运行 8 秒且低速持续 4 秒后才第一次重建。
- 第一次重建后连接一度达到约 10–15 MB/s，随后再次下降；由于 15 秒冷却，第二次重建较晚。
- 第二次重建后主下载稳定在约 20–35 MB/s，最终单条主 Range 平均约 24.6 MB/s 并完整下载文件。
- 因此问题不是无法获得高速线路，而是启动线路淘汰过慢。

## 连续 Seek 后停滞

- 大部分前期 Seek 首帧仍为约 65–100 ms。
- 停滞发生在约 195 秒处，当时主下载仍约 20–28 MB/s，缓存真实需求附近至少连续 32 MB。
- AVPlayer 报告 `waiting=none`，说明它不是正常的网络等待状态。
- `playImmediately` 和软重 Seek 均未消除停滞；用户再次 Seek 后才恢复，随后在约 225 秒再次停住。
- 这更符合 AVPlayer 在多次 localhost 大 Range 请求后保留旧响应或 demux 状态，而不是上游数据不足。

## 0.5.4 处理

- 启动阶段快速顺序重建低速 115 主连接。
- 每次用户 Seek 先取消旧 localhost 响应，再让 AVPlayer 为新位置重新建 Range。
- 恢复 AVPlayer 自动防停滞等待，避免缓冲瞬间不足直接落入 paused。
- 同一位置第二次停滞时重建 AVPlayerItem，但复用同一个 TransportHTTPServer、DownloadFirstMediaSession 和稀疏缓存。
