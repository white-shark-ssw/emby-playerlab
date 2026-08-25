# DEV-detail-episode-page-optimization

## Status

**Active**

- **Work ID**：`DEV-detail-episode-page-optimization`
- **Routing aliases / keywords**：详情页优化 / 详情页 / 选集页 / 剧集页 / detail page / episode page
- **Task**：优化 OnePlayer 的媒体详情页与选集/剧集页面。第一阶段由用户真机录屏明确为两项：1）同一剧集详情页退出后再次进入时，不应再次明显经历“文字剧名 → Logo 图片”以及剧集/季等下方内容重新出现的加载过程；2）详情页纵向滑动应消除当前明显的顿挫、抖动和不连续感。
- **User intent / acceptance criteria**：首次没有本地详情数据时允许真实网络加载；同一 App 会话内已访问过的详情再次进入应优先恢复可安全复用的详情展示元数据和既有图片缓存，不再先显示文字标题后切 Logo，也不应让已加载的剧集/季/类似内容从空态重新出现；后台仍必须取得当前 Emby 数据，Resume/已看/收藏状态仍由服务器拥有。详情纵向滚动必须连续跟手，不出现录屏中的明显停顿、跳动或追帧感。
- **Baseline**：产品运行时基线仍为用户已接受并合并的 OnePlayer 0.14.11 / Build178。本任务 feature branch `feat/detail-episode-page-optimization` 基于 accepted Build178 runtime `main@967b743c88d68b05205eb39f1de75cab41362e8b`。Build179/Build180 首页轮播线未替代 Build178 accepted runtime。
- **Working branch / PR / head commit**：branch `feat/detail-episode-page-optimization`；PR = none；workflow-restored branch head `a8c445af44036218c6c085ae3b4b657ddb0902b1`。
- **Build candidate**：**OnePlayer 0.14.14 / Build181**；artifact `OnePlayer-0.14.14-build181-detail-page-performance`。本任务原先曾构建 0.14.13 / Build180，但并行首页任务后来也占用同号，形成同号不同产品；详情 Build180 因身份冲突作废为用户测试基线，现以 Build181 为唯一详情测试身份。
- **Evidence / root cause**：用户 2026-08-25 真机录屏明确显示重复进入时先出现文字剧名再切换 Logo，下方剧集区域重新异步出现，且详情纵向滑动不连续。源码确认图片字节本身已有 decoded-memory + disk-data cache；缺失的是新 `EmbyMediaDetailViewModel` 的 warm display metadata。滚动侧确认旧实现把原生 `UIScrollView.contentOffset` 高频写到详情根 `@State heroRawScrollMinY`，使整棵详情树参与每帧失效。
- **Implementation**：新增 `EmbyDetailHeroScrollState` + `EmbyDetailHeroScrollScope`，让高频 offset 只由 Hero subtree 观察；原生 ScrollView、stretch/crop/pin 数学不变。新增 session-level `EmbyMediaDetailWarmCache`（系统 `NSCache`），仅保存 `episodes / seasons / imageInfos / similarItems`；命中后先恢复首帧展示，正常 `load()` 仍继续发真实 Emby 请求并整体刷新。PlaybackInfo、MediaSource、PlaySession、ResolvedPlaybackSource、115/CDN 临时 URL 均不进入 warm cache。
- **Files / modules in scope**：产品改动为 `Sources/UI/EmbyMediaDetailView.swift`、`Sources/UI/EmbyDetailPerformanceState.swift`、`Sources/Core/AppIdentity.swift`；静态合同为 `scripts/check_detail_page_performance.py`，并只更新 `scripts/check_adaptive_hero_reveal.py` 中一条与新局部状态 owner 冲突的过时结构断言。共享图片实现、EmbyAPIClient、ImmersiveUIComponents、Player、Transport、Cache、Navigation 均未改。
- **Frozen / inherited contracts**：MPV fast Seek、PiP Build173、UnifiedTransport、Session cache、STRM/302/115 客户端直连、Range/206、Emby Resume/progress、native navigation、Player episode session replacement / trusted-natural-end auto-next 均保持现有合同；Emby episode canonical order 继续由 `/Shows/{SeriesId}/Episodes` 返回顺序拥有。
- **Build181 CI evidence**：dedicated standard MPV Release CI source `917c43554876ce7c8751c10356f081cf2c1fe92b`；run `32845717063` **success**；artifact ID `9562323675`；artifact digest `sha256:91b4f6ef3f746197836da99f064d1b0c8791b8d4f49a19eaa7e0d2898de833ae`；IPA `OnePlayer-0.14.14-build181-detail-page-performance-unsigned.ipa`；IPA SHA-256 `698d80d59767134c9479d517cedf24bf6494e73099d2f9125fa3d7a431d5a2f8`。CI 通过 detail performance、既有 Hero、detail range/media/resume、Build178 episode-ordering、Frozen zero-diff、Xcode 16.4 Release、0.14.14 (181) app identity、iOS 15.0 MinOS、IPA packaging/upload。临时 workflow 已恢复。
- **Conflicted Build180 evidence**：detail Build180 run `32843951020` 也曾成功编译/打包，IPA SHA-256 `53fec4411038cae6fbff3c4f6ec827954d5a98674d95892c0095e6aec46f9b54`；仅因与首页 0.14.13 / Build180 同号而废弃，不作为真机测试基线。
- **Validation state**：Current wrong behavior = **real-device confirmed**；root causes = **source confirmed**；Code written = **yes**；CI passed = **yes**；IPA produced = **yes**；fixed behavior real-device tested = **no**；Stable/frozen = **no**。
- **Next exact action**：用户在 iPhone 15 Pro Max / iOS 17.0 安装 Build181 真机复测。重点：同一剧第一次进入→退出→再次进入是否直接保持 Logo/剧集区；Resume/已看/收藏刷新是否仍正确；持续慢拖、快速甩动、上下反复滑动是否仍有顿挫。若状态隔离后仍明显卡顿，下一证据点才检查 persistent full-screen `.blur(radius: 30)` 合成成本，不提前同时改 GPU 视觉管线。
- **Rejected / do-not-repeat**：不要新增第二套图片字节缓存；不要缓存 PlaybackInfo/PlaySession/MediaSource/ResolvedPlaybackSource/115-CDN 临时 URL；不要用 debounce/throttle 降低滚动响应；不要改 episode canonical order；不要替换原生 ScrollView；不要继续分发身份冲突的详情 Build180。
- **Open questions / risks**：warm episodes 的 `LibraryItem.UserData` 首帧可能短暂旧于服务器，因此 warm data 只作为展示快照，真实 load 仍是最终 authority。录屏 30fps 可证明视觉顿挫但不能直接代表设备 120Hz frame-time；最终性能结论必须以 Build181 目标真机测试为准。
