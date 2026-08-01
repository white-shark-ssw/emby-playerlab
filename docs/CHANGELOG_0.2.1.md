# 0.2.1

- 修复 `MPVPlayerEngine.swift` 的 `no such module MPVKit`。
- 根据 MPVKit 1.0.0 Package.swift：产品 `MPVKit` 实际暴露 target `_MPVKit`。
- libmpv C API 从 `Libmpv.framework` 的 `Libmpv` 模块导入。
- CI 增加 module map 导出，后续构建失败时可直接确认真实模块名。
