# 构建兼容报告

## 当前基线

- App 版本：0.3.5（20）
- Deployment Target：iOS 15.0
- 目标真机：iPhone 15 Pro Max / iOS 17.0
- CI Runner：macOS 15
- 固定 Xcode：16.4
- Swift Language Mode：5.0
- 播放器：Transport AVPlayer + 原生 AVPlayer + Streamyfin MPVKit AV 0.40.0-av
- TrollStore：输出未签名 IPA

## 0.3.x 系统能力

- Foundation URLSession：302、HTTP Range、独立连接并发与流式 DataTask 回调。
- Network.framework 本机 HTTP 206 服务：把自定义字节缓存提供给 AVPlayer。
- CryptoKit SHA256：生成稳定且不暴露媒体信息的磁盘缓存目录名。
- Network NWPathMonitor：区分 Wi-Fi 与蜂窝预加载上限。

以上 API 均可在 iOS 15.0 使用，没有提高 Deployment Target。

## 第三方依赖

- 继续固定 `https://github.com/streamyfin/MPVKit.git` 版本 `0.40.0-av`。
- 0.3.5 Transport 模块没有新增第三方依赖。
- MPVKit 产品仍为 `MPVKit-GPL`，当前用途限定为用户个人自用。

## CI 必须验证

- 使用 iOS 15.0 Deployment Target 完整编译。
- 检查所有嵌入 Framework 的 LC_BUILD_VERSION。
- 确认 `URLSession.data(for:delegate:)`、URLSessionDataDelegate 流式回调、CryptoKit 和 Network 链接成功。
- 生成 TrollStore 未签名 IPA。

## 当前环境验证结果

- 所有 Swift 源文件已通过 `swiftc -parse`。
- project.yml 与 GitHub Actions YAML 已通过语法解析。
- 当前环境没有 Xcode/iPhoneOS SDK，完整类型检查、链接和真机行为必须以 GitHub Actions 与 iPhone 测试为准。
