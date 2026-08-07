# EmbyPlayerLab 0.8.1（Build 45）真机测试清单

## 63368

1. 起播后前10秒确认只有lane A。
2. 约10秒后出现 `adjacent dual enabled ... policy=persistent-until-error pipelineDepth=4`。
3. lane B完成一段后应继续领取紧邻下一段，不应因为lane A较慢而长期idle。
4. 正常播放时 `holes=0`；正在下载区间不再计为hole。
5. 快速连续双击后若真实 `forwardPlayable` 持续接近0，应出现一次 `BufferPriority ... pause-background-for-real-demand`；恢复后出现 `resume-contiguous-pipeline`。
6. 重点观察之前中段掉帧区间：掉帧计数是否显著减少；发生掉帧时记录 `BufferTimeline` 和 `BufferPriority`。
7. 灰色缓冲条应肉眼可见，诊断栏同时显示 `灰条缓冲至 xx:xx`。

## 152901

1. 启动顺序应先出现：
   - `startup head preload start`
   - `startup range ... metadata=false ... error=none`
   - `startup tail preload start attempt=1`
   - `startup range ... metadata=true ... error=none`
2. 只有上述预热结束后才出现 `[KSKTV] prepared`。
3. 正常情况下应在8秒保护阈值之前产生非零 `playableTime/position` 和画面。
4. 若tail metadata连续失败两次，应直接看到 `startup metadata fatal ... fallback transport=AVIO`，而不是长时间黑屏。
5. 若KTV连续缓存≥64MiB但FFmpeg仍不ready，应看到 `FFmpeg未ready但已有...MiB连续数据` 后回退AVIO。
6. 黑屏/未ready阶段按一次快进，不应闪退；日志应出现 `seek queued until ready`。
7. AVIO兜底日志应显示 `TransportBulk ... workers=2`（115）。

## 速度

- 不要求固定峰值，但持续播放时第二通道不应因为旧的“12%收益阈值”被主动关闭。
- 比较lane A/B完整32MiB segment的MiB/s及两条通道同时活跃时间占比。
- 重点观察是否仍出现大量 `-192703`；若出现，记录是metadata、A还是B。
