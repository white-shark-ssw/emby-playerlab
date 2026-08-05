# EmbyPlayerLab 0.7.1

版本：0.7.1
Build：34
Deployment Target：iOS 15.0

## 修复

- 修复 v0.7.0 引入 `TransportStrategy.ktvHTTP` 后，旧版 `AVPlayerEngine` 中传输策略 `switch` 未穷举，导致 Xcode 编译失败。
- 当诊断模式手动选择旧版本机 HTTP 引擎、全局策略仍为 KTV 时，明确使用 `DownloadFirstMediaSession` 作为兼容会话；正常自动播放仍由 `KTVAVPlayerEngine` 接管。
- 未改变 KTVHTTPCache 持续预取、缓存容量和播放中禁止自动热切换的行为。

## 构建日志结论

- CocoaPods 安装成功。
- KTVHTTPCache 与 CocoaAsyncSocket 均编译成功。
- 唯一阻断错误为 `AVPlayerEngine.swift` 中 `switch must be exhaustive`。
- KTVHTTPCache 的 NSKeyedArchiver 弃用信息只是警告，不会阻断 iOS 15 构建。
