# DEV-detail-episode-page-optimization

## Status

**Active**

- **Work ID**：`DEV-detail-episode-page-optimization`
- **Routing aliases / keywords**：详情页优化 / 详情页 / 选集页 / 剧集页 / detail page / episode page
- **Accepted runtime baseline**：OnePlayer 0.14.11 / Build178 仍是整体 accepted `main` runtime baseline；本任务继承 Build176 player episode-session contract 与 Build178 canonical episode ordering。
- **Build181 result**：详情 Hero 高频滚动状态从根 View 隔离到 Hero-only owner 后，用户真机录屏确认此前明显的“停住 → 追帧”结构性抖动已基本消失；但 session-only `NSCache` 无法跨 App 强退/重启保持详情展示元数据，因此 Build181 仅部分成功。
- **Build182 implementation**：在 Build181 的 session `NSCache` 快路径上增加 `Library/Caches/OnePlayer/DetailPresentation` 持久化 presentation snapshot；仅保存可安全重建的 `episodes / seasons / imageInfos / similarItems` 展示元数据，冷启动先恢复展示，正常 Emby `load()` 仍无条件刷新。PlaybackInfo、MediaSource、PlaySession、ResolvedPlaybackSource、115/CDN 临时 URL 不进入缓存。
- **Build182 CI / artifact**：OnePlayer **0.14.15 / Build182**；dedicated standard MPV Release CI source `f086fc0609f745d737e07d01dba18593285b20be`；run `32848214004` success；artifact `OnePlayer-0.14.15-build182-persistent-detail-cache`；artifact ID `9563302306`；IPA SHA-256 `b9638df6f70f11be5f030ec7136a42125f2bc3a16af220c1d8b6de1b0cb3ce4c`；MinOS 15.0；临时 workflow 已恢复。
- **Build182 real-device result — ACCEPTED / FROZEN FOR THESE TWO ISSUES**：用户 2026-08-25 在 iPhone 15 Pro Max / iOS 17.0 明确反馈“目前感觉没问题，这2个问题可以冻结了”。因此以下两项正式冻结：1）详情页纵向滚动流畅度/此前顿挫抖动；2）已访问详情在 App 强退/进程重启后的 Logo/剧集展示恢复。除非后续出现新的明确回归证据，不再继续调整 full-screen blur、Hero scroll owner、详情 presentation cache 生命周期或缓存边界。
- **Frozen Build182 authority boundary**：持久化快照仍只是首帧 presentation；Resume/已看/收藏最终 authority 仍属于服务器实时刷新；STRM→302→115/CDN 客户端直连、Range/206、Emby progress、Player episode session replacement、trusted-natural-end auto-next、canonical episode order 均未改变。
- **New UI refinement request**：用户在冻结上述两项后开始下一轮详情视觉调整：1）把当前“音视频字幕信息” section 移到“更多类似”下面、最底部毛玻璃媒体信息框 `mediaSourceSummarySection` 上面；2）标题改为“视频信息”；3）详情页 section 标题字号整体减小一点，包括“即将播放 / 季 / 演职人员 / 标签 / 剧照 / 更多类似 / 视频信息”等，使页面更精致，卡片正文与 Hero 标题不随之缩小。
- **Real source ownership confirmed**：上述 UI 都在 `Sources/UI/EmbyMediaDetailView.swift`。当前真实顺序是 `castSection → mediaStreamInfoSection → tagSection → stillsSection → similarSection → mediaSourceSummarySection`；目标顺序只调整为 `castSection → tagSection → stillsSection → similarSection → mediaStreamInfoSection → mediaSourceSummarySection`。`mediaStreamInfoSection` 当前标题真实字符串为“音视频字幕信息”；section 标题当前使用 `.title2.weight(.bold)`。
- **Minimal implementation decision**：只改详情 section 顺序、一个标题字符串和这些 section header 的字体；不改卡片大小、section 间距、媒体流内容、展开交互、Hero、缓存、API、选集数据、播放或导航。section header 统一收为 `.system(size: 19, weight: .bold)`，相对当前 `title2` 只做小幅缩小并保留粗体层级。
- **Working branch / PR**：继续使用 `feat/detail-episode-page-optimization`；PR = none。Build182 workflow-restored head 为 `6352671ba843e692c671c66c663c01a43b7848fb`。
- **Parallel conflict / Build identity**：当前并行首页任务 `DEV-home-carousel-drag-smoothness` 已占用 OnePlayer 0.14.16 / **Build183**；仓库搜索未发现 Build184 占用，因此本任务下一 UI 真机候选保留 **OnePlayer 0.14.17 / Build184**。不得复用 Build183。
- **Files in scope for Build184**：产品运行时只需 `Sources/UI/EmbyMediaDetailView.swift` + `Sources/Core/AppIdentity.swift`；对应增加/更新最小详情 UI 静态合同与 `docs/changelog/CHANGELOG_v0_14_17_build184.md`。Build182 的 `EmbyDetailPerformanceState.swift` 保持零改动。
- **Frozen / do-not-touch**：Build182 detail scroll/cache；MPV fast Seek；PiP Build173；UnifiedTransport；Session cache；STRM/302/115 client-direct；Range/206；Emby Resume/progress；native navigation；Build176 player episode session/auto-next；Build178 canonical episode order。
- **Validation state**：Build182 = **Code written / CI passed / IPA produced / real-device accepted for scroll + cold-relaunch cache / frozen for these requirements**。Build184 UI refinement = Code written no / CI no / IPA no / real-device no / stable no。
- **Next exact action**：在真实 `EmbyMediaDetailView.swift` 仅做 section order/title/font 三项最小修改，补静态合同并跑 dedicated standard MPV Release Build184；CI/IPA 成功后交付用户真机确认视觉层级。
- **Rejected / do-not-repeat**：不要因为新视觉调整重新打开 Build182 性能/缓存问题；不要修改 full-screen blur；不要新增/改变缓存；不要调整媒体流数据内容或播放信息 authority；不要改 episode ordering；不要触碰播放器/Transport。
