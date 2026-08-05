# 0.6.1 真机测试清单

测试设备：iPhone 15 Pro Max / iOS 17.0

## 基础

- [ ] 日志开头为 `source=0.6.1`。
- [ ] 自动引擎为“智能 AVPlayer”。
- [ ] 不出现 localhost TransportHTTP 端口。

## 连续播放

- [ ] 正常播放至少 10 分钟。
- [ ] AccessLog Stall 保持 0 或无连续增长。
- [ ] dropped frame 不持续增长。
- [ ] App 不闪退，不被系统退回桌面。

## Seek 压力

- [ ] 连续双击快进 50 次。
- [ ] 连续双击快退 20 次。
- [ ] 拖动到 20%、70%、95%。
- [ ] Seek 后旧预取窗口不再明显回跳到远离目标的位置。
- [ ] 不出现同一时刻大量 `TransportBulk failed=Range 数据不完整`。

## 速度

- [ ] 记录实时速度最低值、中位体感和稳定长 Range 速度。
- [ ] 确认当前位置连续缓存能随播放推进。
- [ ] 后段播放无掉帧、无持续等待。

## 闪退资料

若仍闪退：

- [ ] 重新打开 App 后立即导出 EmbyPlayerLab 日志。
- [ ] 设置 → 隐私与安全性 → 分析与改进 → 分析数据。
- [ ] 导出同一时间的 `EmbyPlayerLab-*.ips`；若没有，查找 `JetsamEvent-*.ips`。
