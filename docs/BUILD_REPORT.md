# Build Report

- Version: 0.9.2 (48)
- Deployment Target: iOS 15.0
- Target device: iPhone 15 Pro Max / iOS 17.0
- Expected CI: Xcode 16.4, arm64 iPhoneOS Release
- Swift language mode: Swift 5
- KTVHTTPCache: 3.1.0 via CocoaPods; legacy/diagnostic path only
- MPVKit: 0.41.0-n8.1.2 via Swift Package Manager, `MPVKit` LGPL product
- KSPlayer: removed from formal target; legacy source guarded by `canImport(KSPlayer)`
- Automatic native path: AVPlayer + UnifiedMediaTransportSession via AVAssetResourceLoader (no localhost HTTP)
- Automatic compatibility path: libmpv + UnifiedMediaTransportSession via `mpv_stream_cb`; video output uses CAMetalLayer + gpu-next/Vulkan/MoltenVK + VideoToolbox
- Unified cache: DownloadFirstSparseStore + PlaybackRangeMap
- Upstream concurrency: exactly two normal 115/CDN slots; Slot 0 may service urgent playback holes without cancelling Slot 1
- Seek anchor: real AVAssetResourceLoader byte demand / real mpv byte seek only; no time-to-byte proportional guess
- Wi-Fi continuous preload: may use configured disk-cache budget rather than old fixed 128 MiB ceiling
- Cellular background preload: explicit user opt-in
- Buffered timeline: high-contrast persistent verified-history gray layer + current live-buffer layer; `[BufferHistory]` logs prove monotonic history
- Runtime speed/stall engine switching after playback established: disabled
- NAS media proxy: prohibited and not used
- Deployment Target changed: no; remains iOS 15.0
- Local validation: Swift parse, RangeMap smoke, plist/YAML/Ruby/shell checks; mpv stream callback bridge previously typechecked against the official C callback signatures
- Full Objective-C importer validation, SPM binary integration, iPhoneOS link, embedded-framework MinimumOS validation, MPV iOS rendering runtime and unsigned IPA packaging: requires GitHub Actions / real device

## 0.9 architecture boundary

The downloader owns all 115/CDN byte traffic. AVPlayer and MPV are consumers of one shared byte store. Engine selection is a startup playback profile, not a separate network stack. libmpv remains experimental on iOS until the pinned MPVKit Metal renderer is linked in CI and verified on the target iPhone.
