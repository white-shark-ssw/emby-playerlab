# EmbyPlayerLab 0.7.10（Build 43）

## 修复

- 回退 v0.7.9 过早启动 persistent lane B 的策略。真机日志显示该策略使 KTV `-192703` 明显增加，并将 lane A/B 中位速度降至约 5.6/2.0 MB/s。
- 恢复 v0.7.5 已验证的 staged adaptive 双通道：主通道独占基线窗口后再启动 lane B。
- lane B 只有在试验窗口内总缓存净增长明显提升且没有失败时才保留；失败后本场不再恢复，避免持续干扰主连接。
- 删除播放器低前向缓存时主动暂停 lane B 的调用；Stall 仅确保预取任务仍然活跃。
- KSPlayer 在 `isReadyToPlay == false` 时不再把 `.finished` 上报为真正 EOF，修复 152901 的 0 秒假 EOF / 重复 prepare。

## 保留

- 大 MP4 自动模式直接 KTV + KSPlayer/FFmpeg。
- 32 MiB 分段、连续 Seek 750ms 合并、真实已加载区间判断。
- 主通道连续失败最多重试三次。
- iOS Deployment Target 15.0。
