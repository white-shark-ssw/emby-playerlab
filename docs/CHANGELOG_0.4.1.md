# 0.4.1

- 根据 0.4.0 115AVIO 真机实验，将 MP4 默认传输策略切换为下载优先。
- 新增 `DownloadFirstMediaSession`：正常播放仅保持一条顺序主下载连接。
- 新增 `DownloadFirstSparseStore`：使用稀疏文件、精确区间索引、`pread/pwrite` 边写边读。
- 新增 `DownloadFirstStreamLoader`：大 Range 数据流每 256 KB 立即写入本地文件。
- AVPlayer 本机 HTTP 读取优先等待主下载数据；只有远距离未缓存请求才临时创建辅助连接。
- 用户 Seek 立即执行；主下载连接延迟约 0.9 秒迁移，避免连续双击反复取消连接。
- 403/410 使用 single-flight PlaybackInfo 刷新。
- 旧版 `MediaTransportSession` 多 Range 模式保留为设置页回退选项。
- 清理缓存时同时清除旧传输缓存和下载优先缓存。
- Deployment Target 保持 iOS 15.0。
- 版本更新为 0.4.1（22）。
