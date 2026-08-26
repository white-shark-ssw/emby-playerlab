# DEV-add-emby-page-optimization

## Status

**Active — Build199 IPA produced / target-device validation pending**

- **Work ID**：`DEV-add-emby-page-optimization`
- **Routing aliases / keywords**：添加 Emby 页面 / 添加服务器 / Emby 服务器添加 / Add Emby / Add Server
- **Task**：重做 OnePlayer 的 Add/Edit Emby 页面，并实现一键粘贴、自动启动、iCloud 同步、同服多线路选优，以及用户最新要求的密码保留与 iCloud 跨设备同步。

## Current user acceptance contract

1. Add/Edit Emby 使用现代 iOS 卡片式 UI；保留服务器地址、用户名、密码；不恢复多余副标题/helper/安全说明。
2. 一键粘贴可解析服务器、账号、密码和多线路；新 parser 变化必须以真实样例为依据，禁止继续猜格式。
3. `自动启动` 在冷启动直接构造目标 Emby 根内容；已有 Home 快照/图片缓存时先显示缓存，再并行做同服线路选优和联网刷新；线路失败不得退回一级服务器页。
4. 同一 Emby 可配置多条入口；仅 Add/Edit 页面显示真实线路延迟/失败/不匹配/最快；其它页面和自动启动过程不显示测速数字。
5. 同服校验继续使用 Emby Server ID；运行时赢家成为当前 API `serverURL`，以保持 Home 图片磁盘缓存 host key 的命中连续性。
6. **密码必须保留并可在 Edit 页面查看/修改。** Build199 从 SessionStore 的密码 Keychain 读取后预填 Edit 密码框；眼睛按钮控制显示/隐藏。
7. **密码也必须随 `iCloud 同步` 跨设备同步。** Build199 将密码放在独立的本机 Keychain account，并在该服务器开启 iCloud 同步时写入独立 `kSecAttrSynchronizable` Keychain account；关闭 iCloud 同步移除 synchronizable 密码副本，删除服务器同时清理本机与 synchronizable 密码。
8. 密码不得写入 UserDefaults、普通服务器 JSON registry 或诊断日志；AccessToken 的既有本机 Keychain authority 不变。
9. 编辑时密码未改变不额外重新认证；改变密码时只对 stored username 重新认证，并要求同一 Server ID / User ID 后才替换 AccessToken 和保存新密码。
10. 多线路只改变 Emby API/server entry；媒体仍为 `Emby / STRM → 302 → 115/CDN → iPhone`，NAS 绝不承载媒体字节。
11. Deployment Target 保持 iOS 15.0；Player/PiP/UnifiedTransport/Cache/Seek/Resume/episode ordering 等 Frozen/P0 合同不变。

## Baseline / identity guard

- Accepted overall real-device runtime remains **OnePlayer 0.14.28 / Build195** on `main`; Build199 does not replace it before target-device acceptance.
- Working branch：`feat/add-emby-page-optimization`。
- Draft PR：**#256** — `Add modern Emby server editor and multi-route startup`。
- Exact Build199 source / current feature head：`2b5f3bef073754371443c6c7a345657dbfa2a09a`。
- PR #256 head was rechecked at the same exact SHA before build evidence was recorded.
- Parallel `DEV-home-carousel-drag-smoothness` owns **Build198 / 0.14.31** on a different branch; Build199 identity is unique to this Add Emby task.
- Current candidate：**OnePlayer 0.14.32 / Build199**。

## Source ownership / verified implementation

- `Sources/UI/ServerListView.swift` is the real Add/Edit owner. Edit receives `initialPassword: sessionStore.password(for:)`, initializes the password field with that value, exposes eye show/hide, and sends a password update only when the edited value actually differs from the initial value.
- `Sources/Session/SessionStore.swift` remains the single session/server-config owner. `persistPassword(...)` stores the password in a dedicated local Keychain account and conditionally mirrors it to a dedicated synchronizable Keychain account; `password(for:)` reads local first, then synchronizable. Server deletion removes both.
- `Sources/Core/KeychainStore.swift` keeps ordinary local secrets at `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; synchronizable entries use `kSecAttrSynchronizable = true` with `kSecAttrAccessibleAfterFirstUnlock`.
- Existing cached-first auto-start, same-server multi-route selection, runtime winner persistence and Home/image cache ownership remain unchanged from the prior Add Emby implementation.
- No Player, PiP, UnifiedTransport, media Cache, Range/206, STRM/302/115 direct path, Resume or episode-order owner was changed for Build199.

## Build199 evidence

- Dedicated workflow：`Build199 Add Emby Password Sync`。
- Exact source：`2b5f3bef073754371443c6c7a345657dbfa2a09a`。
- GitHub Actions run：**`32942618979` — success**。
- Artifact：`OnePlayer-0.14.32-build199-add-emby-password-sync`。
- Artifact ID：**`9597143667`**。
- Artifact archive digest：`sha256:94d19775fc82d42232d1d5f3efe40b0f04719e599cb5cfb7317746490ca51972`。
- IPA：`OnePlayer-0.14.32-build199-add-emby-password-sync-unsigned.ipa`。
- IPA SHA-256：**`8f0f43f62705e5e13ae666cc54d32fd047c596df1d0e9335668b01a25b6eb003`**。
- Exact source ZIP SHA-256：`72b690f1f38898c3fdfa82834a06baa4cbb875cbc99b33c1c7b87eaf4848fe18`。
- App identity validation：**OnePlayer 0.14.32 (199) PASS**。
- App + main runtime Mach-O MinOS：**15.0 PASS**；required target-device ceiling remains iOS 17.0。
- Dedicated contract log：`Build199 accepted Build195 + Add Emby password sync/frozen contracts: OK`。
- Evidence level：**Code written / CI passed / IPA produced / real-device Build199 pending / not stable**。
- Same-head KSPlayer lab success is auxiliary only. Generic `Validate Source` and MDK lab failures are not Build199 acceptance authority and do not overturn the dedicated standard MPV success; no product/Frozen changes are justified by those unrelated checks.

## Prior task evidence retained

- Build192 / 0.14.25：real-device tested; modern editor direction and route diagnostics worked, but Edit password row was missing; not accepted.
- Build196 / 0.14.29：cached-first/password-action follow-up compiled and produced IPA on an older tree; later retired as a distributable baseline after tree identity review.
- Build197 / 0.14.30：dedicated CI/IPA produced, but later user requirement superseded its empty Edit password semantics by requiring the password to remain visible/editable and sync through iCloud。

## Next exact action

1. Install **OnePlayer 0.14.32 / Build199** on iPhone 15 Pro Max / iOS 17.0.
2. Open Edit Server and verify the existing password is prefilled; eye button reveals/hides it; saving without changing the password does not unnecessarily reauthenticate.
3. Change to the correct password and verify token/password refresh succeeds; wrong or different-user credentials must fail without destroying the existing valid session.
4. With `iCloud 同步` ON, verify the password is available on a second device signed into the intended iCloud Keychain environment; this cross-device behavior is **not** proven by CI alone.
5. Toggle iCloud sync OFF and delete/re-add as needed to verify synchronizable password cleanup semantics.
6. Recheck cached-first auto-start under normal network and temporarily unreachable Emby; cached Home should remain available and online recovery should refresh through the winning route.
7. Recheck normal STRM/302 → 115/CDN playback remains iPhone client-direct; NAS must not relay media bytes.

## Rejected / do-not-repeat

- AppShell first renders, then fullScreenCover/quick-switches into Emby.
- Auto-start waits for best-route networking before constructing cached Home.
- Route failure dismisses a valid cached auto-start Home back to the first-level server list.
- Fake local-only iCloud toggle.
- Password stored in UserDefaults/plain configuration/ordinary sync registry/logs.
- Password field visible but ignored, or password always blank after the user explicitly required retention.
- Per-poster multi-route duplicate downloads.
- Background retry/timer/watchdog/reconciliation added without a concrete failure mode.
- NAS/media proxying as part of route aggregation.
- Reusing another Active task's Build/version identity.
