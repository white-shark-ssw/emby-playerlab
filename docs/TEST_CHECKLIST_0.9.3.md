# v0.9.3 真机测试清单

## 63368 / Stall 与 Seek
- [ ] 连续 +10 / 拖动到未缓存区域后，观察是否出现 `[UnifiedAnchor] seek-candidate deferred`，随后由真实 `[blocked-read]` 产生 `real-demand reanchor` 或 `blocked-demand reanchor`。
- [ ] urgentPlayback Range 应约为 8 MiB，而不是连续多个 2 MiB；仍应先出现 `first-chunk` 后播放器恢复。
- [ ] 若 `forwardPlayable < 0.5s` 且触发 `[Stall]`，Orchestrator 必须进入 `recoverTransport`，随后日志应出现 `stall-last-concrete-demand` / `prioritize-current-demand`，不能只因为总 `networkBps` 高就 `.wait`。
- [ ] 复测约 300~400 秒附近远距离拖动，记录 `buffering=true -> position再次推进` 的实际时长，目标明显低于 0.9.2 的约 14.6 秒异常样本。

## 152901 / 起播
- [ ] 首个 sequential Range 对 >=4 GiB MP4 应约为 1 MiB。
- [ ] 记录 Player Start -> Resolve -> first header -> MPV tail seek -> metadata first-chunk -> file-loaded -> position>0。
- [ ] 若 metadata 首块 >=1.5 秒且 <1 MiB/s，应出现一次 `[UnifiedRecovery] slow-start metadata ... action=refresh-115-source-and-resume`。
- [ ] 同一次起播最多只进行一次慢启动刷新，避免重连风暴。
- [ ] 第二次立即重播也必须最终出现 `file-loaded` 与 position>0；若仍失败，保留完整慢连接日志用于下一轮判断是否需要双连接 startup race。

## 进度条
- [ ] 底轨、历史灰、实时灰均为圆润胶囊形；不得再出现明显直角矩形端点。
- [ ] 真正未验证的大 gap 保持断开；<=1 秒抖动小孔继续合并。

## 兼容性
- [ ] Deployment Target = iOS 15.0。
- [ ] iPhone 15 Pro Max / iOS 17.0 可安装运行。
- [ ] 媒体数据仍为客户端 -> 302 -> 115/CDN，不经过 NAS 中转。
