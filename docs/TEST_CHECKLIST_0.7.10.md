# EmbyPlayerLab 0.7.10 测试清单

- [ ] GitHub Actions `Validate Source` 通过。
- [ ] 生成 0.7.10 Build 43 unsigned IPA。
- [ ] 63368 启动日志先出现 `staged primary warmup`，约 10 秒后才出现 `dual trial start`。
- [ ] 63368 lane A 在 lane B 启动前能稳定完成多个 32 MiB Range。
- [ ] lane B 出现 `-192703` 后本场不再 `secondary-recover`。
- [ ] 63368 快速连续双击不会出现 `foreground priority`。
- [ ] 152901 自动模式直接 `KSKTV prepared ... transport=KTV-staged-dual`。
- [ ] 152901 启动阶段不再出现 `premature=true current=0.0` 的 EOF。
- [ ] 152901 可正常播放、Seek，并在稳定后进入双通道试验。
