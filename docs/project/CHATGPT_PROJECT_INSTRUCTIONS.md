# OnePlayer ChatGPT Project Instructions v3

GitHub 仓库：

`white-shark-ssw/emby-playerlab`

每次开始新的 OnePlayer 开发会话时，必须先执行以下步骤：

1. 读取仓库根目录的 `AGENTS.md`。
2. 读取 `docs/project/START_HERE.md`。
3. 读取 `docs/automation/CHATGPT_NOTIFY_RULES.md`，遵守项目级完成通知与临时评论隐私规则。
4. 以 `docs/project/` 中的当前资料作为项目动态权威状态；不要要求用户重新上传或重新解释 v1-v19。
5. 只有当当前权威资料无法解释某个历史问题时，才读取 `docs/history/chat-exports/v01.md ... v19.md`。

资料冲突时，按以下优先级判断：

1. 用户最新真机测试结果；
2. 当前真实源码 / 对应测试分支；
3. CI / IPA 证据；
4. 当前 `docs/project/` 项目资料；
5. 历史聊天导出中的旧结论、旧计划或旧推测。

修改代码前，必须先检查真实定义、调用点、状态所有权以及相关日志/测试。禁止猜测 API、变量名、函数名、框架行为或源码结构。

只做有证据支持的最小修改。不要为了“保险”或“以后可能需要”而擅自加入：

- speculative retry；
- fallback；
- timer；
- watchdog；
- 重复状态；
- compatibility shim；
- 无当前需求的抽象层；
- 与当前问题无关的重构。

如果现有证据并不足以证明需要修改代码，应明确说明“不应该改”或“暂时没有足够依据修改”，而不是为了完成任务强行制造补丁。

开发前必须读取 `MODULE_STATUS.md`。标记为 Frozen 的模块，除非当前任务确实需要，不得顺手修改。

必须保护当前 P0 播放与传输合同，包括：

- 左侧双击立即快退；
- 右侧双击立即快进；
- 连续快速双击立即响应，不等待防抖累计；
- STRM / HTTP 302；
- 115/CDN 客户端直连；
- HTTP Range / 206；
- 会话级缓存；
- Emby 播放进度 / Resume 同步；
- 异常短片 / 提前 EOF 容错；
- 播放诊断日志；
- MPV 主力播放路径。

绝对禁止 NAS 成为媒体字节中转站。

禁止重新采用：

`targetTime / duration × fileSize`

这种时间→字节比例猜测作为 Seek / Transport 锚点。

目标测试设备：

- iPhone 15 Pro Max
- iOS 17.0

Deployment Target 应优先保持 iOS 15.0。

只有当必要依赖或核心 API 已确认无法兼容 iOS 15.0 时，才允许考虑提高最低系统版本；提高前必须说明：

- 具体不兼容原因；
- 已尝试的低版本兼容方案；
- 为什么这些方案不可行。

任何情况下 Deployment Target 不得高于 iOS 17.0。

优先使用：

- 低版本等价 API；
- UIKit / AVFoundation 兼容实现；
- `if #available`；
- 非核心功能条件降级。

播放器、Transport、Cache、Emby Session 等核心生命周期不得依赖 SwiftUI View 生命周期。

不要假设 GitHub `main` 一定是最新功能测试基线。分析日志或继续开发前，必须确认日志对应的 Build / PR / branch / commit，并读取对应真实源码。

代码格式方面：能自然写在一行的短语句、函数调用和表达式不要人为拆成多行。

**开发任务一旦明确并通过全部必要前置检查，AI 必须在当前执行能力允许范围内自主连续推进到可测试 IPA/Artifact 已生成并完成身份核验，再交给用户进行真机测试。** 不得因为代码已经写完、检查通过、已经 commit/push、CI 已启动或通过、正在准备出包、刷新了 checkpoint 等中间状态停下来等待用户回复“继续”。checkpoint 的作用是保证会话可恢复，不是正常停工或交接门槛。

只有以下情况允许在 IPA/Artifact 交付前停止并要求用户介入：确实需要用户做决定、授权、提供凭据/测试输入/其他信息；出现无法仅凭仓库事实安全消解的真实冲突或歧义；权限、CI/基础设施、必要外部服务或依赖形成真实外部阻塞；或者当前环境确实不具备下一步所需执行能力。除此之外，应继续完成适用的实现、检查、提交/推送、CI、IPA/Artifact 生成、Artifact 获取/检查和身份核验，不得把任何中间 checkpoint 当作等待“继续”的理由。

交给用户真机测试前，应按任务实际情况核对 Build/version、branch/PR/head 或 tested source commit、artifact identity/digest、IPA/package identity 与 MinOS。该规则不允许绕过最小修改、Frozen/P0、兼容性、并行任务冲突或证据分级；已生成且身份核验完成的 IPA/Artifact 仍然只属于 `IPA produced`，不得描述成 `Real-device tested` 或 `Stable / frozen`。

必须始终严格区分以下证据级别：

1. Code written
2. CI passed
3. IPA produced
4. Real-device tested
5. Stable / frozen

不得把“CI 成功”或“IPA 已生成”描述成“真机问题已经解决”。

每次发生以下重要事件后，必须在同一轮工作中主动更新 GitHub 中相关的 `docs/project/` 文件，不需要等用户提醒：

- 重要代码实现完成；
- 形成新的 CI / IPA 有效测试基线；
- 用户给出新的真机测试结果；
- 架构决策被确认、否定、冻结或替换；
- Player / PiP / Transport / Cache / Emby / Navigation / Compatibility 架构变化；
- 新增或替换依赖；
- Deployment Target 或兼容规则变化；
- 当前功能测试基线发生变化。

按需更新：

- `PROJECT_STATE.md`
- `MODULE_STATUS.md`
- `TECHNICAL_DECISIONS.md`
- `BUILD_TEST_INDEX.md`

不得只在聊天里说明新的项目结论，而不同步维护 GitHub 项目资料。

**每一个面向用户的最终回答都必须触发完成通知，不再按任务重要性、耗时、代码修改、回答长度或问答类型过滤。** 必须在本轮所有工作、验证和项目文档同步完成、最终回答已经准备好之后，按 `docs/automation/CHATGPT_NOTIFY_RULES.md` 触发 `white-shark-ssw/ChatGPT-Notify` PR #1 通知，再输出最终回答。中间进度/工具过程不是最终回答，不单独通知；每个用户轮次最多发送一次。通知行为不得改变 OnePlayer 的证据级别，也不得把 Bark Key 或其他 secrets 写进 OnePlayer 仓库。
