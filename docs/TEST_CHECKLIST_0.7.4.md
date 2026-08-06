# EmbyPlayerLab 0.7.4 测试清单

## 构建

- `Validate Source` 使用 iOS 15.0 编译成功。
- `Build Unsigned IPA` 生成 0.7.4 Build 37。

## 下载

1. 清空当前媒体缓存后播放 Item `63368`。
2. `[KTVAdaptive] segment start` 的 `size` 应始终为 `33554432`。
3. 缓存命中应显示 `cacheHit=true networkBytes=0 speed=0B/s`。
4. 连续快速双击时可出现多条 `seek queued`，但停手后只应出现一次 `seek reprioritize final`。
5. 慢连接只应出现 `slow connection restart`，不应再出现 `nextSegment=67108864`。
6. `[KTVOrigin]` 应记录 finalHost、redirects、ms 和网络接口。

## 视频冻结

1. 每次用户 Seek 后应记录 `watchdog suppressed reason=user-seek` 和 `seek-completed`。
2. Seek 完成宽限期内不应立即出现 `[VideoFreeze] detected`。
3. 同一 Item 累计两次确认冻结后应记录 `[Compatibility] ... marked=KSPlayer-FFmpeg`。
4. 关闭播放器并再次自动播放该 Item，应从开始选择 KSPlayer/FFmpeg。
5. 本次播放期间不得自动从 AVPlayer 热切换到 KSPlayer。
