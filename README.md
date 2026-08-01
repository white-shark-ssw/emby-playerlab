# Emby Player Lab

面向 TrollStore、自用 STRM → 302 网盘直链环境的原生 iOS 播放器实验室。

## 当前版本：0.2.7

### 系统与构建

- Deployment Target：iOS 15.0
- 重点测试：iPhone 15 Pro Max / iOS 17.0
- 本地环境：Windows
- 云端编译：GitHub Actions macOS 15 / Xcode 16.4
- 安装方式：未签名 IPA + TrollStore
- MPVKit：固定 Streamyfin AVFoundation fork 0.40.0-av（MPVKit-GPL）

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
6. 解压获得 `EmbyPlayerLab-0.2.7-<commit>-unsigned.ipa`，使用 TrollStore 覆盖安装。

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


## 0.2.2 CI 修复

- 先恢复缓存并解析 MPVKit，再检查 module maps。
- 首次运行没有 `.spm-cache` 时不再提前失败。
- 所有诊断日志在工作流开始时创建，因此失败后一定有 Artifact 可下载。


## 0.2.3 MPV 黑屏修复

真机日志确认官方 MPVKit 1.0.0 的 iOS 预编译二进制不包含
`vo_avfoundation`，导致 MPV 只运行解封装、音频和时间轴，却没有视频输出。

0.2.3 改为固定 Streamyfin 实际使用的 `0.40.0-av` 分支：

- 包含 `vo_avfoundation`
- 直接输出到 `AVSampleBufferDisplayLayer`
- 支持 VideoToolbox 硬件解码
- 最低 iOS 13，项目 Deployment Target 仍保持 iOS 15
- 视频输出初始化失败时直接显示明确错误，不再黑屏并伪报 Seek 成功

该预编译产品标记为 GPL-3.0。项目目前仅用于用户本人通过 TrollStore
安装。公开或向他人分发 IPA 前必须重新检查 GPL 合规。


## 0.2.4 音频与中段回弹修复

- 不再错误指定 `ao=avfoundation`，让 MPV 自动选择 iOS 音频后端。
- 增加音频输出、音轨和音频参数日志。
- 连续双击保持一个稳定累计目标，避免关键帧实际落点反向覆盖下一次快进基准。
- 缓冲命中的 MPV 双击使用精确绝对 Seek；缓存未命中仍优先快速关键帧 Seek。


## 0.2.5 异常媒体与退出修复

- MPV 远程 Seek 恢复快速关键帧模式，重新允许跳过异常时间戳区域。
- 连续双击的 UI 目标保持到实际播放位置追上，不再出现中途回弹。
- 退出 MPV 页面时先拆除画面和回调，再排空事件并销毁 libmpv。
- 当前诊断日志持续保存；发生闪退后重新打开 App 仍可导出上一轮日志。


## 0.2.6 302 会话刷新与异常区域硬恢复

`63368` 的 v0.2.5 日志确认：实际播放位置持续停在 30 秒附近，旧代码却在
发出 Seek 时先把 UI 位置写成 35/40 秒；随后旧连接出现 TLS 解码错误、partial
file 和提前 EOF。

本版不再把请求目标当作真实落点。MPV 持续停滞时会重新请求 PlaybackInfo，
获取新的 PlaySessionId，销毁旧 MPV 和缓存，再以新的 MPV 实例重新经过 Emby
入口与 302 链路。重复卡在同一异常区域时会逐步向后跨过该区域。


## 0.2.7 稳定同实例跨区恢复

v0.2.6 在检测到停滞后，会异步销毁旧 libmpv，同时立即创建新 libmpv。真机日志证明旧实例尚未完成 `terminate_destroy` 时新实例已经开始加载，随后发生闪退。

本版不再自动更换 MPV 实例。检测到异常媒体停滞时，在当前 MPV 中清理解码缓冲，并进行 30 秒或 60 秒的大跨度关键帧跳转。停滞状态下拖动进度条则直接跳到用户目标。
