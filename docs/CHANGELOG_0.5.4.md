# EmbyPlayerLab 0.5.4

版本：0.5.4
Build：28
Deployment Target：iOS 15.0

## 真机日志结论

- v0.5.3 的第二次 115 慢连接重建成功把主下载提升到约 20–35 MB/s，并最终完整下载 996 MB 文件；但第一次和第二次重建间隔过长，起播前半段仍长期只有约 5–11 MB/s。
- 连续 Seek 后停滞时，本地稀疏缓存从真实需求位置起已有至少 32 MB，主下载仍在 20 MB/s 以上，说明卡住不是上游缺数据。
- 停滞时 `waiting=none`，旧版恢复逻辑只执行 `playImmediately` 和软 Seek，无法清除 AVPlayer 内部保留的旧 localhost Range 读取与 demux 状态。

## 修复

- 115 启动线路筛选改为前 45 秒的快速模式：连接运行 4 秒后开始判断，低速持续 1.5 秒即可重建，前两次重建冷却缩短为 6 秒。
- 每条新主连接单独记录峰值速度，避免全局历史峰值掩盖当前连接质量。
- 第三次及之后的重建仍使用 8 秒连接年龄、4 秒持续低速和 15 秒冷却，防止重连风暴。
- 每次用户 Seek 前取消当前 localhost 客户端连接和响应任务，清除旧位置的超大 Range 流。
- 传输层 AVPlayer 恢复系统自动防停滞等待；`playImmediately` 仍用于用户 Seek 后的即时续播。
- 第一次停滞恢复会清理旧 localhost 流并立即播放。
- 同一位置第二次停滞会复用现有下载会话和缓存，重建新的 `AVPlayerItem` 并从当前位置恢复，不重新解析 302、不清空缓存。
- 新增 AVPlayer rate、timeControlStatus、itemStatus、bufferEmpty、likelyToKeepUp 和 waitingReason 诊断。

## 保持不变

- 双击 Seek 仍立即提交，不增加手势防抖等待。
- 主下载最多 1 条，紧急 Seek 下载最多 1 条，不恢复 115 第三条探测连接。
- KSPlayer 2.3.4、FFmpegKit 6.1.4、MPVKit 0.40.0-av 不变。
- Deployment Target 继续为 iOS 15.0。
