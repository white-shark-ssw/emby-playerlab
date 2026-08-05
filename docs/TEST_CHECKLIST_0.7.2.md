# EmbyPlayerLab 0.7.2 测试清单

## GitHub Actions

- `Validate Source` 能完成 CocoaPods 安装、KSPlayer 解析和 iPhoneOS 编译。
- 最终链接不再出现 FFmpeg、MoltenVK duplicate symbol。
- 构建日志不再包含 MPVKit 对象最低 iOS 17.5 警告。
- `Build Unsigned IPA` 生成 0.7.2 Build 35 未签名 IPA。
- `check_min_os.sh` 确认 App 与嵌入 Framework 不高于 iOS 15.0。

## 真机 KTV 缓存

- 标准 MP4 显示 `AUTO·KTV`。
- 播放过程中不自动切换引擎。
- 缓冲不足时继续等待或重启 KTV 预取，不闪退。
- 缓存预算大于视频体积时，缓存量持续增长到接近文件大小。
- 连续双击与拖动后，KTV 预取继续工作。
- 第二次播放在保留缓存开启时能复用已缓存分片。

## 非原生容器

- MKV 等非原生容器在会话开始前选择 KSPlayer/FFmpeg。
- 本构建不链接 MPVKit；诊断流程不得自动进入 MPV。
