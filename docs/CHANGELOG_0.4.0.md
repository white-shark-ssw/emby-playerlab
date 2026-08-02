# 0.4.0

## 115AVIO Lab 第一阶段

- 冻结 0.3.5 的 Transport AVPlayer 主链，不再继续叠加 Range 参数补丁。
- 新增独立 `115AVIO Lab`，不会启动 AVPlayer、MPV 或 FFmpeg。
- 新增五种可对照的 115 网络基线：
  - 共享会话单开放 Range；
  - 共享会话单有限 Range；
  - 共享会话双连续 Range；
  - 独立会话双连续 Range；
  - 单连接边下载边写临时文件。
- 新增两种请求头配置：沿用 302 请求头、115 最小请求头。
- 记录首字节、平均吞吐、每通道吞吐、HTTP 状态、协议、连接复用、重定向和连接耗时。
- 新增最小 `AVIOByteSource`、`AVIOProbeContext`，验证 `read / seek / fileSize` 逻辑位置语义。
- 支持导出结构化 JSON 实验报告。
- 不记录或导出 115 最终签名 URL。
- 当前未引入 KSPlayer；得到真实基线后再接入 `AbstractAVIOContext`。
- Deployment Target 保持 iOS 15.0。
- 版本更新为 0.4.0（21）。
