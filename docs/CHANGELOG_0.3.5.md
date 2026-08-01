# 0.3.5

- 根据 0.3.4 真机日志，将 115 后台预加载从大量 1 MB 短 Range 改为持续大 Range。
- 本地缓存分片与上游下载块解耦：本地默认 1 MB，上游默认 16 MB。
- 前四轮使用 4 MB 暖机块，先建立约 48 MB 连续缓冲，再使用用户设置的大块。
- 每个后台 worker 使用独立 URLSession 下载上下文；大 Range 收到数据时即时拆分写入缓存。
- 后台 worker 下载相邻区间，按轮次连续推进缓存前沿。
- 播放请求命中正在下载的大块时等待对应 1 MB 分片落地，不重复发起相同 Range。
- 共享 115 Cookie 存储，保留同一会话内 CDN 返回的 Cookie 更新。
- DiagnosticsLogger 改为批量写盘，TransportHTTP 对 64 KB 小请求进行采样。
- 设置页新增“115 持续预取块”：4/8/16/32/64 MB。
- Deployment Target 继续保持 iOS 15.0。
- 版本更新为 0.3.5（20）。
