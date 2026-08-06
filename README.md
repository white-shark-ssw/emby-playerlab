# Emby Player Lab

面向 TrollStore、自用 STRM → OneStrm 302 → 115 直链环境的原生 iOS 播放器实验室。

## 当前版本：0.7.9

### 系统与构建

- Deployment Target：iOS 15.0
- 重点测试：iPhone 15 Pro Max / iOS 17.0
- 云端编译：GitHub Actions macOS 15 / Xcode 16.4
- 安装方式：未签名 IPA + TrollStore
- KTVHTTPCache：3.1.0（MIT，最低 iOS 12）
- KSPlayer：2.3.4
- MPVKit：源码适配保留；0.7.9 实验构建不链接二进制


### 0.7.9：持续双通道与大 MP4 直启 FFmpeg

- KTV 持续预取从“10 秒单通道基线＋15 秒双通道试跑”改为播放开始后 0.75 秒直接启用两条常驻 32 MB 通道，优先维持115可用带宽。
- 快速 Seek 和短暂缓冲不再同时关闭 lane A/B；lane A 保持并跟随最终播放位置，只有确认持续缓冲或 Stall 才短暂停 lane B 约 1.25 秒。
- lane B 瞬时失败不会永久退出，按失败次数退避后重新加入。
- 大于等于 4 GiB 且时长不少于 1 小时的 MP4，在 KTV 自动模式下直接使用 KTV 双通道＋KSPlayer/FFmpeg，跳过已知会失败的 AVPlayer 和首尾预热。
- KSPlayer 直接创建的 KTV 会话不执行 AVPlayer 专用大 MP4 首尾 warmup，缩短首帧等待。
- 混合缓存区间明确记录 `mixedCache=true`，避免把少量补缺口误认为整条115连接只有几百 KB/s。
- Deployment Target 继续保持 iOS 15.0。


### 0.7.8：播放优先与大 MP4 回归修复

- 修复大 MP4 首尾预取完成后误删播放器准备回调，导致 152901 一直停在 0 秒且无法进入 AVPlayer `Cannot Open` 回退流程。
- KTV 双通道只把已经实际下载到的字节视为 Seek 覆盖，不再把尚未完成的整段 Range 误判为命中。
- 当前播放点缓冲不足或 Stall 时暂停后台双通道约 3 秒，让播放器的真实前景 Range 请求优先；恢复后继续缓存。
- 降低慢连接重建的激进程度，并限制主通道连续失败重试，避免无效连接风暴。
- 播放按钮固定使用已加载条目的真实 ItemId，禁止旧媒体信息生成 `/Videos//stream`。
- Deployment Target 继续保持 iOS 15.0。


### 0.7.7：Swift throwing 表达式编译修复

- 修复 `KTVAVPlayerEngine` 与 `KSAVIOPlayerEngine` 中 throwing 初始化器位于 `??` 右侧时缺少整表达式 `try` 的 Swift 编译错误。
- 改为明确的 `if let` 会话复用分支，避免 `??` 的 `rethrows` 自动闭包规则再次造成遗漏。
- KTV AVPlayer、KTV 双通道、KSPlayer/FFmpeg 会话移交逻辑保持不变。
- Deployment Target 继续保持 iOS 15.0。

### 0.7.6：统一 KTV 高速缓存传输

- AVPlayer 与 KSPlayer/FFmpeg 统一读取 KTVHTTPCache localhost 代理。
- 启动阶段 AVPlayer `Cannot Open` 时直接移交当前 KTV 缓存会话，不清缓存、不重建115连接。
- 已标记为 FFmpeg 优先的媒体从一开始使用 KTV 双通道预取。
- KSPlayer 通过 KTV 代理 10 秒仍未就绪时，才降级到旧 AVIO，保留播放可靠性。
- 第二通道单次瞬时错误先重试一次，不再立即放弃双通道。
- Deployment Target 继续保持 iOS 15.0。

## GitHub 构建

1. 将仓库内容提交到 `main`。
2. 等待 `Validate Source` 成功。
3. 打开 Actions → `Build Unsigned IPA` → `Run workflow`。
4. 下载 `EmbyPlayerLab-unsigned-<commit>` Artifact。
5. 解压获得 `EmbyPlayerLab-0.7.9-<commit>-unsigned.ipa`，使用 TrollStore 覆盖安装。

首次构建会通过 CocoaPods 安装固定版本 KTVHTTPCache 3.1.0，并通过 Swift Package Manager 解析 KSPlayer 2.3.4。

## 安全与许可证

- 密码不落盘，AccessToken 保存到 Keychain。
- KTVHTTPCache 自带文件日志默认关闭，避免临时播放 URL 进入第三方日志。
- App 自有日志只记录原始主机、localhost 端口、缓存字节和速度，不记录完整代理 URL。
- KTVHTTPCache 3.1.0 为 MIT；KSPlayer 2.3.4 及其 FFmpegKit 依赖按项目现有 GPL 说明处理。0.7.9 不链接 MPVKit。

## 0.2.1 修复

- 修复 SwiftPM 接入 MPVKit 1.0.0 时的模块导入错误。
- Swift Package 产品名是 `MPVKit`，但实际 C target 模块为 `_MPVKit`；libmpv API 位于 `Libmpv` 二进制模块。
- `MPVPlayerEngine.swift` 改为导入 `_MPVKit` 与 `Libmpv`。
- Actions 额外导出 MPV module map，便于后续定位二进制模块问题。


## 0.2.2 CI 修复

- 先恢复缓存并解析 MPVKit，再检查 module maps。
- 首次运行没有 `.spm-cache` 时不再提前失败。
- 所有诊断日志在工作流开始时创建，因此失败后一定有 Artifact 可下载。


## 0.2.3 MPV 黑屏修复

真机日志确认官方 MPVKit 1.0.0 的 iOS 预编译二进制不包含
`vo_avfoundation`，导致 MPV 只运行解封装、音频和时间轴，却没有视频输出。

0.2.3 改为固定 Streamyfin 实际使用的 `0.40.0-av` 分支：

- 包含 `vo_avfoundation`
- 直接输出到 `AVSampleBufferDisplayLayer`
- 支持 VideoToolbox 硬件解码
- 最低 iOS 13，项目 Deployment Target 仍保持 iOS 15
- 视频输出初始化失败时直接显示明确错误，不再黑屏并伪报 Seek 成功

该预编译产品标记为 GPL-3.0。项目目前仅用于用户本人通过 TrollStore
安装。公开或向他人分发 IPA 前必须重新检查 GPL 合规。


## 0.2.4 音频与中段回弹修复

- 不再错误指定 `ao=avfoundation`，让 MPV 自动选择 iOS 音频后端。
- 增加音频输出、音轨和音频参数日志。
- 连续双击保持一个稳定累计目标，避免关键帧实际落点反向覆盖下一次快进基准。
- 缓冲命中的 MPV 双击使用精确绝对 Seek；缓存未命中仍优先快速关键帧 Seek。


## 0.2.5 异常媒体与退出修复

- MPV 远程 Seek 恢复快速关键帧模式，重新允许跳过异常时间戳区域。
- 连续双击的 UI 目标保持到实际播放位置追上，不再出现中途回弹。
- 退出 MPV 页面时先拆除画面和回调，再排空事件并销毁 libmpv。
- 当前诊断日志持续保存；发生闪退后重新打开 App 仍可导出上一轮日志。


## 0.2.6 302 会话刷新与异常区域硬恢复

`63368` 的 v0.2.5 日志确认：实际播放位置持续停在 30 秒附近，旧代码却在
发出 Seek 时先把 UI 位置写成 35/40 秒；随后旧连接出现 TLS 解码错误、partial
file 和提前 EOF。

本版不再把请求目标当作真实落点。MPV 持续停滞时会重新请求 PlaybackInfo，
获取新的 PlaySessionId，销毁旧 MPV 和缓存，再以新的 MPV 实例重新经过 Emby
入口与 302 链路。重复卡在同一异常区域时会逐步向后跨过该区域。


## 0.2.7 稳定同实例跨区恢复

v0.2.6 在检测到停滞后，会异步销毁旧 libmpv，同时立即创建新 libmpv。真机日志证明旧实例尚未完成 `terminate_destroy` 时新实例已经开始加载，随后发生闪退。

本版不再自动更换 MPV 实例。检测到异常媒体停滞时，在当前 MPV 中清理解码缓冲，并进行 30 秒或 60 秒的大跨度关键帧跳转。停滞状态下拖动进度条则直接跳到用户目标。


## 0.2.8 坏交错 MP4 兼容读取

真机日志证明异常 MP4 能完成远距离 Seek，但每次落点只读取约 0.1 秒数据，
随后再次进入 `paused-for-cache`。这不是目标点跳转失败，而是顺序取包失败。

最早“可越过”的 MPV 版本同时没有可用音频输出。启用 AudioUnit 后，FFmpeg
需要同时读取音频与视频轨道；对于坏交错 MP4，默认 `interleaved_read` 可能在
两个轨道之间频繁进行远程 Range Seek。

本版首次检测到 MP4 停滞时，在同一个 libmpv 实例中重新加载，并启用：

- `demuxer-lavf-o=interleaved_read=0`
- `demuxer-seekable-cache=no`
- `cache-pause=no`
- `demuxer-max-back-bytes=0`

重载前会刷新 Emby PlaybackInfo 和 PlaySessionId，但不会创建第二个 MPV 实例。


## 0.2.9 MPV 文件切换事件修复

v0.2.8 日志中的 `MPVEndFile reason=2` 不是提前 EOF。根据 libmpv API，
reason 2 表示当前文件因为 stop 或 loadfile replace 被停止。旧代码把它当作真实
EOF，导致一次兼容重载立即递归触发第二、第三次重载，并制造 partial file/TLS 错误。

本版只把 reason 0（真实 EOF）和 reason 4（加载/播放错误）交给提前结束逻辑。
STOP、QUIT、REDIRECT 等文件切换事件只记录日志，不改变播放结束状态。


## 0.2.10 兼容模式 Seek 兜底

兼容模式先立即执行普通 Seek；2.5 秒内没有真实 PLAYBACK_RESTART 时，才在
同一个 MPV handle 中使用 loadfile replace 从目标位置重新打开。time-pos 提前
变化不再被当成 Seek 已完成。


## 0.3.1 构建修复

- 修复 `MediaTransportSession.metrics()` 中 `await` 位于加法表达式右侧导致的 Xcode 编译失败。
- 磁盘缓存大小先异步读取到局部变量，再与内存缓存大小相加。
- 将 `TransportResourceLoader` 的锁操作移入同步辅助方法，避免 Swift 6 并发检查警告。
- AVPlayer 初始位置 Seek 改用带 completionHandler 的兼容重载。
- 不改变 Transport/Range 缓存架构和默认缓存参数。


## 0.3.3 Release 构建修复

- 修复 Xcode 16.4 Release 构建中 `withCheckedThrowingContinuation` 无法推断泛型返回类型的问题。
- `TransportHTTPServer.send` 明确使用 `CheckedContinuation<Void, Error>`。
- 不改变本机 HTTP Range 服务、TAV 缓存、302 解析和播放器路由逻辑。
- Deployment Target 继续保持 iOS 15.0。


## 0.3.4 115 Range 调度修复

根据 0.3.3 真机日志，本版集中处理三项实际瓶颈：

- 115 返回单次 403/410 时先重试当前直链，不再立即刷新 PlaybackInfo。
- 多个并发请求同时确认直链失效时，共用一个 single-flight 刷新任务，避免刷新风暴。
- 正常顺序播放时不再每前进约 4 MB 就取消并重建整个预加载窗口。
- 用户 Seek 时取消低优先级预加载，并在目标对应的近似字节位置建立新预加载窗口。
- 后台预加载最多使用 `并发数 - 2` 路，给当前播放和 Seek 保留连接。
- TAV 本机 HTTP 监听器先启动，302 解析与 AVPlayer 初始化并行进行。
- Range 分片继续允许选择 1/2/4/8/16 MB；默认保持 1 MB，避免拉长首块等待。
- 缓存显示改为有效唯一缓存，不再把同一分片的内存副本与磁盘副本重复相加。
- 缓存命中率按实际返回给播放器的字节计算，不再按整块分片重复累计。
- 传输栏同时显示 5 秒实时速度与全会话平均速度。


## 0.3.5 115 持续下载管线

0.3.4 真机日志显示上游仍以 1 MB 短 Range 为主：单块中位耗时约 1.3 秒，
整个会话平均速度约 1.1 MB/s。大量短请求会反复经历请求调度和连接慢启动，
并产生间歇性 403 重试，无法发挥 115 直链带宽。

本版把播放读取与后台下载拆成两级：

- AVPlayer 当前读取继续使用 1 MB 本地缓存分片，保持起播和 Seek 响应。
- 后台预加载前四轮使用 4 MB 暖机块，建立连续缓冲后再切换到可配置的 8/16/32/64 MB 持续 Range。
- 每个后台 worker 使用独立 URLSession 下载上下文，不再让所有预加载任务挤在同一个会话里。
- 大 Range 在接收过程中每累计一个本地分片就立即写入内存/磁盘缓存，播放器无需等待整块完成。
- 多个 worker 按相邻字节区间并行填充，优先推进连续可播放缓存，而不是只下载远处离散块。
- 115 会话 Cookie 在下载连接间共享，减少因连接上下文不同造成的临时拒绝。
- 诊断日志改为 350 ms/64 KB 批量落盘，并对本机 HTTP 小 Range 日志采样，避免每个 64 KB 请求都打开文件写日志。
- 新增“115 持续预取块”设置，默认 16 MB；本地缓存分片仍默认 1 MB。


## 0.4.0：115AVIO Lab

本版本冻结现有 TAV 主播放链，不继续修改播放器缓存参数。播放器实验室的每个媒体源新增“115AVIO 实验”入口，用于在不启动 AVPlayer、MPV 或 FFmpeg 的情况下测试 302 后 115 直链的真实网络模式。

实验包含：

- 共享 URLSession 单开放 Range 长连接；
- 共享 URLSession 单有限 Range；
- 同一共享会话的双连续 Range；
- 两个独立 URLSession 的双连续 Range；
- 单连接边下载边写临时文件；
- 最小 `read / seek / fileSize` AVIO 语义自检；
- JSON 实验报告导出。

0.4.0 不接入 KSPlayer，也不替换正式播放器。测试结果用于确定 115 的最佳连接池、Range 和请求头模式，再进入 KSPlayer `AbstractAVIOContext` 桥接。


## 0.4.1：下载优先传输层

0.4.0 真机实验确认，115 最佳模式是单连接边下载边写磁盘：30 秒平均约 6.36 MB/s，瞬时达到约 22.9 MB/s；共享会话双 Range 反而最慢。

本版将该结果接入正式 MP4 播放路径：

- 默认传输策略改为“下载优先”。
- 解析 302 后立即启动 1 条浏览器式大 Range 顺序下载连接。
- 网络数据每 256 KB 写入同一个稀疏媒体文件，AVPlayer 本机 HTTP 只读取已经到达的本地字节。
- 文件尾元数据或未缓存 Seek 最多临时增加 1 条辅助连接，不再长期维持 3 个条带 worker。
- 快速连续 Seek 立即响应；只有目标稳定约 0.9 秒后，主顺序下载连接才迁移到新位置。
- 支持持久化稀疏区间索引；退出后保留缓存时，下次会话可以继续利用已下载区间。
- 旧版多 Range 调度保留为设置页回退选项。
- 尚未接入 KSPlayer；本版先验证下载器、稀疏文件和真实播放读取能否稳定协作。


## 0.5.0：真实 Range 驱动与慢连接换线

0.4.1 真机日志确认：下载优先启播和 Seek 明显改善，但时间比例估算会把主连接迁移到错误字节位置；主连接到达文件尾后，中间真实读取缺口仍可能导致永久等待。

本版集中修复：

- Seek 时间比例只用于临时预热，不再直接迁移主连接。
- 本机 HTTP 的真实 Range 与实际阻塞 read 决定主连接迁移位置。
- 多个真实缺口进入单辅助连接队列，不再互相取消导致永远补不完整。
- 主连接到达文件尾或预加载上限后，会检查近期真实需求缺口；存在缺口则继续补齐，不会直接进入 `active=0`。
- 播放器 Stall Watchdog 会把当前位置交给下载优先会话，强制补真实需求缺口。
- 主连接持续低速且连续缓存不足时，短暂启动 8 MB 候选通道测速；候选明显更快才重建主连接，正常仍保持单主连接。
- 播放状态新增“总缓存”和“当前位置连续缓存”，避免离散缓存总量造成误判。

Deployment Target 继续保持 iOS 15.0。


## 0.5.0 KSPlayer AVIO Engine Lab

设置页新增“强制 KSPlayer AVIO（实验）”。该路线使用 KSPlayer 2.3.4 的 `AbstractAVIOContext` 扩展点，将 FFmpeg 的同步 `read/seek/fileSize` 直接接到下载优先稀疏缓存。自动模式仍保持 TAV，便于同一媒体快速对照。

实验引擎不启动 `TransportHTTPServer`，因此不会产生 AVPlayer 的多个超长 localhost Range。下载器保持单顺序主连接、临时 Seek 连接、403/410 刷新和慢连接竞速换线。



## 0.5.2 下载线程稳定与 AVPlayer 停滞恢复

- 115 CDN 禁用额外线路探测，避免第三连接触发 403。
- 文件尾部小范围索引读取不再迁移主下载线程。
- 连续 Seek 使用紧急通道即时补数据，主下载只跟随最后稳定目标，减少连接反复取消重建。
- 传输层 AVPlayer 关闭主动等待，并在本地缓存充足但画面停住时执行立即播放与软重 Seek。
- Deployment Target 继续保持 iOS 15.0。

## 0.5.1 KSPlayer 2.3.4 构建修复

- 修正 `KSPlayerSparseAVIOContext.read/write` 的覆写签名。
- 严格匹配 KSPlayer 2.3.4：输入缓冲区为 `UnsafePointer<UInt8>?`，返回值为 `Int32`。
- 读取时只在 FFmpeg 提供的缓冲区上创建临时可变视图并复制数据，不改变 AVIO 所有权。
- Deployment Target 继续保持 iOS 15.0，依赖版本不变。


## 0.5.3 Seek 自动续播与 115 慢连接重建

- AVPlayer 的“用户希望继续播放”与底层瞬时 `.paused/.waiting` 状态分离；Seek 不再因为 KVO 短暂状态而丢失续播意图。
- 双击和拖动仍立即提交 Seek，提交后、完成后以及短延迟复查都会在用户未主动暂停时恢复播放。
- Seek 提交时只更新界面目标，不再提前伪造引擎真实位置；Watchdog 会等真实时间或首帧到达后再解除 Seek 保护。
- 播放按钮在缓冲和 Seek 期间保持“正在播放”的用户意图，不再错误变成需要手动点击的播放状态。
- 传输层停滞检测从约 8 秒提前到约 4 秒，并继续使用立即播放与软重 Seek 恢复。
- 115 主下载连接若从高带宽持续跌到低速，不增加第三条探测连接，而是在当前游标处单连接重建，最多尝试 4 次。
- Deployment Target 继续保持 iOS 15.0。

## 0.5.4 快速线路筛选与 AVPlayerItem 自愈

- 115 主连接在播放开始后的前 45 秒进入启动线路筛选阶段；低于约 10–16 MB/s 的连接可在 4 秒后快速判定，并以 6 秒冷却连续更换最多两次。
- 启动筛选结束后恢复保守的持续低速判定，避免长时间播放期间频繁重连。
- 每次用户 Seek 前取消旧的 localhost Range 响应，只保留新位置重新发起的读取，避免连续快进后历史超大 Range 流堆积。
- 传输层 AVPlayer 恢复 `automaticallyWaitsToMinimizeStalling`，防止数据短暂不足时直接停在 `.paused` 且不会自动续播。
- 第一次停滞会清理旧 HTTP 流并立即续播；同一位置再次停滞时，不再只做软 Seek，而是复用同一缓存会话和 localhost 地址重建 `AVPlayerItem`。
- 新日志增加 `TransportHTTP reset streams`、`AVPlayerState` 与 `AVPlayerRecovery rebind-item`，便于区分网络低速、旧响应阻塞和 AVFoundation 解码状态卡死。
- Deployment Target 继续保持 iOS 15.0。

## 0.5.5 localhost 重绑竞态与失败回退

- 修复旧 NWConnection 的异步取消回调可能误删新连接的问题：连接清理现在同时校验 ObjectIdentifier 与连接实例。
- AVPlayerItem 重建使用新的 `transportRevision` URL，强制 AVFoundation 放弃旧资产的失败和缓冲状态；localhost 服务会忽略查询参数并继续服务同一媒体。
- 播放项重建时直接重启 localhost listener，保留同一个下载会话和稀疏缓存，但换用新的端口与资产 URL。
- 当 loadedTimeRanges 明显落后于真实播放位置时，第一次停滞就直接重建播放项。
- 重建播放项仍失败时自动重建完整传输会话并从当前位置恢复，避免播放器永久进入 failed。
- 115 线路淘汰阈值放宽到启动期约 8–12 MB/s、稳定期约 6–10 MB/s，避免把可用连接换成更慢线路。
- Deployment Target 继续保持 iOS 15.0。
