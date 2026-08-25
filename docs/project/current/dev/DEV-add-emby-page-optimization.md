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
6. **自动启动必须缓存首页优先**：恢复本地 session/token 后立即创建目标 Emby 首页，用现有 Home UserDefaults 快照 + 图片磁盘缓存先显示上一次内容；同时后台执行同服线路选优/联网刷新。即使当前 Emby/线路不可达，也保留旧首页，不得因为线路选择失败退回一级服务器页。
7. 同一 Emby 可配置多条入口；添加/编辑页显示真实延迟、失败/不匹配、最快标记。
8. **延迟只在 Add/Edit Emby 页面可见。** 服务器列表、首页、收藏、搜索、设置、自动启动过程均不显示测速数字。
9. 正常进入 Emby 时允许多线路无感竞速；线路通过同服 `System/Info/Public` 校验，赢家成为会话 client；Home API/海报图片沿用赢家，不做每张海报多线路重复下载。
10. 运行时赢家线路需要记为当前 `serverURL`，因为现有 `EmbyImageDiskCache` 稳定 key 保留 host/base URL；下一次缓存优先启动才能最大化命中旧海报磁盘缓存。
11. 编辑服务器时密码框必须始终可见。默认空：留空继续使用现有 AccessToken；输入新密码时只允许对 stored username 重新认证，且必须仍为同一 Server ID / User ID，然后仅替换 AccessToken。密码不保存、不同步。
12. 多线路只改变 Emby API/server entry。媒体仍是 Emby/STRM → 302 → 115/CDN → iPhone；NAS 不得中转媒体字节。
13. Deployment Target 保持 iOS 15.0；Player/PiP/UnifiedTransport/Cache/Seek/Resume/episode ordering 等 Frozen/P0 合同不变。

## Baseline / identity

- Accepted overall runtime：OnePlayer **0.14.24 / Build191**，PR #257 已合并 `main`，merge `f153a36e9da8a208150fe638e0b9df5835df1dc0`。
- Initial task base：`main@b1837067aa7f167f28d26f966428fb46502d9373`。
- Working branch：`feat/add-emby-page-optimization`。
- Draft PR：**#256** — `Add modern Emby server editor and multi-route startup`。
- First implementation product head：`2d9aca2002e9788d217410d4a8b16772ef79d814`。
- Cached-first/password follow-up product commit：`571f54647ebc2d8ac811c63bf8c548f234172152`。
- Build191 tree resync commit：`415abd6bba8d35525f1cc510cc911a4f25538115`。
- Exact Build197 CI source：`a4362240844caf1a94503ca654ac01b1e5f51a45`。
- Previous candidate Build192 / 0.14.25：真机有反馈但未接受。
- Build196 / 0.14.29：旧分支树曾通过 CI 并产生 IPA，但后续核验发现其源码树未完整继承已接受 Build191（例如 `AppIdentity.sourceVersion` 仍为 0.14.17）。**该 Build196 IPA 退休，不分发、不作为最终真机归因。**
- **Current candidate：OnePlayer 0.14.30 / Build197** — Build191 accepted tree + Add Emby five-file product changes。

## Source evidence / architecture

- `ServerListView.swift` 是真实 Add/Edit Server 入口；Edit 密码输入现在真实传入 SessionStore，不再存在“显示但忽略”的假输入。
- `SessionStore` 继续作为 sessions、token、server configuration、route selection、auto-start identity 的单一 owner。非空 edit password 在已验证同服最佳线路重新认证，并要求同一 Server ID / User ID；空密码不触发重新登录。
- `RootView` 负责自动启动根路由；恢复 auto-start session 后同步创建本地 `client(for:)`，无需等待网络即可构造 Emby root。
- `V3EmbyHomeViewModel` 现有 UserDefaults 快照（libraries / resume / latest / carousel）继续是唯一 Home 快照 authority；不新增第二套离线首页状态。
- `EmbyImageDiskCache` 继续是唯一图片磁盘缓存 authority；运行时赢家会记为当前 `serverURL`，让下次启动更容易命中同 host 的旧图片缓存。
- `EmbyServerRootViewV3` 对 auto-start initial client 路径先显示缓存 Home，再后台选优；选优成功且线路变化时重建 Home client；选优失败保留旧 Home，不 close。
- 手动从一级服务器页进入时没有 initial client，仍保留先选优再创建 Home 的语义。
- `EmbySession` schema 不扩展；multi-route metadata 保持独立 `EmbyServerConfiguration`。

## iCloud decision

- 普通 AccessToken 继续使用本机 Keychain `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`。
- iCloud 同步使用真实 `kSecAttrSynchronizable` generic-password item；synchronizable item 使用 `kSecAttrAccessibleAfterFirstUnlock`。
- SessionStore synchronizable registry 只包含 opt-in server configuration + AccessToken + auto-start flag；密码绝不进入本地或同步 registry。
- Edit password 成功后只替换 AccessToken；若 iCloud sync 开启，后续 `persistSessions()` 自然刷新同步 registry 中 token。
- 未新增 CloudKit/KVS abstraction、timer、watcher、retry loop 或 fake sync Boolean。
- TrollStore/ad-hoc 环境下的跨设备 iCloud 行为仍需真实第二设备验证。

## Product files

- `Sources/UI/ServerListView.swift` — modern Add/Edit cards、一键粘贴、多线路编辑/测速、editor-only latency、auto-start/iCloud toggle、Edit password。
- `Sources/Session/SessionStore.swift` — Session-owned routes/probes/same-server validation/runtime winner/auto-start/synced registry、same-user password reauthentication。
- `Sources/Core/KeychainStore.swift` — synchronizable Keychain operations；普通本机 token API 保持。
- `Sources/App/RootView.swift` — cached-first auto-start initial client。
- `Sources/UI/EmbyServerRootViewV3.swift` — initial cached Home + concurrent best-route resolution + stale Home retention。

Build197 resync 同时完整继承 Build191 已接受详情页源码树；Add Emby 自身仍只覆盖上述五个产品文件。`EmbyHomeModelV3.swift`、`EmbyHomeCoreV3.swift`、Player、Transport、Cache 实现未由本任务修改。

## Frozen / parallel boundaries

- Zero intended changes to Player, PiP, UnifiedTransport, media Cache, Range/206, STRM/302/115 client-direct, Emby progress/Resume, Build176 episode session, Build178 canonical ordering, Build182 detail presentation cache, Home carousel owner。
- 与并行 Build195 player-picker lazy-row 任务无产品文件/state owner 重叠；Build195 尚未被本候选夹带。
- Build197 的基线同步采用 Build191 已接受整棵源码 + Add Emby 五文件，避免夹带其他尚未接受并行候选。

## Build192 evidence / user result

- OnePlayer **0.14.25 / Build192**；dedicated run `32875941745` success；artifact `9574058602`；IPA SHA-256 `b13b76d322c0b301b751ad3723ff0368cb9bc9d0182ec701cf5fcc7a16e4c81d`。
- Target-device screenshot/result：编辑服务器 UI 正常；测试线路 **73 ms / 最快**；`自动启动`、`iCloud 同步` 均可见并开启；但 Edit 缺少密码框。
- User additionally required cached-first auto-start；因此 Build192 **real-device tested with actionable feedback / not accepted / superseded**。

## Build196 retired evidence

- OnePlayer **0.14.29 / Build196**；dedicated run `32885369998` success；artifact `9577471047`；IPA SHA-256 `b2c0e0a7af6aa29ad0f7117b88fadf3eb9a2c45c73bb961c7a63f50a2c763c66`。
- 这证明 cached-first/password follow-up 在旧 Add Emby 源码树上可编译、可打包。
- 后续源码核验发现该 branch tree 未完整继承 Build191 accepted tree，因此 **Build196 不再作为可分发真机候选；identity 已退休，不能再用 Build196 生成不同源码 IPA。**

## Build197 evidence

- Identity：**OnePlayer 0.14.30 / Build197**。
- Accepted-tree resync commit：`415abd6bba8d35525f1cc510cc911a4f25538115`。
- Exact dedicated CI source：`a4362240844caf1a94503ca654ac01b1e5f51a45`。
- Dedicated workflow：`Build197 Add Emby Build191 Baseline`。
- CI run：**`32886599900`**。
- Source / accepted-baseline contract：**PASS**。
- Xcode 16.4 standard MPV Release：**PASS**。
- App validation：**PASS**。
- Runtime MinOS validation：**PASS**, iOS 15.0 retained。
- IPA packaging/upload：**PASS**。
- Artifact：`OnePlayer-0.14.30-build197-add-emby-build191`，ID **`9577964658`**，artifact digest `sha256:9456912ee08efe70430ffa505847aef69ca4c4b03d3eed31561ae1c983517fb9`。
- IPA：`OnePlayer-0.14.30-build197-add-emby-build191-unsigned.ipa`。
- IPA SHA-256：**`c111fb5c57c8910ac47a3d9d60296529a629af1b874f87600a3f79f1686ec88a`**。
- Evidence level：**Code written / CI passed / IPA produced / real-device Build197 pending / not stable**。
- Build191 / 0.14.24 remains the accepted overall baseline until Build197 receives user real-device acceptance。

## Next exact action

1. Install **OnePlayer 0.14.30 / Build197** on iPhone 15 Pro Max / iOS 17.0。
2. Verify Edit page password row is visible；blank save keeps current token；correct password refreshes token；wrong/different-user credentials fail without destroying current session。
3. With `自动启动` ON and Home already cached, force-quit/relaunch under normal network and with Emby temporarily unreachable；cached Home should appear directly without first-level server page/connection gate。
4. Confirm online relaunch refreshes through the selected winner route and cached posters remain available where winner host is unchanged。
5. Confirm normal STRM/302 → 115/CDN playback remains client-direct；NAS must not relay media bytes。
6. iCloud cross-device behavior remains separately pending actual second-device evidence。

## Rejected / do-not-repeat

- AppShell first appears then auto fullScreenCover into Emby。
- Auto-start waits for `clientForBestRoute` before constructing Home。
- Auto-start route failure closes Emby root back to first-level server page when valid local session/token exists。
- Fake iCloud Toggle with only local Boolean persistence。
- Persisting/syncing password。
- Showing Edit password field whose input is ignored。
- Per-poster multi-route duplicate downloads。
- Background periodic route timer/watchdog/retry。
- Media/NAS proxying as route aggregation。
- Rewriting Home model/cache or `EmbySession` when existing snapshots and Session-owned configuration suffice。
- Reusing Build196 identity for a different source tree。
