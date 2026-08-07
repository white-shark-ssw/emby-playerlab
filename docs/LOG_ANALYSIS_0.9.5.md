# v0.9.4 真机日志 → v0.9.5

## 63368

日志声明 `slots=2`，但整段播放中 Slot 1 始终为 idle。Slot 1 只有 Slot 0 完成一个完整 sequential claim 后才启用；AVPlayer blocked-read 会持续把 Slot 0 的 sequential 提升为 urgent 并取消原 claim，所以启用条件长期无法成立。实际传输退化为单连接。

同时 v0.9.4 将 logical sequential claim 拆成 4 MiB 独立 Range 请求。虽然每 4 MiB 会立即写入 ByteStore，但重复 Range 请求会放大 115 CDN 首包和慢连接波动。v0.9.5 改成长 Range 单请求 + 1 MiB 流式可见。

## 152901 / 144799

本轮两项都在 PlaybackInfo 后、Player Start 前出现新的 `logger initialized source=0.9.4`，与进程异常退出后重新启动一致。App 日志没有 iOS `.ips` native stack，因此不能把崩溃最终归因到单一符号。

v0.9.4 相比上一版在 MPV 创建/Surface 早期新增了 EDR override、强制 EDR 和 CAMetalLayer delegate 绑定。v0.9.5 先回滚这些非核心高风险改动，保留真正用于修复画面偏移的“不由 UIView 强制设置 drawableSize”。同时新增 MPV lifecycle breadcrumb，为后续真机日志提供更精确的崩溃边界。
