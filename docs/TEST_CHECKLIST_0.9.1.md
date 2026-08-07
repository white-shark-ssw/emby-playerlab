# v0.9.1 真机测试清单

## Build
- [ ] `Validate Source` 解析 MPVKit 0.41.0-n8.1.2 并通过 iOS 15.0 Release 编译。
- [ ] Framework MinimumOS 不高于 iOS 15.0。
- [ ] 未签名 IPA 可由 iPhone 15 Pro Max / iOS 17.0 的 TrollStore 安装。

## 63368
- [ ] 自动日志为 `automaticProfile=AVPlayerResourceLoader+UnifiedTransport`。
- [ ] 出现 `[SmartAV] prepare-resource-loader`，且自动路径不出现 `TransportHTTP ready port=`。
- [ ] 连续 +10 秒至少 30 次；记录 >1 秒、>2 秒、>3 秒 Seek 数量。
- [ ] Seek 后若真实请求已缓存，仍应出现 `UnifiedAnchor real-demand reanchor ... reason=range-demand-cached`。
- [ ] 发生 Stall 时同时记录 `forwardPlayable`、连续缓存字节、有效速度，目标是不再出现连续缓存上百 MiB而时间缓存长期只有约0.1秒的状态。

## 152901
- [ ] 日志出现 `[MPVVideo] renderer=gpu-next ... layer=CAMetalLayer`。
- [ ] 不再出现 `Video output avfoundation not found`。
- [ ] 有声音同时必须有正常视频画面。
- [ ] 连续 +10 秒与远距离拖动均能继续出画面；记录 Seek 首帧延迟。

## 缓冲进度条
- [ ] 历史灰条肉眼清晰可见。
- [ ] 后退 10 秒后历史灰条不缩短。
- [ ] 日志 `[BufferHistory] verifiedEnd` 在同一播放会话中不下降。
- [ ] 亮灰实时 buffer 可以移动/缩短，但不能被误认为历史缓存丢失。
