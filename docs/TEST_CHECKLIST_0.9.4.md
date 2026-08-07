# v0.9.4 真机测试清单

## 63368
- 起播阶段若当前位置读到 Slot 0 sequential 未完成区域，应看到 `promote slot0 sequential->urgent`，随后约首个 1 MiB 到达即可恢复，不应再等完整 16 MiB。
- sequential 日志应出现 `first-chunk role=sequential` 与 `progressive=true`；单个 16 MiB claim 内会看到最多 4 个 4 MiB TransportRange。
- 连续 +10 / 远距离拖动后橙色 Stall 次数应明显下降；若出现，记录 `forwardPlayable`、当前 urgent claim 与两个 Slot。

## 152901
- 缓存内 +10 继续保持几十~数百毫秒。
- 缓存外快速连续 +10 时，不应因为旧 16 MiB sequential 整块未完成而让 `MPVStream seek` 延迟数秒。
- 重点记录 `MPVSeekRequest -> MPVStream seek -> first-chunk urgent -> MPVSeekLanding`。

## 144799
- 起播后持续播放、显示/隐藏控制栏、连续 Seek，观察画面是否仍向左下角偏移。
- 日志应有 `[MPVSurface] view=... layer=... drawable=...`；view/layer 几何不得异常变成小尺寸或产生偏移。
- `[MPVVideoState]` 应记录 width/height/dwidth/dheight/video-rotate/hwdec/video-out-params。
- 若再次偏移，偏移发生前后的两组 MPVSurface/MPVVideoState 将作为下一轮直接依据。

## 兼容
- Deployment Target = iOS 15.0。
- iPhone 15 Pro Max / iOS 17.0 正常安装运行。
- 302 后媒体仍客户端直连 115/CDN。
