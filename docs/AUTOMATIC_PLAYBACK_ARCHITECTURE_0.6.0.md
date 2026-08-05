# 0.6.0 自动播放架构

## 用户层

用户只执行播放、暂停和 Seek。普通界面不要求理解或选择 AVPlayer、FFmpeg、MPV。

## 路由层

`PlaybackOrchestrator` 负责：

1. 根据容器和编码选择初始引擎。
2. 区分传输不足与播放器异常。
3. 在数据充足但播放器停滞时执行单向降级。
4. 防止引擎振荡。

## 数据层

`PlaybackTransportContext` 在播放页面生命周期内持有一个 `MediaTransportSession`。

```text
Emby PlaybackInfo / 302 / 115
                ↓
      MediaTransportSession
        ↙              ↘
AVAssetResourceLoader   FFmpeg AVIO
        ↓                 ↓
     AVPlayer          KSPlayer
```

两个引擎共享：

- 最终 115 URL；
- 403/410 single-flight 刷新；
- RangeHTTPClient；
- 内存分片；
- 磁盘分片；
- 当前需求 offset；
- 预取窗口；
- 网络与缓存指标。

## 播放窗口

窗口由真实读取 offset 驱动，而不是由“文件已经下载多少”驱动。

- 普通读取：从当前 offset 向后预取。
- 窗口内读取：不重建网络管线。
- 远距离 Seek：取消旧预取并建立新窗口。
- 115：一个连续预取 worker，稳定阶段使用 64 MB 长 Range；播放器请求缺失数据时使用 playback lane。
- 尾部 metadata probe：只满足探测，不改变当前播放需求。

## 故障决策

### 传输不足

条件包括：

- 当前位置连续缓存低于动态阈值；
- 当前下载速度低于媒体平均码率的安全倍数；
- 播放器处于等待状态。

动作：重置当前窗口并补齐数据，不换引擎。

### 引擎异常

条件包括：

- 连续缓存已经达到安全阈值；
- 有效供数速度足够；
- 时间轴连续多次不推进；
- 播放项报错或提前 EOF。

动作：

```text
智能 AVPlayer → KSPlayer FFmpeg → MPV
```

## 当前边界

- MPV 尚未读取共享 `MediaTransportSession`，自动切到 MPV 后会使用 MPV 自身网络栈。
- ResourceLoader 渐进式 MP4 行为需要 iOS 17.0 真机和多种 MP4 结构验证。
- 当前媒体字节位置与播放时间的转换仍采用容器大小比例，仅用于预取提示；真实读取由 AVPlayer/FFmpeg offset 决定。
- 完整 iPhoneOS 链接和 TrollStore IPA 需 GitHub Actions 验证。
