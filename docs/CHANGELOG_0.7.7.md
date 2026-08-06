# EmbyPlayerLab 0.7.7（Build 40）

## 修复目标

v0.7.6 在 GitHub Actions 的 Swift 主目标编译阶段失败。两个新会话复用表达式把 throwing `KTVCachePlaybackSession` 初始化器放在 nil-coalescing `??` 的右侧，但只给右侧初始化器标了 `try`。Swift 的 `??` 右侧是 `rethrows` 自动闭包，因此整条表达式仍被视为可能抛错。

## 变更

- 修复 `Sources/Player/KTVAVPlayerEngine.swift` 的 KTV 缓存会话创建。
- 修复 `Sources/Player/KSAVIOPlayerEngine.swift` 的 KTV 缓存会话创建。
- 两处都改为明确的 `if let` 复用／创建分支，不再使用 `optional ?? try throwingInitializer()`。
- 扫描全部 Swift 源码，未发现第二处同类表达式。
- KTV 双通道、AVPlayer→FFmpeg缓存会话移交、10秒旧AVIO兜底逻辑不变。
- Deployment Target 保持 iOS 15.0。
