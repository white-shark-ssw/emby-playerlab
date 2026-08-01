# 0.3.3

- 修复 `TransportHTTPServer.swift` Release 编译错误：
  `generic parameter 'T' could not be inferred`。
- 为发送数据的 `withCheckedThrowingContinuation` 显式声明
  `CheckedContinuation<Void, Error>`。
- 当前四项 Sendable 信息仍是 Swift 6 兼容警告，不阻塞 Swift 5 / Xcode 16.4 构建。
- MPVKit 继续固定为 Streamyfin `0.40.0-av`。
- Deployment Target 继续保持 iOS 15.0。
- 版本更新为 0.3.3（18）。
