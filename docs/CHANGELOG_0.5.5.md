# EmbyPlayerLab 0.5.5

版本：0.5.5
Build：29
Deployment Target：iOS 15.0

## 真机日志结论

- v0.5.4 在约 213 秒处检测到 `bufferedEnd=203.133`、`bufferEmpty=true`，但下载层从真实需求位置起已有 32 MB 连续缓存，说明 AVPlayer 的时间轴/播放项状态已经落后于本地缓存。
- 第二次停滞触发 `rebind-item` 后，新 AVPlayerItem 在约 27 ms 内报告 `Could not connect to the server`，且 localhost 服务没有记录到新的 Range 请求。
- 旧连接取消回调可能在连接对象地址复用后误删新连接；同时重建播放项继续使用完全相同的 URL，AVFoundation 可能沿用旧资源状态。
- v0.5.4 的启动线路筛选还会把瞬时 12–14 MB/s 的可用连接替换掉，后续连接反而可能跌到约 4 MB/s。

## 修复

- localhost 连接和响应任务清理增加实例匹配，旧 NWConnection 的异步取消回调只能移除它自己，不能再清理同一 ObjectIdentifier 下的新连接。
- AVPlayerItem 重建使用带 `transportRevision` 查询参数的新资产 URL，强制 AVFoundation 创建新的资源读取上下文；本地 HTTP 服务会忽略查询参数并继续校验原路径。
- 重建时重启 localhost listener，保留下载会话与稀疏缓存，同时换用新端口和新资产 URL。
- 当 `loadedTimeRanges` 明显落后于当前位置时，第一次停滞直接重建播放项，不再浪费一轮 `play()` 重试。
- 如果重建播放项仍失败，自动重建完整传输会话并从当前位置恢复；15 秒内最多触发一次，避免循环重载。
- 115 主连接启动期阈值改为约 8–12 MB/s，稳定期改为约 6–10 MB/s，不再仅因低于历史峰值就更换仍可用的连接。

## 保持不变

- 双击和拖动 Seek 仍立即提交。
- 主下载最多 1 条，紧急 Seek 下载最多 1 条。
- KSPlayer 2.3.4、FFmpegKit 6.1.4、MPVKit 0.40.0-av 不变。
- Deployment Target 继续为 iOS 15.0。
