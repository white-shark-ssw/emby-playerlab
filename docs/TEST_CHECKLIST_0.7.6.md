# EmbyPlayerLab 0.7.6 测试清单

## 构建

- [ ] GitHub Actions `Validate Source` 通过。
- [ ] `Build Unsigned IPA` 生成 0.7.6 Build 39。
- [ ] Deployment Target 为 iOS 15.0。
- [ ] iPhone 15 Pro Max、iOS 17.0 可安装运行。

## 63368

- [ ] 自动模式仍选择 KTV 缓存 AVPlayer。
- [ ] 单通道完成后能启动双通道试跑。
- [ ] 常规完整32 MB分段速度维持此前约10–25 MB/s水平。
- [ ] 连续双击即时响应，后台下载不会随每次点击全部中断。
- [ ] 异常位置不自动热切换、不闪退。

## 152901

- [ ] 若兼容标记仍存在，启动即显示 KSPlayer FFmpeg。
- [ ] 日志出现 `[KSKTV] prepared ... transport=KTV-dual-lane`。
- [ ] 不再出现启动后立即创建 `TransportSession ready`，除非KTV代理10秒兜底失败。
- [ ] KTV lane A/B 均可持续下载，速度与63368处于同一量级。
- [ ] 首帧正常出现，音视频同步。
- [ ] 双击和拖动 Seek 正常。
- [ ] 缓存容量2 GB时持续预取到约2 GB上限，而不是强制下载5.88 GB完整文件。

## 首次回退测试

清除152901兼容标记或换一个同类大MP4：

- [ ] AVPlayer `Cannot Open` 后出现 `[KTVCache] handoff AVPlayer -> FFmpeg`。
- [ ] KTV缓存字节不归零。
- [ ] 115最终URL不因引擎回退重新解析。
- [ ] FFmpeg直接使用原KTV代理开始播放。

## 兜底

- [ ] 若KTV＋FFmpeg 10秒仍未ready，出现 `[KSKTV] startup timeout`。
- [ ] 随后旧AVIO能够继续尝试播放。
- [ ] 兜底过程中无崩溃、无NAS媒体中转。
