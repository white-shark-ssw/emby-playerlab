# OnePlayer 0.14.20 / Build187

- 基于 Build186 carousel drag timing diagnostic，不改变轮播拖动、容器平移、0pt 起拖、一次性锁轴、反向连续、自动轮播或吸附行为。
- 修正诊断导出路径：`HomeCarouselDragTiming` 明确写入 playback channel，使现有“导出播放日志”能够包含首样本位移、锁轴/transition 起点、callback Hz、max gap、maxFPS 与 Low Power Mode 数据。
- 继续继承 accepted Build184 detail performance/cache/visual hierarchy 与 Build176/178/P0/Frozen contracts。
- Deployment Target 保持 iOS 15.0；目标真机 iPhone 15 Pro Max / iOS 17.0。
