# GitHub Build Fix 0.5.1

## 已确认的 v0.5.0 构建状态

- SwiftPM 已成功解析 KSPlayer 2.3.4、FFmpegKit 6.1.4、MPVKit 0.40.0-av。
- Release / iphoneos / arm64 构建使用 `IPHONEOS_DEPLOYMENT_TARGET=15.0`，已进入 EmbyPlayerLab 主 Target 的 Swift 编译。
- 阻塞错误只有 `KSPlayerSparseAVIOContext.swift` 中 `read`、`write` 两个覆写签名不匹配。

## 根因

KSPlayer 2.3.4 的 `AbstractAVIOContext` 定义为：

```swift
open func read(buffer: UnsafePointer<UInt8>?, size: Int32) -> Int32
open func write(buffer: UnsafePointer<UInt8>?, size: Int32) -> Int32
```

v0.5.0 错写为 `UnsafeMutablePointer<UInt8>?` 和 `Int`，因此 Swift 编译器无法识别为覆写。

## 0.5.1 修复

- `read/write` 参数改为 `UnsafePointer<UInt8>?`。
- 返回类型改为 `Int32`。
- `read` 使用 `UnsafeMutablePointer(mutating:)` 为 FFmpeg 已分配的缓冲区创建临时可写视图，再复制下载优先稀疏缓存中的数据。
- EOF 保持返回 FFmpeg `AVERROR_EOF` 数值。
- 不修改 `seek/fileSize/close`，因为这些签名已与 KSPlayer 2.3.4 匹配。

## 本地校验

- 51 个 Swift 文件通过 `swiftc -frontend -parse`。
- 修复后的 AVIO 子类使用 KSPlayer 2.3.4 同签名 Stub 通过 `swiftc -typecheck`。
- `Info.plist`、`project.yml`、GitHub Actions YAML 和 shell 脚本语法通过检查。
- Deployment Target 仍为 iOS 15.0。

## 尚需 GitHub Actions 确认

Linux 环境无法执行 Xcode/iPhoneOS 链接，因此以下结果仍需云端 macOS 构建确认：

- 完整 Swift 类型检查与链接。
- FFmpegKit/MPVKit 二进制嵌入。
- 所有 Framework 的 MinimumOS 检查。
- TrollStore 未签名 IPA 生成。
