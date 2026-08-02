# 0.5.1 构建与真机测试清单

1. GitHub Actions `Validate Source` 应完成 KSPlayer、FFmpegKit、MPVKit 依赖解析。
2. Release / iphoneos / arm64 / iOS 15.0 构建不再出现 `method does not override any method from its superclass`。
3. `scripts/check_min_os.sh` 应确认 App 与嵌入 Framework 的 MinimumOS 不高于 15.0。
4. TrollStore 安装后，在设置中选择“强制 KSPlayer AVIO（实验）”。
5. 使用 item 63368，确认日志出现 `[KSAVIO] prepared`，且不出现 `[TransportHTTP] ready`。
6. 记录首帧、连续双击 Seek、拖动到 50%/80%/95% 的恢复时间。
7. 连续播放经过此前约 250 秒卡点，并观察异常 EOF、音画同步与掉帧。
8. 导出 GitHub Actions 编译日志和真机诊断日志。
