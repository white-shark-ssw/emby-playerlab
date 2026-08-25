# DEV-add-emby-page-optimization

## Status

**Active**

- **Work ID**：`DEV-add-emby-page-optimization`
- **Routing aliases / keywords**：添加 Emby 页面 / 添加服务器 / Emby 服务器添加 / Add Emby / Add Server
- **Task**：重做 OnePlayer 的“添加 Emby 服务器”页面，并扩展与该页面直接相关的服务器启动、剪贴板导入、iCloud 同步与同服多线路入口能力。

## User intent / acceptance criteria

用户已明确以下产品要求：

1. 当前系统 `Form` 风格过于简陋，添加服务器页改为现代化 iOS 卡片式界面。
2. 保留服务器地址、用户名、密码三个核心输入。
3. 增加明显的“一键粘贴”区域；剪贴板内容如果同时含有服务器地址、用户名、密码，应自动填入对应字段，而不是只粘贴 URL。具体可识别的剪贴板格式需依据真实输入样例定义，不得凭空猜格式。
4. 增加 `iCloud 同步` 设置项，并保持此前要求：默认开启。同步必须是真实功能，不能只做假 Toggle；密码仍不得以明文同步/持久化。
5. 原计划中的“设为默认服务器”改为 `自动启动`。开启后，冷启动/重新进入 App 时应直接把该 Emby 作为根目标：**不能先显示一级服务器页面，再用 fullScreenCover/导航快速切入 Emby**，也不能出现一级页面闪现。启动路由必须先决定目标根界面。
6. 用户要求去掉所有说明性文案。新版页面不显示顶部副标题、字段下 helper text、安全说明卡、Toggle 说明文字等冗余说明；只保留必要的字段名、区域名、操作名和错误信息。
7. 增加“多线路聚合”区域。同一个 Emby 允许配置多个服务器入口线路，客户端根据可验证的连接表现选择当前最快可用入口。
8. **线路延迟只允许在添加 Emby / 编辑 Emby 页面显示。** 首页、服务器列表、自动启动过程、收藏/搜索/设置以及其他正常使用页面都不显示线路延迟、测速数字或“最快 xx ms”等诊断 UI。
9. 正常运行时允许利用多线路做无感选优。用户明确接受：进入 Emby / 首次读取海报墙时可以让多个线路并发参与同一首屏数据读取，以真实完成速度选出当前优线路；选优过程不需要对用户可见。
10. 运行时多线路选优不应扩大为“每张海报图片都同时从所有线路重复下载”。优先在进入 Emby、创建实际 client / 首页首屏元数据请求之前完成一次同服线路竞争，赢家成为当前会话入口；后续首页 API 和海报图片沿用该入口。只有新的真实性能证据证明逐图片竞速有必要时才允许重新评估。
11. 多线路只改变 **Emby API/server entry** 的入口选择，不得改变媒体数据合同：正常播放仍是 Emby/STRM → HTTP 302 → 115/CDN → iPhone；NAS 绝不能成为媒体字节中转站。
12. 自动启动与多线路组合时，应先完成该 Emby 的启动入口解析/线路选择，再直接渲染 Emby 根界面；不能为了测速先展示一级服务器页。
13. 保持 iOS 15.0 Deployment Target；不触碰 Player/PiP/UnifiedTransport/Cache/Seek/Resume/episode ordering 等 Frozen/P0 合同。

## Baseline

- Accepted product runtime：OnePlayer **0.14.17 / Build184**。
- Base branch：`main`
- Base commit / branch creation head：`b1837067aa7f167f28d26f966428fb46502d9373`
- Target device：iPhone 15 Pro Max / iOS 17.0
- Deployment Target：保持 iOS 15.0。

## Working branch / PR / head commit

- Working branch：`feat/add-emby-page-optimization`
- Branch created from：`main@b1837067aa7f167f28d26f966428fb46502d9373`
- Current product head：`b1837067aa7f167f28d26f966428fb46502d9373`（截至本 checkpoint，仅需求/源码分析，无产品代码修改）
- PR：none
- Build candidate：暂不分配。

## Source evidence

### Current Add Server UI

- `Sources/UI/ServerListView.swift`
  - 右上角 `+` 通过 `showingAddServer = true` 打开 sheet。
  - 真实添加页是同文件内私有 `AddServerView`。
  - 当前只持有 `server / username / password` 三个本地输入状态，并调用 `sessionStore.addServer(serverText:username:password:)`。
  - 当前 UI 是系统 `Form + Section`，没有一键粘贴、自动启动、iCloud、多线路能力。

### Session owner

- `Sources/Session/SessionStore.swift`
  - 当前是添加服务器行为 owner：URL 规范化、`publicInfo()`、认证、Keychain token、sessions 持久化、activate/leave/remove。
  - 现有 `sessions` 存 UserDefaults，AccessToken 存 Keychain；密码不落盘。
  - 不能为了新版 UI 创建第二套 session/error/connection authority。

### Startup routing

- `Sources/App/RootView.swift`
  - 当前 `RootView` 无条件渲染 `AppShellView()`，仅在 `onAppear` 调 `sessionStore.restore()`。
- `Sources/UI/AppShellView.swift`
  - 当前根 UI 无条件先创建“服务器/设置” TabView。
  - 打开 Emby 的真实路径是设置 `selectedSession` 后使用 `.fullScreenCover(item:)` 展示 `EmbyServerRootViewV3`。
  - 因此若只在现有 `AppShellView` 上做“恢复后自动 selectedSession”，必然存在一级页先被创建/可能闪现的问题，不符合用户要求。
  - 自动启动应改为 root startup routing：恢复配置 → 判断 auto-start target → 必要时解析线路 → 直接选择 `EmbyServerRootViewV3` 或普通 `AppShellView` 作为根内容。

### Current model/networking boundary

- `Sources/Models/EmbyModels.swift`
  - `EmbySession` 当前只有单个 `serverURL: URL`。
- `Sources/Networking/EmbyAPIClient.swift`
  - `EmbyAPIClient` 初始化后固定绑定单个 `baseURL`。
  - `publicInfo()` 使用轻量匿名 `System/Info/Public`，可作为验证线路确实指向 Emby/server identity 的现有 API 证据点。
  - `imageURL(...)` 直接由当前 client 的 `baseURL` 生成海报/Backdrop URL，因此正常图片加载天然跟随已经选中的 Emby entry。
- 因此真实“同服多线路”需要扩展服务器入口模型/SessionStore 选择逻辑；不能只在 AddServer UI 中保存几个无效文本框。

### Home / poster-wall load boundary

- `Sources/UI/EmbyServerRootViewV3.swift`
  - 当前在 `client == nil` 时先调用 `sessionStore.client(for: session)`；只有 client 创建完成后才渲染 `V3EmbyHomeView`。
  - 这提供了一个天然的线路选择边界：可在真正创建/提交当前 Emby client 之前完成多线路竞争，不需要先显示一级服务器页，也不需要首页运行后切换 client。
- `Sources/UI/EmbyHomeModelV3.swift`
  - `V3EmbyHomeViewModel` 将 client 保存为 `private let client`。
  - 首页 refresh 已经并发请求 `userViews()` 与 `resumeItems()`，随后再并发拉各媒体库 latest/items；当前这些并发全部走同一个 client/baseURL。
  - 因此不应在首页 model 已建立后再动态换线路；更干净的方案是在 model/client 建立前确定当前 entry。
- `Sources/UI/EmbyServerSharedV3.swift` / `Sources/UI/EmbySharedImageAndNavigation.swift`
  - 海报使用 `client.imageURL(...)` 生成一个具体 URL，图片 loader 对这个 URL 执行单路缓存/下载。
  - 当前缓存以 URL 为 key。若每张图片同时对多个线路竞速，会把同一逻辑图片变成多个 URL/cache key 并成倍增加请求；目前没有真实证据支持这种复杂度。

## Files / modules in scope

Expected / needs evidence before edits:

- `Sources/UI/ServerListView.swift` — AddServer UI、粘贴、多线路编辑入口。
- `Sources/Models/EmbyModels.swift` — 若确认多线路需要正式持久化，则扩展 Emby session/server-entry model。
- `Sources/Session/SessionStore.swift` — auto-start target、线路持久化/选择、现有 single-session owner 内扩展；不得创建第二 owner。
- `Sources/App/RootView.swift` / `Sources/UI/AppShellView.swift` — 仅为实现无一级页闪现的真正 startup root routing。
- `Sources/UI/EmbyServerRootViewV3.swift` — 可作为进入 Emby 前的 client/线路选择提交边界；不得把测速状态扩散到 Home UI。
- iCloud capability/entitlements/存储实现文件：必须先检查真实项目能力后决定，不能预设 CloudKit/KVS API 或 entitlement 名称。

Read-only / no-touch unless new evidence requires:

- `Sources/UI/EmbyHomeModelV3.swift` / `EmbyServerSharedV3.swift` / `EmbySharedImageAndNavigation.swift`：当前证据说明无需为了线路选优改逐项海报加载；只有实现首屏 race 确认确实需要最小接口变化时再触碰。
- Player、PiP、Transport、Cache、playback session、Emby progress/Resume、episode ordering。

## State owner / shared dependencies

- Add/Edit 页临时输入与线路测速展示状态由对应页面 owner 持有；测速数字不得成为全局可视状态。
- sessions、active session、token、auto-start server identity、多线路持久化/当前 entry 选择应保持在现有 Session 层的单一 owner 体系，不复制到 View 生命周期。
- App startup routing 可以读取 Session owner 的恢复/线路选择结果，但不能让播放器/Transport 生命周期依赖 SwiftUI View 生命周期。

## Multi-route design constraints confirmed so far

- “线路”定义为指向**同一个 Emby Server** 的多个入口 URL，而不是多个独立服务器账户。
- 添加/保存前需要验证线路属于同一个 Emby identity；已有 `System/Info/Public` 可提供 server ID/ServerName/Version 证据。
- 配置页“延迟”必须基于真实网络测量，不按域名顺序、用户输入顺序或猜测决定。
- 延迟数字只属于 Add/Edit 配置诊断 UI；运行时不显示。
- 运行时可在进入 Emby / 首屏加载前并发尝试多条同服 entry，并使用第一条完成有效请求的线路作为当前会话入口；竞争完成后，其余请求应取消/结束，不建立后台常驻竞速。
- 首页现有 client/model 是单 baseURL 生命周期，因此优先“会话/首屏选一次，后续单线路使用”，不做每张海报多线路重复下载。
- 当前没有证据需要后台常驻测速、timer、watchdog、周期重试或媒体链路测速；不要先加入。

## iCloud constraints confirmed so far

- iCloud Toggle 默认开启。
- 必须是真实同步，不允许只保存一个 UI 布尔值制造“已同步”假象。
- 密码继续不落盘、不明文进 iCloud。
- AccessToken 当前在 Keychain；是否以及如何跨设备同步 token 必须先检查现有 Keychain accessibility/synchronizable 能力、entitlements 与安全边界，再决定，不能猜。

## Frozen / do-not-touch

- MPV fast Seek、PiP Build173、UnifiedTransport、Session cache、Range/206、STRM/302/115 client-direct、Emby Resume/progress、Build176 player episode session、Build178 canonical episode order、Build182 detail scroll/presentation cache均保持不变。
- NAS 不得成为媒体字节中转站。
- 不提高 Deployment Target。
- 不新增 speculative retry、fallback、timer、watchdog、兼容 shim 或重复状态 owner。

## Parallel conflicts checked against

- `DEV-detail-episode-selection-navigation`：主要范围 `EmbyMediaDetailView.swift` / `EmbyEpisodePickerView.swift`；当前无直接文件重叠。
- `DEV-home-carousel-drag-smoothness`：Home carousel owner/files；当前无直接文件重叠。当前多线路设计也不需要改 carousel owner；最终实现若必须碰 `EmbyHomeModelV3.swift`，需再次核对该并行任务是否已修改/依赖对应 Home 文件。
- 新需求会触及 `AppShellView.swift` / root/session/model，但现有两个 Active checkpoint 当前未声明这些文件/owner；可继续并行。最终 CI/merge 前必须重新检查。

## Completed

- 完成任务初始化与 branch 建立。
- 定位 AddServer UI、SessionStore、Root/AppShell startup 路由、EmbySession 与 EmbyAPIClient 的真实定义。
- 用户已确认新版 UI/交互方向：现代卡片 UI、一键粘贴（含账号密码）、iCloud、自动启动、同服多线路、删除说明文案。
- 用户进一步确认：线路延迟只在 Add/Edit Emby 页面显示；正常页面不显示任何延迟诊断 UI。
- 用户允许首屏/海报墙加载阶段利用多线路并发做无感选优。
- 已确认“自动启动”不能通过一级页加载后再 fullScreenCover 的方式实现。
- 已确认 `EmbyServerRootViewV3` 的 client 建立点位于 Home 渲染之前，适合作为多线路选择的提交边界。
- 已确认当前海报 URL/缓存是单 URL 路径，暂没有证据支持逐图片多线路竞速。
- 已确认多线路是 Emby API entry 层能力，不能触碰媒体 302→115/CDN 客户端直连合同。

## Validation state

- **Requirements/source architecture inspected / no product code written yet**。
- 无 CI、无 IPA、无真机结论。

## Pending

1. 检查当前 app entitlements / Keychain implementation / iCloud capability，确定真实可用的 iOS 15 同步方案。
2. 获取或明确“一键粘贴”实际剪贴板样例/格式后，只实现有证据覆盖的解析格式。
3. 设计最小的同服多线路持久化模型，以及 Add/Edit 可见测速 + runtime 首屏无感 race 的选择流程，并确认 token 在同 server 多入口下的真实使用边界。
4. 设计 root startup state，保证 auto-start 时一级服务器页根本不被作为过渡 UI 展示。
5. 最后再开始代码修改。

## Next exact action

1. 读取 project entitlements、KeychainStore、App capabilities，确定 iCloud 同步真实边界。
2. 确定多线路最小模型与两种测量场景：Add/Edit 页面显示延迟；runtime 首屏只做无 UI 的 entry race。
3. 依据现有 `EmbyServerRootViewV3` client 创建点实现“先选 entry，再创建 client/Home”，避免首页建立后动态换 client。
4. 基于上述证据实现同一 Emby session 的多个 entry URLs + 单一 auto-start identity + startup root route。
5. 重做 AddServer UI；不加入说明文字，只保留现代卡片分区、字段、操作、Toggle、线路列表与错误。
6. 增加窄 static/source contracts，先验证 root routing / no first-level flash / no playback-core diff / password no-persist / multi-route server identity / latency visibility scope。
7. 形成可测产品基线后再分配未被其他 Active task 占用的 Build/version candidate。

## Rejected / do-not-repeat

- 不使用“AppShellView 先出现 → 自动设置 selectedSession → fullScreenCover 快速盖住”的伪自动启动方案。
- 不做只有视觉没有真实同步行为的 iCloud Toggle。
- 不在首页/服务器列表等正常页面显示线路延迟。
- 不默认做每张海报跨所有线路的重复请求/竞速；当前证据支持先选会话入口，再单线路加载海报。
- 不把多线路做成媒体 URL/CDN 代理或 NAS 中转。
- 不在没有剪贴板格式证据时堆大量猜测 parser/fallback。
- 不增加后台常驻测速 timer/watchdog/retry。
- 不因本任务改 Player/Transport/Cache/PiP。

## Open questions / risks

- 一键粘贴的真实常用剪贴板文本格式尚未提供；实现 parser 前需要实际样例或明确格式合同。
- `自动启动` 开关默认值用户尚未明确；iCloud 默认开启已明确。
- runtime 首屏 race 最终选用 `System/Info/Public`、认证后的 `userViews()`，还是更接近首屏真实负载的最小请求，需要结合 token/请求成本与实际代码改动选择；目标是“真实选优、无可见延迟 UI、无后台常驻测速”。
