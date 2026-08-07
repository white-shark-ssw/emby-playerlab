# EmbyPlayerLab 0.9.2 (Build 48)

## 63368 / 缓冲进度条
- 历史缓冲与实时缓冲改为更明确的实灰阶，不再依赖高透明度白色；轨道提高到 10pt。
- 历史时间范围只合并 <= 1 秒的小抖动空隙；真正由跳播造成的未验证区间仍保持断开，避免伪造已缓冲时间。
- Seek 提交与完成后增加 Stall watchdog 宽限期；当前位置已有 >= 1.5 秒真实前向可播且 AVPlayer 未处于 waiting/buffering 时，不再弹出假“正在补充数据”警告。
- 首次起播阶段在播放时钟真正推进前不触发 Stall 恢复提示。

## 152901 / MPV 起播
- 统一传输首个顺序块从 16 MiB 降为 4 MiB，首批头部数据更早进入 ByteStore；后续仍恢复 16 MiB 双通道大块，避免牺牲持续吞吐。
- MP4 尾部 metadata 紧急窗口由固定 2 MiB 扩大到最多 16 MiB；一次真实尾部 seek 可覆盖剩余 moov/sample table，而不是连续串行 2 MiB 请求。
- metadata 与 urgentPlayback 改为流式写入 ByteStore：每收到约 1 MiB 就立即可供 MPV/AVPlayer 消费，不再等待整个紧急 Range 完成。
- 后台 sequential 仍使用原有持久双 Session + 16 MiB 块，保持 115/CDN 长连接吞吐。

## 兼容性
- Deployment Target 仍为 iOS 15.0。
- 不增加 NAS 媒体中转；媒体字节继续由客户端经 302 直连 115/CDN。
