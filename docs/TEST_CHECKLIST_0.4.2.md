# 0.4.2 真实 Range 调度测试清单

## 构建

1. GitHub Actions 使用 Xcode 16.4 构建 Release arm64。
2. Deployment Target 保持 iOS 15.0。
3. IPA 名称包含 `EmbyPlayerLab-0.4.2`。
4. iPhone 15 Pro Max、iOS 17.0 可覆盖安装。

## 启播与正常播放

1. 设置：传输策略选择“下载优先”。
2. 播放测试媒体 63368。
3. 日志应包含 `adaptiveLaneProbe=true realRangeMigration=true`。
4. 正常情况下活动连接保持 1；文件尾探测、Seek 或候选测速时可短暂为 2。
5. 观察状态栏同时显示“总缓存”和“连续缓存”。
6. 连续播放至少 5 分钟，不应追到缓冲尾部后永久等待。

## 慢连接换线

1. 当主连接 4 秒窗口低于约 2.5 MiB/s，且当前位置连续缓存少于约 24 MiB 时，允许出现 `DownloadFirstLane`。
2. 候选连接没有明显优势时应记录 `keep lane`，主连接不变。
3. 候选明显更快时应记录 `switch slow lane`，随后出现 `reason=slow-lane-switch`。
4. 不应长期维持两个主下载连接。

## Seek 与真实 Range

1. 连续双击 10 次，Seek 本身必须立即响应。
2. `DownloadFirstPriority` 应显示 `migration=await-real-range`。
3. 主连接迁移日志应为 `migrated-real-range`，目标来自实际请求，不是单纯时间比例。
4. 拖动到 50%、80%、95%，检查新画面恢复时间。
5. 未缓存的多个真实缺口应出现 `queued-real-demand`，不应反复取消全部辅助任务。

## 文件尾与 Stall 恢复

1. 跳到约 480 秒并继续播放。
2. 即使主连接先到文件尾，中间仍有缺口时应出现 `main reached end but demand gap remains` 并继续下载。
3. Stall Watchdog 触发时应出现 `DownloadFirstRecovery`。
4. 播放器等待且连续缓存不足时，不应长时间保持 `并发 0`。
5. 再跳到 495 秒和 548 秒，不能因主 cursor 已到 EOF 而立即错误结束。

## 日志验收关键词

- `DownloadFirstMain migrated-real-range`
- `DownloadFirstGap`
- `DownloadFirstRecovery`
- `DownloadFirstLane keep lane`
- `DownloadFirstLane switch slow lane`
- `queued-real-demand`
