# AetherEngine 6.50.0 — OnePlayer compatibility package

Upstream: `superuser404notfound/AetherEngine`

Upstream tag: `6.50.0`

Upstream commit: `546287f2eef7d810b3947070839a85c653f79e46`

This package keeps the upstream `Sources/AetherEngine` source tree intact except for one dependency-module adaptation:

- `import Dovi` → `import Libdovi`

Reason: OnePlayer already ships MPVKit 1.0.0, which provides the FFmpeg n8.1.2 modules and `Libdovi`. The package intentionally does not depend on Aether's separate FFmpegBuild/LibDovi packages so OnePlayer keeps one FFmpeg implementation in the process.

The upstream LGPLv3 + Apple Store / DRM Exception license is preserved in `LICENSE`.
