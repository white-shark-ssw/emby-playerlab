# 0.1.2

- 修复 `EmbySession: Equatable` 的合成失败。
- 原因：成员 `EmbyUser` 仅声明 `Codable`，没有声明 `Equatable`。
- 处理：改为 `EmbyUser: Codable, Equatable`。
- 已用独立 Swift 类型检查验证模型层的 Codable / Equatable / Hashable 协议链。
