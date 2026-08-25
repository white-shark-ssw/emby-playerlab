# DEV-add-emby-page-optimization

## Status

**Active**

- **Work ID**：`DEV-add-emby-page-optimization`
- **Routing aliases / keywords**：添加 Emby 页面 / 添加服务器 / Emby 服务器添加 / Add Emby / Add Server
- **Task**：重做 OnePlayer 的 Add/Edit Emby 页面，并实现一键粘贴、自动启动、iCloud 同步和同服多线路选优。

## User intent / acceptance criteria

1. Add Emby 不再使用简陋系统 Form，改为现代 iOS 卡片式 UI。
2. 保留服务器地址、用户名、密码；去掉顶部副标题、helper、安全说明等解释文字。
3. 有明显的“一键粘贴”区域；剪贴板若含服务器/账号/密码应自动填入。当前实现支持中文/英文标签格式、URL + 后续账号密码的基础多行格式，并可把多条直接 URL 导入聚合线路；后续真机样例优先于继续猜 parser。
4. `iCloud 同步` 默认开启；不能是假 Toggle；密码仍绝不落盘/同步。
5. `自动启动`：App 冷启动时直接以目标 Emby 为根内容，不能先渲染一级服务器页再 fullScreenCover/快速切入。
6. **自动启动必须缓存首页优先**：恢复本地 session/token 后立即创建目标 Emby 首页，用现有 Home UserDefaults 快照 + 图片磁盘缓存先显示上一次内容；同时后台执行同服线路选优/联网刷新。即使当前 Emby/线路不可达，也保留旧首页，不得因为线路选择失败退回一级服务器页。旧数据可接受，网络恢复后再刷新为最新数据。
7. 同一 Emby 可配置多条入口；添加/编辑页显示真实延迟、失败/不匹配、最快标记。
8. **延迟只在 Add/Edit Emby 页面可见。** 服务器列表、首页、收藏、搜索、设置、自动启动过程均不显示测速数字。
9. 正常进入 Emby 时允许多线路无感竞速；线路通过同服 `System/Info/Public` 校验，赢家成为会话 client；Home API/海报图片沿用赢家，不做每张海报多线路重复下载。
10. 运行时赢家线路需要记为当前 serverURL，因为现有 `EmbyImageDiskCache` 的稳定 key 保留 host/base URL；这样下一次自动启动用上次赢家生成图片 URL，才能最大化直接命中旧海报磁盘缓存。
11. 编辑服务器时密码框也必须始终可见。密码字段默认空：留空继续使用现有 AccessToken；输入新密码时只允许对当前 stored username 重新认证，认证结果必须仍为同一 Server ID / User ID，然后仅替换 AccessToken。密码仍不保存、不同步。
12. 多线路只改变 Emby API/server entry。媒体仍是 Emby/STRM → 302 → 115/CDN → iPhone；NAS 不得中转媒体字节。
13. Deployment Target 保持 iOS 15.0；Player/PiP/UnifiedTransport/Cache/Seek/Resume/episode ordering 等 Frozen/P0 合同不变。

## Baseline / identity

- Accepted overall runtime：OnePlayer **0.14.24 / Build191**，PR #257 已合并 `main`。
- Initial base：`main@b1837067aa7f167f28d26f966428fb46502d9373`。
- Working branch：`feat/add-emby-page-optimization`。
- First implementation product head：`2d9aca2002e9788d217410d4a8b16772ef79d814`。
- Current follow-up product commit：`571f54647ebc2d8ac811c63bf8c548f234172152`。
- Current clean feature head after applicator cleanup：`85a16c5bbbf02556c5c8ed4c2fe532b0b3d8d269`。
- Draft PR：**#256** — `Add modern Emby server editor and multi-route startup`。
- Latest Build196 reservation check：`main@908263723a3f8dbc880d6976f051a698b074b49e`，Build195 已归播放器 lazy-row 任务；仓库未发现 Build196 owner。
- Previous candidate：OnePlayer **0.14.25 / Build192** — 已产生真机反馈，未接受。
- **Next candidate reserved：OnePlayer 0.14.29 / Build196** — purpose = edit password + cached-first auto-start + runtime winner persistence。

## Source evidence / architecture

- `ServerListView.swift` 是真实 Add/Edit Server 入口；Build192 的编辑模式通过 `if editingSession == nil` 隐藏整个密码行，且 `updateServer(...)` 不接收密码，因此不能只把 UI 行露出来而静默忽略输入。
- `SessionStore` 是并继续作为 sessions、token、server configuration、route selection、auto-start identity 的单一 owner。Build196 follow-up 仅让 edit password 非空时在已验证同服最佳线路重新认证，并要求 `auth.user.id == stored.user.id`；空密码不触发重新登录。
- `AuthenticationResult` 真实包含 `user / accessToken / serverId`，因此可验证同一个 Server ID / User ID 后再替换 token，无需猜 API。
- `RootView` 负责真正的自动启动根路由。Build196 follow-up 在恢复 auto-start session 后同步创建本地 `client(for:)`，不等待网络即可构造 Emby root。
- `V3EmbyHomeViewModel` 已有持久 Home 快照：libraries、resume、latest、carousel 均按 serverId/userId 从 UserDefaults 恢复；初始化后才执行 live `refresh()`。因此不新增第二套“离线首页”状态。
- `EmbyImageDiskCache` 已有真实磁盘缓存；其 `stableKey(for:)` 只移除 token query，仍保留 scheme/host/path，所以线路 host 会影响海报缓存命中。Build196 follow-up 因此在运行时竞速成功后记住赢家 serverURL，供下一次缓存优先启动生成相同图片 URL。
- `EmbyServerRootViewV3` Build192 会在 `clientForBestRoute` 成功前只显示连接 ProgressView，并在失败时 `close()`。Build196 follow-up 只对 RootView 传入 initial client 的 auto-start 路径启用 cached-first：先显示 Home；后台选优成功若线路变化则重建 Home StateObject 使用赢家刷新；选优失败保留缓存 Home，不 close。
- 手动从一级服务器页进入时没有 initial client，仍保留原来的“先选优再创建 Home”语义；本轮不扩大行为范围。
- `EmbySession` schema 仍不扩展。Multi-route metadata 保持独立 `EmbyServerConfiguration`。

## iCloud decision

- Existing normal AccessToken storage remains `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` in the regular token account.
- Apple Security `kSecAttrSynchronizable` is the selected real sync mechanism: synchronizable generic-password items replicate through iCloud and cannot use a `ThisDeviceOnly` accessibility class.
- `KeychainStore` has separate synchronizable set/get/remove methods using `kSecAttrAccessibleAfterFirstUnlock`.
- SessionStore writes one synchronizable registry containing only opt-in server configuration + AccessToken + auto-start flag. Password is never included. On restore, synced records rehydrate the existing local token account and session/config state.
- Edit password reauthentication only replaces AccessToken; `persistSessions()` then naturally refreshes the opt-in synced record with the new token if iCloud sync is enabled. Password itself never enters either local or synchronizable persistence.
- No CloudKit/KVS abstraction, timer, watcher, retry loop or fake sync Boolean was added.
- Runtime cross-device behavior is still **real-device pending**, especially under TrollStore/ad-hoc signing and the user's iCloud Keychain environment.

## Product files

- `Sources/UI/ServerListView.swift` — modern Add/Edit cards, one-tap clipboard parser, route add/remove/测速, editor-only latency/失败/不匹配/最快, auto-start/iCloud toggles; Build196 makes password row visible in Edit and passes optional edit password to SessionStore.
- `Sources/Session/SessionStore.swift` — Session-owned routes/probes/same-server validation/runtime winner/auto-start/synced registry; Build196 adds same-user password reauthentication and persists runtime route winner.
- `Sources/Core/KeychainStore.swift` — separate synchronizable keychain operations; existing local token API preserved.
- `Sources/App/RootView.swift` — direct auto-start root route; Build196 supplies a synchronous local-token client so cached Home can render before network.
- `Sources/UI/EmbyServerRootViewV3.swift` — Build196 renders initial cached Home immediately, concurrently resolves best route, rebuilds Home only when route changes, and keeps cached Home on auto-start route failure.

`EmbyHomeModelV3.swift`, `EmbyHomeCoreV3.swift`, `EmbyImageDiskCache.swift`, Player, Transport and Cache implementation files were inspected but are **not modified** by the Build196 follow-up.

## Frozen / parallel boundaries

- Zero intended changes to Player, PiP, UnifiedTransport, media Cache, Range/206, STRM/302/115 client-direct, Emby progress/Resume, Build176 episode session, Build178 canonical ordering, Build182 detail presentation cache, Home carousel owner.
- Current parallel Build195 player-picker task changes `PlayerEpisodeSelection.swift`; no file/state overlap with this Add Emby follow-up.
- Cached-first auto-start reuses existing Home snapshots/image disk cache rather than changing Home carousel/model ownership.
- MDK/KSPlayer PR workflows may run automatically from PR creation; they are experiment workflows and are not acceptance authority for this standard MPV task.

## Build191 collision / retired evidence

- This task briefly allocated OnePlayer 0.14.24 / Build191 before the then-current parallel detail owner became authoritative.
- Dedicated run `32875040639` succeeded, but that identity is retired for this task and must not be distributed/used for attribution.
- The authoritative accepted Build191 is the detail-selection build merged through PR #257.

## Build192 evidence and real-device result

- Build192 identity：**OnePlayer 0.14.25 / Build192**。
- Exact dedicated CI source：`49dd9bf9904efd4ef1e6d3ac4d1d57d960ea4f9b`。
- Dedicated standard MPV Release run：**`32875941745` — success**。
- Artifact：`OnePlayer-0.14.25-build192-add-emby-server`, ID **`9574058602`**。
- IPA SHA-256：**`b13b76d322c0b301b751ad3723ff0368cb9bc9d0182ec701cf5fcc7a16e4c81d`**。
- Compatibility：App + main runtime Mach-O MinOS **15.0**。
- 2026-08-26 target-device screenshot / user result on iPhone 15 Pro Max / iOS 17.0：编辑服务器卡片正常呈现；当前线路实际显示 **73 ms / 最快**；`自动启动` 与 `iCloud 同步` 开关均可见并为开启状态；但编辑页**缺少密码框**。
- User explicitly requires password row in Edit. This makes Build192 **real-device tested but not accepted** for the Add/Edit requirement.
- User also changed/clarified auto-start architecture: startup should show existing disk-cached Home immediately and then connect/route-select/refresh; stale data is preferable to failing to enter Emby. This new cached-first contract supersedes Build192's pre-Home network gate.
- Evidence level for Build192：**Code written / CI passed / IPA produced / real-device tested with actionable UI feedback / not accepted / not stable**。

## Build196 implementation state

- Reserved identity：**OnePlayer 0.14.29 / Build196**。
- Product commit：`571f54647ebc2d8ac811c63bf8c548f234172152`。
- Code written：**YES**。
- Edit password：always visible; empty retains token; non-empty reauthenticates stored username and rejects different User ID/Server ID before token replacement。
- Cached-first auto-start：RootView supplies local client immediately; existing Home snapshot/disk-image paths can render before route selection; background route failure does not close the auto-started server root。
- Runtime winner persistence：winner becomes stored `serverURL` so next cached-first launch can reuse the same host-based image cache keys。
- CI：**pending**。
- IPA：**pending**。
- Real-device：**pending**。
- Stable：**NO**。

## Next exact action

1. Build **OnePlayer 0.14.29 / Build196** using dedicated Xcode 16.4 standard MPV Release CI, preserving MinOS 15.0 and the five-file product scope.
2. Verify source contract: Edit password row unconditional; edit password does not persist; cached-first auto-start uses existing Home snapshot/image cache; route failure with initial client does not close; no Home/Player/Transport/Cache implementation file changed.
3. Produce and checksum unsigned IPA/source ZIP, then remove the temporary Build196 workflow from PR #256.
4. Target-device test Build196: Edit page password row visible; leave blank saves without relogin; supplied correct password refreshes token; wrong/different-user credentials fail without destroying current session.
5. Force-quit with `自动启动` ON after Home has cached data, then test with normal network and with Emby temporarily unreachable: old Home should appear directly without first-level server page/connection gate; when network is available it should refresh through the selected winner route.
6. Verify cached posters are available on relaunch where the previous winner URL is unchanged, and normal STRM/302 → 115/CDN playback remains client-direct.
7. iCloud cross-device behavior remains separately pending until actual second-device evidence exists.

## Rejected / do-not-repeat

- AppShell first appears then auto fullScreenCover into Emby.
- Auto-start waits for `clientForBestRoute` before constructing Home.
- Auto-start route failure closes Emby root back to the first-level server page when a valid local session/token exists.
- Fake iCloud Toggle with only local Boolean persistence.
- Persisting/syncing the user's password.
- Showing an Edit password field whose input is silently ignored.
- Per-poster multi-route duplicate downloads.
- Background periodic route timer/watchdog/retry.
- Media/NAS proxying as part of route aggregation.
- Rewriting Home model/cache or `EmbySession` merely for convenience when the existing snapshots and Session-owned configuration are sufficient.
