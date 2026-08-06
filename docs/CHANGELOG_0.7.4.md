# EmbyPlayerLab 0.7.4（Build 37）

## 下载调度

- 持续预取固定为 32 MB Range，不再在低速时轮换 16/32/64 MB。
- 慢连接确认后只从当前字节游标重建同尺寸 Range。
- 连续 Seek 使用 750 ms 合并窗口，后台预取只跟随最终目标一次；AVPlayer 的即时 Seek 不等待该窗口。
- 缓存命中记录 `cacheHit=true`，网络字节与网络速度为 0。
- 单段网络字节最多按该 Range 的实际加载量计入，避免 AVPlayer 并发写入缓存导致段速度虚高。
- 新增 `[KTVOrigin]`：记录最终 CDN Host、302 次数、Range 能力、探测耗时和 Wi-Fi/蜂窝/受限网络状态。

## 视频冻结

- 视频帧检测频率从 100 ms 降为 250 ms。
- 用户 Seek、初始 Seek、Seek 完成和同引擎软恢复期间暂停冻结判定，并重置最后视频帧基准。
- 冻结累计次数与单轮恢复次数分离，避免恢复后计数清零而无法识别反复异常。
- 同一 Item 累计两次确认的视频冻结后写入本地兼容性记录；下次自动播放从开始选择 KSPlayer/FFmpeg。
- 当前会话仍不自动切换引擎。

## 兼容性

- Deployment Target 保持 iOS 15.0。
- KTVHTTPCache 3.1.0、KSPlayer 2.3.4 和 FFmpegKit 版本不变。
- MPVKit 仍不链接。
