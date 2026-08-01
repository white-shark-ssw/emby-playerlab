# 0.2.8

- 重新分析最早 MPV 可越过异常区域与后续版本的差异。
- 关键差异：最早版本音频输出失败；启用 AudioUnit 后，异常 MP4 才稳定停止顺序读取。
- 根据 FFmpeg MOV/MP4 demuxer 文档新增“坏交错 MP4 兼容读取”。
- 首次 MPV 停滞时设置 `demuxer-lavf-o=interleaved_read=0`。
- 兼容模式设置 `demuxer-seekable-cache=no`，强制远程 Seek 进入底层 Range 链路。
- 兼容模式设置 `cache-pause=no`，避免仅因缓存量很少而永久暂停。
- 兼容模式不销毁 libmpv；在同一个 MPV handle 中执行 `stop` 和 `loadfile replace`。
- 每次兼容重载前重新请求 Emby PlaybackInfo，刷新 PlaySessionId 和 302 播放链路。
- 删除自动 30/60 秒 `drop-buffers` 连跳逻辑。
- 普通媒体恢复 `demuxer-seekable-cache=auto`，不再强制为 yes。
- 增加 seekable、partially-seekable、demuxer-via-network、demuxer-cache-idle 日志。
- Info.plist 使用明确版本值 0.2.8（12），避免运行日志继续显示 1.0。
- Deployment Target 继续保持 iOS 15.0。
