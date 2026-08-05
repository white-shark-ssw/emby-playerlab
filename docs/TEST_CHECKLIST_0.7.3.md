# EmbyPlayerLab 0.7.3 测试清单

## 构建

- `Validate Source` 使用 iOS 15.0 Deployment Target 编译成功。
- `Build Unsigned IPA` 生成 0.7.3 Build 36 未签名 IPA。
- 最终链接不包含 MPVKit，不出现 FFmpeg/MoltenVK 重复符号。

## 下载速度

1. 清空缓存，磁盘缓存预算设置为大于测试视频体积。
2. 播放 Item `63368`，确认引擎显示 `AUTO·KTV`。
3. 日志应出现 `[KTVAdaptive] segment start`，Range 大小依次覆盖 16/32/64 MB 试跑。
4. 每个完成分段应记录 `newCache`、`speed` 和下一个字节位置。
5. 观察是否出现 `segment winner`，并确认后续优先使用胜出的 Range 大小。
6. 连接持续慢时应出现 `slow connection rotate`，但不应刷新 302、切换引擎或闪退。
7. 连续双击或拖动后应出现 `seek reprioritize`，旧分段停止，预取从目标字节附近继续。
8. 缓存预算大于视频时，最终缓存量应接近文件大小。

## 视频冻结

1. 第二次播放并 Seek 到此前“画面不动、声音继续”的区域。
2. 若视频轨停止出帧，日志应出现 `[VideoFreeze] detected`。
3. 第一次恢复应为当前位置轻量 Seek，不切换引擎。
4. 若仍冻结，应出现 `same-engine item reload`。
5. 恢复成功应出现 `[VideoFreeze] recovered`。
6. 整个过程音频会话、Emby 进度上报和 KTV 缓存不得被替换成另一播放引擎。
