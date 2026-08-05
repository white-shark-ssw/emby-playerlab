# KTVHTTPCache 第三方依赖说明

- 项目：KTVHTTPCache
- 固定版本：3.1.0
- 上游：ChangbaDevs/KTVHTTPCache
- 许可证：MIT
- 上游声明最低 iOS：12.0
- 本项目 Deployment Target：iOS 15.0
- 安装方式：CocoaPods
- 间接依赖：CocoaAsyncSocket

本项目使用其本地 HTTP 代理、Range 缓存、KTVHCDataLoader 预加载、缓存容量管理和完整文件查询接口。

本地代理只在 iPhone 内运行。它不会将媒体数据送到 NAS，也不会改变 OneStrm 返回 302 后由 iPhone 直接连接 115/CDN 的网络拓扑。

为降低敏感信息风险，本项目默认关闭 KTVHTTPCache 的文件日志，不在 App 日志中记录完整 localhost 代理 URL 或完整临时直链。
