# 0.6.0 真机测试清单

目标设备：iPhone 15 Pro Max
目标系统：iOS 17.0
Emby：4.8.10.0

## 构建确认

- [ ] 日志开头 `source=0.6.0`。
- [ ] GitHub Actions MinimumOS 检查为 iOS 15.0。
- [ ] IPA 可通过 TrollStore 覆盖安装。

## 初始自动路由

使用 MP4/H.264/AAC 的 ItemId `63368`：

- [ ] 播放页显示 `AUTO·AV`。
- [ ] 日志包含 `[SmartAV] prepare-resource-loader`。
- [ ] 日志包含 `[ResourceLoader] accepted`。
- [ ] 日志不包含 `[TransportHTTP] ready port=`。
- [ ] 只解析一次 302，未发生错误时不重复请求 PlaybackInfo。

## 普通速度

- [ ] 起播后正常播放 120 秒。
- [ ] 记录实时速度、平均速度和连续缓存。
- [ ] 115 预取日志中 worker 数为 1。
- [ ] 没有为了瞬时速度下降反复重建连接。
- [ ] 当前连续缓存逐步达到设置窗口，而不是只增长离散总缓存。

## 快速 Seek

- [ ] 连续右侧双击 30 次，每次触发立即 Seek。
- [ ] 连续左侧双击 10 次。
- [ ] 缓存窗口内 Seek 新画面尽量控制在 200 ms 内。
- [ ] 远距离 Seek 后旧预取任务停止，新 offset 成为 `TransportPriority`。
- [ ] 文件尾 metadata 请求不会把主窗口留在文件尾。

## 后段播放

- [ ] 拖到 70% 位置。
- [ ] 连续播放至少 120 秒。
- [ ] 记录 `[AVAccess]` 的 dropped frames、stalls 和 observed bitrate。
- [ ] 不出现持续掉帧或画面冻结。

## 自动降级

若智能 AVPlayer 在数据充足时连续停滞：

- [ ] 日志包含 `[Orchestrator]` 且 `transportHealthy=true`。
- [ ] 自动出现 `Switch 智能 AVPlayer -> KSPlayer FFmpeg`。
- [ ] UI 自动切换到 `AUTO·FF`，用户无需操作。
- [ ] 播放位置基本保持。
- [ ] 没有新的 `TransportResolve`，说明共享 302 会话仍在使用。
- [ ] 已缓存字节继续命中，没有从零开始下载。

若 KSPlayer 仍失败：

- [ ] 自动切换 `AUTO·MPV`。
- [ ] 不发生 AVPlayer/FFmpeg 来回切换。

## 手动暂停保护

- [ ] 用户暂停后执行 Seek，仍保持暂停。
- [ ] 自动引擎切换不得把用户暂停改成播放。
- [ ] 用户处于播放状态时自动切换后应继续播放。

## 关闭页面

- [ ] 只在关闭页面时出现共享 `TransportSession stopped`。
- [ ] 关闭后无持续网络请求。
- [ ] 无崩溃、无旧 ResourceLoader 回调访问新请求。
