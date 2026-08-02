# 0.5.4 真机测试清单

测试设备：iPhone 15 Pro Max / iOS 17.0
测试媒体：Item 63368，传输层 AVPlayer，自动缓存模式。

## A. 起播速度

1. 完全关闭播放器后重新进入同一媒体。
2. 记录起播后 5、10、20、30、60 秒的实时和主连接速度。
3. 初始连接低于约 10 MB/s 时，日志应更早出现 `reconnect-slow-115 ... mode=startup`。
4. 前两次启动重建之间不应再固定等待 15 秒。
5. 重建必须从当前游标继续，不从 0 重新下载。

## B. 连续 Seek

1. 正常播放 10 秒后连续右侧双击 15–20 次。
2. 每次 Seek 日志附近应出现 `TransportHTTP reset streams ... reason=user-seek`。
3. 旧 Range 被取消后，新位置应自动重新请求并继续播放，无需点击播放。
4. 再拖动到 50%、80% 和接近结尾位置，确认都能自动续播。

## C. 停滞自愈

1. 连续播放并快速 Seek，出现停住时不要人工操作。
2. 第一次恢复应出现 `AVPlayerRecovery reset-streams-and-play`。
3. 同一位置仍停住时应出现 `AVPlayerState` 和 `AVPlayerRecovery rebind-item`。
4. `rebind-item` 后应重新出现 localhost Range 请求，播放位置继续增长。
5. 确认没有重新登录、重新获取 PlaybackInfo、重新解析 302 或清空已下载缓存。

## D. 暂停语义

1. 手动暂停后执行双击和拖动，确认仍保持暂停。
2. 正常播放状态下 Seek，确认自动续播。
3. 检查日志中不应出现无休止的 item rebind；同一位置重建有 2.5 秒节流。
