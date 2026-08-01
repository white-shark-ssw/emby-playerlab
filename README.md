# Emby Player Lab

面向 TrollStore、自用 STRM → 302 网盘直链环境的原生 iOS 播放器实验室。

## 当前版本：0.2.1

### 系统与构建

- Deployment Target：iOS 15.0
- 重点测试：iPhone 15 Pro Max / iOS 17.0
- 本地环境：Windows
- 云端编译：GitHub Actions macOS 15 / Xcode 16.4
- 安装方式：未签名 IPA + TrollStore
- MPVKit：固定 1.0.0，只链接 LGPL 产品

### 已实现

- Emby 4.8.10.0 登录和 Keychain Token 保存。
- 输入 ItemId 获取 BaseItem 与 PlaybackInfo。
- 显示真实媒体标题、媒体源名称、容器、编码、时长和大小。
- STRM 播放入口与 HTTP 302 链路。
- AVPlayer 与 MPV 双引擎。
- MKV 等容器自动路由 MPV。
- 播放页手动即时切换 AV / MPV，并从当前点位恢复。
- 左侧双击快退、右侧双击快进，秒数可配置。
- 全屏横向滑动调整进度，松手后只提交一次 Seek。
- MPV 前向/后向 demuxer cache。
- AVPlayer 与 MPV 分别记录 Seek 后真实画面/播放恢复耗时。
- 播放停滞检测与自动恢复。
- AVPlayer 提前结束或连续停滞时自动回退 MPV。
- Emby 播放开始、周期进度、暂停、Seek 和停止上报。
- 连续双击时合并 Emby 进度上报。
- 日志脱敏、导出和最低系统检查。

## GitHub 构建

1. 把仓库内容提交到 `main`。
2. 等待 `Validate Source` 成功。
3. 打开 Actions → `Build Unsigned IPA` → `Run workflow`。
4. 首次解析 MPVKit 会下载多组 XCFramework，耗时和 IPA 大小都会明显增加。
5. 构建成功后，在页面底部下载 `EmbyPlayerLab-unsigned-<commit>` Artifact。
6. 解压获得 `EmbyPlayerLab-0.2.1-<commit>-unsigned.ipa`，使用 TrollStore 覆盖安装。

## 建议测试顺序

1. `145926` 或 `144788`：确认 MKV 自动使用 MPV 并正常出画面。
2. `63368`：先选择“强制 MPV”，确认能跨过原来的停止缓冲位置。
3. `152901`：比较 AVPlayer 与 MPV 的双击恢复耗时。
4. 在画面中部横向滑动，确认只有松手后发生一次 Seek。
5. 导出日志并保留异常发生前后的完整记录。

## 安全处理

- 密码不落盘。
- AccessToken 保存到 Keychain。
- 只有与 Emby 入口同源的播放 URL 才会附加 `api_key` 和 `PlaySessionId`。
- 过滤媒体 Headers 中的 Authorization、Emby Token 和 Cookie。
- 日志隐藏 Token、签名、Cookie、Authorization 和敏感查询参数。

## 当前仍未完成

- 会话级稀疏磁盘 Range 缓存。
- 302 最终域名、状态码和 Content-Range 的统一代理诊断。
- 外挂字幕 URL、音轨和字幕轨切换界面。
- MPV 异常 PTS/DTS 的多级强制容错参数。
- 画中画。

## 0.2.1 修复

- 修复 SwiftPM 接入 MPVKit 1.0.0 时的模块导入错误。
- Swift Package 产品名是 `MPVKit`，但实际 C target 模块为 `_MPVKit`；libmpv API 位于 `Libmpv` 二进制模块。
- `MPVPlayerEngine.swift` 改为导入 `_MPVKit` 与 `Libmpv`。
- Actions 额外导出 MPV module map，便于后续定位二进制模块问题。
