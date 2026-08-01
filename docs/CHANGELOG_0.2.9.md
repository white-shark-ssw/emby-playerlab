# 0.2.9

- 修复 MPV 兼容重载把 `MPV_END_FILE_REASON_STOP` 当成提前 EOF。
- libmpv 的 `reason=2` 表示旧文件被 stop/replace，不是自然播放结束。
- 只对 `reason=0`（EOF）和 `reason=4`（ERROR）触发播放结束处理。
- 忽略 STOP、QUIT、REDIRECT 等文件切换事件。
- 删除 `loadfile replace` 前多余的显式 `stop`，避免产生额外 STOP 事件。
- 普通模式使用 `demuxer-lavf-o=interleaved_read=1` 明确恢复默认值，不再调用不支持的 MPV_FORMAT_NONE。
- 兼容文件替换期间禁止递归启动新的兼容重载。
- 日志同时记录 Bundle 版本与源码版本，便于确认安装包。
- 当前版本 0.2.9（13），Deployment Target 继续保持 iOS 15.0。
