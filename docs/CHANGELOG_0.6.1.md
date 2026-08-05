# EmbyPlayerLab 0.6.1

版本：0.6.1
Build：31
Deployment Target：iOS 15.0

## ResourceLoader 稳定性

- ResourceLoader 请求改为先注册、后绑定 Task。
- 请求完成与 `didCancel` 统一在 delegate 串行队列内决胜。
- 已取消或已失效的 `AVAssetResourceLoadingRequest` 不再调用 `finishLoading`。
- 单次向 AVPlayer 交付的数据由 256 KB 调整为 1 MB，降低任务调度和 Data 复制频率。

## 播放窗口调度

- 增加播放需求代次；Seek 前启动的旧读取完成后不得调度新预取。
- 普通读取只允许播放需求向前推进；后退由明确 Seek 指令完成。
- MP4 文件尾元数据请求不再改变播放需求位置。
- Seek 优先保护窗口由 4 秒延长为 6 秒。

## 并发任务安全

- 单段下载 `inFlight` 增加 UUID 实例令牌。
- 预取块增加 UUID 实例令牌。
- 被取消的旧任务结束时，不能清理同起点的新下载任务。
- 取消错误不再计入真实 Range 失败统计。

## 预取与内存

- 修复缺口扫描把同一 Range 重复加入列表的问题。
- 流式 Range 缓冲改为读偏移推进，避免高频 `Data.removeFirst`。
- 保持 115 单预取连接和 64 MB 稳定长 Range，不通过增加并发追求速度。
