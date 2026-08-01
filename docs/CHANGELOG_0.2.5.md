# 0.2.5

- 修复 v0.2.4 导致异常短片 63368 无法越过坏点的回归。
- MPV Seek 恢复为 `absolute+keyframes`，不再对异常媒体强制精确解码。
- 保留稳定累计目标，只有实际 `time-pos` 到达目标后才释放，不再依赖 850ms 定时释放。
- 三秒仅作为 Seek 目标锚点的最终兜底超时。
- 修复关闭 MPV 播放页时的生命周期竞争和闪退风险。
- 关闭前解绑 PlayerEngine 回调，停止 wakeup callback，发送 quit 并排空剩余 MPV 事件。
- SwiftUI 销毁 MPV 画面时显式取消 KVO 并移除 AVSampleBufferDisplayLayer。
- 关闭按钮先拆除画面，再停止引擎，最后 dismiss 页面。
- 诊断日志改为持续写入 Application Support；即使发生闪退，重新打开 App 后仍可导出上一轮日志。
- Deployment Target 继续保持 iOS 15.0。
