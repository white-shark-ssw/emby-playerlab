# 0.3.0

## 架构变更

- 停止继续使用 MPV `cache-secs` 和反复 reload 作为 115 STRM 的主要解决方案。
- 新增独立 `Sources/Transport/` 模块，不依赖 SwiftUI 生命周期。
- MP4/MOV/M4V 自动路由到 `Transport AVPlayer`。
- 原生 AVPlayer 与 MPV 继续保留，可在播放页循环切换。

## 302 与 115 传输

- `RedirectResolver` 使用 `bytes=0-0` 探测最终资源、文件大小和 Range 能力。
- 解析 Emby 302 后，在当前播放会话中保存最终直链。
- 跨域重定向时移除 Authorization、Emby Token 与 Cookie；仅保留最终域名自己产生的 Cookie。
- Range 请求使用 `Accept-Encoding: identity`，避免字节位置被内容编码改变。
- 最终地址返回 403/410 时重新请求 PlaybackInfo 和 PlaySessionId。

## 分片缓存

- 默认分片大小 4 MB，可选 1/2/4/8/16 MB。
- 相同分片的并发读取自动合并为一个网络任务。
- 支持关闭、内存、磁盘、自动四种缓存模式。
- 内存缓存使用 LRU 淘汰。
- 磁盘缓存使用稀疏分片文件，并通过 Content-Length、ETag、Last-Modified 校验持久缓存。
- 后台预加载保留一个连接给播放器的即时读取，防止预取阻塞起播和 Seek。

## 自由缓存设置

- 内存缓存：64 MB–2 GB。
- 磁盘缓存：0–50 GB。
- Wi-Fi 预加载：0–8 GB。
- 蜂窝预加载：0–2 GB。
- 并发 Range：1–8。
- 可选择退出后是否保留磁盘缓存。

## 播放与诊断

- `AVAssetResourceLoader` 将自定义 Range 缓存直接提供给 AVPlayer。
- 播放页显示平均下载速度、缓存占用、缓存命中率和活动请求数。
- 日志新增 `TransportResolve`、`TransportRange`、`TransportSpeed`、`TransportRefresh`、`TransportSession`。
- Transport AVPlayer 停滞时不再立即 reload，先让传输层继续补齐分片。

## 兼容性

- Deployment Target 继续保持 iOS 15.0。
- 新增能力只使用 iOS 15 已有的 URLSession、CryptoKit、Network、AVAssetResourceLoader 和 AVPlayer。
- 没有新增第三方依赖。
