# DEV-detail-episode-page-optimization

## Status

**Active**

- **Work ID**：`DEV-detail-episode-page-optimization`
- **Routing aliases / keywords**：详情页优化 / 详情页 / 选集页 / 剧集页 / detail page / episode page
- **Task**：优化 OnePlayer 的媒体详情页与选集/剧集页面。当前目标：1）详情页热/冷重进都尽量直接恢复已知 Logo 与剧集展示内容；2）详情纵向滚动保持连续跟手。
- **User intent / acceptance criteria**：首次从未访问过的详情允许真实网络加载；访问成功后的详情即使 App 被强制退出/进程重启，再次进入也应优先恢复可安全复用的展示快照和既有图片磁盘缓存，不再明显经历“文字剧名 → Logo”或剧集区从空态重新出现。后台仍必须取得当前 Emby 数据；Resume/已看/收藏最终 authority 仍属于服务器。滚动不得出现明显停顿后追帧/跳变。
- **Baseline**：产品运行时基线仍为用户已接受并合并的 OnePlayer 0.14.11 / Build178。本任务 branch `feat/detail-episode-page-optimization` 基于 accepted Build178 runtime。首页轮播 Build180 为独立并行候选，不替代 Build178 accepted runtime。
- **Working branch / PR / head commit**：branch `feat/detail-episode-page-optimization`；PR = none；Build181 workflow-restored head `a8c445af44036218c6c085ae3b4b657ddb0902b1`。
- **Build181 real-device result**：用户 2026-08-25 在 iPhone 15 Pro Max / iOS 17.0 提供新录屏 `RPReplay_Final1787660431.mp4` 与 `RPReplay_Final1787660523.mp4`。第一段约 10.2 秒 / 30 fps：逐帧位移检查显示 Build181 已基本消除此前明显的“停住 → 下一帧追出去”结构性抖动，连续惯性段每帧保持位移且速度总体连续衰减；个别大位移出现在重新起手的快速滑动，不是中途卡死补帧。该项记为 **real-device clearly improved / not yet frozen**，当前没有证据需要继续改 full-screen blur。第二段约 5.7 秒 / 30 fps：用户强制退出 App 后重新启动并进入同一剧集，约 4.3s 详情先出现文字标题“逆局”和“正在加载剧集…”，约 4.4s 才恢复 Logo/剧集；明确证明 Build181 的 session-only warm cache 无法跨进程存活。
- **Build181 root-cause conclusion**：图片字节已有 decoded-memory + disk-data cache；剩余冷启动闪变不是图片文件未缓存，而是 `EmbyMediaDetailWarmCache` 当前仅使用 `NSCache`。App 进程退出后 `imageInfos / episodes / seasons / similarItems` 的展示元数据全部丢失，新 ViewModel 冷启动只能先按空数组渲染，再等待真实 Emby 请求返回。
- **Build181 implementation / evidence**：Hero 高频 `contentOffset` 已隔离到 `EmbyDetailHeroScrollState` + Hero-only scope；原生 ScrollView、stretch/crop/pin 数学保持。session-level warm presentation 仅保存 `episodes / seasons / imageInfos / similarItems`，正常 `load()` 始终继续真实刷新。Build181 dedicated CI source `917c43554876ce7c8751c10356f081cf2c1fe92b`；run `32845717063` success；artifact ID `9562323675`；IPA SHA-256 `698d80d59767134c9479d517cedf24bf6494e73099d2f9125fa3d7a431d5a2f8`；iOS MinOS 15.0。
- **Next implementation**：只扩展详情 presentation cache 的生命周期：保留现有进程内 `NSCache` 快路径，同时把同一份安全展示快照原子写入 `Library/Caches`，以 server base URL + userId + itemId 的稳定 key 区分；新进程首次访问先读磁盘展示快照，再执行现有真实 Emby `load()`。磁盘记录仍只包含可重建 `LibraryItem / EmbyImageInfo` 所需的展示元数据，不保存 `PlaybackInfo / MediaSource / PlaySession / ResolvedPlaybackSource / 115-CDN URL`。不改 EmbyAPIClient、共享图片缓存、播放器、Transport、episode ordering 或导航。
- **Build candidate**：**OnePlayer 0.14.15 / Build182** 现保留给本任务冷启动详情展示缓存修正。分配前重新检查 `docs/project/current/dev/`：当前仅另有 `DEV-home-carousel-drag-smoothness`，其候选仍为 Build180；Build182 未被占用。
- **Files / modules in scope**：优先只改 `Sources/UI/EmbyDetailPerformanceState.swift` 和对应静态合同；`EmbyMediaDetailView.swift` 仅在真实调用契约需要时最小修改。共享图片实现、`EmbyAPIClient`、`ImmersiveUIComponents`、Player、Transport、Cache 设置、Navigation 均保持不动。
- **Frozen / inherited contracts**：MPV fast Seek、PiP Build173、UnifiedTransport、Session cache、STRM/302/115 客户端直连、Range/206、Emby Resume/progress、native navigation、Player episode session replacement / trusted-natural-end auto-next 均保持；canonical episode order 继续由 `/Shows/{SeriesId}/Episodes` 返回顺序拥有。
- **Validation state**：Build181 = **Code written / CI passed / IPA produced / real-device tested**；scroll performance = **clearly improved on device**；cross-process detail warm start = **failed on device**；Build181 not stable. Build182 = Code written no / CI no / IPA no / real-device no / stable no。
- **Next exact action**：检查 `LibraryItem` / `EmbyImageInfo` 的真实 Decodable 结构，在详情 performance state 内实现最小磁盘 presentation snapshot，不扩大模型或网络 authority；补静态合同后跑 dedicated Build182 Release CI，成功后交付 IPA。真机重点复测：强制退出 App → 重新启动 → 进入已访问剧集时是否首帧直接保持 Logo/剧集；同时复查 Build181 已改善的纵向滚动不回退。
- **Rejected / do-not-repeat**：不要新增第二套图片字节缓存；不要把展示磁盘快照升级为播放/session 缓存；不要缓存 PlaybackInfo/PlaySession/MediaSource/ResolvedPlaybackSource/115-CDN 临时 URL；不要用 debounce/throttle 换滚动表面稳定；不要改 episode canonical order；不要在目前无证据时继续动 full-screen blur/GPU 管线。
- **Open questions / risks**：磁盘展示快照中的 UserData 可能短暂旧于服务器，因此仅用于冷启动首帧，现有真实 `load()` 必须无条件继续并替换；若后续真机观察到可见旧 Resume 状态，需要把 presentation 与 Resume 展示 owner 进一步拆开，而不是让磁盘快照成为 authority。
