# EmbyPlayerLab 0.7.5 测试清单

## 构建

- `Validate Source` 使用 iOS 15.0 编译成功。
- `Build Unsigned IPA` 生成 0.7.5 Build 38。
- 最终链接保留 KTVHTTPCache、KSPlayer/FFmpegKit，不链接 MPVKit。

## 双通道下载

1. 清空 Item `63368` 缓存并正常播放，不进行 Seek 至少 30 秒。
2. 日志先出现 `lane=A`，约 10 秒后出现 `dual trial start` 与 `lane=B`。
3. 约 15 秒后应出现 `dual lane kept` 或 `dual lane rejected`。
4. `kept` 时播放页并发数应为 2；`rejected` 后应回到 1。
5. 通道 B Range 必须位于通道 A 后方，不应与通道 A 完全重叠。
6. 连续双击时通道 A 可在停手后迁移一次；通道 B 不应随每次双击被取消。
7. 第二通道出现 403、超时或其他失败时，应立即记录 `dual lane stopped` 并回到单通道。
8. 比较单通道基线、双通道试跑和最终稳定速度，确认是否更接近宽带上限。

## 大 MP4 / Item 152901

1. 自动模式播放 Item `152901`。
2. 日志应先出现 `[KTVOpenWarmup] begin`，随后分别记录 `head`、`tail` Range。
3. `finished reason=complete` 或 `timeout` 后才出现 `open warmup ready` 与 AVPlayer 准备。
4. 若 AVPlayer 成功打开，应从 0 秒正常播放，不发生引擎回退。
5. 若仍报 `Cannot Open`，日志应出现 `[StartupFallback] armed/check`。
6. 当缓存已新增至少 16 MB、总缓存至少 32 MB，或活动下载速度超过 2 MB/s 时，应标记该 Item 并从 0 秒启动 KSPlayer/FFmpeg。
7. 回退发生时不得保留旧 AVPlayer 回调，不得闪退，不得从非零位置热切换。
8. 关闭后再次自动播放 152901，应直接选择 KSPlayer/FFmpeg。

## 回归

- Item `63368` 连续双击、远距离拖动和视频冻结看门狗行为不退化。
- 普通 MP4 不等待首尾预取；仅大文件或超长 MP4 启用该流程。
- NAS 不承载媒体字节，仍保持 OneStrm 302 后由 iPhone 直连 115 CDN。
