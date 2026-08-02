# EmbyPlayerLab 0.5.0

- 新增 KSPlayer 2.3.4（GPL-3.0）并固定版本。
- 新增“强制 KSPlayer AVIO（实验）”引擎。
- FFmpeg 通过 `AbstractAVIOContext` 直接调用稀疏缓存 `read/seek/fileSize`。
- KS AVIO 路线不启动 localhost 原始 MP4 代理。
- 用户 Seek 会把下一次真实 AVIO seek 作为主下载迁移位置。
- 元数据尾部探测只使用辅助下载，不迁移顺序主连接。
- 慢连接测速提前到主连接运行约 5 秒，候选块改为 4 MB。
- 自动模式仍使用 TAV，保留 MPV 与原生 AVPlayer 对照。
- Deployment Target 保持 iOS 15.0。
