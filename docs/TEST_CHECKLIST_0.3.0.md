# 0.3.0 真机测试清单

## 安装确认

- 日志开头应显示 `source=0.3.0`。
- 默认播放器应显示 `Transport AVPlayer`，右上角徽标为 `TAV`。
- Deployment Target 仍为 iOS 15.0。

## 63368 连续播放

1. 设置缓存模式为“自动”。
2. 使用默认参数：256 MB 内存、2 GB 磁盘、Wi-Fi 预加载 1024 MB、4 MB 分片、4 路并发。
3. 从 0 秒开始播放 63368，不进行手动 Seek。
4. 确认 18 秒附近是否继续播放。
5. 记录播放页“传输”一行的下载速度和缓存大小。
6. 播放超过 60 秒后进行连续右侧双击。
7. 拖动到 5 分钟附近，再返回 30 秒附近，观察缓存命中率与恢复速度。

## 日志关键字

- `TransportResolve`：应为 range=true，通常 status=206。
- `TransportRange`：观察每个 4 MB 分片耗时和 speedBps。
- `TransportSpeed`：观察平均下载速度是否持续增长。
- `TransportRefresh`：只有临时直链过期时才应出现。
- 不应出现 MPV 的 `paused-for-cache`，除非手动切换到 MPV。

## 设置验证

- 将内存缓存改为 512 MB，重新进入播放页后日志应记录 memory=536870912。
- 将 Wi-Fi 预加载改为 2048 MB，日志应记录 wifiPreload=2147483648。
- 将并发改为 6，日志应记录 concurrent=6。
