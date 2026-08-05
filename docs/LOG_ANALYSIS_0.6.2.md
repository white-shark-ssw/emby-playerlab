# 0.6.1 双次真机测试分析

## 第一次会话

- 播放到可信结尾 609.934 秒并主动关闭。
- TransportSession 最终平均约 5.9 MB/s。
- AVAccess 最终 Stall 0、Dropped 0。
- 36 次 Seek，绝大多数可完成，但存在约 3 秒级首帧等待。

## 第二次会话

- 新进程启动后再次播放同一媒体。
- 异常退出前传输实时速度约 17–18 MB/s，平均约 9.2 MB/s。
- Stall 恢复日志显示当前位置前方约 81 MB 连续缓存，传输被判定为健康。
- AVAccess 已累计 Stall 2、Dropped 8。
- 自定义看门狗在 386 秒附近记录第一次 Stall。
- 约四秒后正好到达第二次 Stall/自动切换触发窗口，日志突然中断；九秒后出现新的 logger initialized。
- 没有 close、stop 或 EOF 记录。

## 判断边界

压缩包只有 App 日志，没有 `EmbyPlayerLab-*.ips` 或 `JetsamEvent-*.ips`。因此不能最终区分 Objective-C/Swift 崩溃与 Jetsam，但时序高度指向 ResourceLoader AVPlayer → KSPlayer AVIO 的热切换阶段。0.6.2 同时降低内存峰值并将切换拆成可诊断的阶段。
