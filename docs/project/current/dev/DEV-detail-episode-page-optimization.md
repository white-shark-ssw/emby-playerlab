# DEV-detail-episode-page-optimization

## Status

**Active**

- **Work ID**：`DEV-detail-episode-page-optimization`
- **Routing aliases / keywords**：详情页优化 / 详情页 / 选集页 / 剧集页 / detail page / episode page
- **Accepted runtime baseline**：OnePlayer 0.14.11 / Build178 仍是整体 accepted `main` runtime baseline；本任务继承 Build176 player episode-session contract 与 Build178 canonical episode ordering。
- **Build182 real-device result — ACCEPTED / FROZEN FOR TWO PERFORMANCE/CACHE ISSUES**：用户 2026-08-25 在 iPhone 15 Pro Max / iOS 17.0 明确反馈“目前感觉没问题，这2个问题可以冻结了”。正式冻结：1）详情页纵向滚动此前的顿挫/抖动；2）已访问详情在 App 强退/进程重启后的 Logo/剧集展示恢复。Build181 Hero-only scroll owner 与 Build182 `Library/Caches/OnePlayer/DetailPresentation` 持久展示缓存均保持，不再因普通视觉调整重开。
- **Frozen Build182 authority boundary**：持久化快照只用于 presentation 首帧；Resume/已看/收藏最终 authority 仍为服务器实时刷新；PlaybackInfo、MediaSource、PlaySession、ResolvedPlaybackSource、115/CDN 临时 URL 不进入详情展示缓存；STRM→302→115/CDN client-direct、Range/206、Emby progress、Build176 player episode session/auto-next、Build178 canonical episode order 均未改变。
- **Build182 CI / artifact**：OnePlayer 0.14.15 / Build182；dedicated CI source `f086fc0609f745d737e07d01dba18593285b20be`；run `32848214004` success；artifact ID `9563302306`；IPA SHA-256 `b9638df6f70f11be5f030ec7136a42125f2bc3a16af220c1d8b6de1b0cb3ce4c`；MinOS 15.0。
- **Build184 UI request**：1）把原“音视频字幕信息”移动到“更多类似”下面、最底部毛玻璃 `mediaSourceSummarySection` 上面；2）标题改为“视频信息”；3）将“即将播放 / 季 / 演职人员 / 标签 / 剧照 / 更多类似（或相似作品）/ 视频信息”等主要 section header 略微缩小，使详情层级更精致；卡片正文和 Hero 不缩小。
- **Build184 implementation**：真实 `Sources/UI/EmbyMediaDetailView.swift` 已改为 `castSection → tagSection → stillsSection → similarSection → mediaStreamInfoSection → mediaSourceSummarySection`；媒体流 section 标题改为“视频信息”；上述 7 组主 section header 统一为 `.system(size: 19, weight: .bold)`。卡片大小、正文、section spacing、媒体流内容/展开动画、Hero、Build182 scroll/cache、API、选集、播放、导航均不变。
- **Build184 product source**：UI 产品提交 `583d156d51e46ca4f913cbd268d18f8cbdb05b2f`；后续仅补 identity/changelog/static contracts。Build identity = **OnePlayer 0.14.17 / Build184**，并行首页任务占用 0.14.16 / Build183，因此无编号冲突。
- **Build184 CI note**：前两轮 run `32851489117` / `32851565454` 在 Xcode 前的静态合同阶段失败，原因分别是旧 `check_detail_media_metadata.py` 与 `check_detail_resume_button.py` 仍硬编码旧标题“音视频字幕信息”。只更新了这两条过时标题断言，媒体内容、Resume、PlaybackInfo 与其它合同均未放松；这两轮不属于 Swift 编译失败。
- **Build184 successful CI / artifact**：dedicated standard MPV Release CI source `0238f2c8fd202df6e7ba52d582b1614c9230eef9`；run **`32851745960` success**；artifact `OnePlayer-0.14.17-build184-detail-visual-refinement`；artifact ID **`9564647845`**；artifact digest `sha256:68e25864307536e15ed79329ae6f11e1018875f74316a050eb4ad88e61c1bd7f`；IPA `OnePlayer-0.14.17-build184-detail-visual-refinement-unsigned.ipa`；IPA SHA-256 **`d89953c76b678fe1bc0b9f3fcc8b5b5b3ea430ec74bdd420834b427c91d47eb4`**。Artifact 下载后 IPA checksum 再次校验一致。
- **Build184 CI coverage**：新 detail visual hierarchy 合同、Build182 detail performance/persistent cache 合同、Hero geometry、episode range jump、media metadata、Resume button、Build178 series episode ordering、Build182 `EmbyDetailPerformanceState.swift` + Build176/178/P0 Frozen zero-diff 全部通过；Xcode 16.4 Release device build、0.14.17 (184) app identity、iOS 15.0 MinOS、IPA packaging/upload 全部通过。临时 dedicated workflow 已恢复为标准 MDK workflow；workflow-restored branch head `8ea6fc2347f899bd65bda315305a8091e38b1c3d`。
- **Working branch / PR**：`feat/detail-episode-page-optimization`；PR = none。
- **Files in long-term Build184 scope**：运行时产品差异相对 Build182 仅 `Sources/UI/EmbyMediaDetailView.swift`、`Sources/Core/AppIdentity.swift`；测试/资料增加 `scripts/check_detail_visual_hierarchy.py`、两条旧标题合同更新、Build184 changelog。`Sources/UI/EmbyDetailPerformanceState.swift` 零改动。
- **Frozen / do-not-touch**：Build182 detail scroll/cache；MPV fast Seek；PiP Build173；UnifiedTransport；Session cache；STRM/302/115 client-direct；Range/206；Emby Resume/progress；native navigation；Build176 player episode session/auto-next；Build178 canonical episode order。
- **Validation state**：Build182 = **Code written / CI passed / IPA produced / real-device accepted for scroll + cold-relaunch cache / frozen for these requirements**。Build184 = **Code written / CI passed / IPA produced / real-device pending / not stable**。
- **Next exact action**：交付 Build184 IPA，让用户在 iPhone 15 Pro Max / iOS 17.0 真机确认“视频信息”最终位置、标题文案和 19pt section header 视觉层级，同时快速回归 Build182 已冻结的滚动与冷启动详情恢复不退化。只有用户接受后才把 Build184 UI 标记 stable/完成并考虑合并。
- **Rejected / do-not-repeat**：不要因视觉调整重新打开 Build182 性能/缓存问题；不要改 full-screen blur；不要调整媒体流数据内容或播放 authority；不要改 episode ordering；不要触碰播放器/Transport。
