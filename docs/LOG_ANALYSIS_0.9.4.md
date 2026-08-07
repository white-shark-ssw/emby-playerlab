# v0.9.3 真机日志分析 → v0.9.4 修复

## 63368：橙色缓冲与聚合速度无关

本轮最早在 2.138 秒就发生 Stall。Slot 1 已经能跑约 7~12 MB/s，但播放器真正等待的 Slot 0 `4 MiB..20 MiB` sequential Range 用了约 11.5 秒、约 1.46 MB/s。v0.9.3 的 sequential Range 只有完整下载后才一次性写入 ByteStore，所以聚合速度很高时当前位置仍可能完全没有新增可读字节。

中段 154~155 秒附近再次复现：8 MiB urgent 很快完成，但紧接着所需区域落在 Slot 1 的 16 MiB sequential claim 中；该 claim 约 10.5 秒才完整结束。AVPlayer 在此期间 `forwardPlayable=0`，多次出现 Stall。

结论：不是单纯 AVPlayer 解码慢，也不是 Seek byte anchor 总是错误；更根本的问题是“关键字节落在未渐进提交的后台大块里”。

## 152901：Seek 请求快，第一帧被旧 sequential read 阻塞

缓存命中的 +10 Seek 仍能维持几十毫秒。超出缓存后，MPVSeekRequest 与真正 `MPVStream seek byte=...` 之间会出现数秒空档；这段时间 Slot 0 正在完成旧的 16 MiB sequential Range。旧 read callback 不返回，libmpv demuxer 就不能进入下一次 byte seek。

多次远距离 Seek 出现约 3~11 秒级恢复时间，与 sequential 16 MiB 慢块完成时刻高度一致。因此这一轮主要修“供数可见性”，而不是继续换 MPV seek 参数。

## 144799：HEVC/MKV 画面后续偏到左下角

144799 使用 MPV + gpu-next + Vulkan/MoltenVK + VideoToolbox。日志中没有记录当时 CAMetalLayer frame/drawableSize，也没有 video-out-params，因此旧日志无法证明具体是哪一个尺寸值发生漂移。

当前 Surface 在每次 `layoutSubviews` 都主动用 UIKit bounds 计算并设置 `CAMetalLayer.drawableSize`，这与 MPVKit 官方 iOS Metal demo 只更新 layer frame 的方式不同；MoltenVK 自己也管理 swapchain/drawable。v0.9.4 移除 UI 层对 drawableSize 的强制写入，并增加几何诊断。
