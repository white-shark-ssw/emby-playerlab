# EmbyPlayerLab 0.5.1

- 修复 GitHub Actions 中 `KSPlayerSparseAVIOContext` 的两个阻塞编译错误。
- `read(buffer:size:)` 与 `write(buffer:size:)` 现在严格匹配 KSPlayer 2.3.4 的 `AbstractAVIOContext`：`UnsafePointer<UInt8>?` + `Int32`。
- `read` 将 FFmpeg 提供的缓冲区临时转换为可写视图后复制稀疏缓存数据，返回实际读取字节数。
- 保留 KSPlayer 2.3.4、FFmpegKit 6.1.4、MPVKit 0.40.0-av。
- Deployment Target 保持 iOS 15.0，目标设备仍为 iPhone 15 Pro Max / iOS 17.0。
- 版本号更新为 0.5.1，Build 25。
