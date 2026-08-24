# OnePlayer ChatGPT Project Instructions v2

> 这份内容用于 ChatGPT Project 的“项目指令”。GitHub 仓库中的 `docs/project/` 是动态项目状态源；本指令负责固定协作规则与兼容边界。

## 1. 项目与权威资料

GitHub 仓库：

`white-shark-ssw/emby-playerlab`

每个新会话在开始 OnePlayer 开发前，优先读取：

1. `docs/project/START_HERE.md`
2. `docs/project/PROJECT_STATE.md`
3. `docs/project/MODULE_STATUS.md`
4. `docs/project/TECHNICAL_DECISIONS.md`
5. `docs/project/BUILD_TEST_INDEX.md`
6. `docs/project/DOCUMENTATION_POLICY.md`

不要要求用户重新上传或重新解释 v1-v19 历史文档。只有当当前权威资料不足以解释某个历史问题时，才查询：

`docs/history/chat-exports/v01.md ... v19.md`

资料冲突时优先级：

1. 用户最新真机结果；
2. 当前真实源码 / 当前测试分支；
3. CI / IPA 证据；
4. `docs/project/` 当前状态；
5. 历史聊天导出中的旧结论或计划。

旧文档里的“准备做”“计划修复”不能当成已完成。

## 2. 主动维护项目资料

每次发生重要开发迭代后，必须在**同一轮工作中主动**更新 GitHub 的相关说明，不需要等用户提醒。

重要迭代包括：

- 新 Build 改变了运行行为；
- CI/IPA 产生新的有效测试基线；
- 用户给出真机验证结论；
- 一个方案被确认、否定、冻结或替换；
- Player / PiP / Transport / Cache / Emby / Navigation / Compatibility 架构发生变化；
- 最低 iOS、依赖或构建规则发生变化。

按需更新：

- `PROJECT_STATE.md`
- `MODULE_STATUS.md`
- `TECHNICAL_DECISIONS.md`
- `BUILD_TEST_INDEX.md`

不得只更新聊天回答而不更新 GitHub 项目状态。

必须严格区分：

1. Code written
2. CI passed
3. IPA produced
4. Real-device tested
5. Stable / frozen

## 3. iOS 系统兼容目标

目标测试设备：

- iPhone 15 Pro Max
- iOS 17.0

App 必须能够在 iOS 17.0 安装并正常运行。

Deployment Target：

- 初始/优先保持 iOS 15.0；
- 若必要依赖或核心能力确实无法兼容 iOS 15.0，必须先说明具体原因和尝试过的兼容方案；
- 未经说明不得提升到 iOS 16/17；
- 任何情况下不得高于 iOS 17.0；
- 不得为了 SwiftUI 界面便利提高最低系统版本。

使用新 API 前检查最低系统要求。优先：

- 低版本等价 API；
- UIKit / AVFoundation 兼容实现；
- `if #available`；
- 非核心功能条件降级。

播放器核心生命周期不得依赖 SwiftUI。

## 4. 播放核心 P0

降低系统版本或开发其他模块不得破坏：

- 左侧双击立即快退；
- 右侧双击立即快进；
- 连续双击立即响应，不能等待防抖累计；
- 跳转秒数可调整；
- STRM / HTTP 302；
- 115/CDN 客户端直连；
- HTTP Range / 206；
- 会话级缓存；
- Emby 播放进度 / Resume 同步；
- 异常短片 / 提前 EOF 容错；
- 播放诊断日志；
- MPV 主力播放路径。

绝对禁止 NAS 成为媒体字节中转站。

真实播放器 byte demand 才能改变传输锚点。禁止重新采用：

`targetTime / duration × fileSize`

这种时间→字节比例猜测。

## 5. 当前冻结原则

开发前先读 `MODULE_STATUS.md`。

标记 Frozen 的模块，除非当前任务确实需要，不得顺手修改。

目前重要冻结原则包括：

- MPV 快速 Seek 的 `absolute+keyframes` 单次 native Seek 合同；
- 不重新加入隐藏 Exact 二次纠偏；
- UnifiedTransport / Cache 核心语义；
- iOS 原生 Push/Pop 和 interactive-pop 由系统拥有；
- PiP 当前冻结在 Build173，除非出现新的架构级方案或明确回归，不继续为旧长尾反复打补丁。

## 6. 第三方依赖与构建

新增/更换 MPVKit、FFmpeg、MDK、KSPlayer 等依赖时必须检查：

- Minimum iOS；
- arm64 真机；
- GitHub Actions 编译；
- Swift Runtime；
- 动态 Framework 最低系统；
- TrollStore 未签名 IPA；
- 许可证。

优先选择最低系统要求更低、版本可固定、维护方式清楚、可自行构建的方案。

GitHub Actions 至少应验证：

- 项目最低 Deployment Target；
- iOS 17.0 兼容配置；
- 嵌入 Framework Minimum OS；
- 未签名 TrollStore IPA。

## 7. 开发协作规则

- 先读取当前真实代码，再修改；不得猜 API、变量名、函数名。
- 不重新启用已经真机否定的路线，除非有新证据。
- 不为了修一个问题扩大修改范围。
- 已经真机稳定的模块尽量冻结。
- GitHub `main` 不一定是最新功能测试基线；先确认当前 Build / PR / branch。
- 用户给日志时，以日志对应 Build 的真实源码分析，不误用 main。
- 代码能自然写在一行时，不人为拆成多行。
- 不把“理论上应该正常”说成“真机已解决”。

## 8. 新会话行为

如果用户说“继续 OnePlayer 开发”“接着做”“查看最新日志”等：

1. 不让用户重新讲历史；
2. 先读取 `docs/project/START_HERE.md` 和当前权威状态；
3. 再读取当前任务相关源码/分支；
4. 必要时才查 v1-v19 历史原文；
5. 完成重要迭代后主动维护 GitHub 项目资料。
