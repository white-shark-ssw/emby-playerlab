# 0.6.0 真机日志分析与 0.6.1 修复依据

分析日志：`EmbyPlayerLab-1785939794.log`

## 成功指标

- 使用智能 AVPlayer / AVAssetResourceLoader 主路径。
- 完整到达可信结尾 609.934 秒。
- AVPlayer AccessLog 全程 0 Stall、0 dropped frame。
- 未触发自动引擎降级。
- 共记录 45 次 Seek；中位新画面约 83 ms。

## 速度与调度问题

- TransportSpeed 实时速度约 3.6–20.1 MB/s，中位约 8.4 MB/s。
- 最终平均下载约 7.5 MB/s。
- 45 次 Seek 中最慢约 2.13 秒。
- ResourceLoader 接收约 1371 个请求、取消约 669 个请求。
- 约 579 个请求声明长度超过 100 MB，其中约 325 个超过 500 MB。
- 预取产生 38 次不完整 Range；大量属于窗口迁移时取消的旧任务。
- 日志中可见 Seek 到文件末段后，旧读取又把预取窗口拉回约 290–324 MB，随后再次跳回末段。

## 闪退判断边界

上传的 RAR 只包含第一次成功播放日志，没有第二次闪退的系统崩溃堆栈。因此不能把闪退最终定性为某一行代码。

0.6.1 先修复源码中能够确认的高风险竞态：

1. `finishLoading` 与 `didCancel` 对同一个 loading request 竞争。
2. Seek 前旧读取在 Seek 后完成并重新调度旧窗口。
3. 取消的旧 in-flight/preload 任务结束后误删同起点新任务。
4. 流式预取频繁移动 Data 头部导致额外 CPU/内存抖动。

若 0.6.1 仍闪退，需要同时导出 App 日志和 iOS “分析数据”中的 `EmbyPlayerLab-*.ips`，以区分 Swift/AVFoundation 异常与 Jetsam 内存终止。
