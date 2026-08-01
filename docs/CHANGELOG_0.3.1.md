# 0.3.1

- 修复 Xcode 16.4 真机构建错误：`await cannot appear to the right of a non-assignment operator`。
- `MediaTransportSession.metrics()` 改为先等待 `diskCache.size()`，再计算缓存总量。
- `TransportResourceLoader` 的 `NSLock` 操作移入同步辅助方法，消除异步上下文锁警告。
- AVPlayer 初始 Seek 改用带 completionHandler 的 API。
- MPVKit 继续固定为 Streamyfin `0.40.0-av`。
- Deployment Target 继续保持 iOS 15.0。
- 版本更新为 0.3.1（16）。
