# Emby Player Lab

面向 TrollStore、自用 STRM/302 Emby 环境的原生 iOS 播放器实验室。

## 当前版本：0.1.0

这一版只建立可验证的最小闭环：

- iOS 15.0 Deployment Target，重点验证 iPhone 15 Pro Max / iOS 17.0。
- 公网 HTTPS Emby 入口登录。
- Keychain 保存 AccessToken。
- 输入 Emby ItemId 获取 `PlaybackInfo`。
- 选择媒体源并使用 Emby 播放入口播放。
- AVPlayer 播放引擎。
- 左侧双击立即快退、右侧双击立即快进。
- 默认 10 秒，可设置 5/10/15/20/30/60 秒。
- 连续双击不做 300～500ms 防抖等待。
- 90 秒默认前向缓冲偏好。
- 显示播放位置、缓冲范围、等待状态和最近一次 Seek 指标。
- 基础提前 EOF 防误判。
- Emby 播放开始、进度、暂停/Seek、停止上报。
- 日志脱敏和系统分享导出。
- GitHub Actions 生成未签名 IPA。

## 尚未接入

- MPVKit 实际播放器实现。
- 稀疏 Range 磁盘缓存。
- 302 最终地址观测代理。
- 完整异常 PTS/DTS 探测。
- 音轨、字幕轨和画中画。
- 完整媒体库浏览。

首个版本刻意不直接引入 MPVKit，先验证 Xcode、TrollStore、Emby、302、进度上报和 AVPlayer Seek 基线。播放器协议已经预留，下一阶段可接入固定版本 MPVKit。

## Windows + GitHub Actions 构建

1. 将整个目录推送到 GitHub。
2. 打开仓库的 Actions 页面。
3. 运行 `Build Unsigned IPA`。
4. 下载 `EmbyPlayerLab-unsigned-<commit>` Artifact。
5. 解压后获得 IPA，通过 TrollStore 安装。

CI 固定选择 `/Applications/Xcode_16.4.app`，使用 iPhoneOS SDK 构建，不依赖证书和 Provisioning Profile。

## 第一次测试顺序

1. 安装 IPA。
2. 输入公网 HTTPS Emby 入口。
3. 登录并确认显示 Emby Server 版本。
4. 输入一条普通媒体的 ItemId。
5. 加载 PlaybackInfo，选择媒体源并播放。
6. 连续快速双击右侧，观察 `缓存命中` 和 `Seek 延迟`。
7. 退出播放器，确认 Emby 中保存了进度。
8. 使用一条会误判结束的短片测试，并导出日志。

## 安全说明

- 密码不落盘。
- AccessToken 仅保存在 Keychain。
- 普通日志会隐藏 `api_key`、token、签名、Cookie、Authorization。
- 只有与 Emby 入口同源的播放 URL 才会附加 `api_key` 和 `PlaySessionId`；跨域绝对媒体 URL 永远不会追加这些参数。
- 仍需真机确认你的 NAS 替换项目是否返回绝对 Location，以及最终网盘域名是否收到任何不应携带的参数。
