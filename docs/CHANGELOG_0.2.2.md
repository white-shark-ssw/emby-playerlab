# 0.2.2

- 修复 GitHub Actions 首次运行时 `.spm-cache` 尚不存在导致工作流提前失败。
- 将 `Inspect MPV module maps` 移到 `Resolve MPVKit 1.0.0` 之后。
- 模块映射检查改为非阻断诊断步骤。
- 在工作流开始时预创建全部日志文件。
- 即使在依赖解析或编译前失败，也会上传可下载的日志 Artifact。
- Build Unsigned IPA 与 Validate Source 同步修复。
- App 版本更新为 0.2.2（Build 6）。
- module map 检查不使用 Bash 4 的 `mapfile`，兼容 macOS Runner 自带 Bash 3.2。
