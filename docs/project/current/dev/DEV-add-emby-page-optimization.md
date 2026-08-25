# DEV-add-emby-page-optimization

## Status

**Active**

- **Work ID**：`DEV-add-emby-page-optimization`
- **Routing aliases / keywords**：添加 Emby 页面 / 添加服务器 / Emby 服务器添加 / Add Emby / Add Server
- **Task**：优化 OnePlayer 的“添加 Emby 服务器”页面。当前仅确认任务用途与现有真实入口，具体视觉与交互调整以后续用户要求为准，不预先猜测或扩展需求。
- **User intent / acceptance criteria**：用户已明确新开独立功能任务，用途为“优化添加 Emby 页面”。当前 acceptance 尚未细化；默认必须保持现有服务器地址、用户名、密码输入与连接流程可用，保持密码不落盘、AccessToken 写入 Keychain 的既有语义，不因纯 UI 优化修改 Emby/播放/传输核心。

## Baseline

- Accepted product runtime：OnePlayer **0.14.17 / Build184**。
- Base branch：`main`
- Base commit / branch creation head：`b1837067aa7f167f28d26f966428fb46502d9373`
- Target device：iPhone 15 Pro Max / iOS 17.0
- Deployment Target：保持 iOS 15.0。

## Working branch / PR / head commit

- Working branch：`feat/add-emby-page-optimization`
- Branch created from：`main@b1837067aa7f167f28d26f966428fb46502d9373`
- Current product head：`b1837067aa7f167f28d26f966428fb46502d9373`（任务初始化时，尚无产品代码修改）
- PR：none
- Build candidate：暂不分配。

## Evidence

- `Sources/UI/ServerListView.swift` 中右上角 `+` 通过 `showingAddServer = true` 打开 sheet；真实添加页是该文件内的私有 `AddServerView`。
- `AddServerView` 当前持有 `server / username / password` 三个输入状态，调用现有 `sessionStore.addServer(serverText:username:password:)`，成功后 dismiss；错误直接展示 `sessionStore.errorMessage`。
- `Sources/Session/SessionStore.swift` 是添加服务器行为的真实 owner：负责 URL 规范化、并发 `publicInfo()` + `authenticate(...)`、Keychain token 写入、session 持久化与错误日志。当前没有证据要求本 UI 任务修改这些语义。

## Files / modules in scope

- Primary UI：`Sources/UI/ServerListView.swift` 中 `AddServerView`。
- Potential shared UI components：仅在具体设计要求证明必要时再读取/使用现有组件。
- Dependency / read-only owner by default：`Sources/Session/SessionStore.swift`。

## State owner / shared dependencies

- 页面本地输入状态由 `AddServerView` 持有。
- 连接中状态、错误、sessions 与添加服务器行为由 `SessionStore` 持有；不得为视觉优化创建第二套连接/错误/session authority。

## Frozen / do-not-touch

- 不修改 MPV Player、PiP、UnifiedTransport、Cache、Range/302/115 client-direct、Emby Resume/progress、episode ordering/session 等 Frozen/P0 合同。
- 不提高 Deployment Target。
- 不新增 speculative retry、fallback、timer、watchdog、重复状态或 compatibility shim。

## Parallel conflicts checked against

- `DEV-detail-episode-selection-navigation`：主要范围为 `EmbyMediaDetailView.swift` / `EmbyEpisodePickerView.swift` 与详情选集状态；与当前 AddServer UI 无直接文件/状态 owner 重叠。
- `DEV-home-carousel-drag-smoothness`：主要范围为 Home carousel owner/files 与 Build186 诊断；与当前 AddServer UI 无直接文件/状态 owner 重叠。
- 目前可独立并行。最终 CI/IPA/merge 前仍需重新检查 `main` 是否前进及是否出现新重叠。

## Completed

- 已完成新功能会话路由与其他 Active checkpoint 冲突检查。
- 已确认当前 accepted runtime baseline 与当前 `main` head。
- 已定位真实 AddServer UI 入口、调用点和 SessionStore 状态所有权。
- 已创建独立 branch `feat/add-emby-page-optimization`。

## Validation state

- **Task initialized / source inspected / no product code written yet**。
- 无 CI、无 IPA、无真机结论。

## Pending

- 等待用户给出本次“添加 Emby 页面”具体视觉/交互优化要求或参考图。
- 收到要求后先按真实源码检查相关组件/调用点，再做有证据支持的最小 UI 修改。

## Next exact action

1. 接收用户对“添加 Emby 页面”的具体 UI/交互要求。
2. 针对要求重新读取 `AddServerView` 及必要的现有 UI component 定义，确认是否仅需 `ServerListView.swift`。
3. 在 `feat/add-emby-page-optimization` 做最小实现；默认保持 `SessionStore.addServer(...)` 行为与状态 owner 不变。
4. 做窄 source/static validation；形成可测基线后再分配与其他 Active 任务不冲突的 Build/version candidate。

## Rejected / do-not-repeat

- 不因“优化页面”泛化成服务器连接架构重写。
- 不复制 `SessionStore` 的连接/错误/session 状态到新 owner。
- 不为视觉便利修改 Frozen 播放/传输模块。

## Open questions / risks

- 具体视觉结构、字段排列、按钮样式、导航/关闭方式、错误呈现与参考产品尚未由用户定义；不得自行假设。
