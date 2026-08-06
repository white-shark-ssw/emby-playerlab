# EmbyPlayerLab 0.7.7 测试清单

## 构建

- [ ] GitHub Actions `Validate Source` 通过。
- [ ] 主目标 Swift 编译不再出现 `operator can throw but expression is not marked with try`。
- [ ] `Build Unsigned IPA` 生成 0.7.7 Build 40。
- [ ] Deployment Target 为 iOS 15.0。
- [ ] iPhone 15 Pro Max、iOS 17.0 可安装运行。

## 63368

- [ ] 仍使用 KTV 缓存 AVPlayer。
- [ ] KTV lane A/B 双通道逻辑与 v0.7.6 一致。
- [ ] 连续双击与异常位置恢复无回归。

## 152901

- [ ] 自动模式使用 KTV 双通道＋KSPlayer/FFmpeg。
- [ ] 日志出现 `[KSKTV] prepared ... transport=KTV-dual-lane`。
- [ ] 不因本次编译修复改变缓存会话移交语义。
- [ ] 若 KTV＋FFmpeg 10秒未 ready，旧 AVIO 兜底仍能触发。
