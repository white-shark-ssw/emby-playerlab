# 0.2.6

- 修复 MPV 把 Seek 请求目标提前写入 `snapshot.position`，造成日志和 UI 假装已经到达目标的问题。
- Seek 完成后读取真实 `time-pos`，记录 `target / actual / delta`。
- MPV 恢复 `hr-seek=no`，继续优先关键帧快速跳转。
- MPV 停滞恢复不再复用同一个实例和旧缓存。
- 恢复时重新请求 Emby PlaybackInfo，获取新的 PlaySessionId 和播放入口。
- 停止旧 MPV、创建新 MPV 实例、从新的目标位置重新打开媒体，强制重新走 302 链路。
- 第一次停滞刷新链路并前移 2 秒；重复卡在同一点时前移 20 秒跨过异常区域。
- MPV 已停滞时，用户向前双击或拖动进度会触发硬恢复，并在目标基础上增加 5 秒安全距离。
- MPV 提前 EOF 也改为刷新播放会话和重建引擎，不再对旧 URL 原地 reload。
- 修复运行日志版本一直显示 1.0：增加 MARKETING_VERSION/CURRENT_PROJECT_VERSION。
- Deployment Target 继续保持 iOS 15.0。
