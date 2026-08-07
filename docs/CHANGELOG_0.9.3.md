# EmbyPlayerLab 0.9.3 (Build 49)

## 63368 / 真正当前位置优先
- 0.9.2 真机日志在约 358.25 秒出现长时间停滞：`forwardPlayable=0`，但 `networkBps` 仍约 8~12 MB/s、全局连续缓存数百 MiB。说明滚动总带宽并不能代表当前位置供数能力。
- 用户 Seek 后，AVAssetResourceLoader 可能先发出数百 MiB 的 speculative Range。0.9.3 对这种大型 Range 只记录候选，不立即消费 `pendingUserSeek`；等待真实 `blocked-read` / byte-offset 后才重锚。
- 非 metadata 的 concrete blocked-read 若与旧 anchor 相距超过 4 个 16 MiB block，会主动 `blocked-demand reanchor`，防止后台双槽继续追旧位置。
- urgentPlayback 窗口由 2 MiB 扩为 8 MiB，仍流式写入；减少连续 2 MiB 网络请求不断重建临时 URLSession 的首包成本。
- Stall 决策新增当前位置 `forwardPlayable` 判断：当前位置低于 0.5 秒时，即使后台总速度和全局缓存看似健康，也会调用同一 AVPlayer/MPV 的 transport recovery，而不是只显示橙色提示原地等待。
- UnifiedTransport 记录最近 concrete playback demand，Stall 时可重新把 anchor/urgent 优先级拉回播放器真实等待字节。

## 152901 / 两次慢起播
- 第一次：`Player Start 16:56:22.042`，约 `16:56:37.602` 才出现 position>0，约 15.6 秒。首个 4 MiB 约 3.08 秒，尾部约 10.18 MiB metadata 约 8.42 秒；主要是 115/CDN 当前连接异常慢，不是 MPV Metal 初始化失败。
- 第二次：首个 4 MiB 约 3.59 秒；尾部 metadata 首个 1 MiB 等约 3.5 秒，到用户约 29.5 秒后退出时只收到约 7 MiB，始终没有 `file-loaded`，因此确实没有进入可播放状态。
- 大型 MP4 首个 sequential header 由 4 MiB 再降到 1 MiB，仅影响 >=4 GiB MP4 的启动首块；普通 63368 仍保持 4 MiB 起步，后续都回到 16 MiB 双槽。
- startup metadata 首块若 >=1.5 秒且低于 1 MiB/s，只允许一次 `refresh-115-source-and-resume`：保留已到 ByteStore 的数据，重新经过 302 获取直链后从剩余 offset 继续，避免单条极慢 CDN 连接拖到几十秒。

## 进度条
- 历史灰、实时灰区段由 `Rectangle` 改为 `Capsule`，两端圆润，不再出现尖锐矩形角。
- 底轨仍为 Capsule，播放进度与 thumb 逻辑不变；真实未验证的大空洞仍保持断开。

## 兼容性
- Deployment Target 仍为 iOS 15.0。
- iPhone 15 Pro Max / iOS 17.0 仍为重点真机目标。
- 不增加 NAS 媒体中转；媒体数据仍为客户端 -> 302 -> 115/CDN。
