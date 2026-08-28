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

**开发任务一旦明确并通过必要前置检查，除非遇到必须由用户决策、提供信息/权限/实机操作、真实冲突、证据不足、外部阻塞，或当前环境确实缺少下一步所需执行能力，否则 AI 不得因代码完成、检查通过、commit/push、PR、CI、checkpoint、准备出包等普通中间状态停下来等待“继续”。** 应在当前执行能力允许范围内自主连续推进至可测试 Artifact/IPA 已生成，并完成适用的产品版本、Build、Candidate、branch/PR/head 或 tested source、Artifact/digest、IPA/package 与 MinOS 身份核验后，再交给用户进行 Runtime/实机测试。

“证据不足”是合法停点，但不能被滥用成普通中间停点：只有当前证据确实不足以证明下一项代码修改、无法安全选择 materially different 的方向，或无法在不猜测的情况下形成可测试 Candidate 时才允许停止。此时必须记录已知事实、缺失证据以及下一项准确需要的用户/Runtime 操作，而不是为了连续推进强行制造补丁。

自主连续开发不得把 checkpoint 延迟到 CI、出包或最终结论之后。任务目标和可用真实基线/工作方向明确后，应尽早建立对应 checkpoint；之后只在具有独立续接价值的实质里程碑滚动记录 branch/head/candidate、`Completed`、`Validation state`、`Pending` 与 `Next exact action`。优先在本来就需要的 GitHub 写节点顺带更新已发生实质变化的 checkpoint，避免为每个微小编辑、检查或命令额外制造 GitHub 写；checkpoint 节奏应使会话突然达到上下文/执行上限时，最多只丢失一个小的有效里程碑，而不是整段实现→CI→出包进度。

对于 blob → tree → commit → ref 等非原子 GitHub 写链，不得为每个微小操作分别写 checkpoint。只有当一组步骤已经产生可复用持久身份（例如 blob/tree/commit SHA、可确认的 branch head、Build/Candidate 或 Artifact ID），且该状态使 `Next exact action` 实质改变时，才把这一组部分完成状态批量写入一次 checkpoint。任何新会话都应能直接依据最近 GitHub checkpoint 记录的持久身份与 `Next exact action` 续接，而不依赖上一会话尚未落盘的临时过程状态。

该连续执行规则不允许绕过最小修改、Frozen/P0、兼容性、并行任务冲突、证据分级或 checkpoint 生存性规则；已生成且身份核验完成的 Artifact/IPA 仍然只属于 `IPA produced`，不得描述成 `Real-device tested` 或 `Stable / frozen`。

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
