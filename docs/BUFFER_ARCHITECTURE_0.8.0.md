# EmbyPlayerLab v0.8 缓存 / 起播 / Seek 架构设计

状态：已批准；0.8.x 实现基线
目标设备：iPhone 15 Pro Max / iOS 17.0
最低系统目标：继续以 iOS 15.0 为实现基线
适用链路：Emby / OneStrm → HTTP 302 → 115 CDN → iPhone 本地缓存 → AVPlayer / KSPlayer-FFmpeg

## 1. 设计目标

本轮不再以“总缓存字节增长最快”为首要目标，而改为：

1. 当前播放点前方的**真实连续可播放缓存**优先。
2. 在不制造永久空洞的前提下尽可能利用网络带宽。
3. 用户 Seek 后立即响应，不因后台预加载等待。
4. 不再通过 `time / duration × fileSize` 猜测播放字节位置。
5. MP4 头部 / 尾部元数据读取是独立例外，不计入前向播放缓存。
6. AVPlayer 与 KSPlayer / FFmpeg 使用统一缓存语义。
7. UI 明确显示真实缓冲范围，便于用户体验和真机诊断。
8. NAS 永远不转发媒体字节。

## 2. 核心模型：Playback Anchor + Contiguous Frontier

缓存调度只围绕两个核心概念工作：

- `Playback Anchor`：播放器当前真实需要的数据位置。
- `Contiguous Frontier`：从 Playback Anchor 开始，向前没有任何 hole 的连续缓存终点。

示意：

```text
Playback Anchor
      ↓
      █████████████████████████████████
                                      ↑
                           Contiguous Frontier
```

系统可以同时存在其他缓存块，但它们不能增加 `forwardContiguous`：

```text
      ████████████████         ███████         ████
      ↑ 当前连续范围           稀疏缓存         metadata
```

必须区分：

- `forwardContiguousBytes / Time`
- `totalCachedBytes`
- `metadataCachedBytes`
- `sparseCachedRanges`
- `holes`

正常播放调度只关心第一项。

## 3. RangeMap

建立统一 `RangeMap`，以真实字节区间记录缓存状态：

```text
[cached] [cached] [hole] [downloading] [cached]
```

RangeMap 负责：

- 合并相邻缓存区间；
- 查询指定 offset 是否已缓存；
- 查询从某 offset 开始的第一个 hole；
- 计算连续前沿；
- 标记正在下载区间；
- 防止两个后台 worker 下载同一区间；
- 区分 playback data 与 metadata data。

禁止根据“累计缓存增加了多少”推断某个位置已经可播放。

## 4. 正确的双通道模型

双通道仍然保留，但两个 worker 必须填充**相邻 hole**。

正确：

```text
Frontier
   ↓
Lane A  [0 ---------------- 32 MiB]
Lane B                          [32 ---------------- 64 MiB]
```

A / B 可以同时下载，因此仍可叠加带宽。

如果 B 先完成：

```text
A downloading    B complete
[.............]  [████████████]
```

连续前沿仍然不能越过 A。

A 完成后才一次前进到 B 的末尾。

错误模型（禁止）：

```text
Lane A [0-32]
                       <巨大 hole>
Lane B                              [128-160]
```

第二通道不能再固定领先 64 / 96 / 128 MiB。

## 5. Worker 分配算法

每次 worker 空闲时：

1. 从当前 Playback Anchor / Contiguous Frontier 查询第一个 hole；
2. Lane A 获取该 hole 的第一个分段；
3. Lane B 获取紧邻 Lane A 的下一个分段；
4. 如果前一个 hole 未完成，不允许继续向更远位置扩张；
5. 如果用户 Seek，前景真实请求优先；后台 worker 不靠时间比例猜目标。

建议第一阶段继续使用 32 MiB 分段，仅为了减少同时变量；等连续模型验证稳定后再测试分段大小。

## 6. Seek 模型

### 禁止

```text
用户 Seek 到 100 秒
→ 100 / duration × fileSize
→ 猜 offset
→ 后台 worker 跳过去
```

### 新模型

```text
用户 Seek
→ AVPlayer / FFmpeg 立即执行 Seek
→ 播放器发出真实 Range / read 请求
→ 缓存层观察真实 requested offset
→ 更新 Playback Anchor
→ RangeMap 从该 offset 建立新的连续前沿
```

后台顺序预取不再决定 Seek 去哪里；播放器真实请求才是事实来源。

快速连续双击时：

- UI / player Seek 每次立即执行；
- 不等待 debounce 后才 Seek；
- 后台只在真实数据请求稳定后更新 Anchor；
- 避免反复 cancel 一个已经跑热的高速网络任务。

## 7. AVPlayer 数据来源

AVPlayer 的缓冲 UI 和播放判断优先使用：

- `AVPlayerItem.loadedTimeRanges`
- `isPlaybackLikelyToKeepUp`
- `isPlaybackBufferEmpty`
- `isPlaybackBufferFull`
- `reasonForWaitingToPlay`

`loadedTimeRanges` 可以不连续，因此 UI 不应假设只有一个 `0...bufferedEnd`。

底层 KTV fork 需要增加只读观测：

- localhost 实际收到的 Range；
- upstream Range；
- cache hit / hole；
- download start/end/cancel；
- error domain/code/underlying；
- 当前 cache spans。

第一阶段 fork 只增加可观测性，不改变 KTV 下载逻辑。

## 8. KSPlayer / FFmpeg 数据来源

当前 KSPlayer 路径已有 `currentPlaybackTime` 与 `playableTime`。

生产 UI 的前向缓冲时间优先使用：

```text
currentPlaybackTime ... playableTime
```

而不是把 KTV 字节区间按文件大小映射成时间。

后续若 fork / adapter 能获得 FFmpeg demuxer 已解复用 packet 的时间戳范围，可进一步把它作为更精确的 `playableRanges`。

## 9. 152901：大 MP4 起播状态机

152901 类型文件不能再使用固定“10 秒没 ready → 放弃 KTV”。

### Metadata 与 Playback Data 分离

允许两类读取：

**Playback Data**

```text
真实首个媒体数据位置
→ 连续向后下载
```

**Container Metadata**

```text
文件头
文件尾 moov / sample table
```

metadata Range 是允许随机访问的例外，但：

- 不进入前向缓冲进度；
- 不增加“已缓冲视频时长”；
- 不推进 Contiguous Frontier。

### 起播流程

1. 创建统一 KTV session；
2. 让 FFmpeg 打开 localhost URL；
3. FFmpeg真实请求文件头 / 文件尾元数据时正常响应；
4. 同时填充首个 playback hole；
5. 只要网络、RangeMap 或 demuxer仍有进展，就继续等待；
6. 第一帧 ready 后进入正常状态；
7. 只有明确 fatal open error / 连续 Range fatal / 长时间完全无进展才启用最终 AVIO 兜底。

不再以固定 10 秒作为失败条件。

## 10. 缓冲进度条设计

### 10.1 视觉层级

播放进度条建议分四层：

```text
底轨：      ─────────────────────────────────────────
已缓冲：    ░░░░░░░░░       ░░░░
已播放：    ███████
当前位置：         ●
```

建议语义：

- 深色半透明：未缓存轨道；
- 灰色：**真实可播放时间范围**；
- 当前主题色 / 白色：已播放范围；
- Thumb：当前播放位置。

### 10.2 不允许画假的连续灰条

如果真实时间缓存是：

```text
0–60 秒
120–150 秒
```

UI必须显示两个灰色区间：

```text
░░░░░░░░░░          ░░░░░
```

禁止画成：

```text
░░░░░░░░░░░░░░░░░░░░░░░
0 ---------------- 150秒
```

否则又会出现“看起来已经缓冲很多，Seek过去却卡”的误导。

### 10.3 普通模式

普通播放器UI只显示：

- 播放进度；
- 灰色真实 `playableRanges`；
- 当前 Thumb。

不显示字节Range、metadata、hole文字，保持简洁。

### 10.4 测试 / 诊断模式

诊断模式在进度条下增加：

```text
前向连续 01:42 · 总缓存 186 MiB · Metadata 16 MiB · Holes 2 · 115 18.4 MiB/s
```

可再提供“Range Map”小条：

- 实灰：连续 playback cache；
- 浅灰：稀疏 playback cache；
- 特殊标记：metadata；
- 空白：hole。

这个诊断条与正式进度条分离，避免把字节空间和时间空间混在一起。

## 11. 当前源码可直接复用的接口

v0.7.10 当前已经存在：

```text
PlayerSnapshot.bufferedRanges
```

AVPlayerEngine 已经使用 `AVPlayerItem.loadedTimeRanges` 生成 `bufferedRanges`。

KSAVIOPlayerEngine 已经用：

```text
currentPlaybackTime ... playableTime
```

生成一个当前连续可播放范围。

因此正式“灰色缓冲条”不需要等待 RangeMap 完成才可以设计；但实现时必须坚持：

- AVPlayer：时间缓冲来自 `loadedTimeRanges`；
- KSPlayer：时间缓冲来自播放器 `playableTime` / 后续真实 demux buffer；
- KTV byte Range 只用于诊断和调度，不能直接换算成播放时间。

## 12. iOS 15 UI 兼容方案

不依赖新 SwiftUI API。

缓冲进度条可以使用成熟 API：

- `GeometryReader`
- `ZStack`
- `Capsule` / `Rectangle`
- `DragGesture`
- `@Published PlayerSnapshot`

因此不会为了缓冲条提高 Deployment Target。

建议最终把现有 `Slider` 替换为自定义 `BufferedTimelineSlider`，保留：

- 拖动 Seek；
- 点击 / 手势；
- 多个灰色缓冲区间；
- 当前进度；
- iOS 15支持。

## 13. 起播 / Rebuffer 阈值

阈值按“可播放时间”定义，不按下载字节定义。

示意状态：

```text
Opening
→ MetadataReady
→ InitialPlayableBufferReady
→ Playing
→ Rebuffering
→ Playing
```

具体秒数在真实实现后由真机数据决定，不在架构阶段硬编码。

重要原则：

- 首次起播阈值可以小；
- Rebuffer恢复阈值应高于首次起播；
- 后台目标缓存可以更大；
- 网络下载仍在健康前进时，不因一个固定墙钟超时直接换传输层。

## 14. 日志规范

下一版架构测试日志必须每隔约1秒或状态变化时记录：

```text
[BufferMap]
engine=...
position=...
playableRanges=[...]
forwardPlayable=...
playbackAnchorByte=...
frontierByte=...
totalCachedBytes=...
metadataCachedBytes=...
holes=[...]
laneA=[start,end,state]
laneB=[start,end,state]
networkBps=...
```

Seek时：

```text
[BufferAnchor]
reason=player-demand
requestedByte=...
oldAnchor=...
newAnchor=...
```

这样以后不再通过“感觉缓存很多”推测底层状态。

## 15. 真机测试矩阵

### 63368

验证：

- 初始播放连续缓存无hole；
- 单通道稳定后双通道可以提高总吞吐；
- A/B始终填充相邻Range；
- 连续双击不反复取消高速连接；
- Seek到灰色buffer范围内应接近即时出画面；
- Seek到灰色范围之外可以等待，但灰条不能提前声称该处已缓存。

### 152901

验证：

- FFmpeg真实读取尾部metadata；
- metadata不污染缓冲进度条；
- 不再固定10秒切AVIO；
- 第一帧时间显著降低；
- 首帧后前向缓存连续；
- Seek落在灰色范围内明显快于未缓冲区；
- 已缓存总MB与灰色时间范围可以分别解释。

### 网络波动

验证：

- lane B失败不制造永久hole；
- lane A优先补前方hole；
- 恢复后连续前沿继续增长；
- UI灰条不会跨过hole。

## 16. 实施阶段

### Phase A — 可观测性

- 固定 / fork KTVHTTPCache；
- 暴露真实 Range 和 CacheSpan / hole；
- 不改变当前下载行为。

### Phase B — RangeMap

- 建立统一 byte RangeMap；
- 连续前沿计算；
- metadata分类；
- 完整日志。

### Phase C — 连续调度

- 单worker连续hole填充；
- 删除time→byte主动Seek猜测；
- 真机验证63368。

### Phase D — 相邻双worker

- 两个相邻32 MiB Range；
- worker完成后按frontier继续分配；
- 真机比较单/双通道总吞吐与错误率。

### Phase E — 152901起播状态机

- metadata真实请求；
- 无固定10秒fallback；
- 明确fatal才AVIO兜底。

### Phase F — BufferedTimelineSlider

- 灰色真实时间缓冲段；
- 正式模式；
- 诊断RangeMap模式；
- iOS 15兼容。

## 17. 设计冻结条件

正式进入 v0.8.x 编码前，设计必须满足：

1. 后台预取不会制造永久hole；
2. Seek不依赖时间比例猜字节；
3. metadata和播放数据分开；
4. 缓冲条展示真实playable time ranges；
5. 总缓存MB不会被当作可播放缓存；
6. 双通道只能填相邻Range；
7. 152901无固定10秒传输fallback；
8. 所有核心逻辑不要求高于iOS 15；
9. NAS不参与媒体字节中转；
10. AVPlayer与FFmpeg均能进入同一缓存观测模型。

## 18. 参考设计依据

- Apple AVPlayerItem `loadedTimeRanges`：可播放数据对应的时间范围，且可以不连续。
- Apple AVPlayerItem `seekableTimeRanges`：可seek时间范围同样可以不连续。
- Android Media3 `Player.getBufferedPosition()`：以媒体时间表示buffered position，而非累计字节。
- KSPlayer：提供 `playableTime` / buffer duration等播放器层缓冲语义。
- Media3 / ExoPlayer CacheSpan / hole思路：缓存区间与hole是调度基础，而非只统计总字节。
- mpv / GStreamer：以readahead、buffering range和可seek范围描述播放缓存。
