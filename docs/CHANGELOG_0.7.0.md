# EmbyPlayerLab 0.7.0

版本：0.7.0
Build：33
Deployment Target：iOS 15.0

## KTVHTTPCache 实验路径

- 固定引入 KTVHTTPCache 3.1.0。
- 标准 MP4/MOV/M4V 自动路由到 `KTV 缓存 AVPlayer`。
- KTV 本地代理仅运行在 iPhone 内部，媒体仍由 115/CDN 直接下载到 iPhone，NAS 不参与视频中转。
- 增加持续预取任务；在磁盘预算允许时从文件起点持续缓存到文件结尾。
- 缓存预算大于视频体积时，自然形成完整文件缓存；预算较小时由 KTV 的缓存淘汰策略管理。
- 增加 KTV 缓存总量、预取速度、任务状态和完整文件状态日志。
- 缓存清理入口同时清除 KTV 缓存。

## 稳定性策略

- 关闭播放过程中的自动引擎热切换。
- Stall 只等待缓存、重启当前预取或恢复同一引擎。
- 引擎错误不再自动创建另一套播放器。
- 疑似提前 EOF 保持当前引擎重载，不再沿 AVPlayer → FFmpeg → MPV 自动降级。

## 构建

- 增加 CocoaPods 1.16.2 构建步骤。
- GitHub Actions 使用 `.xcworkspace` 构建。
- Podfile 固定 KTVHTTPCache 3.1.0，并统一所有 Pod 的最低系统为 iOS 15.0。
- 构建失败 Artifact 增加 `pods-install.log`。

## 已知限制

- 本版先测试 KTVHTTPCache 默认连接行为，不包含自适应 Range 大小或单双连接选优。
- KTV 缓存尚未接入 KSPlayer/FFmpeg。
- 完整 iPhoneOS 编译、链接和真机表现仍需 GitHub Actions 与 iPhone 验证。
