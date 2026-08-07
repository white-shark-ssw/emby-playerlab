# v0.9.5 真机测试清单

测试设备：iPhone 15 Pro Max / iOS 17.0

- 日志开头确认 `source=0.9.5`。
- 63368：启动后应看到 `secondary enabled alongside urgent playback`，随后 `slot1` 不再长期 idle；观察双槽长 Range 吞吐、连续缓冲和连续双击 Seek。
- 152901：点击播放不得退出 App；应至少出现 `[MPVLifecycle] engine create begin/finished` 与 `prepare begin/returned`，再进入 MPVStream/UnifiedTransport。
- 144799：点击播放不得退出 App；播放后观察 `[MPVSurface]` 几何与 `[MPVVideoState]`，确认画面不再偏移。
- 进度条：无白色实心圆点；仍可点击和拖动 Seek；历史灰/实时灰缓冲段清晰可见。
- Deployment Target 必须保持 15.0；GitHub Actions Xcode 16.4 generic iOS device 编译通过。
