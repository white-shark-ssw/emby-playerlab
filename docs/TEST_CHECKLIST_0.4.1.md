# 0.4.1 下载优先传输测试清单

## 构建

1. GitHub Actions `Validate Source` 和 `Build Unsigned IPA` 均成功。
2. 构建报告仍显示 Deployment Target iOS 15.0。
3. IPA 名称包含 `EmbyPlayerLab-0.4.1`。

## 默认设置

- 播放器：自动。
- 传输策略：下载优先（推荐）。
- 磁盘缓存预算：2 GB。
- Wi-Fi 顺序下载：1024 MB。
- Seek 临时预热：16 MB。
- 退出后保留缓存：第一次测试关闭。

## 63368 真机测试

1. 记录点击播放到首帧时间。
2. 连续播放至少 3 分钟，确认没有追到缓冲尾部自动暂停。
3. 观察日志只存在一条 `DownloadFirstMain` 主连接；启动文件尾探测时最多短暂出现一条 `DownloadFirstSeek`。
4. 记录 `DownloadFirstSpeed` 的实时和平均速度。
5. 连续右侧双击 10 次，确认画面目标立即累计，主连接不会每次双击都重建。
6. 拖到 50%、80%、95%，记录新画面耗时。
7. 拖回已经下载的位置，确认本地命中并快速恢复。
8. 退出播放，确认不再出现缓存目录不存在的延迟写入错误。

## 回退验证

设置页把传输策略改为“旧版多 Range”，确认仍能使用 0.4.0 路线播放。

## 期望日志

```text
[TransportPlayer] ... strategy=downloadFirst
[DownloadFirst] ready ... mainConnections=1 seekConnections=1
[DownloadFirstMain] start ... reason=initial
[DownloadFirstNet] lane=main ...
[DownloadFirstSpeed] ... active=1 ...
```

Seek 未命中时允许出现：

```text
[DownloadFirstPriority]
[DownloadFirstSeek]
[DownloadFirstMain] migrated ... reason=settled-seek
```
