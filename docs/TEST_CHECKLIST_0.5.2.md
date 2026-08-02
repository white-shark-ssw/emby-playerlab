# 0.5.2 真机测试清单

测试媒体优先使用 item 63368，并保持与 0.5.1 相同的下载优先缓存设置。

1. 启动播放后确认 `[DownloadFirst] ready` 中 `adaptiveLaneProbe=false`，且日志不再出现 `lane=lane-probe`。
2. 启动阶段允许尾部索引 `DownloadFirstSeek`，但不应再出现主线程立即迁移到约 995 MB 的 `migrated-real-range`。
3. 正常播放 20 秒，记录实时速度、主线程速度和平均速度。
4. 连续快速双击前进至少 15 次；每次界面与画面仍应立即响应，主线程只应在停止双击约 1.2 秒后出现一次 `migrated-stable-seek`。
5. 连续双击期间不应出现主线程在相距数百 MB 的位置间连续 `migrated-real-range`。
6. 停止双击后继续播放至少 30 秒，不应再次卡在约 230 秒。
7. 若出现 `[Stall]`，确认紧随其后出现 `[AVPlayerRecovery] play-immediately`；同一点再次停滞应出现 `soft-reseek`，随后播放位置应继续增长。
8. 分别拖动到 35%、65%、90%，记录 Seek 首帧时间和下载速度；每次稳定后主下载应继续向目标后方顺序下载。
9. 日志中不应出现播放期间的 115 `lane-probe ... status=403`。
10. 退出播放器后出现的“下载优先缓存已经关闭”仅允许来自已取消的旧本地响应；若播放中仍出现并伴随画面失败，保留完整日志。
11. 确认 Emby 进度在连续双击、拖动和退出后仍正确保存。
12. 导出完整日志，重点保留 `[DownloadFirstMain]`、`[DownloadFirstNet]`、`[Seek]`、`[Stall]`、`[AVPlayerRecovery]`。
