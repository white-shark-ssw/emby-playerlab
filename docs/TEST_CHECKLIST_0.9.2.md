# v0.9.2 真机测试清单

## 63368 / 进度条
- [ ] 正常播放 5~30 秒期间，灰色前向缓冲在控制栏显示时肉眼可见。
- [ ] `[BufferHistory]` 在未 Seek 时保持从 0 秒开始的连续区间。
- [ ] 连续跳播后允许出现真正未验证的空白区间；<=1 秒的小抖动孔不应被画成明显断裂。
- [ ] 回退到 0 秒后，如果 `forwardPlayable >= 1.5s` 且 `waiting=none`，不出现 Stall/“正在补充数据”提示。
- [ ] +10/-10 Seek 首帧延迟继续记录，确保 ResourceLoader 路径没有回退。

## 152901 / 起播
- [ ] `[UnifiedSlot] slot=0` 首个 sequential Range 应为约 4 MiB。
- [ ] MPV 首次跳到文件尾时，metadata urgent Range 应一次覆盖剩余尾部索引（最多 16 MiB），不再连续串行 2 MiB。
- [ ] 出现 `[UnifiedSlot] ... first-chunk role=metadata`，证明尾部数据边下边进入 ByteStore。
- [ ] 记录 `Player Start -> file-loaded -> position>0` 三段耗时；目标是相较 0.9.1 的约 10 秒明显下降。
- [ ] 起播阶段不出现误导性的 Stall 恢复橙色提示。
- [ ] 远距离拖动后 `UnifiedAnchor real-demand reanchor` 跟随 MPV 真实 byte seek，随后 sequential 从新 anchor 向后增长。

## 吞吐
- [ ] 后台 sequential 仍是 16 MiB 双 Slot，观察 10~20+ MiB/s 快块是否继续存在。
- [ ] 重点区分“完整块实际速度”与 UI 6 秒滚动 `networkBps`，不要把滚动指标下降等同于连接停止。

## 兼容性
- [ ] Deployment Target = iOS 15.0。
- [ ] iPhone 15 Pro Max / iOS 17.0 可安装运行。
- [ ] 媒体数据仍为客户端 -> 302 -> 115/CDN，不经过 NAS 中转。
