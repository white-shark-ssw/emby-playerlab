# 构建兼容报告

## 当前基线

- App 版本：0.1.0
- Deployment Target：iOS 15.0
- 目标真机：iPhone 15 Pro Max / iOS 17.0
- CI Runner：`macos-15`
- 固定 Xcode：16.4
- Swift Language Mode：5.9
- 当前嵌入第三方 Framework：无
- 当前播放器：AVPlayer
- TrollStore：输出未签名 IPA

## MPVKit 预研结论

当前 `mpvkit/MPVKit` 的 `Package.swift` 声明：

- Swift tools 5.9
- iOS 15.0
- macOS 12
- tvOS 15
- 提供 LGPL 与 GPL 产品

下一阶段只考虑 LGPL 产品，并固定 release/commit。接入前必须在 CI 中检查所有 XCFramework 的 `LC_BUILD_VERSION`。

## 低系统降级

当前功能只使用 iOS 15 可用 API。没有为了 SwiftUI 导航或手势便利使用 iOS 16/17 专属 API：

- 导航使用 `NavigationView`
- 双击位置识别使用 UIKit `UITapGestureRecognizer`
- 分享使用 `UIActivityViewController`
- 播放器承载使用 `UIViewRepresentable` + `AVPlayerLayer`

## 未验证项

当前环境无法实际运行 Xcode，因此首个 GitHub Actions 结果仍是最终编译依据。若 CI 出错，应优先修复工程和 API 使用，不得直接提升 Deployment Target。
