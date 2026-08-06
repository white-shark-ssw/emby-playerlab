# EmbyPlayerLab 0.7.9 测试清单

## 构建

- [ ] GitHub Actions `Validate Source` 通过。
- [ ] `Build Unsigned IPA` 生成0.7.9 Build 42。
- [ ] Deployment Target为iOS 15.0。
- [ ] iPhone 15 Pro Max、iOS 17.0可安装运行。

## 63368 冷缓存

- [ ] 启动日志显示 `lanes=persistent-2`。
- [ ] lane A启动后约750 ms出现 `persistent dual start` 与 lane B。
- [ ] 不再等待 `dual trial start` 或 `dual lane kept`。
- [ ] 连续双击期间lane B不会因每次Seek被关闭。
- [ ] 短暂 `isBuffering` 不立即出现 foreground priority。
- [ ] 确认持续缓冲时日志显示 `secondaryPauseMs=1250`，且 `primaryRetarget=false`。
- [ ] 正式Stall时 `primaryRetarget=true`，lane A从当前播放字节附近继续。
- [ ] 双通道完整网络分段总速度可明显高于单通道；记录完整段速度而不是混合缓存补缺口速度。

## 63368 重播

- [ ] 已缓存段显示 `cacheHit=true`。
- [ ] 只补少量缺口的段显示 `mixedCache=true`。
- [ ] `mixedCache=true` 的几百 KB/s不触发慢连接重建。
- [ ] 快速Seek仍即时响应，不因缓存遍历反复暂停两条通道。

## 152901

- [ ] 自动模式一开始显示 `automaticEngine=KSPlayer-FFmpeg reason=large-mp4-ktv-direct-ffmpeg`。
- [ ] 不出现 `KTVOpenWarmup begin`。
- [ ] 出现 `[KSKTV] prepared ... transport=KTV-dual-lane`。
- [ ] 播放位置正常推进，不先创建AVPlayer，也不出现 `StartupFallback`。
- [ ] lane A和lane B均在开始后工作。
- [ ] 双击Seek有 `KSPlayer KTV seek callback`，位置继续推进。
- [ ] 10秒仍未ready时旧AVIO兜底仍可触发。

## 错误恢复

- [ ] lane B第一次错误快速重试。
- [ ] lane B连续错误后记录 `recovery scheduled`，随后重新加入。
- [ ] lane A仍最多连续重试三次。
- [ ] NAS不承载任何媒体字节。
