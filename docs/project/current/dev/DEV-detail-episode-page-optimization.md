# DEV-detail-episode-page-optimization

## Status

**Active**

- **Work ID**：`DEV-detail-episode-page-optimization`
- **Routing aliases / keywords**：详情页优化 / 详情页 / 选集页 / 剧集页 / detail page / episode page
- **Task**：优化 OnePlayer 的媒体详情页与选集/剧集页面。当前会话已由用户明确作为新的独立功能任务开启；具体视觉、布局、交互和数据呈现要求将在本任务后续消息中逐项确认并实现。
- **User intent / acceptance criteria**：当前已确认的目标范围是“详情页 + 选集页优化”。不得在需求尚未明确时猜测 UI 规格或主动改播放器/Transport/Cache/PiP 等核心路径。后续以用户给出的具体真机表现、截图/录屏、尺寸/交互要求作为验收标准。
- **Baseline**：当前真实功能基线为已接受并合并的 OnePlayer 0.14.11 / Build178。新任务从当前 `main@967b743c88d68b05205eb39f1de75cab41362e8b` 建立；该 head 位于 Build178 合并后的项目治理提交之后，产品运行时基线继承 Build178。
- **Working branch / PR / head commit**：branch `feat/detail-episode-page-optimization`，由 `main@967b743c88d68b05205eb39f1de75cab41362e8b` 创建；PR = none；初始 branch head = `967b743c88d68b05205eb39f1de75cab41362e8b`。
- **Build candidate**：none。分配前必须重新检查 `BUILD_TEST_INDEX.md` 与所有其他 Active checkpoint；Build177 已被 `DEV-home-carousel-drag-smoothness` 保留，不得复用。
- **Evidence**：`PROJECT_STATE.md` 记录 Build178 / 0.14.11 为当前 real-device accepted main 基线；`MODULE_STATUS.md` 将 Emby TV episode ordering 标记为 Stable，并将 Player episode selection / auto-next 标记为 Stable at Build176, inherited by Build178。当前源码已确认存在 `Sources/UI/EmbyDetailOverlayViews.swift` 与 `Sources/UI/EmbyEpisodePickerView.swift`，但“详情页/选集页”的最终真实定义、调用点、状态 owner 与其他关联文件仍需在收到具体优化要求后继续逐项反查，不能仅凭文件名猜修改位置。
- **Files / modules in scope**：预期为详情页、媒体信息展示、选集/剧集列表相关 UI 与其直接数据绑定；当前仅确认候选文件 `Sources/UI/EmbyDetailOverlayViews.swift`、`Sources/UI/EmbyEpisodePickerView.swift`。正式修改前必须继续查明实际页面定义和调用链；若具体需求落在其他文件，以真实源码为准更新此项。
- **State owner / shared dependencies**：Emby episode canonical order 继续由现有 `/Shows/{SeriesId}/Episodes` 数据路径拥有；详情/选集 UI 不得建立第二套排序 owner。播放器内已稳定的 episode session replacement / auto-next owner 不因普通详情页视觉优化而改变。
- **Frozen / do-not-touch**：MPV fast Seek、PiP Build173、UnifiedTransport、Session cache、STRM/302/115 客户端直连、Range/206、Emby Resume/progress、native navigation principle、Player episode session replacement / trusted-natural-end auto-next 均保持现有合同；除非具体需求和源码证据证明必须修改，否则不得触碰。
- **Parallel conflicts checked against**：已检查当前 `docs/project/current/dev/DEV-home-carousel-drag-smoothness.md`。其主要产品范围为 `EmbyHomeCarouselStateV3.swift` / `EmbyHomeCoreV3.swift` 的首页轮播状态与手势，本任务当前预期范围为详情/剧集 UI，未发现同一源码文件或同一状态 owner，因此可以独立并行。后续若用户要求扩展到首页入口、共享图片/导航基础设施或播放器选集 owner，必须重新做冲突检查后再改。
- **Completed**：完成新功能任务路由；读取 `AGENTS.md`、`START_HERE.md`、`CURRENT_WORK.md`、`CURRENT_WORK_DEV.md`、current/dev 规则、`PROJECT_STATE.md`、`MODULE_STATUS.md`、`TECHNICAL_DECISIONS.md`、`BUILD_TEST_INDEX.md`；确认 current main 与 Build178 基线；检查现有 Active 首页轮播任务；创建独立开发 branch。
- **Validation state**：Code written = no；CI passed = no；IPA produced = no；Real-device tested = no；Stable/frozen = no。
- **Pending**：接收用户对详情页与选集页的具体优化要求；随后在 feature branch 上读取真实页面定义、调用点、状态 owner、相关数据模型与已有静态检查/测试，再决定是否以及如何修改代码。
- **Next exact action**：根据用户下一条具体需求，先定位该视觉/交互对应的真实 SwiftUI/UIKit 定义与调用链；确认不会破坏 Build178 已稳定的 Emby episode ordering 与 Build176 episode session contract 后，只做有证据支持的最小修改。
- **Rejected / do-not-repeat**：不要在需求未明确前预设详情页布局；不要为了“顺便统一”重写整个详情页/选集架构；不要增加 speculative fallback/retry/timer/watchdog；不要重新排序 Emby 剧集；不要把普通 UI 优化扩展成播放器 session/transport 重构。
- **Open questions / risks**：详情页与“选集页”可能包含多个独立视图（详情主页面、全部剧集页面、播放器内 episode picker）。必须以用户指出的具体页面/截图/操作路径和真实调用链区分，避免误改已稳定的播放器内选集 UI。
