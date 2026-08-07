# v0.9.5 真机修复范围

- Deployment Target 保持 iOS 15.0；目标真机仍为 iPhone 15 Pro Max / iOS 17.0。
- 63368：修复统一双槽在 AVPlayer blocked-read 持续出现时 Slot 1 永远无法启用的问题；Slot 0 进入 urgent playback 时立即允许 Slot 1 常驻顺序预取。
- 顺序预取改为长 Range 单连接流式写入 ByteStore，避免每 4 MiB 重建一次 Range；默认后台顺序块提高到 32 MiB，urgent playback 仍保持 16 MiB。
- 152901 / 144799：回滚 v0.9.4 新增的 CAMetalLayer EDR override/强制 EDR，并移除不必要的 layer delegate 绑定；保留 MoltenVK 自主管理 drawableSize 的修复。
- MPV 创建与 prepare 增加生命周期 breadcrumb，若仍有 native crash 可精确判断发生在引擎创建还是 mpv prepare。
- 播放进度条隐藏 16×16 白色实心圆点；点击/拖动热区和 Seek 行为保持不变。
- unsigned IPA 文件名更新为 0.9.5。
