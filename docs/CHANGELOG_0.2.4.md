# 0.2.4

- 修复 MPV 有画面但无声音。
- 根因：错误强制设置 `ao=avfoundation`，而 AVFoundation fork 只提供 `vo_avfoundation`。
- 删除强制音频输出，让 mpv 自动选择已编译的 iOS 音频后端。
- 观察并记录 `current-ao`、`aid` 和 `audio-params`。
- 修复影片中段连续双击快进时进度回弹。
- 连续双击期间保留稳定累计目标，850ms 无新操作后才释放目标锚点。
- MPV 缓冲命中时使用 `absolute+exact`，避免关键帧落点早于请求目标。
- MPV 缓冲未命中时仍使用快速 `absolute+keyframes`。
- 增加 SeekAnchor 和 MPVSeekRequest 诊断日志。
- Deployment Target 继续保持 iOS 15.0。
