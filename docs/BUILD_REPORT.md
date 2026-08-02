# Build Report

- Version: 0.4.1
- Build: 22
- Deployment Target: iOS 15.0
- Target test device: iPhone 15 Pro Max, iOS 17.0
- Project generator: XcodeGen
- GitHub Actions runner: macOS 15
- Requested Xcode: 16.4
- Swift language mode: 5.0
- Existing MPVKit: Streamyfin MPVKit `0.40.0-av`
- New third-party dependencies in 0.4.1: none
- Default MP4 transport: download-first single persistent Range + sparse local file
- Auxiliary connections: at most one temporary metadata/Seek connection
- Legacy multi-Range transport: retained as a settings fallback
- KSPlayer status: researched; not yet linked in 0.4.1
- Local validation: Swift parse, isolated type checks, sparse-range tests, sparse-file read/write tests, Plist, YAML and shell syntax
- Full iPhoneOS type checking/linking: requires GitHub Actions
- iOS 17.0 device behavior: requires physical-device test
