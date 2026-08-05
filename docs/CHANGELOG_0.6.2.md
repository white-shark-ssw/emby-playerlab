# EmbyPlayerLab 0.6.2

版本：0.6.2
Build：32
Deployment Target：iOS 15.0

## 自动热切换

- 自动引擎切换改为两阶段执行。
- 旧引擎先解除回调并停止，避免 AVPlayer ResourceLoader 与 KSPlayer AVIO 同时消费共享会话。
- 共享传输会话在切换期间执行消费者静默化，但保留解析结果和缓存。
- 切换期间禁止 Stall 看门狗和错误处理重复发起第二次切换。
- 新引擎收到第一份有效状态后才确认切换完成。

## 崩溃诊断

- 增加同步写入的引擎切换面包屑。
- 面包屑记录 requested、old-callbacks-detached、old-engine-stopped、transport-quiesced、new-engine-created、prepare-called。
- 若进程在切换期间退出，下一次启动日志会输出 `[CrashBreadcrumb]`，可直接确认最后完成阶段。

## 传输与内存

- ResourceLoader 自动路径内存缓存上限由用户配置值进一步限制到 128 MB。
- 115 批量预取块由 64 MB 调整为 32 MB，窗口总大小仍保持 Wi-Fi 最高 128 MB。
- 流式预取的交付块由 256 KB 调整为 1 MB，降低 AsyncStream 元素数量和 Data 分配。
- 消费者切换时取消旧 playback/preload 任务和等待者。
- 已被任务令牌移除的旧分段任务不能在返回后继续写入缓存槽。
