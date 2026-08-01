# 0.2.7

- 撤销 v0.2.6 的“停滞时销毁旧 MPV 并立刻创建新 MPV”方案。
- 真机日志显示旧 MPV 尚未完成 `mpv_terminate_destroy`，新 MPV 已开始加载，随后 App 闪退。
- MPV 停滞恢复改为在同一个实例中执行，不再发生两个 libmpv 实例重叠。
- 第一次停滞：执行 `drop-buffers` 后向后跨过 30 秒并进行关键帧 Seek。
- 再次停滞：向后跨过 60 秒。
- MPV 停滞时右侧双击至少跨过 30 秒。
- MPV 停滞时拖动进度条会直接按用户目标执行同实例跨区恢复。
- 提前 EOF 恢复同样改为 30/60 秒同实例跨区跳转。
- 增加 `MPVStallBypass`、`MPVSeekLanding` 和 `MPVEndFile` 日志。
- MPV 画面视图按真实 DisplayLayer 身份刷新。
- 应用版本为 0.2.7（11），Deployment Target 继续保持 iOS 15.0。
