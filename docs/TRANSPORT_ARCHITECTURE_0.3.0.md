# Transport / AVIO 架构基线

## 当前 0.3.0 数据路径

```text
Emby PlaybackInfo
  → Emby stream URL
  → RedirectResolver（302）
  → 115 最终直链
  → RangeHTTPClient（并发 HTTP 206）
  → MediaTransportSession
      ├─ 请求去重
      ├─ 内存 LRU
      ├─ 稀疏磁盘分片
      ├─ Wi-Fi/蜂窝预加载
      └─ 403/410 刷新 PlaybackInfo
  → AVAssetResourceLoader
  → AVPlayer
```

## 安全边界

- Emby `api_key` 和 PlaySessionId 只存在于 Emby 入口 URL。
- 跳转到其他 Origin 时移除 Authorization、X-Emby-Token、X-MediaBrowser-Token 和原域 Cookie。
- 最终 CDN 自己设置的 Cookie 可以在当前传输会话内复用。
- 日志只记录 Range 数值、状态码、长度和速度，不记录最终签名 URL。

## 预加载策略

- 播放器需求读取优先。
- 配置 4 路并发时，后台预加载最多使用 3 路，至少保留 1 路处理起播和 Seek。
- 每次 AVPlayer 实际请求不少于 64 KB 时，才启动前向预加载，避免 MP4 尾部元数据探测触发无意义下载。
- Seek 到远距离后会取消旧预加载窗口并从新位置建立窗口。

## 下一阶段

- 在真机验证 115 Range 吞吐、63368 连续播放和 Seek 后恢复。
- 根据日志决定是否增加多窗口预加载（音轨/视频轨分离窗口）。
- 为 FFmpeg 建立同一 `MediaTransportSession` 的 AVIO read/seek 桥接。
- 对系统可解码媒体增加本地 fMP4 HLS Remux 路线。
