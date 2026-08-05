# 0.6.2 真机测试清单

测试设备：iPhone 15 Pro Max / iOS 17.0

## 连续两次播放

- [ ] 日志开头为 `source=0.6.2`。
- [ ] 第一次播放完成或主动关闭。
- [ ] 退出播放页后再次播放同一媒体。
- [ ] 第二次播放至少持续到 420 秒。
- [ ] 不出现异常退出。

## 自动切换

- [ ] 若发生连续 Stall，日志依次出现 `Switch requested`、`consumer quiesce`、`Switch prepare called`。
- [ ] 新引擎启动后出现 `Switch first snapshot`。
- [ ] 切换期间不会重复触发第二次自动切换。
- [ ] KSPlayer 接管后播放位置与原位置接近。

## 崩溃资料

若仍闪退：

- [ ] 重新打开 App 后立即导出日志，检查 `[CrashBreadcrumb]`。
- [ ] 导出同一时间的 `EmbyPlayerLab-*.ips`。
- [ ] 若没有 App ips，导出 `JetsamEvent-*.ips`。
