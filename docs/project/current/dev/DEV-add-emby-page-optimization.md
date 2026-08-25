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
5. `自动启动`：App 冷启动时直接以目标 Emby 为根内容，不能先渲染一级服务器页再 fullScreenCover/快速切入。允许在干净 loading 状态完成恢复/线路选择。
6. 同一 Emby 可配置多条入口；添加/编辑页显示真实延迟、失败/不匹配、最快标记。
7. **延迟只在 Add/Edit Emby 页面可见。** 服务器列表、首页、收藏、搜索、设置、自动启动过程均不显示测速数字。
8. 正常进入 Emby 时允许多线路无感竞速；当前合同为 client/Home 创建前通过同服 `System/Info/Public` 竞争，第一条有效同 Server ID 的 entry 成为本次会话 client；随后 Home API/海报图片沿用赢家，不做每张海报多线路重复下载。
9. 多线路只改变 Emby API/server entry。媒体仍是 Emby/STRM → 302 → 115/CDN → iPhone；NAS 不得中转媒体字节。
10. Deployment Target 保持 iOS 15.0；Player/PiP/UnifiedTransport/Cache/Seek/Resume/episode ordering 等 Frozen/P0 合同不变。

## Baseline / identity

- Accepted runtime：OnePlayer **0.14.17 / Build184**。
- Initial base：`main@b1837067aa7f167f28d26f966428fb46502d9373`。
- Working branch：`feat/add-emby-page-optimization`。
- Current product head：`2d9aca2002e9788d217410d4a8b16772ef79d814`。
- Draft PR：**#256** — `Add modern Emby server editor and multi-route startup`。
- PR creation observed main advance through docs-only commits; latest observed main is `a2d99adc36854b19c3db6dfe083ebcc5c6509928`. Comparison from initial base showed only `docs/project/*` changes, no product-source overlap with this task's five modified files. Final merge/IPA must re-check main again.
- Build candidate：**not allocated yet**。Other active identities include carousel/detail Build numbers through 190; this task must select a new free identity after source validation.

## Source evidence / architecture

- `ServerListView.swift` was the real AddServer entry; old private `AddServerView` used system Form and called `SessionStore.addServer(...)`.
- `SessionStore` is and remains the single owner for sessions, token access, add/remove/activate and now server configuration/route selection/auto-start identity.
- `EmbySession` remains unchanged. Multi-route metadata is stored separately as `EmbyServerConfiguration` keyed by session ID, avoiding a broad shared-model Codable migration.
- `RootView` previously always constructed `AppShellView` first; auto-start is implemented at root routing before AppShell exists.
- `EmbyServerRootViewV3` previously created one fixed `EmbyAPIClient` before rendering Home. It now awaits SessionStore best-route selection at that same pre-Home boundary.
- `V3EmbyHomeViewModel` remains untouched and still owns one fixed client. Poster URL/image loader files remain untouched; winner route naturally owns subsequent image URLs/cache keys.

## iCloud decision

- Existing normal AccessToken storage remains `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` in the regular token account.
- Apple Security `kSecAttrSynchronizable` is the selected real sync mechanism: synchronizable generic-password items replicate through iCloud and cannot use a `ThisDeviceOnly` accessibility class.
- `KeychainStore` now has separate synchronizable set/get/remove methods using `kSecAttrAccessibleAfterFirstUnlock`.
- SessionStore writes one synchronizable registry containing only opt-in server configuration + AccessToken + auto-start flag. Password is never included. On restore, synced records rehydrate the existing local token account and session/config state.
- No CloudKit/KVS abstraction, timer, watcher, retry loop or fake sync Boolean was added.
- Runtime cross-device behavior is still **real-device pending**, especially under TrollStore/ad-hoc signing and the user's iCloud Keychain environment.

## Files changed in first implementation

- `Sources/UI/ServerListView.swift` — modern Add/Edit cards, password reveal, one-tap clipboard parser, route add/remove/测速, latency/失败/不匹配/最快 visible only in editor, auto-start/iCloud toggles, context-menu edit entry.
- `Sources/Session/SessionStore.swift` — Session-owned route configuration/probes, same-server validation, best route on add/edit, first-valid same-ID runtime race, single auto-start ID, synchronizable registry persistence/restore.
- `Sources/Core/KeychainStore.swift` — separate synchronizable keychain operations; existing local token API preserved.
- `Sources/App/RootView.swift` — startup resolving state and direct auto-start root route without first-level AppShell flash.
- `Sources/UI/EmbyServerRootViewV3.swift` — async best-route client before Home render and optional root `onClose`.

## Frozen / parallel boundaries

- Zero intended changes to Player, PiP, UnifiedTransport, Cache, Range/206, STRM/302/115 client-direct, Emby progress/Resume, Build176 episode session, Build178 canonical ordering, Build182 detail performance/cache, Home carousel owner.
- Parallel detail/carousel tasks have no current file overlap with this five-file product diff.
- MDK/KSPlayer PR workflows may run automatically from PR creation; they are experiment workflows and are not acceptance authority for this standard MPV task.

## Validation state

- **Code written**：YES — first implementation on product head `2d9aca2`.
- **Draft PR**：#256.
- **Validate Source**：run `32873926692` queued at checkpoint time.
- **KSPlayer Lab PR workflow**：run `32873926668` in progress at checkpoint time; not task acceptance authority.
- **MDK Lab PR workflow**：run `32873926739` failed at its MDK local-file contract before build; unrelated to the standard MPV product path and not evidence that this feature compiles/fails.
- **CI passed**：NO, pending Validate Source.
- **IPA produced**：NO valid task IPA.
- **Real-device tested**：NO.
- **Stable / frozen**：NO.

## Next exact action

1. Wait for PR #256 `Validate Source` and inspect exact build errors if it fails.
2. Fix only evidence-backed compile/contract issues; keep diff restricted to the five current files unless validation proves another file is required.
3. After source validation passes, re-check active Build identities and allocate the next free OnePlayer version/Build.
4. Produce a dedicated standard MPV Release/IPA candidate with app identity + MinOS 15.0 + frozen/P0 zero-diff checks.
5. User real-device test must cover modern Add UI, clipboard credentials, multi-route latency only in Add/Edit, route winner behavior, no first-level auto-start flash, iCloud sync where available, and unchanged 302→115/CDN playback.

## Rejected / do-not-repeat

- AppShell first appears then auto fullScreenCover into Emby.
- Fake iCloud Toggle with only local Boolean persistence.
- Per-poster multi-route duplicate downloads without new evidence.
- Background periodic route timer/watchdog/retry.
- Media/NAS proxying as part of route aggregation.
- Rewriting `EmbySession` or Home model merely for convenience when separate Session-owned configuration is sufficient.
