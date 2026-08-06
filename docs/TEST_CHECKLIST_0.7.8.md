# EmbyPlayerLab 0.7.8 测试清单

## 构建

- [ ] GitHub Actions `Validate Source` 通过。
- [ ] `Build Unsigned IPA` 生成 0.7.8 Build 41。
- [ ] Deployment Target 为 iOS 15.0。
- [ ] iPhone 15 Pro Max、iOS 17.0 可安装运行。

## 63368

- [ ] 冷缓存启动后 lane A 正常下载；网络有收益时 lane B 被保留。
- [ ] 连续双击时，尚未实际下载到的目标不会记录为 `seek coalesced target already covered`。
- [ ] 当前播放点缓冲不足时出现 `[KTVAdaptive] foreground priority`，后台 lane A/B 暂停。
- [ ] 前景恢复后出现 `foreground priority ended`，后台预取继续。
- [ ] 不再出现总缓存持续增长但 `bufferedEnd` 卡在当前位置约0.1秒的长期 Stall。
- [ ] 掉帧计数不再因后台预取抢占当前播放 Range 持续增加。

## 152901

- [ ] 日志依次出现 `KTVOpenWarmup finished` 与 `KTVPlayer open warmup ready item=152901`。
- [ ] AVPlayer若仍报 `Cannot Open`，出现 `StartupFallback armed/check`。
- [ ] 回退后出现 `[KSKTV] prepared ... transport=KTV-dual-lane`。
- [ ] KTV＋FFmpeg 10秒不就绪时，旧AVIO兜底仍可触发。

## ItemId 与错误恢复

- [ ] 清空输入框后点击旧媒体的播放按钮，不会生成 `/Videos//stream`。
- [ ] 播放源日志中的 `item=` 始终等于已加载条目的真实ItemId。
- [ ] lane A连续错误最多自动重试三次，然后记录 `retry suspended`，不无限刷请求。
