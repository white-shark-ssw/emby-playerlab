# 0.5.0 真机测试清单

1. 在设置中选择“强制 KSPlayer AVIO（实验）”。
2. 使用 item 63368，确认日志出现 `[KSAVIO] prepared`，且不出现 `[TransportHTTP] ready`。
3. 记录点击播放到首帧时间和前 10 秒实时速度。
4. 连续播放经过此前约 250 秒卡点。
5. 双击连续快进，确认日志出现 `[KSAVIOSeek]` 和 `migrated-exact-avio`。
6. 拖动到 50%、80%、95%，记录恢复时间。
7. 确认下载完成后播放仍可继续，不出现“总缓存已满但首帧超时”。
8. 导出 GitHub Actions 编译日志和真机诊断日志。
