# 0.1.0

- 建立 iOS 15.0 原生 SwiftUI 播放器实验室。
- 加入 Emby 登录、PlaybackInfo、AVPlayer、立即双击 Seek、缓冲显示和进度上报。
- 连续双击使用独立 pending target，避免旧播放位置回调覆盖累计目标。
- 提前 EOF 自动恢复限制为两次，防止无限循环。
- 过滤媒体请求中的 Emby Authorization、Token 和 Cookie 请求头。
- 加入 macOS 15 / Xcode 16.4 未签名 IPA 工作流。
