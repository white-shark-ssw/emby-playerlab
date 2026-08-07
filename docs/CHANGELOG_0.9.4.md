# EmbyPlayerLab 0.9.4 (Build 50)

## 当前播放位置供数
- sequential 16 MiB 调度块改为 4 MiB 渐进写入 ByteStore，保留双通道与大块调度，但不再整块完成后才对播放器可见。
- blocked-read / MPV byte-offset 命中 Slot 0 sequential 时直接提升为 streaming urgent。
- urgentPlayback 窗口 8 MiB -> 16 MiB；首个 1 MiB 仍流式写入。
- partial sequential 被取消时保留已经写入的范围，不丢失有效缓存。
- 修正 bytesDownloaded 重复累计。

## MPV Metal / 144799
- SwiftUI Surface 不再主动设置 drawableSize；由 MoltenVK/Metal swapchain 管理。
- 每次布局重置 layer transform/anchor/bounds/position，避免历史几何状态残留。
- Surface 作为 CAMetalLayer delegate，detach 时清理；视图开启 clipsToBounds。
- EDR 状态更新与 MPVKit 官方 MetalLayer 一致，非主线程请求同步切回主线程。
- 增加 `video-rotate=no`。
- 新增 MPVSurface / MPVVideoState 日志。

## 兼容
- Deployment Target 保持 iOS 15.0。
- iPhone 15 Pro Max / iOS 17.0 仍为重点真机。
- 媒体数据不经过 NAS。
