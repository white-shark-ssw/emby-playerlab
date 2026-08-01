# 0.1.1

- 修复 `SWIFT_VERSION` 错误配置：`5.9` 改为 `5.0`。
- `AppIdentity` 不再从非主线程上下文直接访问 `UIDevice.current`。
- Validate Source 与 Build Unsigned IPA 在失败时保留完整构建日志。
- Actions 运行摘要自动提取前 40 条编译错误。
- App 版本更新为 0.1.1（Build 2）。
