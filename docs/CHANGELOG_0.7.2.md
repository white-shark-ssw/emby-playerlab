# EmbyPlayerLab 0.7.2（Build 35）

## 修复

- 修复 v0.7.1 最终链接阶段的 513 个重复符号。
- 根因是 CocoaPods 的 `-ObjC` 同时完整拉入 MPVKit 内置 FFmpeg/MoltenVK 与 KSPlayer/FFmpegKit 对应二进制。
- 本次 KTV 缓存实验构建暂时移除 MPVKit 二进制依赖，保留 KTV AVPlayer 与 KSPlayer/FFmpeg。
- MPV 源码适配继续保留在条件编译分支中，未链接 MPVKit 时使用明确的不可用占位实现。
- 诊断引擎循环不再进入未链接的 MPV。
- 播放过程中继续禁止自动热切换。

## 兼容性

- Deployment Target 保持 iOS 15.0。
- 目标真机仍为 iPhone 15 Pro Max / iOS 17.0。
