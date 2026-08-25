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
- Latest pre-doc-sync conflict check：`main@6c72d5d9768d6348c7da281b4a58e4b7e8558071`。Parallel work has advanced through Build193 documentation/state; no product-source overlap with this task's five modified files was introduced before Build192 finalization.
- Current Build candidate：**OnePlayer 0.14.25 / Build192** — reserved for this task after Build191 identity collision was detected.

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

## Build191 collision / retired evidence

- This task briefly allocated **OnePlayer 0.14.24 / Build191** after the then-current docs showed no Build191 owner.
- Dedicated run `32875040639` at source head `32128f3905a86e2d2dfaab646c446840c6476595` completed successfully: task/Frozen contracts, Xcode 16.4 standard MPV Release, app identity, MinOS 15.0, unsigned IPA packaging and artifact upload all passed.
- Artifact `OnePlayer-0.14.24-build191-add-emby-server`, ID `9573677580`, digest `sha256:01e75e9fedf34ca146d2b3b1d3027841511763cf501497be48634d0fccc7f50a`.
- During/after that run, parallel detail task authoritatively reserved **OnePlayer 0.14.24 / Build191** in `docs/project/current/dev/DEV-detail-episode-selection-navigation.md` and `main@dd04f194...`.
- Therefore this task's Build191 artifact is **retired due to identity collision**: it is valid compile/IPA evidence for the same product code, but must not be distributed, used for real-device attribution, or treated as this task's active candidate.
- New unique identity is **OnePlayer 0.14.25 / Build192**.

## Build192 current candidate evidence

- Active identity：**OnePlayer 0.14.25 / Build192**.
- Exact dedicated CI source：`49dd9bf9904efd4ef1e6d3ac4d1d57d960ea4f9b`.
- Dedicated standard MPV Release run：**`32875941745` — success**.
- Artifact：`OnePlayer-0.14.25-build192-add-emby-server`, ID **`9574058602`**, archive digest `sha256:8e675b6154264ee850d6446afa81c6b41cce6aa545f175887b0da9537f536c5d`.
- IPA：`OnePlayer-0.14.25-build192-add-emby-server-unsigned.ipa`; SHA-256 **`b13b76d322c0b301b751ad3723ff0368cb9bc9d0182ec701cf5fcc7a16e4c81d`**.
- Exact source ZIP：`OnePlayer-0.14.25-build192-add-emby-server-49dd9bf-source.zip`; SHA-256 **`87bf231fb49a167a749174fe0e78d79c42ed05172b08df67f31cfb1b8a24ac33`**.
- App validation：`com.embyplayerlab.app`, OnePlayer **0.14.25 (192)**, display name OnePlayer — passed.
- Compatibility：App MinimumOSVersion **15.0**; main runtime Mach-O minOS **15.0**; compatibility audit passed.
- Contract validation：Build192 Add Emby source/Frozen contracts passed; no Player/Transport/Cache product files were changed.
- Temporary Build192 workflow was removed after artifact production; cleanup commit `67d2041d0e4cf06e3c9105a4910eaefc28c14f23`.
- Build191 remains retired for this task due identity collision with the detail task.

## Validation state

- **Code written**：YES — first implementation on product head `2d9aca2`.
- **Draft PR**：#256.
- **Legacy Validate Source**：run `32873926692` is not acceptance authority because its old 0.13.3 / Build69 identity guard is stale relative to current accepted 0.14.x project state.
- **Dedicated Build191 compile evidence**：YES, run `32875040639` success, but identity retired after parallel collision.
- **Current CI passed**：YES — Build192 dedicated run `32875941745` succeeded.
- **Current valid IPA produced**：YES — Build192 artifact ID `9574058602`, IPA SHA-256 `b13b76d322c0b301b751ad3723ff0368cb9bc9d0182ec701cf5fcc7a16e4c81d`.
- **Real-device tested**：NO.
- **Stable / frozen**：NO.

## Next exact action

1. Install **OnePlayer 0.14.25 / Build192** on iPhone 15 Pro Max / iOS 17.0 for real-device validation.
2. Verify modern Add/Edit UI, clipboard credential parsing with the user's real sample, route latency/fastest/failure only inside Add/Edit, add/edit persistence and same-server route winner behavior.
3. Verify automatic startup never visibly renders the first-level server page before the target Emby root, and closing the auto-started root returns cleanly to the normal first-level page.
4. Verify opt-in iCloud Keychain server configuration/token sync where the signing/iCloud environment permits; do not call cross-device behavior solved until a second-device result exists.
5. Regression-check normal Emby entry and playback still follow STRM/302 → 115/CDN client-direct, with existing Seek/PiP/Resume/Cache contracts unchanged.
6. Only user target-device acceptance may promote/merge/freeze this task; CI/IPA evidence alone is not sufficient.

## Rejected / do-not-repeat

- AppShell first appears then auto fullScreenCover into Emby.
- Fake iCloud Toggle with only local Boolean persistence.
- Per-poster multi-route duplicate downloads without new evidence.
- Background periodic route timer/watchdog/retry.
- Media/NAS proxying as part of route aggregation.
- Rewriting `EmbySession` or Home model merely for convenience when separate Session-owned configuration is sufficient.
