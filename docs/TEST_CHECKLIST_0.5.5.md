# 0.5.5 真机测试清单

测试设备：iPhone 15 Pro Max / iOS 17.0
测试媒体：Item 63368，传输层 AVPlayer，自动缓存模式。

## A. 连续 Seek 与中途停滞

1. 正常播放 20 秒后连续右侧双击 15–25 次。
2. 停止操作后至少等待 30 秒，不手动按播放、不再次 Seek。
3. 若出现 `Stall` 且 `bufferedEnd` 落后当前位置，应在第一次恢复直接看到 `AVPlayerRecovery rebind-item`。
4. `rebind-item` 后必须出现新的 localhost Range 请求，且 URL revision 增长。
5. 播放位置应重新持续增长，不应出现 `itemStatus=2` 后永久停止。

## B. 连接竞态验证

1. 日志中允许出现旧连接取消，但新连接建立后不能立刻被旧回调清除。
2. `rebind-item` 后若仍发生 item failed，应出现 `AVPlayerRecovery item-failure-reload`。
3. fallback reload 后应重新出现 `TransportHTTP ready`、`TransportResolve` 和当前位置附近的 Range 请求。
4. 15 秒内不得重复无限重载。

## C. 下载速度

1. 记录起播后 10、20、30、60 秒主连接速度。
2. 12–14 MB/s 的短暂下降不应立即触发重连。
3. 只有持续低于新阈值时才应出现 `reconnect-slow-115`。
4. 重连后若速度更低，不应连续快速触发重连风暴。

## D. 暂停与结束

1. 用户主动暂停后 Seek 仍应保持暂停。
2. 正常播放状态 Seek 后应自动继续播放。
3. 接近结尾 Seek 不应被误判为中途停滞或提前 EOF。
