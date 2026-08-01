# GitHub 借鉴记录

## Streamyfin

借鉴思路：

- Seek 时先立即更新本地目标位置，再提交播放器命令。
- 播放器位置、缓冲秒数和等待状态分开观察。
- 正常播放进度更新节流，Seek 期间保持高响应。
- MPV 使用 `cache-secs`、`demuxer-max-bytes`、`demuxer-max-back-bytes`。
- VideoToolbox 硬解失败时允许软件回退。
- 播放器销毁和同一 View 重用必须显式恢复内核状态。

不直接复制其 React Native/Expo 桥接层。

## MPVKit

- 当前主仓库支持 iOS 15。
- 优先 LGPL 产品。
- 上游 README 明确说明维护不频繁，因此必须固定版本和保存构建验证结果。
- 第一版不让 MPVKit 阻塞基础 IPA 构建。

## Swiftfin / 同类客户端教训

- 手势、播放器状态、进度上报不能全部耦合在单一大对象中。
- 双击 Seek 不应等待累计防抖。
- 播放器重建会显著增加 Seek 和切集延迟。
- 服务器进度上报必须与 UI 刷新频率分离。

## 缓存

首版只使用 AVPlayer 前向缓冲偏好并显示 `loadedTimeRanges`。下一阶段实现统一 `MediaDataSource` 与会话级稀疏 RangeCache，不使用完整临时 URL 作为缓存键。
