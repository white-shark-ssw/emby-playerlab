# EmbyPlayerLab 0.8.0（Build 44）测试清单

## CI / 安装

- [ ] `Validate Source` 中 `Validate contiguous RangeMap` 通过。
- [ ] Xcode 16.4 / iPhoneOS Debug编译通过。
- [ ] Release unsigned IPA生成成功。
- [ ] `check_min_os.sh`确认所有嵌入二进制最低系统不高于iOS 15.0目标。
- [ ] iPhone 15 Pro Max / iOS 17.0通过TrollStore覆盖安装。

## 63368 连续缓存

- [ ] 启动日志出现 `scheduler=contiguous-frontier-1x2`。
- [ ] lane A从 `0-33554431` 开始。
- [ ] 双通道试验开始后，lane B只能领取与当前frontier窗口相邻的下一段，不再出现固定领先96 MiB。
- [ ] `[BufferMap] holes=0` 在正常顺序预取期间保持为0。
- [ ] 如果lane B失败，lane A先修补最早hole；日志中不能继续向远端制造新Range。
- [ ] 快速连续双击仍立即Seek，不等待后台debounce才提交播放器Seek。
- [ ] Seek日志出现 `byteGuess=disabled`，不再出现时间比例估算byte。
- [ ] 灰色缓冲条只覆盖 `loadedTimeRanges` 真正报告的时间段；存在gap时必须视觉断开。
- [ ] Seek落在灰色范围内通常明显快于灰色范围外。

## 152901 起播 / metadata

- [ ] 自动模式仍选择KTV + KSPlayer/FFmpeg。
- [ ] 不再出现固定 `startup timeout ... fallback transport=AVIO`。
- [ ] 日志出现 `[KTVMetadata] ... classification=metadata-not-playable`。
- [ ] metadata增加时，`metadataBytes`增长但playback frontier不能因此跳到文件尾。
- [ ] 只要Range仍持续推进，即使首帧超过10秒也不能切AVIO。
- [ ] 真正出现连续Range失败+至少12秒无进展时才允许state-driven AVIO fallback。
- [ ] 第一帧出现后，KSPlayer缓冲灰条来自 `playableTime`，不是总缓存字节换算。

## 诊断一致性

- [ ] `[BufferMap]` 每约1秒包含 position / schedulerAnchor / frontier / playbackBytes / metadataBytes / holes / ktvZones / laneA / laneB / networkBps。
- [ ] UI“前向可播”与当前灰色时间段一致。
- [ ] “总缓存MB”不能被解释为当前位置前方可播长度。
- [ ] MP4尾部metadata不画入播放进度灰条。

## 已知0.8.0限制（测试时不要误判）

- [ ] `[BufferMap] demandAnchor=unavailable` 是预期状态，不是错误。
- [ ] Seek到未缓冲远端时，后台主动预取仍可能继续从文件头顺序推进；播放器自己的真实KTV Range负责目标点数据。
- [ ] 下一阶段接入localhost真实Range demand后，再验证Seek后的byte-level frontier re-anchor。
