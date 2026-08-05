# EmbyPlayerLab 0.6.0

版本：0.6.0
Build：30
Deployment Target：iOS 15.0

## 自动播放编排

- 新增 `PlaybackOrchestrator`。
- 普通播放默认隐藏手动引擎选择和播放页切换按钮。
- MP4/MOV/M4V 且编码适合系统原生解码时，默认进入“智能 AVPlayer”。
- 其他容器默认进入 KSPlayer FFmpeg。
- 自动降级顺序固定为：智能 AVPlayer → KSPlayer FFmpeg → MPV。
- 自动降级为单向过程，同一播放会话不会在引擎之间来回振荡。
- 引擎切换保留用户播放/暂停意图和当前位置。

## 移除自动路径 localhost

- 新自动路径不再启动 `TransportHTTPServer`。
- AVPlayer 改用 `AVAssetResourceLoaderDelegate` 和自定义 `embytransport://` URL。
- 旧 localhost TAV 继续保留在源码中，仅用于诊断和回归对照。
- ResourceLoader 请求采用 256 KB 交付块，并记录接收、取消和失败日志。
- 请求表增加 UUID 代次校验，旧异步回调不能删除地址复用后的新请求。

## 共享传输会话

- 新增 `PlaybackTransportContext`。
- 智能 AVPlayer 与 KSPlayer FFmpeg 共用一个 `MediaTransportSession`。
- 共用同一份 302 解析结果、115 临时直链、内存缓存、磁盘缓存和需求窗口。
- 自动切换到 FFmpeg 时不停止共享传输会话，不重新下载已经缓存的数据。
- 只有退出播放页时才停止共享会话。
- MPV 暂未接入共享 IO，仍作为最终网络容错路径。

## 按需播放窗口

- 在线播放不再以完整文件下载为目标。
- Wi-Fi 窗口限制在 32–128 MB，默认 128 MB。
- 蜂窝窗口限制在 16–64 MB，默认 64 MB。
- 115 连续预取只使用一个后台 worker，稳定阶段使用 64 MB 长 Range，减少短请求和连接慢启动。
- Seek 会取消旧窗口的预取任务，并以新位置重新建立窗口。
- 当前需求位置的连续缓存单独计入 `contiguousCacheBytes`。
- 文件尾部小范围 MP4 元数据探测不会移动主播放需求位置或启动尾部预取窗口。

## 自动故障分类

- 根据媒体大小/时长估算平均供数需求。
- 当前有效速度或连续缓存不足时，只恢复传输窗口，不切换引擎。
- 数据充足但智能 AVPlayer 连续停滞两次时，自动切换 KSPlayer FFmpeg。
- KSPlayer 连续停滞或准备失败时，自动切换 MPV。
- 疑似提前 EOF 使用同一条自动降级链。
- AVPlayer 记录 access log 的停滞数、丢帧数和 observed bitrate。

## 兼容性

- Deployment Target 继续保持 iOS 15.0。
- 没有使用要求 iOS 17.1 或 iOS 18 的 API。
- KSPlayer 仍固定 2.3.4。
- MPVKit 仍固定 0.40.0-av。
