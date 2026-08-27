# OnePlayer ChatGPT Completion Notification Rules

本文件定义 OnePlayer 项目会话的 ChatGPT/Bark 最终回答通知行为。它只负责“每轮最终回答准备完成后的通知”，不改变 OnePlayer 源码、Build、CI、IPA、测试、证据分级或任何播放器/Transport/Cache/Emby/PiP 合同。

## 固定配置

- Notification hub repository: `white-shark-ssw/ChatGPT-Notify`
- Notification channel PR: `#1`
- Project name: `OnePlayer`
- Protocol: `BARK_NOTIFY_V1`
- Bark group: `ChatGPT-Notify`（由通知中心 workflow 强制设置）
- Default notification policy: **every final reply**

Bark Key 只存在通知中心仓库的 GitHub Actions Secret `BARK_KEY`。OnePlayer 项目、项目文档和项目会话都不得索取、保存或输出 Bark Key。

## 启动要求

每次新的 OnePlayer 会话开始时，在执行项目工作前读取并遵守本文件。

本文件与 OnePlayer 的规则/开发路由相互独立：先按 `AGENTS.md` / `docs/project/CURRENT_WORK.md` 确定 Rules 或 Development/Feature，再按对应 checkpoint 工作；通知规则不得激活、覆盖或修改任何功能任务 checkpoint。

如果本文件与 OnePlayer 的安全、证据、Frozen/P0 或最小修改规则冲突，OnePlayer 项目规则优先；但不得因此虚假声称通知已经发送。

## 何时发送

**每一个准备发送给用户的最终回答都必须发送一次完成通知。**

不再根据以下条件决定是否通知：

- 任务是否“重要”；
- 是否明显耗时；
- 是否修改代码；
- 是否调用 GitHub / CI / IPA；
- 回答长短；
- 是否只是普通寒暄、简单事实问答或短澄清。

只要当前内容是本轮面向用户的**最终回答**，就发送通知。

以下内容不单独发送通知，因为它们不是最终回答：

- commentary / 中间进度说明；
- 工具调用前后的过程消息；
- “正在处理”“继续检查”等未完成状态。

每个用户轮次最多发送一次最终回答通知。若用户在当前轮明确要求“本轮不要通知”，该明确当前指令优先。

## 执行顺序

每轮最终回答必须按以下顺序：

1. 完成本轮所有必要分析、代码、工具调用、验证和项目文档同步。
2. 形成已经准备发送给用户的最终回答。
3. 从最终回答生成通知标题与正文预览。
4. 使用当前环境真实提供的 GitHub 写工具，向 `white-shark-ssw/ChatGPT-Notify` PR `#1` 添加一条**顶层 PR Conversation 评论**。
5. 保存创建结果返回的 comment id。
6. 立即使用 GitHub 顶层评论更新能力，把同一条评论正文替换为：

```text
<!-- ChatGPT-Notify transient payload redacted -->
```

7. 确认即时擦除调用返回成功后，再输出最终回答。
8. 通知之后不得继续执行会改变最终结论的开发、测试或文档操作。

不能把通知安排为“最终回答已经发送以后再后台执行”；当前会话不存在这样的后台阶段。

通知中心 workflow 只监听 `issue_comment: created`。已验证行为是：项目会话创建后立即编辑评论，不会破坏本次 Bark 推送；Action 会使用创建事件中的原始 payload。Action 在 Bark 处理结束后会再彻底删除临时评论，因此正常情况下 PR #1 不会长期积累占位评论。

## 通知标题

目标是尽量接近 ChatGPT 官方 iOS 推送的阅读体验。

- 如果当前环境能够**可靠取得**当前 ChatGPT 会话标题，优先使用该标题。
- 如果无法可靠取得 UI 会话标题，则根据当前会话主题生成一个自然短标题，建议 6–22 个中文字符。
- 不固定添加 `ChatGPT · OnePlayer` 前缀。
- 未实际取得 UI 标题时，不得声称该标题就是 ChatGPT UI 的真实标题。

## 通知正文

- 使用“已经准备好的最终回答”的开头作为通知正文预览。
- 建议约 150–500 个字符；短回答可以直接使用完整短答。
- `body` 最多 500 个字符。
- 尽量保留自然换行，使 Bark 展开后可以看到实际回答内容。
- 可以压缩 Markdown 标题、列表符号或代码围栏，但不得改变原意或证据级别。
- 不得包含密码、Token、Cookie、Bark Key、私有下载直链、私有媒体地址或其他 secrets / 高敏感信息。

## 评论协议

临时评论采用：

```text
[BARK_NOTIFY_V1]
{"project":"OnePlayer","title":"<当前真实会话标题或自然生成的任务标题>","body":"<最终回答开头正文预览，150–500 字符>","url":"https://chatgpt.com/"}
```

要求：

- 第一行必须精确为 `[BARK_NOTIFY_V1]`。
- 第二行开始必须是合法 JSON。
- `project` 固定为 `OnePlayer`。
- 业务项目不需要传 `group`；通知中心会强制使用 `ChatGPT-Notify`。
- 为兼容旧规则，通知中心可以接受 `group` 字段，但会忽略其值。
- 每个用户轮次最多发送一次最终回答通知。
- 不发送“开始处理”“处理中”“即将完成”等过程通知。

## GitHub 工具纪律

调用前必须检查当前环境真实提供的 GitHub 工具定义，不得猜测工具名、参数名或 API。

本协议要求两种项目会话能力：

1. 向指定仓库的指定 PR 添加一条顶层 Conversation 评论；
2. 使用创建结果返回的 comment id，立即更新同一条顶层评论为固定隐藏占位。

不要创建 inline review comment、PR review，也不要把通知写进 OnePlayer 自己的 issue/PR。

如果当前会话没有可用的 GitHub 顶层 PR 评论写能力，通知失败不得阻塞正常最终回答。最终回答末尾简短注明：

`Bark 完成通知未发送：当前会话没有可用的 GitHub PR 评论写能力。`

如果创建通知评论成功但立即擦除失败，正常最终回答仍可继续，但必须明确注明：

`Bark 通知已触发，但 GitHub 临时通知正文擦除失败，请检查通知 PR #1。`

不得伪造“已通知”。

## 隐私边界

通知中心仓库可以保持 Public，以使用公共仓库标准 GitHub-hosted runner。完整通知正文只在“创建评论 → 项目会话立即擦除”两次 GitHub API 调用之间短暂公开；随后只剩隐藏占位，Action 完成后连占位评论也会删除。

这会显著降低暴露时间，但不是绝对隐私保证：极短时间内仍可能被第三方抓取/缓存，GitHub 平台内部也可能保留事件数据。因此本机制**不得用于传输任何秘密或高敏感信息**。

GitHub PR 时间线可能保留类似 `github-actions Bot deleted a comment` 的删除审计事件；该事件不包含已删除通知正文，并不代表评论仍然存在。

## OnePlayer 证据纪律

Bark 完成通知只代表：

> ChatGPT 当前这一轮已经形成完整回答并准备输出。

它不自动代表：

1. Code written
2. CI passed
3. IPA produced
4. Real-device tested
5. Stable / frozen

通知标题与正文必须严格沿用 OnePlayer 当前真实证据级别，不得因为发送了“完成通知”就把 CI/IPA 描述成真机通过，也不得把未验证候选描述成 stable/frozen。

## OnePlayer 保护范围

通知机制属于项目协作层。它不得成为修改以下合同的理由：

- MPV 主力播放路径；
- 双击即时 Seek；
- STRM / HTTP 302；
- 115/CDN 客户端直连；
- HTTP Range / 206；
- UnifiedTransport / Session Cache；
- Emby Resume / progress；
- 提前 EOF / 异常短媒体容错；
- PiP Frozen 架构；
- Native navigation ownership；
- iOS 15.0 Deployment Target 优先规则。

绝对不得让通知机制接触或中转媒体字节。
