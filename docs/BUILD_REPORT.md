# 构建兼容报告

## 当前基线

- App 版本：0.2.0
- Deployment Target：iOS 15.0
- 目标真机：iPhone 15 Pro Max / iOS 17.0
- CI Runner：macOS 15
- 固定 Xcode：16.4
- Swift Language Mode：5.0
- 播放器：AVPlayer + MPVKit 1.0.0
- MPVKit 产品：MPVKit（LGPL），不链接 MPVKit-GPL
- TrollStore：输出未签名 IPA

## MPVKit 依赖边界

MPVKit 1.0.0 的 Swift Package 声明最低 iOS 15.0。该版本包含 mpv 0.41.0、FFmpeg n8.1.2 及相关二进制依赖。GitHub Actions 会在构建后递归检查 App 内所有 Framework 和 dylib 的 `LC_BUILD_VERSION`。

## 低系统兼容策略

- 导航继续使用 NavigationView。
- 复杂播放手势使用 UIKit UIGestureRecognizer。
- 播放器画面使用 UIViewRepresentable。
- iOS 17 的扩展动态范围属性通过 `if #available` 启用。
- 核心播放器、缓存状态和 Emby 上报不依赖 SwiftUI 生命周期。

## 尚待 CI 验证

当前环境无法运行 Xcode，因此 MPVKit 的完整 Swift 类型检查、链接、Framework 嵌入和 TrollStore 真机启动必须以 GitHub Actions 与用户实机结果为准。若 MPVKit 1.0.0 的任何二进制最低系统版本高于 iOS 15.0，不得直接提升 Deployment Target；先记录具体 Framework 并评估替代构建。
