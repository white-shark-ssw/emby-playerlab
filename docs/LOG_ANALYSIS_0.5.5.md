# 0.5.4 真机日志分析与 0.5.5 修复

## 已确认的失败链路

1. 连续 Seek 到约 212.86 秒后，AVPlayer 进入 `AVPlayerWaitingToMinimizeStallsReason`。
2. 停滞日志显示当前位置约 213.25 秒，但 `bufferedEnd` 只有 203.13 秒；下载层在真实需求位置起已有 32 MB 连续缓存，主下载仍在运行。
3. 第一次恢复只清理流并调用播放，时间轴没有恢复。
4. 第二次恢复重建 AVPlayerItem，但新播放项立即报告 `Could not connect to the server`，localhost 没有收到新请求。
5. 播放项进入 failed 后，后续 Seek 只能改变目标时间，无法重新获得画面。

## 根因修正

- TransportHTTPServer 原先只用 ObjectIdentifier 管理连接。旧连接取消是异步回调，如果对象地址很快复用，旧回调可能把新连接及其任务从字典中移除并取消。
- 重建 AVPlayerItem 时重复使用完全相同的本地 URL，不能确保 AVFoundation 丢弃旧资产的失败/缓冲状态。
- 停滞恢复没有利用 `bufferedEnd` 明显落后于当前位置这一强信号，导致第一次恢复仍执行无效播放重试。

## 0.5.5 处理

- 连接清理必须同时匹配 ObjectIdentifier 与 NWConnection 实例。
- 每次播放项重建增加新的 `transportRevision` URL 查询参数。
- 本地 HTTP 请求解析会剥离查询参数后再验证媒体路径。
- 时间轴落后时第一次停滞直接重建 AVPlayerItem。
- 重建失败时自动重新建立传输服务器和下载会话，从当前时间恢复，避免播放器永久进入 failed。
- 放宽 115 连接淘汰阈值，避免将 12–20 MB/s 的正常连接替换成更慢线路。
