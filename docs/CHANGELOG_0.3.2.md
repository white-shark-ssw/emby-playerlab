# 0.3.2

- TAV 主入口由 AVAssetResourceLoader 自定义 Scheme 改为本机 HTTP Range 服务。
- 使用 Network.framework 在 127.0.0.1 随机端口提供 HTTP 200/206、HEAD 和 Range。
- AVPlayer 直接读取本地 HTTP URL，可自行请求 MP4 文件头、文件尾和任意字节区间。
- 修复异步 ResourceLoader 请求未强引用 loadingRequest 的问题；该旧路径仅保留诊断用途。
- 解析 115 最终直链后立即并发预取文件头，并同时预取最后一个分片。
- 默认 Range 分片由 4 MB 调整为 1 MB，降低起播首包延迟。
- 停止传输会话前先记录真实缓存和吞吐指标，不再总是显示 Zero KB。
- TAV 长时间等待时不再自动切回已确认会音频欠载、卡顿和音画不同步的 MPV。
- Info.plist 增加 NSAllowsLocalNetworking，仅用于 127.0.0.1 播放入口。
- Deployment Target 继续保持 iOS 15.0。
- 版本更新为 0.3.2（17）。
