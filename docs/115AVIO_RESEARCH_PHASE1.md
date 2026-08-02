# EmbyPlayerLab 播放器内核与 115 传输层源码研究

## 第一阶段：真实架构对照与技术选型

- 研究日期：2026-08-02
- 当前实验版本：EmbyPlayerLab 0.3.5
- 目标设备：iPhone 15 Pro Max，iOS 17.0
- 当前 Deployment Target：iOS 15.0
- 研究对象：
  - VidHub 3.0.2
  - EplayerX 10.0.15
  - SenPlayer 6.1.6
  - KSPlayer
  - KTVHTTPCache
  - VLCKit / MobileVLCKit

---

## 1. 阶段结论

当前 `AVPlayer → localhost 原始 MP4 → 自研多 Range 预加载` 路线不适合作为最终主架构。

0.3.5 已经证明：

- 16 MB 大块和三个后台下载通道没有形成稳定的吞吐叠加。
- 单个大 Range 偶尔能够达到较高速度，但大部分请求仍在较低速度运行。
- AVPlayer 自己的开放 Range 与后台预加载器存在两个独立调度中心。
- 总缓存量增加不等于当前位置之后形成连续缓存。
- 115 对多个并行、有限长度 Range 的表现存在明显波动和间歇性 403。
- 继续增加块大小、并发数或预加载量，不足以解决根因。

三个商业播放器的共同核心不是“更激进地给 AVPlayer 下载原始文件”，而是：

```text
播放器解封装器
→ 自定义 AVIO
→ 逻辑读取位置
→ 精确区间缓存
→ 一个主要网络读取上下文
→ 必要时增加辅助读取上下文
```

EplayerX 和 SenPlayer 还提供另一条路线：

```text
自定义 AVIO
→ FFmpeg 解封装
→ Remux 为本地 HLS / fMP4
→ AVPlayer
```

---

## 2. 三款 App 的静态分析映射

### 2.1 EplayerX

主程序中可以确认存在：

```text
KSPlayer
KSMEPlayer
KSAVPlayer
AbstractAVIOContext
PreLoadIOContext
CacheIOContext
ReadCacheIOContext
URLContextDownload
LimitCacheIOContext
LimitPreLoadIOContext
LimitCountPreLoadIOContext
LimitSeparatePreLoadIOContext
DynamicLimitPreLoadIOContext
ProAVPlayer
ConversionToM3U8
LocalHLSServer
RemuxerIO
```

缓存层还保留了：

```text
logicalPos
entryList
seekOffsets
isInterleaved
firstSeekTime
isReadComplete
isFirstFileSize
eof
end
bytesRead
loadMoreBuffer
preloadInterrupted
```

推断出的真实数据路径：

```text
KSMEPlayer / FFmpeg
→ AbstractAVIOContext
→ EplayerX 私有 PreLoadIOContext
→ 缓存区间索引
→ URLContextDownload
→ 远程媒体
```

系统原生兼容路线：

```text
PreLoadIOContext
→ FFmpeg Demux / Remux
→ LocalHLSServer
→ AVPlayer
```

### 2.2 SenPlayer

SenPlayer 与 EplayerX 使用相同基础体系，但额外出现：

```text
[CacheIOContext] 115cdn
httpRedirectResolvedURL
busySeekCount
lastseekTime
fakeUrlPos
moreUrlPos
isInterleaved
isJudgeEOF
isReadComplete
ProAVPlayerHLSBridge
```

这些字段说明 SenPlayer 至少实现了：

1. 保存 302 最终地址，而不是每个 Range 都重新走 Emby。
2. 针对 115 CDN 的专用判断或分支。
3. 统计短时间频繁 Seek。
4. 区分主读取位置和辅助读取位置。
5. 检测交错差的媒体读取。
6. 把暂时无数据和真正 EOF 分开。
7. 支持自定义 AVIO 到本地 HLS 的桥接。

最值得借鉴的不是字段名称本身，而是它的控制模型：

```text
主读取上下文：持续顺序读取
辅助上下文：Seek、索引或交错读取时临时启用
缓存层：向 FFmpeg 暴露统一逻辑文件
```

### 2.3 VidHub

VidHub 包含两条播放器链：

```text
OmiMPV / libmpv
MVPlayerCore / FFmpeg
```

`MVPlayerCore` 中能够确认：

```text
AbstractAVIO
MemoryIOContext
DiskCacheIOContext
LimitCacheIOContext
MemCacheCluster
MemCacheManager
RangeIndex
RingBuffer
ByteStreamWriter
FFDecoder
VideoToolbox
AVSampleBufferDisplayView
AVSampleBufferAudioRenderer
AVSampleBufferRenderSynchronizer
```

VidHub 的关键点是：

```text
网络与缓存不由 MPV 或 AVPlayer 直接管理
→ 自定义 AVIO 为解封装器提供稳定逻辑文件
→ 内存和磁盘缓存是播放器内核的一部分
```

`MVPlayerCore` 是闭源授权框架，不能直接纳入本项目，但其架构可以独立实现。

---

## 3. KSPlayer 源码研究

### 3.1 KSPlayer 的正确定位

KSPlayer 不是缓存答案本身，而是一个适合承载自定义 AVIO 的播放内核。

当前公开源码的核心路径：

```text
KSMEPlayer
→ MEPlayerItem
→ avformat_open_input
→ av_read_frame
→ FFmpeg / VideoToolbox Decode
→ Audio Renderer / Video Renderer
```

`MEPlayerItem` 在打开输入前会调用：

```swift
KSOptions.process(url:)
```

该方法可以返回：

```swift
AbstractAVIOContext
```

然后 KSPlayer 将其 `AVIOContext` 写入：

```text
AVFormatContext.pb
```

因此 FFmpeg 后续的：

```text
read
seek
fileSize
EOF
```

都可以由应用自己的传输层接管。

这正是 EplayerX 和 SenPlayer 私有 `PreLoadIOContext` 的注入位置。

### 3.2 可以直接利用的 KSPlayer 模块

建议复用：

```text
KSMEPlayer
MEPlayerItem
AbstractAVIOContext
FFmpegDecode
VideoToolboxDecode
AudioRendererPlayer
VideoOutput
MetalPlayView / AVSampleBufferDisplayLayer 路线
轨道选择
字幕框架
播放器状态和 packet/frame queue
```

不应假设公开 KSPlayer 已经包含：

```text
SenPlayer 的 115 缓存
EplayerX 的 PreLoadIOContext
磁盘预缓存
完整快速 Seek 缓存
ProAVPlayer 私有扩展
```

### 3.3 KSPlayer 许可证和系统要求

公开 KSPlayer：

- 许可证：GPL-3.0。
- 当前 Package.swift 最低 iOS：13。
- Swift tools：5.9。
- FFmpeg 二进制依赖：KSPlayer 官方 FFmpegKit 分支。
- 当前项目的 iOS 15.0 Deployment Target 不需要因为 KSPlayer 提高。

采用 GPL 版本时，应在分发 IPA 时保留许可证，并提供对应源码。自用并不取消许可证义务，但当前项目本来就维护完整源码，因此技术上可接受。

KSPlayer 另有付费 LGPL 源码版本。其缓存相关能力与公开版本不同，不能把商业版本源码从其他 App 中抽取出来复用。

---

## 4. KTVHTTPCache 源码研究

### 4.1 真正有价值的设计

KTVHTTPCache 最值得借鉴的是“请求区间分解”：

```text
播放器请求 Range
→ 查询已有缓存碎片
→ 把请求拆成多个来源
   - File Source
   - Network Source
   - File Source
   - Network Source
→ 按逻辑顺序拼接返回
```

关键类：

```text
KTVHCDataSourceManager
KTVHCDataNetworkSource
KTVHCDataFileSource
KTVHCDataUnit
KTVHCDataUnitItem
KTVHCDownload
```

### 4.2 Network Source 的行为

一个 Network Source：

1. 创建一个 URLSession task。
2. 将收到的数据立即写入片段文件。
3. 同时用另一个文件句柄允许读取。
4. 每收到一段数据就通知 Source Manager。
5. 不要求完整 Range 下载结束后才能提供数据。

这与我们此前“下载完整 16 MB，再确认整个块”的思路不同。

正确模式是：

```text
网络边收
→ 缓存边写
→ AVIO 边读
```

### 4.3 连接池设计

KTVHTTPCache 的公开实现使用一个全局 URLSession，而不是每个 worker 创建独立 Session。

这意味着：

- 共用连接池。
- 共用 CookieStorage。
- 统一重定向。
- 统一请求头。
- 网络 Source 只是不同 task，不是不同会话环境。

这与 EmbyPlayerLab 0.3.5 的“每条预加载 lane 使用独立 URLSession”存在重要差异。

### 4.4 适合直接搬运的部分

MIT 许可证允许较自由地使用和修改。

建议优先改写或移植：

```text
DataUnit / DataUnitItem 区间模型
FileSource / NetworkSource 抽象
DataSourceManager 的来源拼接
网络边写边读机制
同一个下载任务的多读取者复用
缓存碎片合并和清理
```

不建议直接照搬完整 localhost HTTP 层，因为最终目标是直接服务 FFmpeg AVIO，而不是继续让 AVPlayer 读取原始 MP4。

KTVHTTPCache 自身也存在播放器取消请求后重复流量的问题，因此不能把整个框架视为无需修改的最终答案。

---

## 5. VLCKit 的角色

VLCKit / MobileVLCKit 可以作为成熟播放器对照组，而不是立即确定为最终内核。

优势：

- libVLC 完整网络和解封装能力。
- 支持非 AVFoundation 标准媒体来源。
- LGPL 2.1+。
- 官方文档最低 iOS 低于当前项目的 iOS 15.0。
- 可以验证当前问题是否主要来自 URLSession / localhost 调度。

风险：

- 包体较大。
- GitHub Actions 自行构建耗时高。
- 与现有 MPV/FFmpeg 同时嵌入会进一步扩大 IPA。
- 原生 HDR、Dolby Vision、Atmos 路线不一定符合长期目标。
- 自定义 115 缓存和诊断控制粒度可能不如自建 AVIO。

建议只做隔离播放实验：

```text
同一最终直链
→ MobileVLCKit
→ 记录吞吐、Seek、403、硬解和稳定性
```

---

## 6. 建议的最终主架构

```text
Emby PlaybackInfo
        ↓
RedirectLease
- 解析一次 302
- 保存 115 最终地址
- 统一 Cookie
- Emby Token 不跨域
- 403/410 single-flight 更新
        ↓
SparseRangeStore
- 精确区间索引
- 内存热缓存
- 稀疏磁盘文件或片段文件
- 正在下载区间可边写边读
- 同一区间请求合并
        ↓
115AVIOContext : AbstractAVIOContext
- read(buffer, size)
- seek(offset, whence)
- fileSize
- temporary EOF / true EOF
- 主读取位置
- 辅助读取位置
        ↓
KSPlayer KSMEPlayer / MEPlayerItem
        ↓
VideoToolbox + 系统音频渲染
```

### 6.1 正常播放

只保持一个主要顺序读取上下文：

```text
FFmpeg 当前 read 偏移
→ 先查 SparseRangeStore
→ 命中立即返回
→ 未命中创建或加入 NetworkSource
→ 收到数据即可返回
→ 后台沿当前逻辑位置继续读取
```

不是把文件平均分给三个 worker。

### 6.2 Seek

```text
用户 Seek
→ FFmpeg 调用 AVIO seek
→ 更新 logicalPos
→ 当前目标请求升为最高优先级
→ 创建一个辅助 NetworkSource
→ 目标附近数据到达即可恢复
→ 稳定后重新建立顺序主读取
```

旧位置的数据和连接可短暂保留，用于连续双击或快速回退，但不永久占用多路通道。

### 6.3 交错差媒体

检测短时间内在两个远距离区间之间反复切换：

```text
主上下文负责主要视频区间
辅助上下文负责另一轨道或索引区间
```

最多维持两个有效读取窗口，而不是无条件多路条带下载。

### 6.4 EOF 防误判

`read()` 必须区分：

```text
logicalPos >= confirmedFileSize
→ 真 EOF

当前区间正在下载
→ 等待或返回可重试状态

网络暂时短读
→ 重试，不返回 EOF

302 正在更新
→ 等待更新

服务端提前断开但未达到 Content-Length
→ 网络异常，不返回真 EOF
```

---

## 7. 原生 AVPlayer 路线

对 H.264/AAC 等系统支持格式，不再提供：

```text
AVPlayer → localhost 原始 MP4
```

后续候选路线：

```text
115AVIOContext
→ FFmpeg Demux
→ Remux 为本地 fragmented MP4 / HLS
→ AVPlayer
```

这样 AVPlayer 只消费已经整理好的本地片段，不负责远程原始文件的探测和 Range 调度。

该路线排在 KSMEPlayer + 115AVIOContext 验证成功之后。

---

## 8. 可复用性矩阵

| 来源 | 可直接采用 | 建议改写 | 不应复制 |
|---|---|---|---|
| KSPlayer GPL | 播放内核、AbstractAVIOContext、FFmpeg/VideoToolbox 渲染 | 业务接入、状态适配 | 付费缓存源码 |
| KTVHTTPCache MIT | 区间模型、Source Manager、边写边读、任务复用 | 从 HTTP Proxy 改为 AVIO 后端 | 无 |
| VLCKit LGPL | 对照播放引擎 | 构建和日志适配 | 无 |
| EplayerX IPA | 架构和行为观察 | 独立实现同等功能 | 私有 PreLoadIOContext 源码 |
| SenPlayer IPA | 115/Seek/EOF 设计线索 | 独立实现 115AVIOContext | 私有缓存和商业框架代码 |
| VidHub IPA | MVPlayerCore 架构线索 | 独立实现 AVIO/缓存/渲染 | MVPlayerCore 二进制和授权逻辑 |

---

## 9. 系统兼容性

当前研究结论不要求提高 Deployment Target：

```text
项目：iOS 15.0
KSPlayer 公共包：iOS 13+
KTVHTTPCache：iOS 12+
VLCKit 官方文档：低于 iOS 15
```

计划继续保持 iOS 15.0。

需要在真实接入时检查：

- KSPlayer 当前 FFmpegKit 二进制的 LC_BUILD_VERSION。
- 所有 arm64 Framework 的 MinimumOSVersion。
- Swift Runtime 和 Xcode 16.4 链接。
- GitHub Actions 编译时间和缓存。
- TrollStore 未签名 IPA 的动态库布局。

---

## 10. 下一阶段实验

下一步不直接替换主播放器，而是创建独立的：

```text
115AVIO Lab
```

### 实验 A：网络模式基线

不启动播放器，只测试同一个最终资源：

1. 单一共享 URLSession，单个持续开放 Range。
2. 单一共享 URLSession，单个 256 MB Range。
3. 同一 Session 两个 task。
4. 独立 Session 两个 task。
5. Cookie 共用与隔离。
6. Range 4/16/64/256 MB。
7. 读取到内存。
8. 边写稀疏文件边读。

记录：

```text
首字节
5/15/60 秒吞吐
HTTP 协议
连接复用
403 次数
Cookie 变化
服务端短读
实际累计字节
```

### 实验 B：AbstractAVIOContext 最小实现

```text
115AVIOContext
→ KSPlayer MEPlayerItem
→ 只实现 read / seek / fileSize
→ 不启用磁盘缓存
```

目标是确认：

- FFmpeg 真实请求偏移。
- 直接 AVIO 是否比 localhost AVPlayer 更稳定。
- 同一个持续连接是否能维持高吞吐。
- 63368 是否能够连续经过异常位置。

### 实验 C：SparseRangeStore

在实验 B 成功后加入：

```text
区间索引
内存热缓存
边写边读
同 Range 任务合并
Seek 辅助 Source
EOF Guard
```

### 实验 D：本地 HLS Remux

仅在 KSMEPlayer 路线稳定后实现：

```text
115AVIOContext
→ Remux
→ 本地 fMP4 HLS
→ AVPlayer
```

---

## 11. 阶段决策

第一阶段推荐方案：

```text
KSPlayer KSMEPlayer
+ 自建 115AVIOContext
+ 移植 KTVHTTPCache 的区间与 Source Manager 思路
```

不推荐继续投入：

```text
AVPlayer
→ localhost 原始 MP4
→ 时间估算字节
→ 多 worker 预加载
```

VLCKit保留为对照和容错候选，不作为第一实现目标。

下一阶段的代码应是隔离实验室，不立即替换现有 App 主播放器。只有 115AVIO Lab 能稳定达到高于媒体消耗速度，并通过 Seek/EOF 测试后，才进入正式播放器集成。
