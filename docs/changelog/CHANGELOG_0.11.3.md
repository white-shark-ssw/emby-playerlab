# EmbyPlayerLab v0.11.3（Build 57）

- 修复 v0.11.2 urgent/metadata 网络 chunk 被重复统计 6 次，实时下载速度恢复为真实字节量。
- 大于等于 4 GiB 的 MP4 在启动阶段读 EOF 前 64 MiB 时，识别为关键容器尾索引；优先使用主持久 Lane，不再让 152901 一边缓存 100+ MB 文件头、一边等待慢尾索引完成。
- 启动尾索引特殊路径避开用户主动 timeline Seek；普通播放和片尾 Seek 仍按真实播放需求处理。
- 新增双 Lane 健康度：只有健康 peer 足够快且当前 Lane 连续两块低于 peer 50% 时，才在 idle 后轮换该 Lane 的持久 URLSession；整网弱时不重连抖动。
- MPV 持久缓冲历史不再依赖不稳定的初始 `isPlaying` 属性，改为以非 buffering 且 position 连续推进为验证依据。
- 保持两条 115/CDN 直连、iOS 15.0 Deployment Target、现有 AVPlayer/MPV 自动路由和即时双击 Seek 行为。
