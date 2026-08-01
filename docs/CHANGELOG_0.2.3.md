# 0.2.3

- 根据真机日志修复 MPV 全程黑屏。
- 根因：官方 MPVKit 1.0.0 不包含 `vo_avfoundation`。
- 切换到 `streamyfin/MPVKit` 的精确版本 `0.40.0-av`。
- SwiftPM 产品改为 `MPVKit-GPL`，Swift 模块改为 `import MPVKit`。
- `wid` 和 `vo=avfoundation` 改为关键初始化项；失败会中止 MPV 启动并显示错误。
- 增加 `AVSampleBufferDisplayLayer.status` 失败日志。
- Deployment Target 继续保持 iOS 15.0；依赖本身最低 iOS 13。
- 更新第三方许可证说明。
