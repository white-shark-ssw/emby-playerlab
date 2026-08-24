# OnePlayer — START HERE

这是 OnePlayer 后续开发的**唯一入口说明**。新会话不需要重新阅读 v1-v19 全部历史。

## 新会话接手顺序

先读取并以以下文件为当前权威状态：

1. `docs/project/PROJECT_STATE.md`
2. `docs/project/MODULE_STATUS.md`
3. `docs/project/TECHNICAL_DECISIONS.md`
4. `docs/project/BUILD_TEST_INDEX.md`
5. `docs/project/DOCUMENTATION_POLICY.md`

只有需要追溯旧实验、旧日志或被推翻方案时，才查：

`docs/history/chat-exports/v01.md ... v19.md`

## 当前开发原则

- GitHub 当前源码/实际测试分支优先于旧聊天文档。
- 真机测试结果优先于 CI/IPA 成功。
- 不把“代码已写 / CI通过 / IPA生成 / 真机验证 / 稳定解决”混为一谈。
- 已冻结模块不要因无关开发顺手修改。
- 每次重要开发或真机结论后，**主动更新 `docs/project/`，无需用户另行提醒**。
- 目标真机：iPhone 15 Pro Max / iOS 17.0。
- Deployment Target 优先保持 iOS 15.0，任何情况下不得高于 iOS 17.0。
- NAS 不得中转媒体字节；STRM → 302 → 115/CDN 必须由客户端直连。

## 当前阶段

PiP 已在 Build173 / OnePlayer 0.14.6 暂时冻结。后续开发以 `PROJECT_STATE.md` 中记录的最新功能基线为准。
